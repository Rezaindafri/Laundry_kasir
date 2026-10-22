import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/report_models.dart';

abstract class ReportRemoteDataSource {
  Future<OwnerReportOverview> getOverview({
    required DateTime startDate,
    required DateTime endDate,
    String? cashierId,
    bool background = false,
  });

  Future<Uint8List> exportCsv({
    required DateTime startDate,
    required DateTime endDate,
    String? cashierId,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final Dio dio;

  const ReportRemoteDataSourceImpl(this.dio);

  @override
  Future<OwnerReportOverview> getOverview({
    required DateTime startDate,
    required DateTime endDate,
    String? cashierId,
    bool background = false,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.reportsOverview,
        options: Options(extra: {'silentFailure': background}),
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
    String? cashierId,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ApiEndpoints.reportsExport,
        queryParameters: {
          ..._dateParameters(startDate, endDate),
          'type': 'csv',
          if (cashierId != null) 'cashier_id': cashierId,
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
    if (response is! Map || response['data'] is! Map) {
      throw const ServerException('Gagal memuat laporan. Respons tidak valid.');
    }
    final data = response['data'];
    if (data['period'] is! Map ||
        data['summary'] is! Map ||
        data['summary']['payments_received'] is! num ||
        DateTime.tryParse(data['period']['start_date']?.toString() ?? '') ==
            null ||
        DateTime.tryParse(data['period']['end_date']?.toString() ?? '') ==
            null) {
      throw const ServerException('Gagal memuat laporan. Data tidak lengkap.');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  ServerException _serverException(DioException error, String fallback) {
    if ((error.response?.statusCode ?? 0) >= 500) {
      return ServerException(fallback, statusCode: error.response?.statusCode);
    }
    final body = error.response?.data;
    final message = body is Map ? body['message']?.toString() : null;
    return ServerException(
      message ?? fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
