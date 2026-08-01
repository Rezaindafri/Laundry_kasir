import 'package:uuid/uuid.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

class MockTransactionRepository implements TransactionRepository {
  final _uuid = const Uuid();
  final List<TransactionEntity> _items = [];

  @override
  Future<Result<List<TransactionEntity>>> getTransactions() async =>
      Success(List.unmodifiable(_items));

  @override
  Future<Result<TransactionEntity>> create(
      TransactionEntity transaction,) async {
    final item = transaction.id.isEmpty
        ? TransactionEntity(
            id: _uuid.v4(),
            invoice: transaction.invoice,
            customerId: transaction.customerId,
            customerName: transaction.customerName,
            customerPhone: transaction.customerPhone,
            serviceName: transaction.serviceName,
            quantity: transaction.quantity,
            quantityUnit: transaction.quantityUnit,
            unitPrice: transaction.unitPrice,
            expressFee: transaction.expressFee,
            total: transaction.total,
            paidAmount: transaction.paidAmount,
            paymentMethod: transaction.paymentMethod,
            paymentStatus: transaction.paymentStatus,
            laundryStatus: transaction.laundryStatus,
            createdAt: transaction.createdAt,
            estimatedFinishAt: transaction.estimatedFinishAt,
            notes: transaction.notes,
          )
        : transaction;
    _items.insert(0, item);
    return Success(item);
  }

  @override
  Future<Result<TransactionEntity>> update(
      TransactionEntity transaction,) async {
    final index = _items.indexWhere((item) => item.id == transaction.id);
    if (index >= 0) _items[index] = transaction;
    return Success(transaction);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _items.removeWhere((item) => item.id == id);
    return const Success(null);
  }
}
