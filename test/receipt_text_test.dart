import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/utils/receipt_text.dart';
import 'package:laundry_management_system/core/utils/whatsapp_receipt_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('thermal footer keeps the same wording within 58 mm line widths', () {
    final lines = ReceiptText.thermalCollectionPaymentNote.split('\n');
    expect(lines.every((line) => line.length <= 32), isTrue);
    expect(lines.join(' '), ReceiptText.collectionPaymentNote);
    expect(lines.join(' '),
        'Tunjukkan bon ini saat melakukan pengambilan/pembayaran transaksi.');
  });

  test(
      'caption contains customer, business, invoice and bold full transaction total',
      () {
    final message = ReceiptText.whatsAppCaption(
        customerName: '  Sinta  ',
        businessName: '  Usaha Kita  ',
        invoice: 'INV-TEST',
        total: 100000);
    expect(
        message,
        'Halo Sinta,\n\n'
        'Kami dari Usaha Kita mohon izin mengirimkan struk transaksi Anda.\n\n'
        'Nomor transaksi: INV-TEST\n'
        'Total transaksi: *Rp100.000*\n\n'
        'Struk transaksi terlampir pada pesan ini.\n'
        'Terima kasih atas kepercayaan Anda.');
    expect(message, isNot(contains('**')));
    expect(message, isNot(contains('bon laundry')));
  });

  test('currency keeps full rupiah amounts for zero and large totals', () {
    for (final amount in {0: 'Rp0', 1234567890: 'Rp1.234.567.890'}.entries) {
      expect(
          ReceiptText.whatsAppCaption(
              customerName: 'Pelanggan',
              businessName: 'Usaha',
              invoice: 'INV-TEST',
              total: amount.key),
          contains('Total transaksi: *${amount.value}*'));
    }
  });

  test('missing names do not invent a business identity', () {
    final message = ReceiptText.whatsAppCaption(
        customerName: ' ', businessName: '', invoice: 'INV-TEST', total: 10000);
    expect(message, startsWith('Halo Pelanggan,\n\nKami mohon izin'));
    expect(message, isNot(contains('Kami dari ')));
  });

  test('receipt bridge preserves multiline caption and WhatsApp bold markup',
      () async {
    const channel =
        MethodChannel('com.example.laundry_management_system/whatsapp_receipt');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final message = ReceiptText.whatsAppCaption(
        customerName: 'Sinta',
        businessName: 'Usaha Kita',
        invoice: 'INV-TEST',
        total: 100000);
    expect(
        await WhatsAppReceiptLauncher.open(
            phone: '081234567890',
            image: Uint8List.fromList([1, 2, 3]),
            message: message,
            filename: 'bon-INV-TEST.png'),
        isTrue);
    expect(received!.method, 'openReceiptChat');
    final payload = received!.arguments as Map;
    expect(payload['message'], message);
    expect(payload['phone'], '6281234567890');
    expect(payload['filename'], 'bon-INV-TEST.png');
    expect(payload['image'], [1, 2, 3]);
  });
}
