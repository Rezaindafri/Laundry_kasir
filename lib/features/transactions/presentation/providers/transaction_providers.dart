import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../data/repositories/mock_transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) => MockTransactionRepository());
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionEntity>>(
        TransactionsNotifier.new,);

class TransactionsNotifier extends AsyncNotifier<List<TransactionEntity>> {
  @override
  Future<List<TransactionEntity>> build() async {
    final result =
        await ref.read(transactionRepositoryProvider).getTransactions();
    return result.when(
        success: (items) => items, error: (failure) => throw failure,);
  }

  Future<Result<TransactionEntity>> create(
      TransactionEntity transaction,) async {
    final result =
        await ref.read(transactionRepositoryProvider).create(transaction);
    result.when(
      success: (item) => state =
          AsyncData(<TransactionEntity>[item, ...(state.valueOrNull ?? [])]),
      error: (_) {},
    );
    return result;
  }

  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async {
    final result =
        await ref.read(transactionRepositoryProvider).update(transaction);
    result.when(
      success: (item) {
        final items = <TransactionEntity>[...(state.valueOrNull ?? [])];
        final index = items.indexWhere((value) => value.id == item.id);
        if (index >= 0) items[index] = item;
        state = AsyncData(items);
      },
      error: (_) {},
    );
    return result;
  }
}
