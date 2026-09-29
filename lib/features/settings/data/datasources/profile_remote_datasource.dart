import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/super_owner_settings_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile(
      {required String name, String? username});
  Future<void> updatePassword({
    required String currentPassword,
    required String password,
  });
  Future<SuperOwnerSettings> getSuperOwnerSettings();
  Future<void> updatePasswordMinLength(int value);
  Future<int> getAccountPasswordMinLength();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio;

  const ProfileRemoteDataSourceImpl(this.dio);

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await dio.get(ApiEndpoints.profile);
      return UserModel.fromJson(_user(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memuat profil.');
    }
  }

  @override
  Future<UserModel> updateProfile(
      {required String name, String? username}) async {
    try {
      final response = await dio.patch(
        ApiEndpoints.profile,
        data: {
          'name': name,
          if (username != null) 'username': username,
        },
      );
      return UserModel.fromJson(_user(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memperbarui profil.');
    }
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String password,
  }) async {
    try {
      await dio.patch(
        ApiEndpoints.profilePassword,
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': password,
        },
      );
    } on DioException catch (error) {
      throw _exception(error, 'Gagal mengubah password.');
    }
  }

  @override
  Future<SuperOwnerSettings> getSuperOwnerSettings() async {
    try {
      final response = await dio.get(ApiEndpoints.systemSettings);
      final data = response.data is Map && response.data['data'] is Map
          ? Map<String, dynamic>.from(response.data['data'] as Map)
          : <String, dynamic>{};
      return SuperOwnerSettings.fromJson(data);
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memuat pengaturan Super Owner.');
    }
  }

  @override
  Future<void> updatePasswordMinLength(int value) async {
    try {
      await dio.patch(
        ApiEndpoints.systemSettings,
        data: {'password_min_length': value},
      );
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memperbarui kebijakan password.');
    }
  }

  @override
  Future<int> getAccountPasswordMinLength() async {
    try {
      final response = await dio.get(ApiEndpoints.accountPolicy);
      final data = response.data is Map && response.data['data'] is Map
          ? Map<String, dynamic>.from(response.data['data'] as Map)
          : <String, dynamic>{};
      return (data['password_min_length'] as num?)?.toInt() ?? 6;
    } on DioException catch (error) {
      throw _exception(error, 'Gagal memuat kebijakan password.');
    }
  }

  Map<String, dynamic> _user(dynamic response) {
    final payload = response is Map && response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    return AuthRemoteDataSourceImpl.normalizeUserJson(payload);
  }

  ServerException _exception(DioException error, String fallback) {
    final data = error.response?.data;
    return ServerException(
      data is Map ? data['message']?.toString() ?? fallback : fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
