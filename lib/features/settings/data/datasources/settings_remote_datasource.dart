import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/laundry_settings.dart';

abstract class SettingsRemoteDataSource {
  Future<LaundrySettings> getSettings();
  Future<LaundrySettings> saveSettings(LaundrySettings settings);
  Future<Uint8List> downloadBackup();
  Future<void> restoreBackup(Map<String, dynamic> backup);
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final Dio dio;

  const SettingsRemoteDataSourceImpl(this.dio);

  @override
  Future<LaundrySettings> getSettings() async {
    try {
      final response = await dio.get(ApiEndpoints.settings);
      return _settings(_data(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memuat pengaturan usaha.');
    }
  }

  @override
  Future<LaundrySettings> saveSettings(LaundrySettings settings) async {
    try {
      final response = await dio.patch(
        ApiEndpoints.settings,
        data: {
          'business_name': settings.businessName,
          'phone': settings.phone,
          'address': settings.address,
        },
      );
      return _settings(_data(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal menyimpan pengaturan usaha.');
    }
  }

  @override
  Future<Uint8List> downloadBackup() async {
    try {
      final response = await dio.get(
        ApiEndpoints.backup,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes is! List<int>) {
        throw const ServerException('Berkas backup tidak valid.');
      }
      return Uint8List.fromList(bytes);
    } on DioException catch (error) {
      throw _exception(error, 'Gagal membuat backup konfigurasi.');
    }
  }

  @override
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    try {
      await dio.post(ApiEndpoints.restore, data: backup);
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memulihkan konfigurasi.');
    }
  }

  Map<String, dynamic> decodeBackup(Uint8List bytes) =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);

  LaundrySettings _settings(Map<String, dynamic> json) => LaundrySettings(
        businessName:
            json['business_name']?.toString() ?? 'Clean Fresh Laundry',
        phone: json['phone']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        paperSize: '58 mm',
      );

  Map<String, dynamic> _data(dynamic response) =>
      response is Map && response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

  ServerException _exception(DioException error, String fallback) {
    final data = error.response?.data;
    return ServerException(
      data is Map ? data['message']?.toString() ?? fallback : fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
