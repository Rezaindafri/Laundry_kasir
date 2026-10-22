<?php

// Explicit, local-only administrative reset. No credentials are kept in source.
// Requires a full verified SQL backup; deletes rows atomically, never tables.
use App\Models\User;
use App\Services\AccountPolicyService;
use App\Services\AuditLogService;
use Illuminate\Contracts\Http\Kernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Symfony\Component\Process\Process;

require 'D:/laragon/www/api-indafri-laundry/vendor/autoload.php';
$app = require 'D:/laragon/www/api-indafri-laundry/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$backupDirectory = null;
$ownsMaintenance = false;
$committed = false;
$testTokenId = null;
$exitCode = 0;

try {
    $connection = DB::connection();
    $config = $connection->getConfig();
    $database = $connection->getDatabaseName();
    if (!$app->environment('local') || $config['driver'] !== 'mysql' ||
        !in_array($config['host'], ['127.0.0.1', 'localhost', '::1'], true) ||
        $database !== 'indafri_laundry_db' || ($argv[1] ?? '') !== '--reset' ||
        ($argv[2] ?? '') !== $database || ($argv[3] ?? '') !== '--acknowledge-delete') {
        throw new RuntimeException('Refused: local environment/database/explicit acknowledgement mismatch.');
    }
    if ($app->isDownForMaintenance()) throw new RuntimeException('Already in maintenance; refusing to change its state.');
    $expected = ['audit_logs', 'cache', 'cache_locks', 'customers', 'expenses', 'failed_jobs',
        'job_batches', 'jobs', 'laundry_settings', 'migrations', 'password_reset_tokens',
        'payment_destinations', 'personal_access_tokens', 'services', 'sessions',
        'system_settings', 'transaction_details', 'transaction_payments', 'transactions', 'users'];
    $tables = $connection->select('SELECT TABLE_NAME AS name, ENGINE AS engine,
        DATA_LENGTH + INDEX_LENGTH AS bytes FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = ? ORDER BY TABLE_NAME', [$database, 'BASE TABLE']);
    if (array_column($tables, 'name') !== $expected) throw new RuntimeException('Unexpected tables; inspect before resetting.');
    foreach ($tables as $table) {
        if ($table->engine !== 'InnoDB') throw new RuntimeException('Refused: not every table supports transactional rollback.');
    }
    $references = $connection->select('SELECT TABLE_SCHEMA AS child_schema,
        TABLE_NAME AS child, REFERENCED_TABLE_SCHEMA AS parent_schema, REFERENCED_TABLE_NAME AS parent
        FROM information_schema.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_NAME IS NOT NULL
        AND (TABLE_SCHEMA = ? OR REFERENCED_TABLE_SCHEMA = ?)', [$database, $database]);
    foreach ($references as $reference) {
        if ($reference->child_schema !== $database || $reference->parent_schema !== $database) {
            throw new RuntimeException('Cross-database foreign key; reset refused.');
        }
    }
    $pending = array_fill_keys(array_values(array_diff($expected, ['migrations'])), true);
    $order = [];
    while ($pending) {
        $ready = array_filter(array_keys($pending), static function ($name) use ($references, $pending) {
            foreach ($references as $reference) {
                if ($reference->parent === $name && $reference->child !== $name && isset($pending[$reference->child])) return false;
            }
            return true;
        });
        if (!$ready) throw new RuntimeException('Foreign key cycle; reset refused.');
        foreach ($ready as $name) { $order[] = $name; unset($pending[$name]); }
    }
    echo 'Preflight passed. Waiting for credentials on stdin; nothing deleted yet.' . PHP_EOL;
    $line = fgets(STDIN);
    if ($line === false) throw new RuntimeException('No credentials received; nothing changed.');
    $credentials = json_decode($line, true, flags: JSON_THROW_ON_ERROR);
    unset($line);
    $username = $credentials['username'] ?? null;
    $password = $credentials['password'] ?? null;
    $minimum = app(AccountPolicyService::class)->passwordMinLength();
    if (!is_string($username) || !preg_match('/^[A-Za-z0-9_]{1,100}$/D', $username) ||
        !is_string($password) || mb_strlen($password) < $minimum || strlen($password) > 1024) {
        throw new RuntimeException('Requested account does not meet account policy; no reset performed.');
    }
    $dumpExecutable = 'D:/laragon/bin/mysql/mysql-8.4.3-winx64/bin/mysqldump.exe';
    if (!is_file($dumpExecutable)) throw new RuntimeException('Backup utility unavailable; reset refused.');
    $needed = max(64 * 1024 * 1024, 3 * array_sum(array_column($tables, 'bytes')));
    if (disk_free_space('D:/') < $needed) throw new RuntimeException('Insufficient free space for a recovery backup.');
    $backupRoot = 'D:/laragon/private-backups/api-indafri-laundry';
    if (!is_dir($backupRoot) && !mkdir($backupRoot, 0700, true)) throw new RuntimeException('Cannot prepare private backup location.');
    if (strtolower(str_replace('\\', '/', realpath($backupRoot))) !== strtolower($backupRoot)) {
        throw new RuntimeException('Backup path resolves outside the intended location.');
    }
    $stamp = (new DateTimeImmutable('now', new DateTimeZone('Asia/Jakarta')))->format('Ymd-His');
    $backupDirectory = $backupRoot . '/before-reset-' . $stamp . '-' . bin2hex(random_bytes(4));
    if (!mkdir($backupDirectory, 0700)) throw new RuntimeException('Cannot create a new backup; never overwrite old backups.');
    $windowsAccount = getenv('USERDOMAIN') . '\\' . getenv('USERNAME');
    $acl = new Process(['icacls.exe', str_replace('/', '\\', $backupDirectory), '/inheritance:r',
        '/grant:r', $windowsAccount . ':(OI)(CI)F', '*S-1-5-18:(OI)(CI)F']);
    $acl->run();
    if (!$acl->isSuccessful()) throw new RuntimeException('Cannot restrict backup access; reset refused.');
    $sqlFile = $backupDirectory . '/database.sql';
    $optionFile = $backupDirectory . '/mysql-client.cnf';
    $quote = static fn ($value) => '"' . str_replace(['\\', '"', "\n", "\r"],
        ['\\\\', '\\"', '\\n', '\\r'], (string) $value) . '"';
    if (Artisan::call('down', ['--retry' => 60]) !== 0) throw new RuntimeException('Unable to pause API writes.');
    $ownsMaintenance = true;
    $before = [];
    foreach ($expected as $name) $before[$name] = $connection->table($name)->count();
    $migrationsBefore = $connection->table('migrations')->orderBy('id')->get()->toJson();
    try {
        $options = '[client]' . PHP_EOL;
        foreach (['host', 'port', 'username', 'password'] as $key) {
            $iniKey = $key === 'username' ? 'user' : $key;
            $options .= $iniKey . '=' . $quote($config[$key] ?? '') . PHP_EOL;
        }
        if (file_put_contents($optionFile, $options, LOCK_EX) === false) throw new RuntimeException('Cannot prepare backup authentication.');
        unset($options);
        $dump = new Process([$dumpExecutable, '--defaults-extra-file=' . $optionFile,
            '--single-transaction', '--quick', '--no-tablespaces', '--hex-blob',
            '--routines', '--events', '--triggers', '--set-gtid-purged=OFF',
            '--column-statistics=0', '--comments', '--dump-date', '--result-file=' . $sqlFile, $database],
            null, ['MYSQL_PWD' => false]);
        $dump->setTimeout(120);
        $dump->run();
        if (!$dump->isSuccessful() || !is_file($sqlFile) || filesize($sqlFile) < 1024) {
            throw new RuntimeException('Full SQL backup failed; database remains unchanged.');
        }
        $stream = fopen($sqlFile, 'rb');
        fseek($stream, max(0, filesize($sqlFile) - 4096));
        $tail = stream_get_contents($stream); fclose($stream);
        if (!str_contains($tail, '-- Dump completed on ')) throw new RuntimeException('Incomplete backup; reset refused.');
        unset($tail);
    } finally {
        // Only this newly created, exact credentials file is removed.
        if (is_file($optionFile) && !unlink($optionFile)) throw new RuntimeException('Cannot remove temporary client credentials; reset refused.');
    }
    $backupHash = hash_file('sha256', $sqlFile);
    $report = ['database' => $database, 'before_rows' => $before,
        'backup_sql' => $sqlFile, 'backup_sha256' => $backupHash,
        'files_retained' => true, 'schema_and_app_key_unchanged' => true];
    file_put_contents($backupDirectory . '/manifest.json', json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR), LOCK_EX);
    echo 'Full SQL backup verified. Applying atomic row reset.' . PHP_EOL;
    $user = DB::transaction(function () use ($connection, $order, $before, $expected,
        $username, $password, $migrationsBefore) {
        foreach ($order as $name) {
            $connection->table($name)->lockForUpdate()->get(['*']);
            if ($connection->table($name)->count() !== $before[$name]) throw new RuntimeException('Data changed during backup; reset refused.');
        }
        foreach ($order as $name) $connection->table($name)->delete();
        $newUser = User::create(['name' => 'Super Owner', 'username' => $username,
            'email' => null, 'password' => $password, 'role' => 'super_owner',
            'owner_id' => null, 'is_active' => true]);
        if ($connection->table('users')->count() !== 1 || !Hash::check($password, $newUser->password) ||
            $newUser->role !== 'super_owner' || !$newUser->is_active) throw new RuntimeException('Account verification failed; reset rolled back.');
        foreach (array_diff($expected, ['users', 'migrations']) as $name) {
            if ($connection->table($name)->count() !== 0) throw new RuntimeException('Reset incomplete; rolled back.');
        }
        if ($connection->table('migrations')->orderBy('id')->get()->toJson() !== $migrationsBefore) {
            throw new RuntimeException('Migration metadata mismatch; rolled back.');
        }
        app(AuditLogService::class)->record(null, null, 'user', (int) $newUser->id,
            'user.created', ['role' => 'super_owner', 'bootstrap' => true, 'local_reset' => true]);
        return $newUser;
    });
    $committed = true;
    if (Artisan::call('up') !== 0) throw new RuntimeException('Reset committed, but API maintenance could not be released.');
    $ownsMaintenance = false;
    $call = static function (string $method, string $uri, ?array $body = null, ?string $token = null) use ($app) {
        Auth::forgetGuards();
        $request = Request::create($uri, $method, server: ['HTTP_ACCEPT' => 'application/json',
            'CONTENT_TYPE' => 'application/json', 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1'],
            content: $body === null ? null : json_encode($body, JSON_THROW_ON_ERROR));
        if ($token !== null) $request->headers->set('Authorization', 'Bearer ' . $token);
        $kernel = $app->make(Kernel::class);
        $response = $kernel->handle($request);
        $kernel->terminate($request, $response);
        return $response;
    };
    $login = $call('POST', '/api/auth/login', ['username' => $username, 'password' => $password]);
    $payload = json_decode($login->getContent(), true, flags: JSON_THROW_ON_ERROR);
    if ($login->getStatusCode() !== 200 || ($payload['data']['user']['role'] ?? '') !== 'super_owner') {
        throw new RuntimeException('Reset committed; login endpoint verification failed.');
    }
    $token = $payload['data']['token'];
    $testTokenId = (int) explode('|', $token, 2)[0];
    $me = $call('GET', '/api/auth/me', token: $token);
    $dashboard = $call('GET', '/api/dashboard/super-owner', token: $token);
    $operational = $call('GET', '/api/dashboard/owner', token: $token);
    if ($me->getStatusCode() !== 200 || $dashboard->getStatusCode() !== 200 || $operational->getStatusCode() !== 403) {
        throw new RuntimeException('Reset committed; role/access verification failed.');
    }
    $connection->table('personal_access_tokens')->where('id', $testTokenId)->delete();
    $testTokenId = null;
    // Only empty, newly recreated login-rate-limit caches remain after verification.
    $connection->table('cache')->delete();
    $connection->table('cache_locks')->delete();
    unset($credentials, $password, $token, $payload, $login);
    $after = [];
    foreach ($expected as $name) $after[$name] = $connection->table($name)->count();
    $report += ['reset_committed' => true, 'after_rows' => $after,
        'new_account' => $user->only(['id', 'username', 'role', 'is_active']),
        'login_http' => 200, 'auth_me_http' => 200, 'super_owner_dashboard_http' => 200,
        'owner_operational_access_http' => 403, 'test_token_removed' => true];
    file_put_contents($backupDirectory . '/manifest.json', json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR), LOCK_EX);
    echo json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR) . PHP_EOL;
} catch (Throwable $error) {
    // No query/stack/credentials are emitted; application files and backup stay.
    fwrite(STDERR, ($committed ? 'RESET COMMITTED: ' : 'RESET NOT APPLIED: ') .
        ($error instanceof RuntimeException && !$error instanceof Illuminate\Database\QueryException
            ? $error->getMessage() : 'Operation failed; no sensitive details printed.') . PHP_EOL);
    if ($backupDirectory) fwrite(STDERR, 'Recovery backup directory: ' . $backupDirectory . PHP_EOL);
    $exitCode = 1;
} finally {
    if ($testTokenId !== null) DB::table('personal_access_tokens')->where('id', $testTokenId)->delete();
    if ($ownsMaintenance) Artisan::call('up');
}
exit($exitCode);
