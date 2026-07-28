import 'package:equatable/equatable.dart';

/// Representasi error di layer domain/presentation.
/// Repository selalu mengembalikan Failure (bukan Exception mentah)
/// supaya UI tidak perlu tahu detail teknis (Dio, SocketException, dll).
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Terjadi kesalahan pada server.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure(
      [super.message = 'Tidak ada koneksi internet. Periksa jaringan Anda.',]);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
      [super.message = 'Sesi berakhir, silakan login kembali.',]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Gagal mengambil data lokal.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Terjadi kesalahan tidak terduga.']);
}
