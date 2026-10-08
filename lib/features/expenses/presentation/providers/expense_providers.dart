import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/models/expense_model.dart';

final expenseRemoteDataSourceProvider = Provider<ExpenseRemoteDataSource>(
  (ref) => ExpenseRemoteDataSourceImpl(DioClient().dio),
);

final expensesProvider =
    AsyncNotifierProvider<ExpensesNotifier, List<ExpenseEntry>>(
  ExpensesNotifier.new,
);

class ExpensesNotifier extends AsyncNotifier<List<ExpenseEntry>> {
  String? _sessionUserId;

  @override
  Future<List<ExpenseEntry>> build() async {
    final sessionUserId = ref.watch(currentSessionUserIdProvider);
    if (_sessionUserId != sessionUserId) _sessionUserId = sessionUserId;
    return ref.read(expenseRemoteDataSourceProvider).getExpenses();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> save(ExpenseInput input, {String? id}) async {
    final remote = ref.read(expenseRemoteDataSourceProvider);
    if (id == null) {
      await remote.createExpense(input);
    } else {
      await remote.updateExpense(id, input);
    }
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(expenseRemoteDataSourceProvider).deleteExpense(id);
    await refresh();
  }
}
