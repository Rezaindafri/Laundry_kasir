import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/mock_transaction_repository.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

import 'dart:typed_data';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  if (AppConstants.useMockApi) {
    return MockTransactionRepository();
  }
  return TransactionRepositoryImpl(
    remoteDataSource: TransactionRemoteDataSourceImpl(DioClient().dio),
  );
});
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionEntity>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<TransactionEntity>> {
  @override
  Future<List<TransactionEntity>> build() async {
    final result =
        await ref.read(transactionRepositoryProvider).getTransactions();
    return result.when(
      success: (items) => items,
      error: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<Result<TransactionEntity>> create(
    TransactionEntity transaction,
  ) async {
    final result =
        await ref.read(transactionRepositoryProvider).create(transaction);

    switch (result) {
      case Success<TransactionEntity>(:final data):
        final refreshed =
            await ref.read(transactionRepositoryProvider).getTransactions();
        refreshed.when(
          success: (items) => state = AsyncData(items),
          error: (_) => state =
              AsyncData(<TransactionEntity>[data, ...(state.valueOrNull ?? [])]),
        );
      case Error<TransactionEntity>():
        break;
    }

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

  Future<Result<TransactionEntity>> collectTransaction({
    required TransactionEntity transaction,
    required bool settlePayment,
    Uint8List? proofImage,
  }) async {
    final result = await ref.read(transactionRepositoryProvider).collect(
      transaction: transaction,
      settlePayment: settlePayment,
      proofImage: proofImage,
    );
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

  Future<Result<void>> deleteTransaction(String id) async {
    final result = await ref.read(transactionRepositoryProvider).delete(id);
    result.when(
      success: (_) {
        final items = (state.valueOrNull ?? [])
            .where((item) => item.id != id)
            .toList();
        state = AsyncData(items);
      },
      error: (_) {},
    );
    return result;
  }
}
