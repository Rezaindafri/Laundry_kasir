import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      final response = await remoteDataSource.login(
        username: username,
        password: password,
      );

      // Tanpa "Ingat saya", sesi hanya hidup di memori provider hingga
      // aplikasi ditutup. Token tidak boleh tertinggal di perangkat.
      if (rememberMe) {
        await localDataSource.saveSession(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          user: response.user,
          rememberMe: true,
        );
      } else {
        await localDataSource.clearSession();
      }

      return Success(response.user.toEntity());
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Error(CacheFailure(e.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearSession();
      return const Success(null);
    } catch (_) {
      // Tetap hapus sesi lokal walau call ke server gagal,
      // supaya user tidak "terjebak" dalam keadaan setengah logout.
      await localDataSource.clearSession();
      return const Success(null);
    }
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    try {
      final rememberMe = await localDataSource.isRememberLoginEnabled();
      if (!rememberMe) return const Success(null);

      final user = await localDataSource.getSavedUser();
      return Success(user?.toEntity());
    } on CacheException catch (e) {
      return Error(CacheFailure(e.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<bool> hasActiveSession() async {
    final token = await localDataSource.getAccessToken();
    final rememberMe = await localDataSource.isRememberLoginEnabled();
    return token != null && rememberMe;
  }
}
