import '../../../transactions/domain/entities/transaction_entity.dart';

/// Implementasi web: Bluetooth ESC/POS bukan capability browser yang didukung
/// plugin. Kontrak tetap sama supaya seluruh aplikasi tetap dapat dijalankan.
class ThermalReceiptService {
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
  }) async =>
      const [];

  Future<bool> print(
    TransactionEntity transaction, {
    required String macAddress,
    String businessName = 'CLEAN FRESH LAUNDRY',
    String paperSize = '58 mm',
  }) async =>
      false;
}
