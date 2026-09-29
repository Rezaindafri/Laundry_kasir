/// Exception mentah di layer data (datasource). Di-catch oleh
/// repository lalu dikonversi menjadi Failure sebelum sampai ke UI.
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException(this.message, {this.statusCode});
}

class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException([this.message = 'Unauthorized.']);
}

class CacheException implements Exception {
  final String message;

  const CacheException([this.message = 'Gagal membaca cache lokal.']);
}
