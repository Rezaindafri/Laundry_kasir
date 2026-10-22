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
import 'request_failure_notice.dart';

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
  final _failureController = StreamController<RequestFailureNotice>.broadcast();

  Stream<RequestFailureNotice> get requestFailureEvents =>
      _failureController.stream;

  Stream<SessionExpiryEvent> get sessionExpiryEvents =>
      _sessionExpiryController.stream;

  Future<void> dispose() async {
    dio.close(force: true);
    await _sessionExpiryController.close();
    await _failureController.close();
  }

  late final Dio dio = _createDio();

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        sendTimeout: AppConstants.receiveTimeout,
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
            String? token;
            try {
              token = await _secureStorage
                  .read(key: StorageKeys.accessToken)
                  .timeout(AppConstants.connectTimeout);
            } catch (error, stack) {
              // Async interceptors must always resolve/reject, even when secure
              // storage fails. Never send an authenticated request anonymously.
              return handler.reject(DioException(
                  requestOptions: options,
                  error: const ServerException(
                      'Sesi belum dapat dibaca. Coba lagi.'),
                  stackTrace: stack));
            }
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isRejectedLogin = error.response?.statusCode == 401 &&
              error.requestOptions.path.endsWith('/auth/login');
          if (kDebugMode && error.requestOptions.extra['silentFailure'] != true) {
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
          final failure = RequestFailureNotice.fromError(error);
          // Ignore responses from an account that has since logged out or
          // switched. Background prefetches also opt out of notifications.
          if (failure != null && !_failureController.isClosed) {
            try {
              final currentToken = await _secureStorage
                  .read(key: StorageKeys.accessToken)
                  .timeout(AppConstants.connectTimeout);
              if (authorization == null ||
                  authorization == 'Bearer $currentToken') {
                _failureController.add(failure);
              }
            } catch (_) {
              // Notification failure must not leave the Dio handler pending.
            }
          }
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
