import '../../../../core/utils/result.dart';
import '../entities/user_entity.dart';

/// Kontrak repository auth. Implementasi konkret ada di data layer
/// (AuthRepositoryImpl), sehingga domain & presentation layer tidak
/// bergantung pada Dio/FlutterSecureStorage secara langsung.
abstract class AuthRepository {
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  Future<Result<void>> logout();

  /// Validates a remembered session with Laravel and returns current account
  /// data; null if no remembered session remains. Development mock is local.
  Future<Result<UserEntity?>> getCurrentUser();

  Future<bool> hasActiveSession();
}
