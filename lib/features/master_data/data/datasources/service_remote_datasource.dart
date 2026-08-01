import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../models/service_model.dart';

abstract class ServiceRemoteDataSource {
  Future<List<ServiceModel>> getServices();
  Future<ServiceModel> saveService(LaundryServiceEntity service);
  Future<void> deleteService(String id);
}

class ServiceRemoteDataSourceImpl implements ServiceRemoteDataSource {
  final Dio dio;
  const ServiceRemoteDataSourceImpl(this.dio);
  @override
  Future<List<ServiceModel>> getServices() async {
    try {
      final response = await dio.get(ApiEndpoints.services);
      final data = _list(response.data);
      return data
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ServerException(_message(error),
          statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<ServiceModel> saveService(LaundryServiceEntity service) async {
    try {
      final response = service.id.isEmpty
          ? await dio.post(ApiEndpoints.services,
              data: ServiceModel.toRequest(service))
          : await dio.put(ApiEndpoints.serviceById(service.id),
              data: ServiceModel.toRequest(service));
      return ServiceModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ServerException(_message(error),
          statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<void> deleteService(String id) async {
    try {
      await dio.delete(ApiEndpoints.serviceById(id));
    } on DioException catch (error) {
      throw ServerException(_message(error),
          statusCode: error.response?.statusCode);
    }
  }
}

List<dynamic> _list(dynamic data) => data is Map<String, dynamic>
    ? (data['data'] as List<dynamic>? ?? const [])
    : (data as List<dynamic>? ?? const []);
Map<String, dynamic> _object(dynamic data) => data is Map<String, dynamic>
    ? (data['data'] as Map<String, dynamic>? ?? data)
    : <String, dynamic>{};
String _message(DioException error) {
  final data = error.response?.data;
  return data is Map<String, dynamic>
      ? (data['message']?.toString() ?? 'Permintaan layanan gagal.')
      : 'Permintaan layanan gagal.';
}
