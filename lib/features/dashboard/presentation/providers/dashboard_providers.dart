import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../data/models/dashboard_owner_model.dart';
import '../../data/models/dashboard_kasir_model.dart';
import '../../data/models/dashboard_super_owner_model.dart';
import '../../domain/repositories/dashboard_repository.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSourceImpl(DioClient().dio),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    remoteDataSource: ref.watch(dashboardRemoteDataSourceProvider),
  );
});

final ownerDashboardProvider =
    AsyncNotifierProvider<OwnerDashboardNotifier, DashboardOwnerResponse>(
  OwnerDashboardNotifier.new,
);

class OwnerDashboardNotifier extends AsyncNotifier<DashboardOwnerResponse> {
  String _period = 'week';
  String? _cashierId;
  String? _sessionUserId;

  @override
  Future<DashboardOwnerResponse> build() async {
    final sessionUserId = ref.watch(currentSessionUserIdProvider);
    if (_sessionUserId != sessionUserId) {
      _sessionUserId = sessionUserId;
      _period = 'week';
      _cashierId = null;
    }
    final result =
        await ref.read(dashboardRepositoryProvider).getOwnerDashboard(
              period: _period,
              cashierId: _cashierId,
            );
    return result.when(
      success: (data) => data,
      error: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> applyFilters({required String period, String? cashierId}) async {
    _period = period;
    _cashierId = cashierId;
    await refresh();
  }
}

final kasirDashboardProvider =
    AsyncNotifierProvider<KasirDashboardNotifier, DashboardKasirResponse>(
  KasirDashboardNotifier.new,
);

class KasirDashboardNotifier extends AsyncNotifier<DashboardKasirResponse> {
  @override
  Future<DashboardKasirResponse> build() async {
    ref.watch(currentSessionUserIdProvider);
    final result =
        await ref.read(dashboardRepositoryProvider).getKasirDashboard();
    return result.when(
      success: (data) => data,
      error: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final superOwnerDashboardProvider = AsyncNotifierProvider<
    SuperOwnerDashboardNotifier, DashboardSuperOwnerResponse>(
  SuperOwnerDashboardNotifier.new,
);

class SuperOwnerDashboardNotifier
    extends AsyncNotifier<DashboardSuperOwnerResponse> {
  @override
  Future<DashboardSuperOwnerResponse> build() async {
    ref.watch(currentSessionUserIdProvider);
    final result =
        await ref.read(dashboardRepositoryProvider).getSuperOwnerDashboard();
    return result.when(
      success: (data) => data,
      error: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}
