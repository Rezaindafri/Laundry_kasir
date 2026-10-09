import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/session_expiry.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import 'splash_intro_provider.dart';

/// Harus di-override di main() dengan instance SharedPreferences.getInstance()
/// sebelum runApp, karena inisialisasinya async.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider belum di-override di main.dart',
  );
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dioProvider = Provider((ref) => DioClient().dio);
final sessionExpiryEventsProvider = Provider<Stream<SessionExpiryEvent>>(
  (ref) => DioClient().sessionExpiryEvents,
);

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
  Future<void> _sessionOperations = Future.value();
  bool _disposed = false;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _sessionOperations.then((_) => operation());
    _sessionOperations =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<UserEntity?> build() async {
    _disposed = false;
    final subscription = ref.read(sessionExpiryEventsProvider).listen((event) {
      unawaited(
        _serialize(() async {
          if (_disposed) return;
          final local = ref.read(authLocalDataSourceProvider);
          if (await local.getAccessToken() != event.accessToken) return;
          try {
            await local.clearSession();
          } finally {
            if (!_disposed) state = const AsyncData(null);
          }
        }).catchError((Object _, StackTrace __) {
          // A storage/channel failure must not leave a rejected account active.
          if (!_disposed) state = const AsyncData(null);
        }),
      );
    });
    ref.onDispose(() {
      _disposed = true;
      unawaited(subscription.cancel());
    });
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
  }) =>
      _serialize(() async {
        final result = await ref.read(loginUseCaseProvider).call(
              username: username,
              password: password,
              rememberMe: rememberMe,
            );

        result.when(
          success: (user) {
            if (!_disposed) state = AsyncData(user);
          },
          error: (_) {
            if (!_disposed) state = const AsyncData(null);
          },
        );

        return result;
      });

  Future<void> logout() => _serialize(() async {
        ref.read(splashIntroCompletedProvider.notifier).state = false;
        ref.read(logoutInProgressProvider.notifier).state = true;

        try {
          await ref.read(logoutUseCaseProvider).call();
        } finally {
          if (!_disposed) {
            state = const AsyncData(null);
            ref.read(logoutInProgressProvider.notifier).state = false;
          }
        }
      });

  Future<void> replaceCurrentUser(UserEntity user) => _serialize(() async {
        if (_disposed || state.valueOrNull?.id != user.id) return;
        if (await ref.read(authLocalDataSourceProvider).getAccessToken() ==
            null) {
          return;
        }
        if (!_disposed) state = AsyncData(user);
      });
}
