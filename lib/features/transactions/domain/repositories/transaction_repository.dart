import '../../../../core/utils/result.dart';
import '../entities/transaction_entity.dart';
import '../entities/transaction_page_entity.dart';

import 'dart:typed_data';

abstract class TransactionRepository {
  Future<Result<List<TransactionEntity>>> getTransactions();
  Future<Result<TransactionEntity>> getById(String id);
  Future<Result<TransactionPageEntity>> getTransactionsPage(
    Map<String, dynamic> query,
  );
  Future<Result<TransactionEntity>> create(TransactionEntity transaction);
  Future<Result<TransactionEntity>> update(TransactionEntity transaction);
  Future<Result<TransactionEntity>> pay(
      {required TransactionEntity transaction,
      required int amount,
      required PaymentMethod method,
      String? note,
      required String requestId});
  Future<Result<TransactionEntity>> collect({
    required TransactionEntity transaction,
    required bool settlePayment,
    Uint8List? proofImage,
    List<String>? detailIds,
    int? paymentAmount,
    String? paymentNote,
  });
  Future<Result<void>> delete(String id);
}
