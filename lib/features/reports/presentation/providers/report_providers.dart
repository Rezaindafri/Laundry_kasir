import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/models/report_models.dart';

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>(
  (ref) => ReportRemoteDataSourceImpl(DioClient().dio),
);

final reportsOverviewProvider =
    AsyncNotifierProvider<ReportsOverviewNotifier, OwnerReportOverview>(
  ReportsOverviewNotifier.new,
);

class ReportsOverviewNotifier extends AsyncNotifier<OwnerReportOverview> {
  DateTimeRange? _range;
  String? _cashierId;
  String? _sessionUserId;
  ReportRemoteDataSource get _remote =>
      ref.read(reportRemoteDataSourceProvider);

  @override
  Future<OwnerReportOverview> build() {
    final sessionUserId = ref.watch(currentSessionUserIdProvider);
    if (_sessionUserId != sessionUserId) {
      _sessionUserId = sessionUserId;
      _range = null;
      _cashierId = null;
    }
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> setRange(DateTimeRange range) async {
    _range = range;
    await refresh();
  }

  Future<void> setCashier(String? cashierId) async {
    _cashierId = cashierId;
    await refresh();
  }

  Future<Uint8List> exportCsv() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _range ?? DateTimeRange(start: today, end: now);
    return _remote.exportCsv(
      startDate: range.start,
      endDate: range.end,
      cashierId: _cashierId,
    );
  }

  Future<OwnerReportOverview> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _range ?? DateTimeRange(start: today, end: now);
    return _remote.getOverview(
      startDate: range.start,
      endDate: range.end,
      cashierId: _cashierId,
    );
  }
}
