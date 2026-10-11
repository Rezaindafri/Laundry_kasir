import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/payment_destination.dart';

class PaymentDestinationDataSource {
  const PaymentDestinationDataSource(this.dio);
  final Dio dio;

  Future<List<PaymentDestination>> list() async {
    try {
      final response = await dio.get(ApiEndpoints.paymentDestinations);
      return (response.data['data'] as List)
          .map((value) => PaymentDestination.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList();
    } on DioException catch (error) {
      throw _error(error, 'Tujuan pembayaran belum dapat dimuat.');
    }
  }

  Future<void> save(Map<String, dynamic> fields,
      {int? id, Uint8List? image, String? imageName}) async {
    final data = FormData.fromMap({
      ...fields,
      if (id != null) '_method': 'PATCH',
      if (image != null)
        'qris_image':
            MultipartFile.fromBytes(image, filename: imageName ?? 'qris.png'),
    });
    try {
      await dio.post(
          id == null
              ? ApiEndpoints.paymentDestinations
              : ApiEndpoints.paymentDestination(id),
          data: data);
    } on DioException catch (error) {
      throw _error(error, 'Tujuan pembayaran gagal disimpan.');
    }
  }

  Future<Uint8List> image(int id) async {
    try {
      final response = await dio.get<List<int>>(
          ApiEndpoints.paymentDestinationImage(id),
          options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(response.data ?? []);
    } on DioException catch (error) {
      throw _error(error, 'Gambar QRIS tidak tersedia atau akses ditolak.');
    }
  }

  ServerException _error(DioException error, String fallback) {
    final data = error.response?.data;
    final errors = data is Map ? data['errors'] : null;
    final validation = errors is Map
        ? errors.values.whereType<List>().expand((v) => v).firstOrNull
        : null;
    return ServerException(
        validation?.toString() ??
            (data is Map ? data['message']?.toString() : null) ??
            fallback,
        statusCode: error.response?.statusCode);
  }
}
