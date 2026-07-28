import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  group('TransactionEntity', () {
    final transaction = TransactionEntity(
      id: 'trx-001',
      invoice: 'INV-20260728-0001',
      customerId: 'customer-001',
      customerName: 'Andi',
      customerPhone: '081234567890',
      serviceName: 'Cuci Setrika',
      quantity: 3.5,
      quantityUnit: 'Kg',
      unitPrice: 9000,
      expressFee: 0,
      total: 31500,
      paidAmount: 10000,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.downPayment,
      laundryStatus: LaundryStatus.received,
      createdAt: DateTime(2026, 7, 28),
      estimatedFinishAt: DateTime(2026, 7, 30),
    );

    test('menghitung sisa pembayaran dengan benar', () {
      expect(transaction.remainingPayment, 21500);
    });

    test('copyWith memperbarui status tanpa mengubah invoice', () {
      final completed =
          transaction.copyWith(laundryStatus: LaundryStatus.completed);
      expect(completed.laundryStatus, LaundryStatus.completed);
      expect(completed.invoice, transaction.invoice);
    });
  });
}
