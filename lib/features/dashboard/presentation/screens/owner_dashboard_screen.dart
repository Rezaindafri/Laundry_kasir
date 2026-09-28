import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../master_data/domain/entities/customer_entity.dart';
import '../../../master_data/presentation/providers/master_data_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/models/dashboard_owner_model.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_shell.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  final UserEntity user;

  const OwnerDashboardScreen({required this.user, super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  _RevenuePeriod _selectedPeriod = _RevenuePeriod.week;
  String _selectedAccount = 'Keseluruhan';

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(ownerDashboardProvider);
    final dashboard = dashboardState.valueOrNull;
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    final effectiveTransactions =
        _filterByAccount(transactions, _selectedAccount);
    final effectiveCustomers = _filterCustomersByAccount(
        customers, _selectedAccount, effectiveTransactions);

    final dashboardSummary = dashboard?.summary != null
        ? _buildDashboardSummaryFromApi(dashboard!.summary, currency)
        : _buildDashboardSummary(
            effectiveTransactions,
            effectiveCustomers,
            now,
            _selectedPeriod,
          );
    final chartSeries = dashboard?.chart.isNotEmpty == true
        ? dashboard!.chart
            .map((item) => _RevenuePoint(
                item.label.substring(0, 1).toUpperCase() +
                    item.label.substring(1),
                item.value.toDouble()))
            .toList()
        : _buildRevenueSeries(effectiveTransactions, now, _selectedPeriod);
    final serviceDistribution = _serviceDistribution(effectiveTransactions);
    final operationalStats = _operationalStats(effectiveTransactions, now);
    final attentionItems =
        _attentionItems(effectiveTransactions, now, currency);
    final popularServices = _popularServices(effectiveTransactions);
    final accountOptions = dashboard?.accountOptions ?? _availableAccounts();

    if (dashboardState.isLoading) {
      return DashboardShell(
        user: widget.user,
        title: 'Dashboard Owner',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (dashboardState.hasError && dashboard == null) {
      return DashboardShell(
        user: widget.user,
        title: 'Dashboard Owner',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat dashboard owner. Coba tarik ke bawah untuk memperbarui.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
          ),
        ),
      );
    }

    return DashboardShell(
      user: widget.user,
      title: 'Dashboard Owner',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerDashboardProvider);
          await ref.read(ownerDashboardProvider.future);
          ref.invalidate(transactionsProvider);
          await ref.read(transactionsProvider.future);
          ref.invalidate(customersProvider);
          await ref.read(customersProvider.future);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _FilterChipButton(
                    label: _selectedAccount,
                    onTap: () => _showFilterSheet(context, accountOptions),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                  children: [
                    _KpiCard(
                      label: 'Pendapatan',
                      value: currency.format(dashboardSummary.revenue),
                      trend: dashboardSummary.revenueTrend,
                      onTap: () => GoRouter.of(context).push(AppRoutes.reports),
                    ),
                    _KpiCard(
                      label: 'Transaksi',
                      value: dashboardSummary.transactions.toString(),
                      trend: dashboardSummary.transactionTrend,
                      onTap: () =>
                          GoRouter.of(context).push(AppRoutes.transactions),
                    ),
                    _KpiCard(
                      label: 'Pelanggan',
                      value: dashboardSummary.customers.toString(),
                      trend: dashboardSummary.customerTrend,
                      onTap: () =>
                          GoRouter.of(context).push(AppRoutes.customers),
                    ),
                    _KpiCard(
                      label: 'Belum Diambil',
                      value: dashboardSummary.processing.toString(),
                      trend: dashboardSummary.processingTrend,
                      onTap: () =>
                          GoRouter.of(context).push(AppRoutes.transactions),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pendapatan',
                        style: AppTextStyles.title,
                      ),
                    ),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: _RevenuePeriod.values.map((period) {
                          final selected = period == _selectedPeriod;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedPeriod = period),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    selected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                ),
                              ),
                              child: Text(
                                period.label,
                                style: AppTextStyles.bodyMuted.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '',
                  trailing: '',
                  child: chartSeries.isEmpty ||
                          chartSeries.every((point) => point.value <= 0)
                      ? _EmptyRevenueState(currency: currency)
                      : _RevenueChart(points: chartSeries),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Performa Laundry',
                  trailing: 'Lihat semua',
                  child: _LaundryPerformance(distribution: serviceDistribution),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Monitoring Operasional',
                  trailing: 'Lihat detail',
                  child: _OperationalMonitoring(items: operationalStats),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Yang Perlu Perhatian',
                  trailing: 'Lihat semua',
                  child: Column(
                    children: attentionItems
                        .map((item) => _AttentionRow(item: item))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Layanan Terpopuler',
                  trailing: 'Detail',
                  child: _InsightList(items: popularServices),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Pelanggan',
                  trailing: 'Analitik',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_activeCustomers(effectiveTransactions).length}',
                        style: AppTextStyles.headline.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'pelanggan aktif',
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: 12),
                      if (effectiveCustomers.isEmpty)
                        Text('Belum ada data pelanggan',
                            style: AppTextStyles.bodyMuted)
                      else ...[
                        for (final customer in effectiveCustomers.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      customer.name.trim().isNotEmpty
                                          ? customer.name[0].toUpperCase()
                                          : '?',
                                      style: AppTextStyles.label.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    customer.name,
                                    style: AppTextStyles.body,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(
      BuildContext context, List<String> accounts) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Akun',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...accounts.map((account) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(account),
                      leading: Radio<String>(
                        value: account,
                        groupValue: _selectedAccount,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedAccount = value);
                            Navigator.pop(sheetContext, value);
                          }
                        },
                      ),
                      onTap: () {
                        setState(() => _selectedAccount = account);
                        Navigator.pop(sheetContext, account);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _selectedAccount = result);
    }
  }
}

