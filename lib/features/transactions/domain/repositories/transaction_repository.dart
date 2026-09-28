import '../../../../core/utils/result.dart';
import '../entities/transaction_entity.dart';
import '../entities/transaction_page_entity.dart';

import 'dart:typed_data';

abstract class TransactionRepository {
  Future<Result<List<TransactionEntity>>> getTransactions();
  Future<Result<TransactionPageEntity>> getTransactionsPage(
    Map<String, dynamic> query,
  );
  Future<Result<TransactionEntity>> create(TransactionEntity transaction);
  Future<Result<TransactionEntity>> update(TransactionEntity transaction);
  Future<Result<TransactionEntity>> collect({
    required TransactionEntity transaction,
    required bool settlePayment,
    Uint8List? proofImage,
  });
  Future<Result<void>> delete(String id);
}
