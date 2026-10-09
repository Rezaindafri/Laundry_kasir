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

      // Selalu simpan token saat login agar request API berikutnya tetap
      // memakai Authorization header selama sesi aplikasi aktif.
      // "Ingat saya" hanya menentukan apakah token dan user ditahan
      // untuk auto-login ketika aplikasi dibuka kembali.
      await localDataSource.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
        rememberMe: rememberMe,
      );

      return Success(response.user.toEntity());
    } on ServerException catch (e) {
      if (e.statusCode == 401) {
        return const Error(
          UnauthorizedFailure('Username atau password salah.'),
        );
      }
      if (e.statusCode == 403 &&
          e.message.toLowerCase().contains('dinonaktifkan')) {
        return const Error(ServerFailure('Akun dinonaktifkan.'));
      }
      if (e.statusCode == 429) {
        return const Error(
          ServerFailure('Terlalu banyak percobaan login. Coba lagi sebentar.'),
        );
      }
      return const Error(
        ServerFailure('Terjadi kesalahan, coba lagi nanti.'),
      );
    } on CacheException {
      return const Error(
        CacheFailure('Terjadi kesalahan, coba lagi nanti.'),
      );
    } catch (_) {
      return const Error(
        UnknownFailure('Terjadi kesalahan, coba lagi nanti.'),
      );
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
      if (!rememberMe) {
        await localDataSource.clearSession();
        return const Success(null);
      }

      final user = await localDataSource.getSavedUser();
      final token = await localDataSource.getAccessToken();
      if (user == null || token == null) {
        await localDataSource.clearSession();
        return const Success(null);
      }
      if (remoteDataSource is AuthRemoteDataSourceMock) {
        return Success(user.toEntity());
      }

      // Local role/name are a cache, not proof the session is still valid.
      final verified = await remoteDataSource.getCurrentUser();
      // An API rejection while /me is in flight must not be undone by its
      // late success response. Never trust or persist another token's user.
      if (await localDataSource.getAccessToken() != token) {
        return const Success(null);
      }
      await localDataSource.updateSavedUser(verified);
      if (await localDataSource.getAccessToken() != token) {
        return const Success(null);
      }
      return Success(verified.toEntity());
    } on ServerException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await localDataSource.clearSession();
        return const Success(null);
      }
      return const Error(ServerFailure('Sesi tidak dapat diverifikasi.'));
    } on CacheException catch (e) {
      return Error(CacheFailure(e.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<bool> hasActiveSession() async {
    final result = await getCurrentUser();
    return result.when(success: (user) => user != null, error: (_) => false);
  }
}
