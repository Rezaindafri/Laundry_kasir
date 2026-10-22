<?php

// Read-only preflight. Deliberately never prints credentials, keys or row data.
require 'D:/laragon/www/api-indafri-laundry/vendor/autoload.php';
$app = require 'D:/laragon/www/api-indafri-laundry/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$connection = Illuminate\Support\Facades\DB::connection();
$config = $connection->getConfig();
if (!$app->environment('local') || $config['driver'] !== 'mysql' ||
    !in_array($config['host'], ['127.0.0.1', 'localhost', '::1'], true)) {
    fwrite(STDERR, 'Refused: target is not local Laragon MySQL.' . PHP_EOL);
    exit(1);
}
$database = $connection->getDatabaseName();
$tables = $connection->select('SELECT TABLE_NAME AS name, ENGINE AS engine,
    DATA_LENGTH + INDEX_LENGTH AS bytes FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = ? ORDER BY TABLE_NAME', [$database, 'BASE TABLE']);
$inventory = [];
foreach ($tables as $table) {
    $inventory[] = ['table' => $table->name, 'engine' => $table->engine,
        'rows' => $connection->table($table->name)->count(), 'bytes' => (int) $table->bytes];
}
$references = $connection->select('SELECT TABLE_NAME AS child, COLUMN_NAME AS column_name,
    REFERENCED_TABLE_SCHEMA AS parent_schema, REFERENCED_TABLE_NAME AS parent
    FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = ?
    AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME', [$database]);
echo json_encode(['environment' => $app->environment(), 'host' => $config['host'],
    'database' => $database, 'tables' => $inventory, 'foreign_keys' => $references,
    'roles' => $connection->table('users')->selectRaw('role, COUNT(*) AS count')
        ->groupBy('role')->get()->all()], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR) . PHP_EOL;
