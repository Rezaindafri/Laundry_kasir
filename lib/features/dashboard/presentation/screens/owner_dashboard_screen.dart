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
import '../../../transactions/presentation/screens/transactions_screen.dart';
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
  String _selectedAccountId = 'all';

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
        _filterByAccount(transactions, _selectedAccountId);
    final effectiveCustomers = _filterCustomersByAccount(
        customers, _selectedAccountId, effectiveTransactions);

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
    final serviceDistribution = dashboard == null
        ? _serviceDistribution(effectiveTransactions)
        : _serverDistribution(dashboard.insights);
    final operationalStats = dashboard == null
        ? _operationalStats(effectiveTransactions, now)
        : _serverMonitoring(dashboard.insights);
    final attentionItems = dashboard == null
        ? _attentionItems(effectiveTransactions, now, currency)
        : _serverAttention(dashboard.insights);
    final popularServices = dashboard == null
        ? _popularServices(effectiveTransactions)
        : _serverPopularServices(dashboard.insights);
    final activeCustomerCount = dashboard == null
        ? _activeCustomers(effectiveTransactions).length
        : (dashboard.insights['active_customers'] as num?)?.toInt() ?? 0;
    final customerNames = dashboard == null
        ? effectiveCustomers.map((customer) => customer.name).take(3).toList()
        : (dashboard.insights['customer_names'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final activeCustomerItems = dashboard == null
        ? effectiveCustomers
            .map((customer) => <String, dynamic>{
                  'id': customer.id,
                  'name': customer.name,
                })
            .toList()
        : _serverActiveCustomers(dashboard.insights);
    final accounts = dashboard?.accounts ?? const <DashboardOwnerAccount>[];

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
          await ref.read(ownerDashboardProvider.notifier).refresh();
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
                    label: _selectedAccountLabel(accounts),
                    onTap: () => _showFilterSheet(
                      context,
                      accounts,
                      dashboard,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PaymentHighlightCard(
                  value: currency.format(dashboardSummary.revenue),
                  periodLabel: _selectedPeriod.label,
                  caption: _selectedPeriod.paymentCaption,
                  onTap: () => _showFinancialDetails(
                    context,
                    title:
                        'Pembayaran diterima — ${_selectedPeriod.label}',
                    total: dashboard?.summary.paymentsReceived ?? 0,
                    items: dashboard?.paymentDetails ?? const [],
                    isPayment: true,
                    currency: currency,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.48,
                  children: [
                    _KpiCard(
                      label: 'Transaksi',
                      value: dashboardSummary.transactions.toString(),
                      trend: dashboardSummary.transactionTrend,
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      onTap: () => GoRouter.of(context).push(
                        _transactionRoute(TransactionListFilter.all),
                      ),
                    ),
                    _KpiCard(
                      label: 'Pelanggan',
                      value: dashboardSummary.customers.toString(),
                      trend: dashboardSummary.customerTrend,
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF7C3AED),
                      onTap: () => _openCustomerDetails(
                        context,
                        activeCustomerItems,
                      ),
                    ),
                    _KpiCard(
                      label: 'Diproses',
                      value: dashboardSummary.processing.toString(),
                      trend: dashboardSummary.processingTrend,
                      icon: Icons.local_laundry_service_outlined,
                      color: AppColors.statusDicuci,
                      onTap: () => GoRouter.of(context).push(
                        _transactionRoute(TransactionListFilter.washing),
                      ),
                    ),
                    _KpiCard(
                      label: 'Tagihan belum lunas',
                      value: currency.format(
                        dashboard?.summary.outstandingAmount ?? 0,
                      ),
                      trend: 'Perlu ditinjau',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFFB45309),
                      onTap: () => _showFinancialDetails(
                        context,
                        title: 'Tagihan belum lunas',
                        total: dashboard?.summary.outstandingAmount ?? 0,
                        items: dashboard?.outstandingItems ?? const [],
                        isPayment: false,
                        currency: currency,
                      ),
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
                            onTap: () => _applyServerFilters(
                              period: period,
                              dashboard: dashboard,
                            ),
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
                  trailing: '',
                  child: _LaundryPerformance(distribution: serviceDistribution),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Monitoring Operasional',
                  trailing: 'Lihat detail',
                  onTrailingTap: () => GoRouter.of(context).push(
                    _transactionRoute(TransactionListFilter.all),
                  ),
                  child: _OperationalMonitoring(items: operationalStats),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Yang Perlu Perhatian',
                  trailing: 'Lihat semua',
                  onTrailingTap: () => GoRouter.of(context).push(
                    _transactionRoute(TransactionListFilter.all),
                  ),
                  child: attentionItems.isEmpty
                      ? Text('Tidak ada transaksi yang perlu ditinjau.',
                          style: AppTextStyles.bodyMuted)
                      : Column(
                          children: attentionItems
                              .map((item) => _AttentionRow(item: item))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Layanan Terpopuler',
                  trailing: '',
                  child: _PopularServicesCard(items: popularServices),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Pelanggan',
                  trailing: '',
                  child: _CustomerSummaryCard(
                    count: activeCustomerCount,
                    names: customerNames,
                    onTap: () => _showActiveCustomers(
                      context,
                      activeCustomerItems,
                    ),
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
    BuildContext context,
    List<DashboardOwnerAccount> accounts,
    DashboardOwnerResponse? dashboard,
  ) async {
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Keseluruhan'),
                  leading: Radio<String>(
                    value: 'all',
                    groupValue: _selectedAccountId,
                    onChanged: (value) {
                      if (value != null) Navigator.pop(sheetContext, value);
                    },
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'all'),
                ),
                ...accounts.map((account) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(account.label),
                      leading: Radio<String>(
                        value: account.id,
                        groupValue: _selectedAccountId,
                        onChanged: (value) {
                          if (value != null) {
                            Navigator.pop(sheetContext, value);
                          }
                        },
                      ),
                      onTap: () => Navigator.pop(sheetContext, account.id),
                    )),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _selectedAccountId = result);
      await _applyServerFilters(dashboard: dashboard);
    }
  }

  Future<void> _applyServerFilters({
    _RevenuePeriod? period,
    DashboardOwnerResponse? dashboard,
  }) async {
    final selectedPeriod = period ?? _selectedPeriod;
    if (period != null) setState(() => _selectedPeriod = period);
    final cashierId = _selectedAccountId == 'all' ? null : _selectedAccountId;
    await ref.read(ownerDashboardProvider.notifier).applyFilters(
          period: selectedPeriod.apiValue,
          cashierId: cashierId,
        );
  }

  String _selectedAccountLabel(List<DashboardOwnerAccount> accounts) {
    for (final account in accounts) {
      if (account.id == _selectedAccountId) return account.label;
    }
    return 'Keseluruhan';
  }

  String _transactionRoute(TransactionListFilter filter) {
    final range = _selectedPeriod.dateRange(DateTime.now());
    return Uri(
      path: AppRoutes.transactions,
      queryParameters: {
        'filter': filter.name,
        'from': DateUtils.dateOnly(range.start).toIso8601String(),
        'to': DateUtils.dateOnly(range.end).toIso8601String(),
        if (_selectedAccountId != 'all') 'cashier_id': _selectedAccountId,
      },
    ).toString();
  }

  Future<void> _showActiveCustomers(
    BuildContext context,
    List<Map<String, dynamic>> customers,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            builder: (_, controller) => ListView.separated(
              controller: controller,
              padding: const EdgeInsets.all(16),
              itemCount: customers.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Pelanggan aktif',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    subtitle: const Text(
                      'Memiliki transaksi pada periode dan akun terpilih.',
                    ),
                    trailing: Text('${customers.length}'),
                  );
                }
                final customer = customers[index - 1];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (customer['name']?.toString().trim().isNotEmpty ?? false)
                          ? customer['name'].toString().trim()[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(customer['name']?.toString() ?? 'Pelanggan'),
                );
              },
            ),
          ),
        ),
      );

  void _openCustomerDetails(
    BuildContext context,
    List<Map<String, dynamic>> customers,
  ) {
    if (_selectedAccountId == 'all') {
      GoRouter.of(context).push(AppRoutes.customers);
      return;
    }
    _showActiveCustomers(context, customers);
  }

  Future<void> _showFinancialDetails(
    BuildContext context, {
    required String title,
    required int total,
    required List<Map<String, dynamic>> items,
    required bool isPayment,
    bool isOrder = false,
    required NumberFormat currency,
  }) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.45,
            builder: (_, controller) => ListView.separated(
              controller: controller,
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title,
                        style: Theme.of(sheetContext).textTheme.titleLarge),
                    subtitle: const Text('Total sesuai ringkasan periode'),
                    trailing: Text(currency.format(total),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                }
                final item = items[index - 1];
                final amount = isPayment
                    ? (item['payment_amount'] as num?)?.toInt() ?? 0
                    : isOrder
                        ? (item['total'] as num?)?.toInt() ?? 0
                        : (item['outstanding_amount'] as num?)?.toInt() ?? 0;
                return ListTile(
                  title: Text('${item['invoice'] ?? '-'} • ${item['customer_name'] ?? 'Pelanggan'}'),
                  subtitle: Text(isPayment
                      ? '${item['payment_method']?.toString().toUpperCase() ?? 'CASH'} • ${_paymentDateLabel(item['paid_at'])}'
                      : isOrder
                          ? 'Status ${item['laundry_status'] ?? '-'} • ${item['payment_status'] ?? '-'}'
                          : 'Total ${currency.format((item['total'] as num?)?.toInt() ?? 0)} • Sudah dibayar ${currency.format((item['paid_amount'] as num?)?.toInt() ?? 0)}'),
                  trailing: Text(currency.format(amount),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                );
              },
            ),
          ),
        ),
      );
}

