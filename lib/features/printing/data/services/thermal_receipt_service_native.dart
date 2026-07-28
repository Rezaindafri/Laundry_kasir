import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

class ThermalReceiptService {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  static final _date = DateFormat('dd/MM/yy');

  Future<List<int>> buildReceipt(
    TransactionEntity transaction, {
    String businessName = 'CLEAN FRESH LAUNDRY',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    bytes.addAll(
      generator.text(
        businessName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'KODE PENGAMBILAN',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.qrcode(
        transaction.invoice,
        align: PosAlign.center,
        size: QRSize.size5,
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Pelanggan', width: 9),
        PosColumn(
          text: transaction.customerName,
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Masuk', width: 6),
        PosColumn(
          text: _date.format(transaction.createdAt),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Selesai', width: 6),
        PosColumn(
          text: _date.format(transaction.estimatedFinishAt),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Layanan', width: 5),
        PosColumn(
          text: transaction.serviceName,
          width: 7,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Jumlah', width: 5),
        PosColumn(
          text: '${transaction.quantity} ${transaction.quantityUnit}',
          width: 7,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Total', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: _currency.format(transaction.total),
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Status', width: 5),
        PosColumn(
          text: transaction.paymentStatus.label.toUpperCase(),
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'Tunjukkan bon ini saat',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'pengambilan laundry.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Terima kasih.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<bool> print(
    TransactionEntity transaction, {
    required String macAddress,
    String businessName = 'CLEAN FRESH LAUNDRY',
  }) async {
    final connected =
        await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (!connected) return false;
    return PrintBluetoothThermal.writeBytes(
      await buildReceipt(transaction, businessName: businessName),
    );
  }
}
