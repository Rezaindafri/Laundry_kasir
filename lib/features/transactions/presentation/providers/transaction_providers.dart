import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/mock_transaction_repository.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

import 'dart:typed_data';

final transactionRemoteDataSourceProvider =
    Provider<TransactionRemoteDataSource>(
  (ref) => TransactionRemoteDataSourceImpl(DioClient().dio),
);

final transactionProofProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, id) {
  ref.watch(currentSessionUserIdProvider);
  return ref.watch(transactionRemoteDataSourceProvider).downloadProof(id);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  if (AppConstants.useMockApi) {
    return MockTransactionRepository();
  }
  return TransactionRepositoryImpl(
    remoteDataSource: ref.watch(transactionRemoteDataSourceProvider),
  );
});

/// Paginated screens own their query/filter state, separate from the all-items
/// cache. A successful payment/handover must also reload those live queries.
final transactionListRefreshProvider = StateProvider<int>((ref) => 0);

final transactionDetailProvider = FutureProvider.autoDispose.family<TransactionEntity, String>((ref, id) async {
  ref.watch(currentSessionUserIdProvider);
  final result = await ref.watch(transactionRepositoryProvider).getById(id);
  return result.when(success: (value) => value, error: (failure) => throw failure);
});

final transactionLineProofProvider =
    FutureProvider.autoDispose.family<Uint8List, (String, String)>((ref, key) {
  ref.watch(currentSessionUserIdProvider);
  return ref
      .watch(transactionRemoteDataSourceProvider)
      .downloadProof(key.$1, detailId: key.$2);
});
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionEntity>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<TransactionEntity>> {
  @override
  Future<List<TransactionEntity>> build() async {
    ref.watch(currentSessionUserIdProvider);
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
          error: (_) => state = AsyncData(
              <TransactionEntity>[data, ...(state.valueOrNull ?? [])]),
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
    List<String>? detailIds,
    int? paymentAmount,
    String? paymentNote,
  }) async {
    final result = await ref.read(transactionRepositoryProvider).collect(
          transaction: transaction,
          settlePayment: settlePayment,
          proofImage: proofImage,
          detailIds: detailIds,
          paymentAmount: paymentAmount,
          paymentNote: paymentNote,
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
        final items =
            (state.valueOrNull ?? []).where((item) => item.id != id).toList();
        state = AsyncData(items);
      },
      error: (_) {},
    );
    return result;
  }

  Future<Result<TransactionEntity>> pay(
      {required TransactionEntity transaction,
      required int amount,
      required PaymentMethod method,
      String? note,
      required String requestId}) async {
    final result = await ref.read(transactionRepositoryProvider).pay(
        transaction: transaction,
        amount: amount,
        method: method,
        note: note,
        requestId: requestId);
    result.when(
        success: (item) {
          final items = <TransactionEntity>[...(state.valueOrNull ?? [])];
          final index = items.indexWhere((value) => value.id == item.id);
          if (index >= 0) items[index] = item;
          state = AsyncData(items);
        },
        error: (_) {});
    return result;
  }
}