String _paymentDateLabel(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? 'Tanggal tidak tersedia'
      : DateFormat('d MMM y, HH:mm', 'id_ID').format(date.toLocal());
}

enum _RevenuePeriod {
  today,
  week,
  month,
  year;

  String get label {
    switch (this) {
      case _RevenuePeriod.today:
        return 'Hari ini';
      case _RevenuePeriod.week:
        return 'Minggu ini';
      case _RevenuePeriod.month:
        return 'Bulan ini';
      case _RevenuePeriod.year:
        return 'Tahun';
    }
  }

  String get apiValue => name;

  String get paymentCaption => switch (this) {
        _RevenuePeriod.today => 'Dicatat hari ini',
        _RevenuePeriod.week => 'Dicatat dalam 7 hari terakhir',
        _RevenuePeriod.month => 'Dicatat bulan ini',
        _RevenuePeriod.year => 'Dicatat tahun ini',
      };

  DateTimeRange dateRange(DateTime now) {
    final today = DateUtils.dateOnly(now);
    return switch (this) {
      _RevenuePeriod.today => DateTimeRange(start: today, end: today),
      _RevenuePeriod.week => DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      _RevenuePeriod.month => DateTimeRange(
          start: DateTime(today.year, today.month),
          end: today,
        ),
      _RevenuePeriod.year => DateTimeRange(
          start: DateTime(today.year),
          end: today,
        ),
    };
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
    revenue: summary.paymentsReceived,
    revenueTrend: summary.paymentsReceived > 0
        ? 'Diterima pada periode ini'
        : 'Belum ada pembayaran pada periode ini',
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
    case _RevenuePeriod.today:
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final revenue = items
          .where((item) =>
              !item.createdAt.isBefore(start) && item.createdAt.isBefore(end))
          .fold<int>(0, (sum, item) => sum + item.paidAmount);
      return [_RevenuePoint('Hari ini', revenue.toDouble())];
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
    default:
      return const <_RevenuePoint>[];
  }
}

