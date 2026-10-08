import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/expense_model.dart';

abstract class ExpenseRemoteDataSource {
  Future<List<ExpenseEntry>> getExpenses();
  Future<ExpenseEntry> createExpense(ExpenseInput input);
  Future<ExpenseEntry> updateExpense(String id, ExpenseInput input);
  Future<void> deleteExpense(String id);
}

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  final Dio dio;

  const ExpenseRemoteDataSourceImpl(this.dio);

  @override
  Future<List<ExpenseEntry>> getExpenses() async {
    try {
      final expenses = <ExpenseEntry>[];
      var page = 1;
      var lastPage = 1;

      do {
        final response = await dio.get(
          ApiEndpoints.expenses,
          queryParameters: {'per_page': 100, 'page': page},
        );
        final payload = response.data;
        if (payload is! Map) break;

        final rows = payload['data'] is List
            ? payload['data'] as List
            : const <dynamic>[];
        expenses.addAll(
          rows
              .whereType<Map>()
              .map((item) => ExpenseEntry.fromJson(
                    Map<String, dynamic>.from(item),
                  )),
        );

        final meta = payload['meta'];
        lastPage = meta is Map
            ? _positiveInt(meta['last_page']) ?? page
            : page;
        page++;
      } while (page <= lastPage);

      return expenses;
    } on DioException catch (error) {
      throw _exception(error, 'Gagal mengambil data pengeluaran.');
    }
  }

  int? _positiveInt(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  @override
  Future<ExpenseEntry> createExpense(ExpenseInput input) async {
    try {
      final response = await dio.post(ApiEndpoints.expenses, data: input.toJson());
      return ExpenseEntry.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal mencatat pengeluaran.');
    }
  }

  @override
  Future<ExpenseEntry> updateExpense(String id, ExpenseInput input) async {
    try {
      final response =
          await dio.patch(ApiEndpoints.expenseById(id), data: input.toJson());
      return ExpenseEntry.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memperbarui pengeluaran.');
    }
  }

  @override
  Future<void> deleteExpense(String id) async {
    try {
      await dio.delete(ApiEndpoints.expenseById(id));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal menghapus pengeluaran.');
    }
  }

  Map<String, dynamic> _data(dynamic payload) => payload is Map && payload['data'] is Map
      ? Map<String, dynamic>.from(payload['data'] as Map)
      : <String, dynamic>{};

  ServerException _exception(DioException error, String fallback) {
    final body = error.response?.data;
    return ServerException(
      body is Map && body['message'] != null ? body['message'].toString() : fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