List<String> _availableAccounts() {
  return const ['Keseluruhan', 'Kasir 1'];
}

enum _RevenuePeriod {
  week,
  month,
  year;

  String get label {
    switch (this) {
      case _RevenuePeriod.week:
        return 'Minggu ini';
      case _RevenuePeriod.month:
        return 'Bulan ini';
      case _RevenuePeriod.year:
        return 'Tahun';
    }
  }
}

class _DashboardSummary {
  final int revenue;
  final String revenueTrend;
  final int transactions;
  final String transactionTrend;
  final int customers;
  final String customerTrend;
  final int processing;
  final String processingTrend;

  const _DashboardSummary({
    required this.revenue,
    required this.revenueTrend,
    required this.transactions,
    required this.transactionTrend,
    required this.customers,
    required this.customerTrend,
    required this.processing,
    required this.processingTrend,
  });
}

List<TransactionEntity> _filterByAccount(
    List<TransactionEntity> items, String account) {
  if (account == 'Keseluruhan' || account.isEmpty) {
    return items;
  }

  return items;
}

List<CustomerEntity> _filterCustomersByAccount(
  List<CustomerEntity> customers,
  String account,
  List<TransactionEntity> transactions,
) {
  if (account == 'Keseluruhan' || account.isEmpty) {
    return customers;
  }

  return customers;
}

_DashboardSummary _buildDashboardSummaryFromApi(
  DashboardOwnerSummary summary,
  NumberFormat currency,
) {
  return _DashboardSummary(
    revenue: summary.revenue,
    revenueTrend: summary.todayRevenue > 0
        ? 'Hari ini ${currency.format(summary.todayRevenue)}'
        : 'Belum ada data',
    transactions: summary.transactions,
    transactionTrend:
        summary.transactions > 0 ? 'Data realtime' : 'Belum ada data',
    customers: summary.customers,
    customerTrend:
        summary.customers > 0 ? 'Pelanggan aktif' : 'Belum ada pelanggan',
    processing: summary.processing,
    processingTrend: summary.processing > 0
        ? '${summary.readyToPickup} siap diambil'
        : 'Kosong',
  );
}

