import 'package:uuid/uuid.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_page_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

import 'dart:typed_data';

class MockTransactionRepository implements TransactionRepository {
  final _uuid = const Uuid();
  final List<TransactionEntity> _items = [];

  @override
  Future<Result<List<TransactionEntity>>> getTransactions() async =>
      Success(List.unmodifiable(_items));

  @override
  Future<Result<TransactionPageEntity>> getTransactionsPage(
    Map<String, dynamic> query,
  ) async {
    final page = (query['page'] as num?)?.toInt() ?? 1;
    final perPage = (query['per_page'] as num?)?.toInt() ?? 20;
    final start = (page - 1) * perPage;
    final end = start + perPage > _items.length ? _items.length : start + perPage;
    return Success(TransactionPageEntity(
      items: start >= _items.length ? const [] : _items.sublist(start, end),
      currentPage: page,
      lastPage: _items.isEmpty ? 1 : (_items.length / perPage).ceil(),
      total: _items.length,
    ));
  }

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
  Future<Result<TransactionEntity>> collect({
    required TransactionEntity transaction,
    required bool settlePayment,
    Uint8List? proofImage,
  }) async {
    final collected = transaction.copyWith(
      laundryStatus: LaundryStatus.collected,
      paymentStatus:
          settlePayment ? PaymentStatus.paid : transaction.paymentStatus,
      paidAmount: settlePayment ? transaction.total : transaction.paidAmount,
    );
    return update(collected);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _items.removeWhere((item) => item.id == id);
    return const Success(null);
  }
}
