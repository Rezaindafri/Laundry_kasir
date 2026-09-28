import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../data/models/dashboard_owner_model.dart';
import '../../data/models/dashboard_kasir_model.dart';
import '../../domain/repositories/dashboard_repository.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSourceImpl(DioClient().dio),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    remoteDataSource: ref.watch(dashboardRemoteDataSourceProvider),
  );
});

final ownerDashboardProvider = AsyncNotifierProvider<OwnerDashboardNotifier, DashboardOwnerResponse>(
  OwnerDashboardNotifier.new,
);

class OwnerDashboardNotifier extends AsyncNotifier<DashboardOwnerResponse> {
  @override
  Future<DashboardOwnerResponse> build() async {
    final result = await ref.read(dashboardRepositoryProvider).getOwnerDashboard();
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

final kasirDashboardProvider =
    AsyncNotifierProvider<KasirDashboardNotifier, DashboardKasirResponse>(
  KasirDashboardNotifier.new,
);

class KasirDashboardNotifier extends AsyncNotifier<DashboardKasirResponse> {
  @override
  Future<DashboardKasirResponse> build() async {
    final result = await ref.read(dashboardRepositoryProvider).getKasirDashboard();
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
