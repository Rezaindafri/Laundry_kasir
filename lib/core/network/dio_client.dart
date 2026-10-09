import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../error/exceptions.dart';
import 'api_endpoints.dart';
import 'session_expiry.dart';

/// Wrapper Dio dengan:
/// - Base URL & timeout dari AppConstants
/// - Bearer token Sanctum (tidak dikirim pada login)
/// - Event sesi ditolak, dengan token request agar respons lama aman
/// - Logging metadata tanpa token/body, hanya pada debug build
class DioClient {
  DioClient._internal({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  DioClient.forTesting({required FlutterSecureStorage secureStorage})
      : this._internal(secureStorage: secureStorage);

  static final DioClient _instance = DioClient._internal();

  factory DioClient() => _instance;

  final FlutterSecureStorage _secureStorage;
  final Logger _logger = Logger();
  final _sessionExpiryController =
      StreamController<SessionExpiryEvent>.broadcast();

  Stream<SessionExpiryEvent> get sessionExpiryEvents =>
      _sessionExpiryController.stream;

  Future<void> dispose() async {
    dio.close(force: true);
    await _sessionExpiryController.close();
  }

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
          options.headers['Accept'] = 'application/json';
          if (options.path.endsWith(ApiEndpoints.login)) {
            options.headers.remove('Authorization');
          } else {
            final token =
                await _secureStorage.read(key: StorageKeys.accessToken);
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isRejectedLogin = error.response?.statusCode == 401 &&
              error.requestOptions.path.endsWith('/auth/login');
          if (kDebugMode) {
            final message = '[API ${isRejectedLogin ? 'INFO' : 'ERROR'}] '
                '${error.requestOptions.method} ${error.requestOptions.path} '
                '-> ${error.response?.statusCode ?? error.type.name}';
            if (isRejectedLogin) {
              _logger.i(message);
            } else {
              _logger.e(message);
            }
          }

          final data = _errorBody(error.response);
          final inactiveAccount = error.response?.statusCode == 403 &&
              data is Map &&
              (data['code'] == 'account_inactive' ||
                  data['message']?.toString().toLowerCase().contains(
                            'akun dinonaktifkan',
                          ) ==
                      true);
          final authorization =
              error.requestOptions.headers['Authorization']?.toString();
          if (!error.requestOptions.path.endsWith(ApiEndpoints.login) &&
              (error.response?.statusCode == 401 || inactiveAccount) &&
              authorization?.startsWith('Bearer ') == true &&
              !_sessionExpiryController.isClosed) {
            _sessionExpiryController.add(
              SessionExpiryEvent(
                accessToken: authorization!.substring(7),
                statusCode: error.response!.statusCode!,
              ),
            );
          }

          if (error.response?.statusCode == 401) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: const UnauthorizedException(),
                type: error.type,
                response: error.response,
                message: error.message,
                stackTrace: error.stackTrace,
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  // Image/CSV downloads use ResponseType.bytes, including for JSON failures.
  // Decode only JSON error responses so inactive-account handling still works.
  static dynamic _errorBody(Response<dynamic>? response) {
    final body = response?.data;
    if (body is List<int> &&
        response?.headers
                .value(Headers.contentTypeHeader)
                ?.contains('application/json') ==
            true) {
      try {
        return jsonDecode(utf8.decode(body));
      } on FormatException {
        return null;
      }
    }
    return body;
  }
}