int _revenueForPeriod(
    List<TransactionEntity> items, _RevenuePeriod period, DateTime now,
    {required int offset}) {
  switch (period) {
    case _RevenuePeriod.today:
      final date = DateUtils.dateOnly(now).subtract(Duration(days: offset));
      final end = date.add(const Duration(days: 1));
      return items
          .where((item) =>
              !item.createdAt.isBefore(date) && item.createdAt.isBefore(end))
          .fold<int>(0, (sum, item) => sum + item.paidAmount);
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
    default:
      return 0;
  }
}

int _transactionCountForPeriod(
    List<TransactionEntity> items, _RevenuePeriod period, DateTime now,
    {required int offset}) {
  switch (period) {
    case _RevenuePeriod.today:
      final date = DateUtils.dateOnly(now).subtract(Duration(days: offset));
      final end = date.add(const Duration(days: 1));
      return items
          .where((item) =>
              !item.createdAt.isBefore(date) && item.createdAt.isBefore(end))
          .length;
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
    default:
      return 0;
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
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
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(label,
                      style: AppTextStyles.bodyMuted,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppTextStyles.headline.copyWith(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHighlightCard extends StatelessWidget {
  final String value;
  final String periodLabel;
  final String caption;
  final VoidCallback onTap;

  const _PaymentHighlightCard({
    required this.value,
    required this.periodLabel,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D5EA6), Color(0xFF237DCA)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33237DCA),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pembayaran diterima',
                            style: TextStyle(color: Color(0xFFDCEEFF)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            periodLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: AppTextStyles.headline.copyWith(
                            color: Colors.white,
                            fontSize: 30,
                          )),
                    ),
                    const SizedBox(height: 5),
                    Text(caption,
                        style: const TextStyle(color: Color(0xFFDCEEFF))),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: Colors.white, size: 27),
              ),
            ],
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback? onTrailingTap;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.trailing,
    this.onTrailingTap,
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
              if (trailing.isNotEmpty)
                InkWell(
                  onTap: onTrailingTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      trailing,
                      style: AppTextStyles.bodyMuted.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
    final currency = NumberFormat.compactCurrency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    final maxValue =
        points.map((point) => point.value).fold<double>(0, math.max);
    final total = points.fold<double>(0, (sum, point) => sum + point.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total: ${currency.format(total)}', style: AppTextStyles.bodyMuted),
            Text('Tertinggi: ${currency.format(maxValue)}',
                style: AppTextStyles.bodyMuted),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 164,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points)
                Expanded(
                  child: _RevenueBar(
                    point: point,
                    maxValue: maxValue,
                    currency: currency,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RevenueBar extends StatelessWidget {
  final _RevenuePoint point;
  final double maxValue;
  final NumberFormat currency;

  const _RevenueBar({
    required this.point,
    required this.maxValue,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue == 0 ? 0.0 : point.value / maxValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.bottomCenter,
                child: Tooltip(
                  message: '${point.label}: ${currency.format(point.value)}',
                  child: Container(
                    height: point.value == 0
                        ? 4
                        : math.max(8, constraints.maxHeight * fraction),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            point.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 10),
          ),
        ],
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

    if (items.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('Belum ada transaksi untuk ditampilkan.')),
      );
    }

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
        ],
      ),
    );
  }
}

