import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_device_service_native.dart';
import 'thermal_receipt_header.dart';
import '../../domain/entities/printer_device.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/utils/receipt_text.dart';

class ThermalReceiptService {
  ThermalReceiptService({PrinterDeviceService? printerDeviceService})
      : _printerDeviceService = printerDeviceService ?? PrinterDeviceService();

  final PrinterDeviceService _printerDeviceService;
  bool _isPrinting = false;
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  static final _dateTime = DateFormat('dd/MM/yy HH:mm', 'id_ID');

  static String buildEstimateSummary(TransactionEntity transaction) {
    if (!transaction.hasEstimatedFinish) return 'tanpa estimasi';
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
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperSize == '80 mm' ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        businessName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      ),
    );
    bytes.addAll(await buildThermalReceiptHeader(
      invoice: transaction.invoice,
      customerName: transaction.customerName,
      customerPhone: transaction.customerPhone,
      width: paperSize == '80 mm' ? 576 : 384,
    ));
    bytes.addAll(generator.text(transaction.invoice,
        styles: const PosStyles(bold: true)));
    bytes.addAll(generator.hr());
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
          text: transaction.hasEstimatedFinish
              ? _dateTime
                  .format(BusinessTime.wallTime(transaction.estimatedFinishAt))
              : 'Tanpa estimasi',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(generator.text('Waktu: WIB',
        styles: const PosStyles(fontType: PosFontType.fontB)));
    bytes.addAll(generator.hr());
    bytes
        .addAll(generator.text('Layanan', styles: const PosStyles(bold: true)));
    for (final line in transaction.serviceLines) {
      bytes.addAll(
          generator.text(line.name, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: '${line.quantity} ${line.unit}', width: 5),
        PosColumn(
            text: _currency.format(line.subtotal),
            width: 7,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      bytes.addAll(generator.text(
          line.estimatedFinishAt == null
              ? (line.hasKnownTiming
                  ? 'Tanpa estimasi'
                  : 'Estimasi tidak tersedia')
              : 'Est. ${_dateTime.format(BusinessTime.wallTime(line.estimatedFinishAt!))} WIB',
          styles: const PosStyles(fontType: PosFontType.fontB)));
      if (line.isCollected)
        bytes.addAll(generator.text('Sudah diambil',
            styles: const PosStyles(fontType: PosFontType.fontB)));
    }
    bytes.addAll(generator.hr());
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
    bytes.addAll(generator.row([
      PosColumn(text: 'Dibayar', width: 5),
      PosColumn(
          text: _currency.format(transaction.paidAmount),
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Sisa', width: 5),
      PosColumn(
          text: _currency
              .format(transaction.remainingPayment.clamp(0, transaction.total)),
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        ReceiptText.thermalCollectionPaymentNote,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Terima kasih.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    // cut() from esc_pos_utils_plus inserts FIVE empty lines, in addition to
    // the former feed(3). Send a cutter command without that hidden padding.
    bytes.addAll(generator.feed(2));
    bytes.addAll([0x1d, 0x56, 0x00]);
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
    var readyToConnect = false;
    try {
      final printerAddress = macAddress.trim();
      if (!RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')
          .hasMatch(printerAddress)) {
        throw const PrinterException(
          'Printer belum dipilih atau alamat printer tidak valid. Pilih kembali printer di Pengaturan.',
        );
      }
      // Check immediately before connecting too, in case permission changed
      // since selection or printing is called outside the transaction screen.
      await _printerDeviceService.ensureReady();
      readyToConnect = true;
      final bytes = await buildReceipt(
        transaction,
        businessName: businessName,
        paperSize: paperSize,
      );

      // The plugin returns false when connect() is called while an old output
      // stream exists. Always close it first so a second receipt can connect.
      await PrintBluetoothThermal.disconnect;
      var connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: printerAddress);
      if (!connected) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await PrintBluetoothThermal.disconnect;
        connected = await PrintBluetoothThermal.connect(
            macPrinterAddress: printerAddress);
      }
      if (!connected) return false;

      return await PrintBluetoothThermal.writeBytes(bytes);
    } on PrinterException {
      rethrow;
    } catch (error) {
      throw PrinterException('Gagal berkomunikasi dengan printer: $error');
    } finally {
      // Do not leave the plugin's stream open: it blocks the next connect().
      if (readyToConnect) {
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {
          // The next print will perform a clean disconnect/reconnect anyway.
        }
      }
      _isPrinting = false;
    }
  }
}
