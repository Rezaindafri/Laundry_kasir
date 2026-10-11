<?php

// Read-only verification of a forward migration. No customer information,
// credentials, files, or database mutations are produced by this script.
$backend = $argv[1] ?? '';
if (!is_file($backend . '/bootstrap/app.php')) {
    throw new RuntimeException('Specify the Laravel project directory.');
}
require $backend . '/vendor/autoload.php';
$app = require $backend . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$tables = [
    'transactions' => ['id', 'owner_id', 'customer_id', 'cashier_id', 'invoice_number',
        'total_price', 'paid_amount', 'payment_status', 'payment_method', 'laundry_status',
        'order_status', 'estimated_finish_at', 'created_at', 'updated_at', 'proof_image_path'],
    'transaction_details' => ['id', 'transaction_id', 'service_id', 'qty', 'price', 'subtotal', 'created_at', 'updated_at'],
    'transaction_payments' => ['id', 'owner_id', 'transaction_id', 'recorded_by', 'amount', 'payment_method', 'paid_at', 'source'],
    'customers' => ['id', 'owner_id', 'created_at', 'updated_at'],
    'services' => ['id', 'owner_id', 'price', 'estimation_hours', 'created_at', 'updated_at'],
];
$result = [];
foreach ($tables as $table => $columns) {
    $hash = hash_init('sha256');
    $count = 0;
    foreach (Illuminate\Support\Facades\DB::table($table)->select($columns)->orderBy('id')->cursor() as $row) {
        hash_update($hash, json_encode($row, JSON_THROW_ON_ERROR));
        $count++;
    }
    $result[$table] = ['count' => $count, 'checksum' => hash_final($hash)];
}
echo json_encode($result, JSON_THROW_ON_ERROR);