class _PopularServicesCard extends StatelessWidget {
  final List<_InsightItem> items;

  const _PopularServicesCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _CompactEmptyState(
        icon: Icons.workspace_premium_outlined,
        message: 'Belum ada layanan yang dapat diperingkatkan.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: index == 0
                      ? const Color(0xFFFFF4D6)
                      : AppColors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${index + 1}',
                  style: AppTextStyles.label.copyWith(
                    color: index == 0
                        ? const Color(0xFFB45309)
                        : AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(items[index].label,
                    style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(items[index].value,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          if (index < items.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  final int count;
  final List<String> names;
  final VoidCallback onTap;

  const _CustomerSummaryCard({
    required this.count,
    required this.names,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const _CompactEmptyState(
        icon: Icons.people_outline,
        message: 'Belum ada pelanggan aktif pada periode ini.',
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_2_outlined, color: Color(0xFF0369A1)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Pelanggan aktif', style: AppTextStyles.body),
              ),
              Text('$count',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 24,
                    color: const Color(0xFF075985),
                  )),
            ],
          ),
        ),
        if (names.isNotEmpty) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Pelanggan pada periode ini',
                style: AppTextStyles.bodyMuted),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < names.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    child: Text(names[index].trim().isEmpty
                        ? '?'
                        : names[index].trim()[0].toUpperCase()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(names[index],
                        style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.circle, size: 8, color: AppColors.success),
                  const SizedBox(width: 5),
                  Text('Aktif', style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
        ],
        ],
      ),
    );
  }
}

