import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/customer_model.dart';
import '../../domain/entities/customer_entity.dart';

abstract class CustomerRemoteDataSource {
  Future<List<CustomerModel>> getCustomers();
  Future<CustomerModel> saveCustomer(CustomerEntity customer);
  Future<void> deleteCustomer(String id);
}

class CustomerRemoteDataSourceImpl implements CustomerRemoteDataSource {
  final Dio dio;
  const CustomerRemoteDataSourceImpl(this.dio);

  @override
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final response = await dio.get(ApiEndpoints.customers);
      final data = _listPayload(response.data);
      return data
          .map((item) => CustomerModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ServerException(_message(error),
          statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<CustomerModel> saveCustomer(CustomerEntity customer) async {
    try {
      final response = customer.id.isEmpty
          ? await dio.post(ApiEndpoints.customers,
              data: CustomerModel.toRequest(customer))
          : await dio.put(ApiEndpoints.customerById(customer.id),
              data: CustomerModel.toRequest(customer));
      return CustomerModel.fromJson(_objectPayload(response.data));
    } on DioException catch (error) {
      throw ServerException(_message(error),
          statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      await dio.delete(ApiEndpoints.customerById(id));
    } on DioException catch (error) {
      throw ServerException(_message(error),
          statusCode: error.response?.statusCode);
    }
  }
}

List<dynamic> _listPayload(dynamic data) => data is Map<String, dynamic>
    ? (data['data'] as List<dynamic>? ?? const [])
    : (data as List<dynamic>? ?? const []);
Map<String, dynamic> _objectPayload(dynamic data) =>
    data is Map<String, dynamic>
        ? (data['data'] as Map<String, dynamic>? ?? data)
        : <String, dynamic>{};
String _message(DioException error) {
  final data = error.response?.data;
  return data is Map<String, dynamic>
      ? (data['message']?.toString() ?? 'Permintaan pelanggan gagal.')
      : 'Permintaan pelanggan gagal.';
}
