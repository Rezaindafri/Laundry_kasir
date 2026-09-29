import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

/// Harus di-override di main() dengan instance SharedPreferences.getInstance()
/// sebelum runApp, karena inisialisasinya async.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider belum di-override di main.dart');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dioProvider = Provider((ref) => DioClient().dio);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return createAuthRemoteDataSource(ref.watch(dioProvider));
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(
    secureStorage: ref.watch(secureStorageProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

final loginUseCaseProvider = Provider((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

/// State sesi login aplikasi. AsyncValue<UserEntity?>:
/// - loading  -> sedang cek Auto Login (Splash Screen)
/// - data null -> belum login
/// - data user -> sudah login
/// - error -> gagal cek sesi lokal
final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, UserEntity?>(SessionNotifier.new);

/// Identity sesi aktif untuk provider yang memuat data terisolasi per akun.
/// Saat login berganti, provider yang mengawasi nilai ini akan memuat ulang
/// data dari backend dan tidak boleh menampilkan cache akun sebelumnya.
final currentSessionUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.id,
);

/// Key cache konfigurasi usaha: kasir berbagi cache dengan Owner yang menjadi
/// kelompok operasionalnya, sedangkan antar Owner tetap terpisah.
final currentOperationalOwnerScopeIdProvider = Provider<String?>(
  (ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    return user?.ownerId ?? user?.id;
  },
);

class SessionNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    final result = await ref.read(getCurrentUserUseCaseProvider).call();
    return result.when(
      success: (user) => user,
      error: (_) => null,
    );
  }

  Future<Result<UserEntity>> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(loginUseCaseProvider).call(
          username: username,
          password: password,
          rememberMe: rememberMe,
        );

    result.when(
      success: (user) => state = AsyncData(user),
      error: (_) => state = const AsyncData(null),
    );

    return result;
  }

  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider).call();
    state = const AsyncData(null);
  }

  Future<void> replaceCurrentUser(UserEntity user) async {
    state = AsyncData(user);
  }
}
