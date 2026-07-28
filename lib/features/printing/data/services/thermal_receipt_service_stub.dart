import '../../../transactions/domain/entities/transaction_entity.dart';

/// Implementasi web: Bluetooth ESC/POS bukan capability browser yang didukung
/// plugin. Kontrak tetap sama supaya seluruh aplikasi tetap dapat dijalankan.
class ThermalReceiptService {
  Future<List<int>> buildReceipt(
    TransactionEntity transaction, {
    String businessName = 'CLEAN FRESH LAUNDRY',
  }) async =>
      const [];

  Future<bool> print(
    TransactionEntity transaction, {
    required String macAddress,
    String businessName = 'CLEAN FRESH LAUNDRY',
  }) async =>
      false;
}
