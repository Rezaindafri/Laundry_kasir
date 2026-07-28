import '../error/failures.dart';

/// Result sealed class sebagai pengganti Either<Failure, T> (dartz).
/// Dipakai sebagai return type semua method Repository di domain layer,
/// supaya UseCase & Provider bisa handle sukses/gagal secara eksplisit
/// tanpa saling melempar exception.
///
/// Contoh pemakaian:
/// ```dart
/// final result = await authRepository.login(...);
/// switch (result) {
///   case Success(:final data) => // pakai data
///   case Error(:final failure) => // tampilkan failure.message
/// }
/// ```
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isError => this is Error<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.data);
    if (self is Error<T>) return error(self.failure);
    throw StateError('Unknown Result subtype');
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Error<T> extends Result<T> {
  final Failure failure;
  const Error(this.failure);
}