_DashboardSummary _buildDashboardSummary(
  List<TransactionEntity> items,
  List<CustomerEntity> customers,
  DateTime now,
  _RevenuePeriod period,
) {
  final revenue = items.fold<int>(0, (sum, item) => sum + item.paidAmount);
  final transactionsCount = items.length;
  final customerCount = customers.length;
  final processingCount = _processingCount(items, now);

  final comparisonRevenue = _revenueForPeriod(items, period, now, offset: 1);
  final revenueTrend = revenue == 0
      ? 'Belum ada data'
      : comparisonRevenue == 0
          ? 'Baru dimulai'
          : revenue >= comparisonRevenue
              ? '+${_formatPercent(revenue - comparisonRevenue, comparisonRevenue)}%'
              : '-${_formatPercent(comparisonRevenue - revenue, comparisonRevenue)}%';

  final comparisonTransactions =
      _transactionCountForPeriod(items, period, now, offset: 1);
  final transactionTrend = transactionsCount == 0
      ? 'Belum ada data'
      : comparisonTransactions == 0
          ? 'Baru dimulai'
          : transactionsCount >= comparisonTransactions
              ? '+${_formatPercent(transactionsCount - comparisonTransactions, comparisonTransactions)}%'
              : '-${_formatPercent(comparisonTransactions - transactionsCount, comparisonTransactions)}%';

  final customerTrend =
      customerCount > 0 ? 'Aktif hari ini' : 'Belum ada pelanggan';
  final processingTrend = processingCount > 0
      ? '${_readyForPickup(items, now)} siap diambil'
      : 'Kosong';

  return _DashboardSummary(
    revenue: revenue,
    revenueTrend: revenueTrend,
    transactions: transactionsCount,
    transactionTrend: transactionTrend,
    customers: customerCount,
    customerTrend: customerTrend,
    processing: processingCount,
    processingTrend: processingTrend,
  );
}

List<_RevenuePoint> _buildRevenueSeries(
    List<TransactionEntity> items, DateTime now, _RevenuePeriod period) {
  switch (period) {
    case _RevenuePeriod.week:
      final series = <_RevenuePoint>[];
      for (var i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final target = DateTime(date.year, date.month, date.day);
        final revenue = items
            .where((item) => DateTime(item.createdAt.year, item.createdAt.month,
                    item.createdAt.day)
                .isAtSameMomentAs(target))
            .fold<int>(0, (sum, item) => sum + item.paidAmount);
        series.add(_RevenuePoint(
            DateFormat.E('id_ID').format(date).substring(0, 3),
            revenue.toDouble()));
      }
      return series;
    case _RevenuePeriod.month:
      return List.generate(4, (index) {
        final start =
            DateTime(now.year, now.month, 1).add(Duration(days: index * 7));
        final end = start.add(const Duration(days: 6));
        final revenue = items.where((item) {
          final date = item.createdAt;
          return !date.isBefore(start) && !date.isAfter(end);
        }).fold<int>(0, (sum, item) => sum + item.paidAmount);
        return _RevenuePoint('M${index + 1}', revenue.toDouble());
      });
    case _RevenuePeriod.year:
      return List.generate(7, (index) {
        final month = now.month - (6 - index);
        final year = now.year;
        final normalizedMonth = month <= 0 ? month + 12 : month;
        final normalizedYear = month <= 0 ? year - 1 : year;
        final firstDay = DateTime(normalizedYear, normalizedMonth, 1);
        final lastDay = DateTime(normalizedYear, normalizedMonth + 1, 0);
        final revenue = items.where((item) {
          final date = item.createdAt;
          return !date.isBefore(firstDay) && !date.isAfter(lastDay);
        }).fold<int>(0, (sum, item) => sum + item.paidAmount);
        return _RevenuePoint(
            DateFormat.MMM('id_ID').format(firstDay).substring(0, 3),
            revenue.toDouble());
      });
  }
}

