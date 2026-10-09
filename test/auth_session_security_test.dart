import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/constants/storage_keys.dart';
import 'package:laundry_management_system/core/error/exceptions.dart';
import 'package:laundry_management_system/core/network/dio_client.dart';
import 'package:laundry_management_system/core/network/session_expiry.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:laundry_management_system/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:laundry_management_system/features/auth/data/models/auth_response_model.dart';
import 'package:laundry_management_system/features/auth/data/models/user_model.dart';
import 'package:laundry_management_system/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';

// Every request uses an in-memory adapter: no sockets or real credentials.
class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _cachedUser = UserModel(
  id: '10',
  name: 'Cached owner',
  username: 'fixture',
  role: 'owner',
  isActive: true,
  createdAt: DateTime(2026),
);

final _verifiedUser = UserModel(
  id: '10',
  name: 'Current cashier',
  username: 'fixture',
  role: 'kasir',
  ownerId: '20',
  isActive: true,
  createdAt: DateTime(2026),
);

class _MemoryLocal implements AuthLocalDataSource {
  UserModel? user = _cachedUser;
  String? token = 'fixture-old-token';
  bool remember = true;
  int clears = 0;

  @override
  Future<void> clearSession() async {
    clears++;
    user = null;
    token = null;
    remember = false;
  }

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<UserModel?> getSavedUser() async => user;

  @override
  Future<bool> isRememberLoginEnabled() async => remember;

  @override
  Future<void> updateSavedUser(UserModel value) async => user = value;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
    required bool rememberMe,
  }) async {
    token = accessToken;
    this.user = user;
    remember = rememberMe;
  }
}

class _MemoryRemote implements AuthRemoteDataSource {
  UserModel user = _verifiedUser;
  ServerException? failure;
  Completer<AuthResponseModel>? pendingLogin;
  Completer<UserModel>? pendingVerification;
  int verifications = 0;

  @override
  Future<UserModel> getCurrentUser() async {
    verifications++;
    if (failure != null) throw failure!;
    if (pendingVerification != null) return await pendingVerification!.future;
    return user;
  }

  @override
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    if (failure != null) throw failure!;
    if (pendingLogin != null) return await pendingLogin!.future;
    return AuthResponseModel(
      accessToken: 'fixture-new-token',
      refreshToken: '',
      user: user,
    );
  }

  @override
  Future<void> logout() async {
    if (failure != null) throw failure!;
  }
}

