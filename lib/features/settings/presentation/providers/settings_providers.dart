import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/local_settings_repository.dart';
import '../../data/datasources/settings_remote_datasource.dart';
import '../../domain/entities/laundry_settings.dart';

final settingsRepositoryProvider = Provider<LocalSettingsRepository>(
  (ref) => LocalSettingsRepository(ref.watch(sharedPreferencesProvider)),
);
final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource>(
  (ref) => SettingsRemoteDataSourceImpl(DioClient().dio),
);
final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSourceImpl(DioClient().dio),
);
final currentProfileProvider = FutureProvider(
  (ref) {
    ref.watch(currentSessionUserIdProvider);
    return ref.watch(profileRemoteDataSourceProvider).getProfile();
  },
);
final superOwnerSettingsProvider = FutureProvider(
  (ref) {
    ref.watch(currentSessionUserIdProvider);
    return ref.watch(profileRemoteDataSourceProvider).getSuperOwnerSettings();
  },
);
final accountPasswordMinLengthProvider = FutureProvider(
  (ref) {
    ref.watch(currentSessionUserIdProvider);
    return ref
        .watch(profileRemoteDataSourceProvider)
        .getAccountPasswordMinLength();
  },
);
final laundrySettingsProvider =
    AsyncNotifierProvider<LaundrySettingsNotifier, LaundrySettings>(
  LaundrySettingsNotifier.new,
);

class LaundrySettingsNotifier extends AsyncNotifier<LaundrySettings> {
  LaundrySettings _withDeviceSettings(
    LaundrySettings business,
    LaundrySettings device,
  ) =>
      LaundrySettings(
        businessName: business.businessName,
        phone: business.phone,
        address: business.address,
        paperSize: device.paperSize,
        defaultPrinter: device.defaultPrinter,
        defaultPrinterName: device.defaultPrinterName,
      );

  Future<void> refresh() async {
    final ownerScopeId = ref.read(currentOperationalOwnerScopeIdProvider);
    try {
      final remote =
          await ref.read(settingsRemoteDataSourceProvider).getSettings();
      if (ownerScopeId != ref.read(currentOperationalOwnerScopeIdProvider)) {
        return;
      }
      final device =
          ref.read(settingsRepositoryProvider).load(ownerId: ownerScopeId);
      state = AsyncData(_withDeviceSettings(remote, device));
    } catch (_) {
      // Do not discard an unsaved settings form when connectivity is lost.
    }
  }

  @override
  Future<LaundrySettings> build() async {
    final ownerScopeId = ref.watch(currentOperationalOwnerScopeIdProvider);
    final local =
        ref.read(settingsRepositoryProvider).load(ownerId: ownerScopeId);
    try {
      final remote =
          await ref.read(settingsRemoteDataSourceProvider).getSettings();
      final merged = _withDeviceSettings(remote, local);
      await ref
          .read(settingsRepositoryProvider)
          .save(merged, ownerId: ownerScopeId);
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<void> save(LaundrySettings value) async {
    final ownerScopeId = ref.read(currentOperationalOwnerScopeIdProvider);
    await ref
        .read(settingsRepositoryProvider)
        .save(value, ownerId: ownerScopeId);
    final remote =
        await ref.read(settingsRemoteDataSourceProvider).saveSettings(value);
    if (ownerScopeId != ref.read(currentOperationalOwnerScopeIdProvider)) {
      return;
    }
    final device =
        ref.read(settingsRepositoryProvider).load(ownerId: ownerScopeId);
    state = AsyncData(_withDeviceSettings(remote, device));
  }

  Future<void> saveDeviceSettings(LaundrySettings value) async {
    final ownerScopeId = ref.read(currentOperationalOwnerScopeIdProvider);
    await ref.read(settingsRepositoryProvider).saveDeviceSettings(value);
    if (ownerScopeId != ref.read(currentOperationalOwnerScopeIdProvider)) {
      return;
    }
    final current = state.valueOrNull ??
        ref.read(settingsRepositoryProvider).load(ownerId: ownerScopeId);
    state = AsyncData(_withDeviceSettings(current, value));
  }

  Future<Uint8List> downloadBackup() =>
      ref.read(settingsRemoteDataSourceProvider).downloadBackup();

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    await ref.read(settingsRemoteDataSourceProvider).restoreBackup(backup);
  }
}
