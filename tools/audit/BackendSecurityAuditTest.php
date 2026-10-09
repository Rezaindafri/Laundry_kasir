<?php

/**
 * Diagnostic security checks, intentionally separate from the normal suite.
 * Run with the backend's phpunit.xml and SQLite :memory: (see audit report).
 * Failing checks describe defects; they are not workarounds or mocked fixes.
 */

use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\LaundrySetting;
use App\Models\Service;
use App\Models\Transaction;
use App\Models\TransactionPayment;
use App\Models\User;
use App\Services\AuditLogService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class BackendSecurityAuditTest extends TestCase
{
    use RefreshDatabase;

    public function createApplication()
    {
        $app = parent::createApplication();
        if (config('database.default') !== 'sqlite' || config('database.connections.sqlite.database') !== ':memory:') {
            throw new RuntimeException('Refusing audit: cached configuration does not use SQLite :memory:.');
        }
        return $app;
    }

    protected function setUp(): void
    {
        // Abort before RefreshDatabase can run if the command was misconfigured.
        if (getenv('DB_CONNECTION') !== 'sqlite' || getenv('DB_DATABASE') !== ':memory:') {
            throw new RuntimeException('Audit requires DB_CONNECTION=sqlite and DB_DATABASE=:memory:.');
        }
        parent::setUp();
        $this->assertSame('sqlite', config('database.default'));
        $this->assertSame(':memory:', config('database.connections.sqlite.database'));
    }

    private function account(string $role, string $username, ?int $ownerId = null): User
    {
        return User::create([
            'name' => $username, 'username' => $username,
            'password' => bcrypt('audit-only-password'), 'role' => $role,
            'owner_id' => $ownerId, 'is_active' => true,
        ]);
    }

    private function token(User $user): string
    {
        Auth::forgetGuards();
        $response = $this->postJson('/api/auth/login', [
            'username' => $user->username, 'password' => 'audit-only-password',
        ])->assertOk();
        $this->assertArrayNotHasKey('password', $response->json('data.user'));
        return $response->json('data.token');
    }

    private function asToken(string $token): array
    {
        Auth::forgetGuards();
        return ['Authorization' => 'Bearer ' . $token];
    }

    private function order(User $owner, array $changes = []): Transaction
    {
        $customer = Customer::create(['owner_id' => $owner->id, 'name' => 'Audit customer']);
        return Transaction::create(array_replace([
            'owner_id' => $owner->id, 'cashier_id' => $owner->id,
            'customer_id' => $customer->id, 'invoice_number' => 'INV-AUDIT-' . uniqid(),
            'total_price' => 100000, 'paid_amount' => 0, 'payment_status' => 'unpaid',
            'payment_method' => 'cash', 'laundry_status' => 'received', 'order_status' => 'new',
            'estimated_finish_at' => now()->addHours(2),
        ], $changes));
    }

    public function test_real_bearer_cashier_owner_and_super_owner_workflow(): void
    {
        $owner = $this->account('owner', 'audit_owner');
        $other = $this->account('owner', 'audit_other');
        $cashier = $this->account('kasir', 'audit_cashier', $owner->id);
        $super = $this->account('super_owner', 'audit_super');
        $ownerToken = $this->token($owner);
        $cashierToken = $this->token($cashier);
        $superToken = $this->token($super);
        $service = $this->postJson('/api/services', [
            'name' => 'Audit service', 'price' => 100000, 'unit' => 'kg', 'estimation_hours' => 2,
        ], $this->asToken($ownerToken))->assertCreated()->json('data');
        $customer = $this->postJson('/api/customers', ['name' => 'Audit customer'],
            $this->asToken($cashierToken))->assertCreated()->json('data');
        $order = $this->postJson('/api/transactions', [
            'customer_id' => $customer['id'], 'paid_amount' => 30000,
            'services' => [['service_id' => $service['id'], 'qty' => 1, 'price' => 1]],
        ], $this->asToken($cashierToken))->assertCreated()
            ->assertJsonPath('data.total_price', 100000)
            ->assertJsonPath('data.payment_status', 'downPayment')->json('data');
        $this->postJson('/api/transactions/' . $order['id'] . '/collection', ['settle_payment' => 1],
            $this->asToken($cashierToken))->assertUnprocessable();
        $this->travel(3)->hours();
        $this->postJson('/api/transactions/' . $order['id'] . '/payment', ['paid_amount' => 100000],
            $this->asToken($ownerToken))->assertOk();
        $this->postJson('/api/transactions/' . $order['id'] . '/collection', ['settle_payment' => 0],
            $this->asToken($cashierToken))->assertOk()->assertJsonPath('data.laundry_status', 'collected');
        $report = $this->getJson('/api/reports/overview', $this->asToken($ownerToken))->assertOk();
        $this->assertSame(100000, $report->json('data.summary.payments_received'));
        $this->assertSame(0, $report->json('data.summary.outstanding_amount'));
        $this->assertCount(2, $report->json('data.payments'));
        $this->assertEquals(100000, TransactionPayment::where('transaction_id', $order['id'])->sum('amount'));
        $this->getJson('/api/transactions/' . $order['id'], $this->asToken($this->token($other)))->assertNotFound();
        $this->getJson('/api/users', $this->asToken($cashierToken))->assertForbidden();
        $this->getJson('/api/reports/overview', $this->asToken($cashierToken))->assertForbidden();
        $this->getJson('/api/dashboard/super-owner', $this->asToken($superToken))->assertOk();
        $this->getJson('/api/transactions', $this->asToken($superToken))->assertForbidden();
        $this->getJson('/api/reports/overview', $this->asToken($superToken))->assertForbidden();
        $this->assertDatabaseHas('audit_logs', ['actor_id' => $owner->id, 'action' => 'transaction.payment_recorded']);
    }

    public function test_logout_revokes_a_real_bearer_token(): void
    {
        $owner = $this->account('owner', 'audit_logout');
        $token = $this->token($owner);
        $response = $this->postJson('/api/auth/logout', [], $this->asToken($token));
        // Keep diagnostic output short; the HTTP status is enough to reproduce.
        $this->assertSame(200, $response->status(), 'Logout must revoke the token without HTTP 500.');
        $this->getJson('/api/customers', $this->asToken($token))->assertUnauthorized();
    }

    public function test_injection_strings_do_not_bypass_login_or_owner_scope(): void
    {
        $owner = $this->account('owner', 'audit_injection');
        $this->postJson('/api/auth/login', ['username' => "' OR 1=1 --", 'password' => 'x'])->assertUnauthorized();
        $this->getJson('/api/transactions?search=' . urlencode("' OR 1=1 --"),
            $this->asToken($this->token($owner)))->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_upload_rejects_executable_and_oversized_image(): void
    {
        $owner = $this->account('owner', 'audit_upload');
        $order = $this->order($owner, ['estimated_finish_at' => now()->subMinute()]);
        Storage::fake('public');
        $token = $this->token($owner);
        foreach ([UploadedFile::fake()->create('payload.php', 1, 'application/x-httpd-php'),
            UploadedFile::fake()->image('too-big.jpg')->size(2049)] as $file) {
            $this->postJson('/api/transactions/' . $order->id . '/collection', [
                'settle_payment' => 1, 'proof_image' => $file,
            ], $this->asToken($token))->assertUnprocessable();
        }
        $this->assertEquals(0, $order->fresh()->paid_amount);
        $this->assertEquals(0, TransactionPayment::count());
        $this->assertCount(0, Storage::disk('public')->allFiles());
    }

    public function test_collected_order_cannot_be_reopened_via_status_api(): void
    {
        $owner = $this->account('owner', 'audit_reopen');
        $order = $this->order($owner, ['laundry_status' => 'collected', 'order_status' => 'delivered',
            'paid_amount' => 100000, 'payment_status' => 'paid']);
        $this->patchJson('/api/transactions/' . $order->id . '/status', ['laundry_status' => 'received'],
            $this->asToken($this->token($owner)))->assertUnprocessable();
        $this->assertSame('collected', $order->fresh()->laundry_status);
    }

    public function test_login_is_rate_limited(): void
    {
        $limited = false;
        for ($i = 0; $i < 25; $i++) {
            Auth::forgetGuards();
            $response = $this->postJson('/api/auth/login', ['username' => 'audit_missing', 'password' => 'x']);
            if ($response->status() === 429) { $limited = true; break; }
        }
        $this->assertTrue($limited, '25 failed logins accepted without HTTP 429.');
    }

    public function test_token_is_rejected_after_thirty_days(): void
    {
        $owner = $this->account('owner', 'audit_expiry');
        $token = $this->token($owner);
        $this->travel(31)->days();
        $this->getJson('/api/profile', $this->asToken($token))->assertUnauthorized();
    }

    public function test_password_change_revokes_other_sessions(): void
    {
        $owner = $this->account('owner', 'audit_password');
        $oldToken = $this->token($owner);
        $currentToken = $this->token($owner);
        $this->patchJson('/api/profile/password', [
            'current_password' => 'audit-only-password', 'password' => 'audit-new-password',
            'password_confirmation' => 'audit-new-password',
        ], $this->asToken($currentToken))->assertOk();
        $this->getJson('/api/profile', $this->asToken($oldToken))->assertUnauthorized();
    }

    public function test_unauthenticated_api_without_accept_header_returns_401(): void
    {
        $this->get('/api/customers')->assertUnauthorized();
    }

    public function test_api_error_does_not_disclose_internal_exception(): void
    {
        $owner = $this->account('owner', 'audit_error');
        $order = $this->order($owner);
        $token = $this->token($owner);
        config(['app.debug' => false]);
        $audit = Mockery::mock(AuditLogService::class);
        $audit->shouldReceive('record')->andThrow(new RuntimeException('AUDIT_INTERNAL_DETAIL'));
        $this->app->instance(AuditLogService::class, $audit);
        $response = $this->postJson('/api/transactions/' . $order->id . '/payment', ['paid_amount' => 30000],
            $this->asToken($token))->assertStatus(500);
        $this->assertEquals(0, $order->fresh()->paid_amount);
        $this->assertEquals(0, TransactionPayment::count());
        $this->assertStringNotContainsString('AUDIT_INTERNAL_DETAIL', $response->getContent());
    }

    public function test_csv_does_not_export_customer_name_as_spreadsheet_formula(): void
    {
        $owner = $this->account('owner', 'audit_csv');
        $order = $this->order($owner);
        $order->customer->update(['name' => '=1+1']);
        $token = $this->token($owner);
        $this->postJson('/api/transactions/' . $order->id . '/payment', ['paid_amount' => 30000],
            $this->asToken($token))->assertOk();
        $csv = $this->get('/api/reports/export?type=csv', $this->asToken($token))->assertOk()->getContent();
        $this->assertStringNotContainsString(',=1+1,', $csv);
    }

    public function test_restore_rejects_entire_backup_before_applying_any_rows(): void
    {
        $super = $this->account('super_owner', 'audit_restore_super');
        $owner = $this->account('owner', 'audit_restore_owner');
        $cashier = $this->account('kasir', 'audit_restore_cashier', $owner->id);
        LaundrySetting::create(['owner_id' => $owner->id, 'business_name' => 'Original name',
            'phone' => '', 'address' => '']);
        $this->postJson('/api/settings/restore', [
            'version' => 2, 'type' => 'owner_configuration_backup',
            'settings' => [
                ['owner_id' => $owner->id, 'business_name' => 'Unexpected replacement'],
                ['owner_id' => $cashier->id, 'business_name' => 'Not an owner'],
            ],
        ], $this->asToken($this->token($super)))->assertUnprocessable();
        $this->assertDatabaseHas('laundry_settings', [
            'owner_id' => $owner->id, 'business_name' => 'Original name',
        ]);
    }

    public function test_owner_with_dependents_cannot_be_demoted_to_cashier(): void
    {
        $super = $this->account('super_owner', 'audit_demote_super');
        $owner = $this->account('owner', 'audit_demote_owner');
        $other = $this->account('owner', 'audit_demote_other');
        $this->account('kasir', 'audit_demote_cashier', $owner->id);
        $this->order($owner);
        $this->patchJson('/api/users/' . $owner->id, [
            'role' => 'kasir', 'owner_id' => $other->id,
        ], $this->asToken($this->token($super)))->assertUnprocessable();
        $this->assertSame('owner', $owner->fresh()->role);
    }
}
