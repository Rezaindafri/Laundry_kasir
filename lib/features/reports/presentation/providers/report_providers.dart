import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/business_time.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/models/report_models.dart';

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>(
  (ref) => ReportRemoteDataSourceImpl(DioClient().dio),
);
final reportClockProvider = Provider<DateTime Function()>(
  (ref) => BusinessTime.calendarNow,
);

final reportsOverviewProvider =
    AsyncNotifierProvider<ReportsOverviewNotifier, OwnerReportOverview>(
  ReportsOverviewNotifier.new,
);

class _ReportKey {
  _ReportKey(DateTimeRange range, this.cashierId)
      : start = DateTime(range.start.year, range.start.month, range.start.day),
        end = DateTime(range.end.year, range.end.month, range.end.day);
  final DateTime start;
  final DateTime end;
  final String? cashierId;

  @override
  bool operator ==(Object other) =>
      other is _ReportKey &&
      start == other.start &&
      end == other.end &&
      cashierId == other.cashierId;
  @override
  int get hashCode => Object.hash(start, end, cashierId);
}

class ReportsOverviewNotifier extends AsyncNotifier<OwnerReportOverview> {
  DateTimeRange? _range;
  String? _cashierId;
  String? _sessionUserId;
  bool _alive = true;
  int _generation = 0;
  int _selection = 0;
  DateTime? _loadedAt;
  List<ReportAccount> accounts = const [];
  final _cache = LinkedHashMap<_ReportKey, OwnerReportOverview>();
  final _pending = <_ReportKey, Future<OwnerReportOverview>>{};
  // Bound memory and traffic; arbitrary date/account combinations load on demand.
  static const _maxEntries = 48;
  static const _maxPrefetchAccounts = 12;
  static const _maxAge = Duration(minutes: 2);

  DateTimeRange get range {
    final now = ref.read(reportClockProvider)();
    return _range ??
        DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
  }

  String? get cashierId => _cashierId;

  ReportRemoteDataSource get _remote =>
      ref.read(reportRemoteDataSourceProvider);

  @override
  Future<OwnerReportOverview> build() async {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _clear();
    });
    final sessionUserId = ref.watch(currentSessionUserIdProvider);
    if (_sessionUserId != sessionUserId) {
      _sessionUserId = sessionUserId;
      _range = null;
      _cashierId = null;
      accounts = const [];
      _clear();
    }
    // Riverpod also publishes the Future returned by build(). A filter can be
    // selected before that initial Future finishes, so returning its old result
    // would overwrite even a newer manually assigned AsyncData.
    while (true) {
      final generation = _generation;
      final selection = _selection;
      OwnerReportOverview result;
      try {
        result = await _fetch(_ReportKey(range, _cashierId));
      } catch (_) {
        if (!_alive || generation == _generation && selection == _selection) {
          rethrow;
        }
        continue;
      }
      if (!_alive) return result;
      if (generation != _generation || selection != _selection) continue;
      accounts = result.accounts;
      _loadedAt = ref.read(reportClockProvider)();
      unawaited(_prefetch(generation));
      return result;
    }
  }

  void _clear() {
    _generation++;
    _selection++;
    _cache.clear();
    _pending.clear();
    _loadedAt = null;
  }

  Future<void> refresh() async {
    _clear();
    await _select();
  }

  Future<void> setRange(DateTimeRange value) async {
    _range = value;
    await _select();
  }

  Future<void> setCashier(String? cashierId) async {
    _cashierId = cashierId;
    await _select();
  }

  Future<void> _select() async {
    final now = ref.read(reportClockProvider)();
    if (_loadedAt != null &&
        (now.difference(_loadedAt!) > _maxAge ||
            now.day != _loadedAt!.day ||
            now.month != _loadedAt!.month ||
            now.year != _loadedAt!.year)) _clear();
    final generation = _generation;
    final selection = ++_selection;
    final key = _ReportKey(range, _cashierId);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      state = AsyncData(cached);
      unawaited(_prefetch(generation));
      return;
    }
    state = const AsyncLoading();
    try {
      final data = await _fetch(key);
      if (!_alive || generation != _generation || selection != _selection)
        return;
      accounts = data.accounts;
      _loadedAt ??= now;
      state = AsyncData(data);
      unawaited(_prefetch(generation));
    } catch (error, stack) {
      if (_alive && generation == _generation && selection == _selection) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<OwnerReportOverview> _fetch(_ReportKey key,
      {bool background = false}) {
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _pending[key] ??= _request(key, background: background);
  }

  Future<OwnerReportOverview> _request(_ReportKey key,
      {required bool background}) async {
    final generation = _generation;
    try {
      final data = await _remote.getOverview(
          startDate: key.start,
          endDate: key.end,
          cashierId: key.cashierId,
          background: background);
      if (_alive && generation == _generation) {
        _cache[key] = data;
        while (_cache.length > _maxEntries) _cache.remove(_cache.keys.first);
      }
      return data;
    } finally {
      if (generation == _generation) _pending.remove(key);
    }
  }

  int? _prefetchingGeneration;
  Future<void> _prefetch(int generation) async {
    if (_prefetchingGeneration == generation) return;
    final now = ref.read(reportClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final periods = [
      DateTimeRange(start: today, end: today),
      DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
      DateTimeRange(start: DateTime(now.year, now.month), end: today)
    ];
    final selectedAccount = _cashierId;
    final selectedRange = range;
    final queue = Queue<_ReportKey>.of([
      for (final period in periods) _ReportKey(period, selectedAccount),
      _ReportKey(selectedRange, null),
      for (final account in accounts.take(_maxPrefetchAccounts)) ...[
        _ReportKey(selectedRange, account.id),
        for (final period in periods) _ReportKey(period, account.id),
      ],
    ]);
    Future<void> worker() async {
      while (_alive && generation == _generation && queue.isNotEmpty) {
        final key = queue.removeFirst();
        try {
          await _fetch(key, background: true);
        } catch (_) {
          // Do not drain dozens of failing speculative requests when offline
          // or rate-limited. A future user action can try preparing them again.
          queue.clear();
          return;
        }
      }
    }

    _prefetchingGeneration = generation;
    try {
      await Future.wait([worker(), worker()]);
    } finally {
      if (_prefetchingGeneration == generation) _prefetchingGeneration = null;
    }
  }

  Future<Uint8List> exportCsv() {
    final selected = range;
    return _remote.exportCsv(
        startDate: selected.start,
        endDate: selected.end,
        cashierId: _cashierId);
  }
}
