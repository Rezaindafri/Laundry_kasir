import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/report_models.dart';

abstract class ReportRemoteDataSource {
  Future<RevenueReport> getRevenue({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<ReportStatistics> getStatistics();
  Future<OwnerReportOverview> getOverview({
    required DateTime startDate,
    required DateTime endDate,
    String? cashierId,
  });

  Future<Uint8List> exportCsv({
    required DateTime startDate,
    required DateTime endDate,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final Dio dio;

  const ReportRemoteDataSourceImpl(this.dio);

  @override
  Future<RevenueReport> getRevenue({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.reportsRevenue,
        queryParameters: _dateParameters(startDate, endDate),
      );
      return RevenueReport.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal mengambil laporan pendapatan.');
    }
  }

  @override
  Future<ReportStatistics> getStatistics() async {
    try {
      final response = await dio.get(ApiEndpoints.reportsStatistics);
      return ReportStatistics.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal mengambil statistik laporan.');
    }
  }

  @override
  Future<OwnerReportOverview> getOverview({
    required DateTime startDate,
    required DateTime endDate,
    String? cashierId,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.reportsOverview,
        queryParameters: {
          ..._dateParameters(startDate, endDate),
          if (cashierId != null) 'cashier_id': cashierId,
        },
      );
      return OwnerReportOverview.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal mengambil rincian laporan.');
    }
  }

  @override
  Future<Uint8List> exportCsv({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ApiEndpoints.reportsExport,
        queryParameters: {
          ..._dateParameters(startDate, endDate),
          'type': 'csv',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException('File CSV kosong.');
      }
      return Uint8List.fromList(data);
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal mengekspor laporan CSV.');
    }
  }

  Map<String, String> _dateParameters(DateTime startDate, DateTime endDate) => {
        'start_date': _date(startDate),
        'end_date': _date(endDate),
      };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _data(dynamic response) {
    if (response is! Map) return <String, dynamic>{};
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  ServerException _serverException(DioException error, String fallback) {
    final body = error.response?.data;
    final message = body is Map ? body['message']?.toString() : null;
    return ServerException(
      message ?? fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
