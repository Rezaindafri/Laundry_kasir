import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Kontrak remote datasource auth.
abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  });

  Future<void> logout();
  Future<UserModel> getCurrentUser();
}

/// Implementasi asli memakai Dio ke backend Laravel.
/// Provider memilih implementasi ini ketika useMockApi bernilai false.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  const AuthRemoteDataSourceImpl(this.dio);

  static Map<String, dynamic> normalizeUserJson(Map<String, dynamic> userJson) {
    final normalized = Map<String, dynamic>.from(userJson);

    normalized['id'] = normalized['id']?.toString() ?? 'unknown';
    normalized['owner_id'] = normalized['owner_id']?.toString();
    normalized['is_active'] = normalized['is_active'] ?? true;
    normalized['avatar_url'] = normalized['avatar_url'];
    normalized['created_at'] =
        normalized['created_at'] ?? DateTime.now().toIso8601String();

    return normalized;
  }

  @override
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );

      final payload = response.data['data'];
      final Map<String, dynamic> userJson = normalizeUserJson(
        Map<String, dynamic>.from(payload['user'] ?? {}),
      );

      return AuthResponseModel(
        accessToken: payload['token'] ?? '',
        refreshToken: '',
        user: UserModel.fromJson(userJson),
      );
    } on DioException catch (e) {
      if (e.error is UnauthorizedException) {
        throw const ServerException(
          'Username atau password salah.',
          statusCode: 401,
        );
      }
      throw ServerException(
        e.response?.data?['message'] ?? 'Gagal terhubung ke server.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw const ServerException('Terjadi kesalahan, coba lagi nanti.');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?['message'] ?? 'Gagal logout dari server.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await dio.get(ApiEndpoints.me);
      final user = normalizeUserJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      if (user['is_active'] != true) {
        throw const ServerException('Akun dinonaktifkan.', statusCode: 403);
      }
      return UserModel.fromJson(user);
    } on DioException catch (error) {
      throw ServerException(
        'Sesi tidak dapat diverifikasi.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}

/// Implementasi MOCK/DUMMY — dipakai selama backend Laravel belum siap
/// (AppConstants.useMockApi = true). Menyimulasikan latency network
/// dan 3 akun default sesuai role: super_owner, owner, kasir.
class AuthRemoteDataSourceMock implements AuthRemoteDataSource {
  static final Map<String, Map<String, dynamic>> _dummyAccounts = {
    'superowner': {
      'password': 'super123',
      'user': {
        'id': 'usr-001',
        'name': 'Budi Santoso',
        'username': 'superowner',
        'role': 'super_owner',
        'is_active': true,
        'avatar_url': null,
        'created_at': '2025-01-01T08:00:00.000Z',
      },
    },
    'owner': {
      'password': 'owner123',
      'user': {
        'id': 'usr-002',
        'name': 'Siti Aminah',
        'username': 'owner',
        'role': 'owner',
        'is_active': true,
        'avatar_url': null,
        'created_at': '2025-02-10T08:00:00.000Z',
      },
    },
    'kasir': {
      'password': 'kasir123',
      'user': {
        'id': 'usr-003',
        'name': 'Andi Wijaya',
        'username': 'kasir',
        'role': 'kasir',
        'is_active': true,
        'avatar_url': null,
        'created_at': '2025-03-05T08:00:00.000Z',
      },
    },
  };

  @override
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final account = _dummyAccounts[username.trim().toLowerCase()];
    if (account == null || account['password'] != password) {
      throw const ServerException(
        'Username atau password salah.',
        statusCode: 401,
      );
    }

    final userJson = account['user'] as Map<String, dynamic>;
    return AuthResponseModel(
      accessToken: 'mock-access-token-${DateTime.now().millisecondsSinceEpoch}',
      refreshToken:
          'mock-refresh-token-${DateTime.now().millisecondsSinceEpoch}',
      user: UserModel.fromJson(userJson),
    );
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Tidak ada server call pada mode mock.
  }

  @override
  Future<UserModel> getCurrentUser() async {
    // Only AuthRepository's explicit development mock path uses local data.
    throw const ServerException('Mode mock tidak memiliki server sesi.');
  }
}

/// Helper untuk memilih implementasi sesuai AppConstants.useMockApi.
AuthRemoteDataSource createAuthRemoteDataSource(Dio dio) {
  return AppConstants.useMockApi
      ? AuthRemoteDataSourceMock()
      : AuthRemoteDataSourceImpl(dio);
}
