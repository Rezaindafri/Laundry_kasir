import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/printing/data/services/thermal_receipt_service.dart';
import 'package:laundry_management_system/features/transactions/data/models/transaction_model.dart';
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

    test('status waktu mengikuti backend dan tidak dihitung ulang di Flutter',
        () {
      final createdAt = DateTime(2026, 7, 28, 10, 0);
      final estimatedFinishAt = createdAt.add(const Duration(hours: 3));
      final transactionWithEstimate = TransactionEntity(
        id: 'trx-002',
        invoice: 'INV-002',
        customerId: 'customer-002',
        customerName: 'Budi',
        customerPhone: '081234567890',
        serviceName: 'Cuci Kering',
        quantity: 2,
        quantityUnit: 'Kg',
        unitPrice: 6000,
        expressFee: 0,
        total: 12000,
        paidAmount: 0,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.unpaid,
        laundryStatus: LaundryStatus.received,
        createdAt: createdAt,
        estimatedFinishAt: estimatedFinishAt,
      );

      expect(
        transactionWithEstimate
            .resolveLaundryStatusAt(createdAt.add(const Duration(hours: 1))),
        LaundryStatus.received,
      );
      expect(
        transactionWithEstimate.resolveLaundryStatusAt(estimatedFinishAt),
        LaundryStatus.received,
      );
      expect(
        transactionWithEstimate.resolveLaundryStatusAt(
          estimatedFinishAt.add(const Duration(hours: 5)),
        ),
        LaundryStatus.received,
      );
    });

    test('estimasi layanan bisa diatur dalam hari dan dikonversi ke jam', () {
      final service = LaundryServiceEntity(
        id: 'svc-001',
        name: 'Cuci Kering',
        price: 12000,
        unit: 'kg',
        estimatedHours: 2,
        estimateUnit: EstimateDurationUnit.days,
      );

      expect(service.estimatedDurationInHours, 48);
      expect(service.estimatedDurationLabel, '2 hari');
    });

    test('payload transaksi mengirimkan data pelanggan dan layanan', () {
      final model = TransactionModel(
        id: 1,
        invoice: 'INV-001',
        customerId: 10,
        serviceId: 99,
        customerName: 'Andi',
        customerPhone: '081234567890',
        serviceName: 'Cuci Setrika',
        quantity: 3.5,
        quantityUnit: 'Kg',
        unitPrice: 9000,
        expressFee: 0,
        total: 31500,
        paidAmount: 0,
        paymentMethod: 'cash',
        paymentStatus: 'unpaid',
        laundryStatus: 'received',
        createdAt: DateTime(2026, 7, 28),
        details: const [],
      );

      final payload = model.toJson(forRequest: true);

      expect(payload['customer_id'], 10);
      expect(payload['payment_status'], 'unpaid');
      expect(payload['services'], isA<List>());
      expect(payload['services'][0]['service_id'], 99);
      expect(payload['services'][0]['qty'], 3.5);
      expect(payload['services'][0]['price'], 9000);
    });

    test('estimasi bon menampilkan durasi yang bisa dibaca', () {
      final transaction = TransactionEntity(
        id: 'trx-003',
        invoice: 'INV-003',
        customerId: 'customer-003',
        customerName: 'Dina',
        customerPhone: '081234567890',
        serviceName: 'Setrika',
        quantity: 1,
        quantityUnit: 'item',
        unitPrice: 5000,
        expressFee: 0,
        total: 5000,
        paidAmount: 0,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.unpaid,
        laundryStatus: LaundryStatus.received,
        createdAt: DateTime(2026, 7, 28, 10, 0),
        estimatedFinishAt: DateTime(2026, 7, 28, 13, 0),
      );

      expect(ThermalReceiptService.buildEstimateSummary(transaction), '3 jam');
    });
  });
}
