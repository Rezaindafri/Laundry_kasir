import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Menyimpan/menghapus token & user secara lokal untuk keperluan
/// Session Management, Remember Login, dan Auto Login.
abstract class AuthLocalDataSource {
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
    required bool rememberMe,
  });

  Future<UserModel?> getSavedUser();
  Future<String?> getAccessToken();
  Future<bool> isRememberLoginEnabled();
  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage secureStorage;
  final SharedPreferences sharedPreferences;

  const AuthLocalDataSourceImpl({
    required this.secureStorage,
    required this.sharedPreferences,
  });

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
    required bool rememberMe,
  }) async {
    try {
      await secureStorage.write(key: StorageKeys.accessToken, value: accessToken);
      await secureStorage.write(key: StorageKeys.refreshToken, value: refreshToken);
      await secureStorage.write(
        key: StorageKeys.currentUser,
        value: jsonEncode(user.toJson()),
      );
      await sharedPreferences.setBool(StorageKeys.rememberLogin, rememberMe);
    } catch (_) {
      throw const CacheException('Gagal menyimpan sesi login.');
    }
  }

  @override
  Future<UserModel?> getSavedUser() async {
    try {
      final raw = await secureStorage.read(key: StorageKeys.currentUser);
      if (raw == null) return null;
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const CacheException('Gagal membaca data sesi.');
    }
  }

  @override
  Future<String?> getAccessToken() {
    return secureStorage.read(key: StorageKeys.accessToken);
  }

  @override
  Future<bool> isRememberLoginEnabled() async {
    return sharedPreferences.getBool(StorageKeys.rememberLogin) ?? false;
  }

  @override
  Future<void> clearSession() async {
    await secureStorage.delete(key: StorageKeys.accessToken);
    await secureStorage.delete(key: StorageKeys.refreshToken);
    await secureStorage.delete(key: StorageKeys.currentUser);
    await sharedPreferences.remove(StorageKeys.rememberLogin);
  }
}
