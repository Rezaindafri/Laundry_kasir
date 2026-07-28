import '../../../../core/utils/result.dart';
import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<Result<List<TransactionEntity>>> getTransactions();
  Future<Result<TransactionEntity>> create(TransactionEntity transaction);
  Future<Result<TransactionEntity>> update(TransactionEntity transaction);
}
