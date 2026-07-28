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

  /// Mengembalikan user yang tersimpan secara lokal (session aktif),
  /// null jika belum pernah login / sesi habis.
  Future<Result<UserEntity?>> getCurrentUser();

  Future<bool> hasActiveSession();
}
