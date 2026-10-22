import 'package:dio/dio.dart';

/// No response to a write does NOT prove the server rolled it back. Never
/// automatically replay it; the user must check the latest server state first.
class RequestFailureNotice {
  const RequestFailureNotice({required this.isWrite});

  final bool isWrite;

  String get message => isWrite
      ? 'Proses terganggu. Periksa data terbaru sebelum mencoba lagi.'
      : 'Gagal memuat data. Periksa koneksi dan coba lagi.';

  static RequestFailureNotice? fromError(DioException error) {
    if (error.requestOptions.extra['silentFailure'] == true ||
        error.type == DioExceptionType.cancel) return null;
    final status = error.response?.statusCode;
    final transportFailure = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown =>
        true,
      _ => false,
    };
    if (!transportFailure && (status == null || status < 500)) return null;
    return RequestFailureNotice(
      isWrite: !const {'GET', 'HEAD', 'OPTIONS'}
          .contains(error.requestOptions.method.toUpperCase()),
    );
  }
}
