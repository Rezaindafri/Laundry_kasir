import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/dashboard_owner_model.dart';
import '../models/dashboard_kasir_model.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardOwnerResponse> getOwnerDashboard();
  Future<DashboardKasirResponse> getKasirDashboard();
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final Dio dio;

  const DashboardRemoteDataSourceImpl(this.dio);

  @override
  Future<DashboardOwnerResponse> getOwnerDashboard() async {
    try {
      final response = await dio.get(
        ApiEndpoints.dashboardOwner,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final payload = response.data is Map<String, dynamic>
          ? response.data
          : <String, dynamic>{};

      final data = payload['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};

      return DashboardOwnerResponse.fromJson(data);
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ?? 'Gagal mengambil data dashboard owner.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<DashboardKasirResponse> getKasirDashboard() async {
    try {
      final response = await dio.get(
        ApiEndpoints.dashboardKasir,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final payload = response.data is Map<String, dynamic>
          ? response.data
          : <String, dynamic>{};
      final data = payload['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};
      return DashboardKasirResponse.fromJson(data);
    } on DioException catch (error) {
      throw ServerException(
        error.response?.data?['message']?.toString() ??
            'Gagal mengambil data dashboard kasir.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
