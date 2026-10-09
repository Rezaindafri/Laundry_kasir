import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../domain/entities/printer_device.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../../core/utils/business_time.dart';

class ThermalReceiptService {
  bool _isPrinting = false;
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  static final _dateTime = DateFormat('dd/MM/yy HH:mm', 'id_ID');

  static String buildEstimateSummary(TransactionEntity transaction) {
    final diff =
        transaction.estimatedFinishAt.difference(transaction.createdAt);
    final totalHours = diff.inHours;
    if (totalHours <= 0) return 'segera';

    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    if (days > 0 && hours > 0) {
      return '$days hari $hours jam';
    }
    if (days > 0) {
      return '$days hari';
    }
    return '$totalHours jam';
  }

  Future<List<int>> buildReceipt(
    TransactionEntity transaction, {
    String businessName = 'CLEAN FRESH LAUNDRY',
    String paperSize = '58 mm',
  }) async {
    final printedAt = DateTime.now();
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperSize == '80 mm' ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
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
          text: _dateTime.format(BusinessTime.wallTime(transaction.createdAt)),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Estimasi', width: 6),
        PosColumn(
          text: _dateTime
              .format(BusinessTime.wallTime(transaction.estimatedFinishAt)),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Bon', width: 6),
        PosColumn(
          text: _dateTime.format(BusinessTime.wallTime(printedAt)),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(generator.text('Waktu pada bon: WIB'));
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
        PosColumn(text: 'Estimasi', width: 5),
        PosColumn(
          text: buildEstimateSummary(transaction),
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
    String paperSize = '58 mm',
  }) async {
    if (_isPrinting) {
      throw const PrinterException(
          'Proses cetak masih berjalan. Tunggu sebentar.');
    }
    _isPrinting = true;
    try {
      final bytes = await buildReceipt(
        transaction,
        businessName: businessName,
        paperSize: paperSize,
      );

      // The plugin returns false when connect() is called while an old output
      // stream exists. Always close it first so a second receipt can connect.
      await PrintBluetoothThermal.disconnect;
      var connected =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (!connected) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await PrintBluetoothThermal.disconnect;
        connected =
            await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      }
      if (!connected) return false;

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (error) {
      throw PrinterException('Gagal berkomunikasi dengan printer: $error');
    } finally {
      // Do not leave the plugin's stream open: it blocks the next connect().
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {
        // The next print will perform a clean disconnect/reconnect anyway.
      }
      _isPrinting = false;
    }
  }
}
