import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/models/report_models.dart';

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>(
  (ref) => ReportRemoteDataSourceImpl(DioClient().dio),
);

final reportsOverviewProvider =
    AsyncNotifierProvider<ReportsOverviewNotifier, ReportsOverview>(
  ReportsOverviewNotifier.new,
);

class ReportsOverviewNotifier extends AsyncNotifier<ReportsOverview> {
  ReportRemoteDataSource get _remote =>
      ref.read(reportRemoteDataSourceProvider);

  @override
  Future<ReportsOverview> build() {
    ref.watch(currentSessionUserIdProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<Uint8List> exportCsv({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _remote.exportCsv(startDate: startDate, endDate: endDate);

  Future<ReportsOverview> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final results = await Future.wait([
      _remote.getRevenue(startDate: today, endDate: today),
      _remote.getRevenue(startDate: monthStart, endDate: today),
      _remote.getStatistics(),
    ]);
    return ReportsOverview(
      today: results[0] as RevenueReport,
      thisMonth: results[1] as RevenueReport,
      statistics: results[2] as ReportStatistics,
    );
  }
}
