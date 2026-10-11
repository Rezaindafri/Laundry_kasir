import 'package:dio/dio.dart';

import 'dart:typed_data';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/transaction_model.dart';
import '../models/transaction_page_model.dart';

abstract class TransactionRemoteDataSource {
  Future<List<TransactionModel>> getTransactions();
  Future<TransactionPageModel> getTransactionsPage(Map<String, dynamic> query);
  Future<TransactionModel> createTransaction(
      {required TransactionModel transaction});
  Future<TransactionModel> updateTransaction(
      {required TransactionModel transaction});
  Future<TransactionModel> recordPayment(
      {required String id,
      required int amount,
      required String method,
      String? note,
      required String requestId});
  Future<TransactionModel> collectTransaction({
    required TransactionModel transaction,
    required bool settlePayment,
    Uint8List? proofImage,
    List<String>? detailIds,
    int? paymentAmount,
    String? paymentNote,
  });
  Future<void> deleteTransaction(String id);
  Future<Uint8List> downloadProof(String id, {String? detailId});
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final Dio dio;

  const TransactionRemoteDataSourceImpl(this.dio);

  @override
  Future<TransactionModel> recordPayment(
      {required String id,
      required int amount,
      required String method,
      String? note,
      required String requestId}) async {
    try {
      final response = await dio.post(ApiEndpoints.payment(id), data: {
        'amount': amount,
        'payment_method': method,
        'payment_note': note,
        'request_id': requestId,
      });
      return TransactionModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map));
    } on DioException catch (error) {
      throw ServerException(
          error.response?.data?['message']?.toString() ??
              'Gagal mencatat pembayaran.',
          statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<Uint8List> downloadProof(String id, {String? detailId}) async {
    try {
      final response = await dio.get<List<int>>(
        ApiEndpoints.transactionProof(id),
        queryParameters: {if (detailId != null) 'detail_id': detailId},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (error) {
      throw ServerException(
        'Bukti pengambilan tidak tersedia atau akses tidak diizinkan.',
        statusCode: error.response?.statusCode,
      );
    }
  }

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
          .map(
              (item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ??
            'Gagal mengambil riwayat transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<TransactionPageModel> getTransactionsPage(
    Map<String, dynamic> query,
  ) async {
    try {
      final response = await dio.get(
        ApiEndpoints.transactions,
        queryParameters: query,
        options: Options(
          headers: {'Accept': 'application/json'},
          listFormat: ListFormat.multiCompatible,
        ),
      );
      return TransactionPageModel.fromResponse(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ??
            'Gagal mengambil transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<TransactionModel> createTransaction(
      {required TransactionModel transaction}) async {
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
        error.response?.data?['message']?.toString() ??
            'Gagal membuat transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<TransactionModel> updateTransaction(
      {required TransactionModel transaction}) async {
    try {
      final payload = transaction.toJson(forRequest: false);
      final isPaymentSettlement = payload['payment_status'] == 'paid' ||
          (payload['paid_amount'] as num? ?? 0) > 0;

      final response = isPaymentSettlement
          ? await dio.post(
              ApiEndpoints.payment(transaction.id.toString()),
              data: {
                'paid_amount': payload['paid_amount'],
                'payment_method': payload['payment_method'] ?? 'cash',
                'payment_status': payload['payment_status'],
              },
              options: Options(headers: {'Accept': 'application/json'}),
            )
          : await dio.put(
              ApiEndpoints.transactionById(transaction.id.toString()),
              data: {
                'paid_amount': payload['paid_amount'],
                'payment_status': payload['payment_status'],
                'payment_method': payload['payment_method'] ?? 'cash',
                'laundry_status': payload['laundry_status'],
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
        error.response?.data?['message']?.toString() ??
            'Gagal memperbarui transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<TransactionModel> collectTransaction({
    required TransactionModel transaction,
    required bool settlePayment,
    Uint8List? proofImage,
    List<String>? detailIds,
    int? paymentAmount,
    String? paymentNote,
  }) async {
    try {
      final data = <String, dynamic>{
        // FormData mengubah bool menjadi string. Laravel menerima 1/0 secara
        // konsisten untuk rule `boolean`, sedangkan string "true" tidak.
        'settle_payment': settlePayment ? 1 : 0,
        'payment_method': transaction.paymentMethod,
        if (detailIds != null) 'detail_ids': detailIds,
        if (paymentAmount != null) 'payment_amount': paymentAmount,
        if (paymentNote != null) 'payment_note': paymentNote,
      };
      if (proofImage != null) {
        data['proof_image'] = MultipartFile.fromBytes(
          proofImage,
          filename: 'bukti-pengambilan.jpg',
        );
      }
      final response = await dio.post(
        ApiEndpoints.collection(transaction.id.toString()),
        data: FormData.fromMap(data, ListFormat.multiCompatible),
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final payload = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data)
          : <String, dynamic>{};
      return TransactionModel.fromJson(payload);
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ??
            'Gagal mencatat pengambilan laundry.',
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
        error.response?.data?['message']?.toString() ??
            'Gagal menghapus transaksi.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
