import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/transaction_model.dart';

abstract class TransactionRemoteDataSource {
  Future<List<TransactionModel>> getTransactions();
  Future<TransactionModel> createTransaction({required TransactionModel transaction});
  Future<TransactionModel> updateTransaction({required TransactionModel transaction});
  Future<void> deleteTransaction(String id);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final Dio dio;

  const TransactionRemoteDataSourceImpl(this.dio);

  @override
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final response = await dio.get(
        ApiEndpoints.transactions,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final data = response.data is Map<String, dynamic>
          ? (response.data['data'] as List<dynamic>? ?? const [])
          : (response.data as List<dynamic>? ?? const []);

      return data
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ?? 'Gagal mengambil riwayat transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<TransactionModel> createTransaction({required TransactionModel transaction}) async {
    try {
      final response = await dio.post(
        ApiEndpoints.transactions,
        data: transaction.toJson(forRequest: true),
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final payload = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data)
          : <String, dynamic>{};

      return TransactionModel.fromJson(payload);
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ?? 'Gagal membuat transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<TransactionModel> updateTransaction({required TransactionModel transaction}) async {
    try {
      final payload = transaction.toJson(forRequest: false);
      final response = await dio.put(
        ApiEndpoints.transactionById(transaction.id.toString()),
        data: {
          'payment_status': payload['payment_status'],
          'order_status': payload['order_status'],
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final data = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data)
          : <String, dynamic>{};

      return TransactionModel.fromJson(data);
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ?? 'Gagal memperbarui transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await dio.delete(
        ApiEndpoints.transactionById(id),
        options: Options(headers: {'Accept': 'application/json'}),
      );
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ?? 'Gagal menghapus transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
