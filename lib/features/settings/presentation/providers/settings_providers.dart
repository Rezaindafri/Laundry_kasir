import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/local_settings_repository.dart';
import '../../domain/entities/laundry_settings.dart';

final settingsRepositoryProvider = Provider<LocalSettingsRepository>(
    (ref) => LocalSettingsRepository(ref.watch(sharedPreferencesProvider)),);
final laundrySettingsProvider =
    AsyncNotifierProvider<LaundrySettingsNotifier, LaundrySettings>(
        LaundrySettingsNotifier.new,);

class LaundrySettingsNotifier extends AsyncNotifier<LaundrySettings> {
  @override
  Future<LaundrySettings> build() async =>
      ref.read(settingsRepositoryProvider).load();
  Future<void> save(LaundrySettings value) async {
    await ref.read(settingsRepositoryProvider).save(value);
    state = AsyncData(value);
  }
}