Future<void> _settleEvents() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dio rejected sessions', () {
    late DioClient client;
    late List<SessionExpiryEvent> events;
    late StreamSubscription<SessionExpiryEvent> subscription;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fixture-old-token',
      });
      client = DioClient.forTesting(
        secureStorage: const FlutterSecureStorage(),
      );
      events = [];
      subscription = client.sessionExpiryEvents.listen(events.add);
    });

    tearDown(() async {
      await subscription.cancel();
      await client.dispose();
    });

    test('401 keeps response and emits the rejected request token', () async {
      client.dio.httpClientAdapter =
          _ResponseAdapter(401, {'message': 'Denied'});
      await expectLater(
        client.dio.get('/profile'),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', 401)
              .having((e) => e.error, 'error', isA<UnauthorizedException>()),
        ),
      );
      await _settleEvents();
      expect(events.single.accessToken, 'fixture-old-token');
      expect(events.single.statusCode, 401);
    });

    test('login 401 neither attaches an old token nor expires a session',
        () async {
      final adapter = _ResponseAdapter(401, {'code': 'invalid_credentials'});
      client.dio.httpClientAdapter = adapter;
      await expectLater(
        client.dio.post('/auth/login'),
        throwsA(isA<DioException>()),
      );
      await _settleEvents();
      expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
      expect(events, isEmpty);
    });

    test('a role permission 403 does not log out the account', () async {
      client.dio.httpClientAdapter = _ResponseAdapter(403, {
        'message': 'Akses tidak diizinkan.',
      });
      await expectLater(
        client.dio.get('/users'),
        throwsA(isA<DioException>()),
      );
      await _settleEvents();
      expect(events, isEmpty);
    });

    test('an inactive-account 403 expires its own session', () async {
      client.dio.httpClientAdapter = _ResponseAdapter(403, {
        'code': 'account_inactive',
      });
      await expectLater(
        client.dio.get('/profile'),
        throwsA(isA<DioException>()),
      );
      await _settleEvents();
      expect(events.single.statusCode, 403);
    });
  });

  group('Remembered session verification', () {
    late _MemoryLocal local;
    late _MemoryRemote remote;
    late AuthRepositoryImpl repository;

    setUp(() {
      local = _MemoryLocal();
      remote = _MemoryRemote();
      repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      );
    });

    test('startup replaces cached role and owner with server account',
        () async {
      final result = await repository.getCurrentUser();
      expect((result as Success).data, _verifiedUser.toEntity());
      expect(remote.verifications, 1);
      expect(local.user, _verifiedUser);
    });

    for (final status in [401, 403]) {
      test('startup $status clears the saved session', () async {
        remote.failure = ServerException('Rejected', statusCode: status);
        final result = await repository.getCurrentUser();
        expect((result as Success).data, isNull);
        expect(local.token, isNull);
        expect(local.user, isNull);
      });
    }

    test('server error never grants access based on cached owner role',
        () async {
      remote.failure = const ServerException('Unavailable', statusCode: 500);
      expect((await repository.getCurrentUser()).isError, isTrue);
      expect(await repository.hasActiveSession(), isFalse);
      // Retained only for retry; the provider must not treat this as a login.
      expect(local.token, 'fixture-old-token');
    });

    test('non-remembered startup clears a leftover session without network',
        () async {
      local.remember = false;
      expect((await repository.getCurrentUser() as Success).data, isNull);
      expect(remote.verifications, 0);
      expect(local.token, isNull);
    });

    test('a late startup response does not resurrect a cleared session',
        () async {
      remote.pendingVerification = Completer<UserModel>();
      final startup = repository.getCurrentUser();
      await _settleEvents();
      await local.clearSession();
      remote.pendingVerification!.complete(_verifiedUser);
      expect((await startup as Success).data, isNull);
      expect(local.user, isNull);
      expect(local.token, isNull);
    });

    test('a throttled login returns the safe visible message', () async {
      remote.failure = const ServerException('Internal', statusCode: 429);
      final result = await repository.login(
        username: 'fixture',
        password: 'not-a-real-password',
        rememberMe: true,
      );
      expect(
        (result as Error).failure.message,
        'Terlalu banyak percobaan login. Coba lagi sebentar.',
      );
    });

    test('logout still clears local session when the server is unavailable',
        () async {
      remote.failure = const ServerException('Unavailable', statusCode: 500);
      await repository.logout();
      expect(local.token, isNull);
      expect(local.user, isNull);
    });
  });

  group('Session event race protection', () {
    late _MemoryLocal local;
    late _MemoryRemote remote;
    late StreamController<SessionExpiryEvent> events;
    late ProviderContainer container;

    setUp(() async {
      local = _MemoryLocal();
      remote = _MemoryRemote();
      events = StreamController<SessionExpiryEvent>.broadcast();
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(local),
          authRepositoryProvider.overrideWithValue(
            AuthRepositoryImpl(
              remoteDataSource: remote,
              localDataSource: local,
            ),
          ),
          sessionExpiryEventsProvider.overrideWithValue(events.stream),
        ],
      );
      await container.read(sessionProvider.future);
    });

    tearDown(() async {
      container.dispose();
      await events.close();
    });

    test('rejection of the active token clears account and storage', () async {
      events.add(
        const SessionExpiryEvent(
          accessToken: 'fixture-old-token',
          statusCode: 401,
        ),
      );
      await _settleEvents();
      expect(container.read(sessionProvider).valueOrNull, isNull);
      expect(local.token, isNull);
    });

    test('a late rejection of an earlier token leaves a new login intact',
        () async {
      await container.read(sessionProvider.notifier).login(
            username: 'fixture',
            password: 'not-a-real-password',
            rememberMe: true,
          );
      events.add(
        const SessionExpiryEvent(
          accessToken: 'fixture-old-token',
          statusCode: 401,
        ),
      );
      await _settleEvents();
      expect(local.token, 'fixture-new-token');
      expect(
        container.read(sessionProvider).valueOrNull,
        _verifiedUser.toEntity(),
      );
    });

    test('expiry arriving while login awaits is compared after the new save',
        () async {
      remote.pendingLogin = Completer<AuthResponseModel>();
      final login = container.read(sessionProvider.notifier).login(
            username: 'fixture',
            password: 'not-a-real-password',
            rememberMe: true,
          );
      await _settleEvents();
      events.add(
        const SessionExpiryEvent(
          accessToken: 'fixture-old-token',
          statusCode: 401,
        ),
      );
      remote.pendingLogin!.complete(
        AuthResponseModel(
          accessToken: 'fixture-new-token',
          refreshToken: '',
          user: _verifiedUser,
        ),
      );
      await login;
      await _settleEvents();
      expect(local.token, 'fixture-new-token');
      expect(
        container.read(sessionProvider).valueOrNull,
        _verifiedUser.toEntity(),
      );
    });

    test('a late profile update cannot restore a rejected session', () async {
      events.add(
        const SessionExpiryEvent(
          accessToken: 'fixture-old-token',
          statusCode: 401,
        ),
      );
      await container
          .read(sessionProvider.notifier)
          .replaceCurrentUser(_verifiedUser.toEntity());
      await _settleEvents();
      expect(container.read(sessionProvider).valueOrNull, isNull);
      expect(local.token, isNull);
    });
  });
}
