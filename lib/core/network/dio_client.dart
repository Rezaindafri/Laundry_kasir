import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../error/exceptions.dart';

/// Wrapper Dio dengan:
/// - Base URL & timeout dari AppConstants
/// - Interceptor: menyisipkan JWT access token ke header
/// - Interceptor: auto logout ke UnauthorizedException saat 401
/// - Logging request/response (debug only)
class DioClient {
  DioClient._internal();

  static final DioClient _instance = DioClient._internal();

  factory DioClient() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  late final Dio dio = _createDio();

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: StorageKeys.accessToken);
          options.headers['Accept'] = 'application/json';
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isRejectedLogin = error.response?.statusCode == 401 &&
              error.requestOptions.path.endsWith('/auth/login');
          final message = '[API ${isRejectedLogin ? 'INFO' : 'ERROR'}] '
              '${error.requestOptions.method} ${error.requestOptions.path} '
              '-> ${error.message}';
          if (isRejectedLogin) {
            // Salah kredensial adalah hasil yang diharapkan dari percobaan
            // login, bukan kegagalan jaringan/CORS.
            _logger.i(message);
          } else {
            _logger.e(message);
          }

          if (error.response?.statusCode == 401) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: const UnauthorizedException(),
                type: error.type,
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }
}