class _CompactEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CompactEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: AppTextStyles.bodyMuted)),
          ],
        ),
      );
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
    return status == LaundryStatus.completed || status == LaundryStatus.late;
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

List<_DistributionItem> _serverDistribution(Map<String, dynamic> insights) {
  final rows = insights['service_distribution'] as List<dynamic>? ?? const [];
  final colors = [
    AppColors.primary,
    AppColors.statusSelesai,
    AppColors.statusDicuci,
    AppColors.warning,
  ];
  return rows.whereType<Map>().toList().asMap().entries.map((entry) {
    final row = entry.value;
    return _DistributionItem(
      row['label']?.toString() ?? 'Layanan',
      (row['count'] as num?)?.toInt() ?? 0,
      colors[entry.key % colors.length],
    );
  }).toList();
}

List<_MonitoringItem> _serverMonitoring(Map<String, dynamic> insights) {
  final monitoring = Map<String, dynamic>.from(
    insights['monitoring'] as Map? ?? const {},
  );
  int count(String key) => (monitoring[key] as num?)?.toInt() ?? 0;
  return [
    _MonitoringItem('Diproses', count('processing'),
        Icons.local_laundry_service_outlined, AppColors.statusDicuci),
    _MonitoringItem('Mendekati Deadline', count('due_soon'),
        Icons.timelapse_rounded, AppColors.statusDikeringkan),
    _MonitoringItem('Terlambat', count('late'), Icons.warning_amber_rounded,
        AppColors.error),
    _MonitoringItem('Siap Diambil', count('ready_to_pickup'),
        Icons.check_circle_outline_rounded, AppColors.success),
  ];
}

List<_AttentionItem> _serverAttention(Map<String, dynamic> insights) {
  final rows = insights['attention_items'] as List<dynamic>? ?? const [];
  if (rows.isNotEmpty) {
    return rows.whereType<Map>().map((row) {
      final reasons = (row['reasons'] as List<dynamic>? ?? const [])
          .map((reason) => reason.toString())
          .join(' • ');
      final isLate = row['laundry_status']?.toString() == 'late';
      final outstanding = (row['outstanding_amount'] as num?)?.toInt() ?? 0;
      return _AttentionItem(
        '${row['invoice'] ?? '-'} • ${row['customer_name'] ?? 'Pelanggan'}',
        outstanding > 0 ? '$reasons • Sisa tagihan Rp$outstanding' : reasons,
        isLate
            ? AppColors.error
            : outstanding > 0
                ? AppColors.warning
                : AppColors.info,
        isLate ? Icons.warning_amber_rounded : Icons.receipt_long_outlined,
      );
    }).toList();
  }
  final monitoring = Map<String, dynamic>.from(
    insights['monitoring'] as Map? ?? const {},
  );
  int count(String key) => (monitoring[key] as num?)?.toInt() ?? 0;
  final alerts = <_AttentionItem>[];
  if (count('late') > 0) {
    alerts.add(_AttentionItem(
        'Transaksi terlambat',
        '${count('late')} transaksi perlu ditangani',
        AppColors.error,
        Icons.warning_amber_rounded));
  }
  if (count('due_soon') > 0) {
    alerts.add(_AttentionItem(
        'Mendekati deadline',
        '${count('due_soon')} transaksi segera selesai',
        AppColors.warning,
        Icons.schedule_rounded));
  }
  if (count('ready_to_pickup') > 0) {
    alerts.add(_AttentionItem(
        'Menunggu pengambilan',
        '${count('ready_to_pickup')} transaksi siap diambil',
        AppColors.info,
        Icons.inventory_2_outlined));
  }
  return alerts;
}

List<_InsightItem> _serverPopularServices(Map<String, dynamic> insights) {
  final rows = insights['popular_services'] as List<dynamic>? ?? const [];
  return rows
      .whereType<Map>()
      .map((row) => _InsightItem(
            row['label']?.toString() ?? 'Layanan',
            '${(row['count'] as num?)?.toInt() ?? 0}x',
          ))
      .toList();
}

List<Map<String, dynamic>> _serverActiveCustomers(
  Map<String, dynamic> insights,
) {
  final rows = insights['active_customer_items'] as List<dynamic>? ?? const [];
  return rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
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
