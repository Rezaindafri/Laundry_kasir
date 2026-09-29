import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class UserManagementRemoteDataSource {
  Future<List<UserModel>> getUsers();
  Future<UserModel> saveUser(UserEntity user, {String? password});
  Future<UserModel> toggleUserStatus(String id);
}

class UserManagementRemoteDataSourceImpl
    implements UserManagementRemoteDataSource {
  final Dio dio;

  const UserManagementRemoteDataSourceImpl(this.dio);

  @override
  Future<List<UserModel>> getUsers() async {
    try {
      final response = await dio.get(ApiEndpoints.users);
      final payload = response.data;
      final data = payload is Map && payload['data'] is List
          ? payload['data'] as List
          : const <dynamic>[];
      return data
          .whereType<Map>()
          .map(
            (item) => UserModel.fromJson(
              _normalize(Map<String, dynamic>.from(item)),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal memuat daftar pengguna.');
    }
  }

  @override
  Future<UserModel> saveUser(UserEntity user, {String? password}) async {
    final request = <String, dynamic>{
      'name': user.name,
      'username': user.username,
      'role': user.role.apiValue,
      'is_active': user.isActive,
    };
    if (user.role.apiValue == 'kasir' && user.ownerId != null) {
      request['owner_id'] = user.ownerId;
    }
    if (password != null && password.isNotEmpty) request['password'] = password;

    try {
      final response = user.id.isEmpty
          ? await dio.post(ApiEndpoints.users, data: request)
          : await dio.put(ApiEndpoints.userById(user.id), data: request);
      return UserModel.fromJson(_objectData(response.data));
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal menyimpan akun pengguna.');
    }
  }

  @override
  Future<UserModel> toggleUserStatus(String id) async {
    try {
      final response = await dio.patch(ApiEndpoints.userStatus(id));
      return UserModel.fromJson(_objectData(response.data));
    } on DioException catch (error) {
      throw _serverException(error, 'Gagal mengubah status akun.');
    }
  }

  Map<String, dynamic> _objectData(dynamic payload) {
    if (payload is! Map || payload['data'] is! Map) return <String, dynamic>{};
    return _normalize(Map<String, dynamic>.from(payload['data'] as Map));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> json) => {
        ...json,
        'id': json['id']?.toString() ?? '',
        'is_active': json['is_active'] == true || json['is_active'] == 1,
        'avatar_url': json['avatar_url'],
        'created_at':
            json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      };

  ServerException _serverException(DioException error, String fallback) {
    final body = error.response?.data;
    final message = body is Map ? body['message']?.toString() : null;
    return ServerException(
      message ?? fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
