import 'package:intl/intl.dart';

/// Shared wording for thermal receipts, receipt images and their WhatsApp caption.
abstract class ReceiptText {
  static const _noteStart = 'Tunjukkan bon ini saat';
  static const _noteAction = 'melakukan pengambilan/pembayaran';
  static const _noteEnd = 'transaksi.';
  static const collectionPaymentNote = '$_noteStart $_noteAction $_noteEnd';
  // Keep each thermal line at most 32 characters for standard 58 mm paper.
  static const thermalCollectionPaymentNote =
      '$_noteStart\n$_noteAction\n$_noteEnd';

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String whatsAppCaption({
    required String customerName,
    required String businessName,
    required String invoice,
    required int total,
  }) {
    final customer = customerName.trim();
    final business = businessName.trim();
    final sender = business.isEmpty ? 'Kami' : 'Kami dari $business';
    return 'Halo ${customer.isEmpty ? 'Pelanggan' : customer},\n\n'
        '$sender mohon izin mengirimkan struk transaksi Anda.\n\n'
        'Nomor transaksi: $invoice\n'
        'Total transaksi: *${_currency.format(total)}*\n\n'
        'Struk transaksi terlampir pada pesan ini.\n'
        'Terima kasih atas kepercayaan Anda.';
  }
}
