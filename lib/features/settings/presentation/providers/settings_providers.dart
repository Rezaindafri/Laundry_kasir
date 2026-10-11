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
  Future<void> refresh() async {
    final current = state.valueOrNull;
    try {
      final remote = await ref.read(settingsRemoteDataSourceProvider).getSettings();
      if (current != null) {
        state = AsyncData(remote.copyWith(paperSize: current.paperSize,
          defaultPrinter: current.defaultPrinter, defaultPrinterName: current.defaultPrinterName));
      } else { state = AsyncData(remote); }
    } catch (_) {
      // Do not discard an unsaved settings form when connectivity is lost.
    }
  }
  @override
  Future<LaundrySettings> build() async {
    final ownerScopeId = ref.watch(currentOperationalOwnerScopeIdProvider);
    final local = ref.read(settingsRepositoryProvider).load(ownerId: ownerScopeId);
    try {
      final remote =
          await ref.read(settingsRemoteDataSourceProvider).getSettings();
      final merged = remote.copyWith(
        paperSize: local.paperSize,
        defaultPrinter: local.defaultPrinter,
        defaultPrinterName: local.defaultPrinterName,
      );
      await ref.read(settingsRepositoryProvider).save(merged, ownerId: ownerScopeId);
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
    state = AsyncData(remote.copyWith(
      paperSize: value.paperSize,
      defaultPrinter: value.defaultPrinter,
      defaultPrinterName: value.defaultPrinterName,
    ));
  }

  Future<void> saveDeviceSettings(LaundrySettings value) async {
    final ownerScopeId = ref.read(currentOperationalOwnerScopeIdProvider);
    await ref
        .read(settingsRepositoryProvider)
        .save(value, ownerId: ownerScopeId);
    state = AsyncData(value);
  }

  Future<Uint8List> downloadBackup() =>
      ref.read(settingsRemoteDataSourceProvider).downloadBackup();

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    await ref.read(settingsRemoteDataSourceProvider).restoreBackup(backup);
  }
}
