import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:laundry_management_system/features/printing/data/services/thermal_receipt_header.dart';
import 'package:laundry_management_system/features/printing/data/services/thermal_receipt_service_native.dart';
import 'package:laundry_management_system/features/transactions/data/models/transaction_model.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';

final _transaction = TransactionModel.fromJson({
  'id': 1,
  'invoice_number': 'INV-20261022-0001',
  'customer_id': 1,
  'customer': {'name': 'Pelanggan Fixture', 'phone': '081234567890'},
  'total_price': 100000,
  'paid_amount': 30000,
  'payment_status': 'downPayment',
  'created_at': '2026-10-22T01:00:00Z',
  'estimated_finish_at': '2026-10-22T03:00:00Z',
  'laundry_status': 'received',
  'transaction_details': [
    {
      'id': 1,
      'service_id': 1,
      'service_name': 'Layanan fixture',
      'service_unit': 'kg',
      'qty': 5,
      'price': 20000,
      'subtotal': 100000,
      'estimated_finish_at': '2026-10-22T03:00:00Z',
      'laundry_status': 'received'
    },
  ],
}).toEntity();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID'));

  for (final width in [384, 576]) {
    test('QR/customer raster header fits $width dots with quiet margin',
        () async {
      final bytes = await buildThermalReceiptHeader(
          invoice: _transaction.invoice,
          customerName: _transaction.customerName,
          customerPhone: _transaction.customerPhone,
          width: width);
      expect(bytes.take(4), [0x1d, 0x76, 0x30, 0]);
      final rowBytes = bytes[4] | bytes[5] << 8;
      final height = bytes[6] | bytes[7] << 8;
      expect(rowBytes * 8, width);
      expect(bytes.length, 8 + rowBytes * height);
      expect(bytes.skip(8).take(rowBytes * 10).every((value) => value == 0),
          isTrue);
      var qrPixels = 0;
      var customerPixels = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < rowBytes; x++) {
          if (bytes[8 + y * rowBytes + x] != 0) {
            if (x < rowBytes ~/ 2) {
              qrPixels++;
            } else {
              customerPixels++;
            }
          }
        }
      }
      expect(qrPixels, greaterThan(100));
      expect(customerPixels, greaterThan(100));
    });
  }

  for (final paper in ['58 mm', '80 mm']) {
    test(
        'compact $paper receipt resets first, keeps totals, only feeds two lines',
        () async {
      final bytes = await ThermalReceiptService().buildReceipt(_transaction,
          businessName: 'Usaha Fixture', paperSize: paper);
      expect(bytes.take(2), [0x1b, 0x40]);
      expect(bytes.sublist(bytes.length - 6), [0x1b, 0x64, 2, 0x1d, 0x56, 0]);
      final body = String.fromCharCodes(bytes);
      expect(body, contains('INV-20261022-0001'));
      expect(body, contains('Rp100.000'));
      expect(body, contains('Rp30.000'));
      expect(body, contains('Rp70.000'));
      expect(body, contains('Layanan fixture'));
    });
  }

  testWidgets(
      'receipt image positions QR/customer side by side and invoice below',
      (tester) async {
    const fontPath = String.fromEnvironment('RECEIPT_PREVIEW_FONT');
    if (fontPath.isNotEmpty) {
      await tester.runAsync(() async {
        await (FontLoader('monospace')
              ..addFont(File(fontPath)
                  .readAsBytes()
                  .then((value) => ByteData.sublistView(value))))
            .load();
      });
    }
    final previewKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: RepaintBoundary(
          key: previewKey,
          child: ReceiptImage(
              transaction: _transaction,
              businessName: 'Usaha Fixture',
              businessPhone: '081111111111')),
    ))));
    final qr = tester.getRect(find.byType(QrImageView));
    final customer = tester.getRect(find.text('Pelanggan Fixture'));
    final invoice = tester.getRect(find.text(_transaction.invoice));
    expect(qr.right, lessThan(customer.left));
    expect(invoice.top, greaterThanOrEqualTo(qr.bottom));
    expect(tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
        'Kode transaksi ${_transaction.invoice}');
    // The service subtotal equals the transaction total in this fixture.
    expect(find.text('Rp100.000'), findsNWidgets(2));
    expect(find.text('Rp30.000'), findsOneWidget);
    expect(find.text('Rp70.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    const path = String.fromEnvironment('RECEIPT_PREVIEW_PATH');
    if (path.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = previewKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(path);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
}