int _revenueForPeriod(
    List<TransactionEntity> items, _RevenuePeriod period, DateTime now,
    {required int offset}) {
  switch (period) {
    case _RevenuePeriod.week:
      final target = now.subtract(Duration(days: 7 * offset));
      return items
          .where((item) =>
              item.createdAt.isAfter(target) && item.createdAt.isBefore(now))
          .fold<int>(0, (sum, item) => sum + item.paidAmount);
    case _RevenuePeriod.month:
      final target = DateTime(now.year, now.month - offset, 1);
      final end = DateTime(now.year, now.month, 0);
      return items
          .where((item) =>
              !item.createdAt.isBefore(target) && !item.createdAt.isAfter(end))
          .fold<int>(0, (sum, item) => sum + item.paidAmount);
    case _RevenuePeriod.year:
      final start = DateTime(now.year - offset, 1, 1);
      final end = DateTime(now.year - offset + 1, 0, 31);
      return items
          .where((item) =>
              !item.createdAt.isBefore(start) && !item.createdAt.isAfter(end))
          .fold<int>(0, (sum, item) => sum + item.paidAmount);
  }
}

int _transactionCountForPeriod(
    List<TransactionEntity> items, _RevenuePeriod period, DateTime now,
    {required int offset}) {
  switch (period) {
    case _RevenuePeriod.week:
      final target = now.subtract(Duration(days: 7 * offset));
      return items
          .where((item) =>
              item.createdAt.isAfter(target) && item.createdAt.isBefore(now))
          .length;
    case _RevenuePeriod.month:
      final start = DateTime(now.year, now.month - offset, 1);
      final end = DateTime(now.year, now.month, 0);
      return items
          .where((item) =>
              !item.createdAt.isBefore(start) && !item.createdAt.isAfter(end))
          .length;
    case _RevenuePeriod.year:
      final start = DateTime(now.year - offset, 1, 1);
      final end = DateTime(now.year - offset + 1, 12, 31);
      return items
          .where((item) =>
              !item.createdAt.isBefore(start) && !item.createdAt.isAfter(end))
          .length;
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label,
                style:
                    AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final VoidCallback onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodyMuted),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTextStyles.headline.copyWith(fontSize: 24),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trend,
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppTextStyles.title),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  trailing,
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _EmptyRevenueState extends StatelessWidget {
  final NumberFormat currency;

  const _EmptyRevenueState({required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada pendapatan',
                style: AppTextStyles.title.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Data pendapatan akan muncul setelah transaksi berhasil dibayar.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${currency.format(0)} total',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<_RevenuePoint> points;

  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.isEmpty
        ? 1.0
        : points.map((p) => p.value).reduce(math.max).toDouble();
    final textDirection = Directionality.of(context);
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _RevenueChartPainter(
          points: points,
          maxValue: maxValue,
          textDirection: textDirection,
        ),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<_RevenuePoint> points;
  final double maxValue;
  final TextDirection textDirection;

  const _RevenueChartPainter({
    required this.points,
    required this.maxValue,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x6640A3FF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final gridPaint = Paint()
      ..color = const Color(0xFFE6EDF6)
      ..strokeWidth = 1;
    final textStyle = AppTextStyles.bodyMuted.copyWith(fontSize: 11);

    final chartRect = Rect.fromLTWH(12, 14, size.width - 26, size.height - 36);
    final innerHeight = chartRect.height;
    final innerWidth = chartRect.width;

    for (var i = 0; i <= 3; i++) {
      final y = chartRect.top + (innerHeight / 3) * i;
      canvas.drawLine(
          Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }

    final path = Path();
    final areaPath = Path();
    final pointsCount = points.length;
    if (pointsCount > 0) {
      for (var i = 0; i < pointsCount; i++) {
        final point = points[i];
        final x =
            chartRect.left + (innerWidth / math.max(1, pointsCount - 1)) * i;
        final normalized = point.value / (maxValue == 0 ? 1 : maxValue);
        final y = chartRect.bottom - (normalized * innerHeight);
        if (i == 0) {
          path.moveTo(x, y);
          areaPath.moveTo(x, chartRect.bottom);
          areaPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          areaPath.lineTo(x, y);
        }
      }
      areaPath.lineTo(chartRect.right, chartRect.bottom);
      areaPath.close();
      canvas.drawPath(areaPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x =
          chartRect.left + (innerWidth / math.max(1, points.length - 1)) * i;
      final normalized = point.value / (maxValue == 0 ? 1 : maxValue);
      final y = chartRect.bottom - (normalized * innerHeight);
      final dotPaint = Paint()..color = AppColors.primary;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      final label = point.label;
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: textDirection,
      )..layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, size.height - 20));
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) => false;
}

class _LaundryPerformance extends StatelessWidget {
  final List<_DistributionItem> distribution;

  const _LaundryPerformance({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.fold<int>(0, (sum, item) => sum + item.count);
    final items = distribution.where((item) => item.count > 0).toList();

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _DonutPainter(items, Directionality.of(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppTextStyles.bodyMuted,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          item.count.toString(),
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          total == 0
                              ? '0%'
                              : '${((item.count / total) * 100).round()}%',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalMonitoring extends StatelessWidget {
  final List<_MonitoringItem> items;

  const _OperationalMonitoring({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, size: 16, color: item.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.label, style: AppTextStyles.body),
                ),
                Text(
                  item.count.toString(),
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final _AttentionItem item;

  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 16, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(item.subtitle, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _InsightList extends StatelessWidget {
  final List<_InsightItem> items;

  const _InsightList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('Belum ada data layanan', style: AppTextStyles.bodyMuted);
    }

    return Column(
      children: [
        for (final item in items)
          Row(
            children: [
              Expanded(
                child: Text(item.label, style: AppTextStyles.body),
              ),
              Text(
                item.value,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DistributionItem> items;
  final TextDirection textDirection;

  const _DonutPainter(this.items, this.textDirection);

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = -math.pi / 2;
    final total = items.fold<int>(0, (sum, item) => sum + item.count);
    if (total == 0) {
      final basePaint = Paint()
        ..color = const Color(0xFFE7EDF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16;
      canvas.drawArc(
        Rect.fromCenter(
            center: size.center(Offset.zero),
            width: size.width,
            height: size.height),
        0,
        math.pi * 2,
        false,
        basePaint,
      );
      return;
    }

    double sweepStart = startAngle;
    for (final item in items) {
      final sweep = (item.count / total) * math.pi * 2;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
            center: size.center(Offset.zero),
            width: size.width * 0.9,
            height: size.height * 0.9),
        sweepStart,
        sweep,
        false,
        paint,
      );
      sweepStart += sweep;
    }

    final innerCircle = Paint()..color = Colors.white;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.38, innerCircle);

    final label = total.toString();
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTextStyles.title.copyWith(fontSize: 18),
      ),
      textDirection: textDirection,
    )..layout();
    textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RevenuePoint {
  final String label;
  final double value;

  const _RevenuePoint(this.label, this.value);
}

class _DistributionItem {
  final String label;
  final int count;
  final Color color;

  const _DistributionItem(this.label, this.count, this.color);
}

class _MonitoringItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _MonitoringItem(this.label, this.count, this.icon, this.color);
}

class _AttentionItem {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _AttentionItem(this.title, this.subtitle, this.color, this.icon);
}

class _InsightItem {
  final String label;
  final String value;

  const _InsightItem(this.label, this.value);
}

int _processingCount(List<TransactionEntity> items, DateTime now) {
  return items.where((item) {
    final status = item.resolveLaundryStatusAt(now);
    return status != LaundryStatus.completed &&
        status != LaundryStatus.collected &&
        status != LaundryStatus.late;
  }).length;
}

int _readyForPickup(List<TransactionEntity> items, DateTime now) {
  return items.where((item) {
    final status = item.resolveLaundryStatusAt(now);
    return status == LaundryStatus.completed ||
        status == LaundryStatus.collected;
  }).length;
}

List<_DistributionItem> _serviceDistribution(List<TransactionEntity> items) {
  final map = <String, int>{};
  for (final item in items) {
    map.update(item.serviceName, (value) => value + 1, ifAbsent: () => 1);
  }

  final colors = [
    AppColors.primary,
    AppColors.statusSelesai,
    AppColors.statusDicuci,
    AppColors.warning,
    AppColors.error,
  ];

  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return entries
      .take(4)
      .toList()
      .asMap()
      .entries
      .map((entry) => _DistributionItem(entry.value.key, entry.value.value,
          colors[entry.key % colors.length]))
      .toList();
}

List<_MonitoringItem> _operationalStats(
    List<TransactionEntity> items, DateTime now) {
  final inProgress = items.where((item) {
    final status = item.resolveLaundryStatusAt(now);
    return status != LaundryStatus.completed &&
        status != LaundryStatus.collected &&
        status != LaundryStatus.late;
  }).length;

  final nearDeadline = items.where((item) {
    final diff = item.estimatedFinishAt.difference(now).inHours;
    return diff >= 0 &&
        diff <= 24 &&
        item.laundryStatus != LaundryStatus.collected;
  }).length;

  final late = items
      .where((item) => item.resolveLaundryStatusAt(now) == LaundryStatus.late)
      .length;
  final ready = items
      .where(
          (item) => item.resolveLaundryStatusAt(now) == LaundryStatus.completed)
      .length;

  return [
    _MonitoringItem('Diproses', inProgress,
        Icons.local_laundry_service_outlined, AppColors.statusDicuci),
    _MonitoringItem('Mendekati Deadline', nearDeadline, Icons.timelapse_rounded,
        AppColors.statusDikeringkan),
    _MonitoringItem(
        'Terlambat', late, Icons.warning_amber_rounded, AppColors.error),
    _MonitoringItem('Siap Diambil', ready, Icons.check_circle_outline_rounded,
        AppColors.success),
  ];
}

List<_AttentionItem> _attentionItems(
    List<TransactionEntity> items, DateTime now, NumberFormat currency) {
  final alerts = <_AttentionItem>[];
  final late = items
      .where((item) => item.resolveLaundryStatusAt(now) == LaundryStatus.late)
      .toList();
  for (final item in late.take(1)) {
    alerts.add(_AttentionItem(
      'Transaksi terlambat',
      '${item.customerName} • ${currency.format(item.total)}',
      AppColors.error,
      Icons.warning_amber_rounded,
    ));
  }

  final nearDeadline = items.where((item) {
    final diff = item.estimatedFinishAt.difference(now).inHours;
    return diff >= 0 &&
        diff <= 24 &&
        item.laundryStatus != LaundryStatus.collected;
  }).toList();
  for (final item in nearDeadline.take(1)) {
    alerts.add(_AttentionItem(
      'Mendekati deadline',
      '${item.customerName} • Estimasi ${DateFormat.Hm('id_ID').format(item.estimatedFinishAt)}',
      AppColors.warning,
      Icons.schedule_rounded,
    ));
  }

  final unpaid =
      items.where((item) => item.paymentStatus != PaymentStatus.paid).toList();
  for (final item in unpaid.take(1)) {
    alerts.add(_AttentionItem(
      'Pembayaran belum lengkap',
      '${item.customerName} • ${currency.format(item.remainingPayment)} tersisa',
      AppColors.info,
      Icons.account_balance_wallet_outlined,
    ));
  }

  return alerts.take(3).toList();
}

List<_InsightItem> _popularServices(List<TransactionEntity> items) {
  final map = <String, int>{};
  for (final item in items) {
    map.update(item.serviceName, (value) => value + 1, ifAbsent: () => 1);
  }

  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .take(3)
      .map((entry) => _InsightItem(entry.key, '${entry.value}x'))
      .toList();
}

List<String> _activeCustomers(List<TransactionEntity> items) {
  final ids = <String>{};
  for (final item in items) {
    ids.add(item.customerId);
  }
  return ids.toList();
}

int _formatPercent(int delta, int base) {
  if (base <= 0) return 0;
  return ((delta / base) * 100).abs().round();
}
