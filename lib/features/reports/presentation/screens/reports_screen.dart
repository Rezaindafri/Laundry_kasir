import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/business_time.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../data/models/report_models.dart';
import '../providers/report_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  bool _isExporting = false;
  _ReportPeriod _selectedPeriod = _ReportPeriod.today;
  String? _selectedCashierId;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(reportsOverviewProvider);
    final user = ref.watch(sessionProvider).valueOrNull;

    return Scaffold(
      drawer: user == null ? null : AppNavigationDrawer(user: user),
      appBar: AppBar(
        title: const Text('Laporan'),
        automaticallyImplyLeading: true,
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: _errorMessage(error),
          onRetry: () => ref.read(reportsOverviewProvider.notifier).refresh(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(reportsOverviewProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Laporan Owner',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _selectRange,
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: const Text('Periode'),
                  ),
                ],
              ),
              Text(
                '${DateFormat('d MMM y', 'id_ID').format(data.startDate)} – ${DateFormat('d MMM y', 'id_ID').format(data.endDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ReportPeriod.values
                    .map(
                      (period) => ChoiceChip(
                        label: Text(period.label),
                        selected: period == _selectedPeriod,
                        onSelected: (_) => _applyPeriod(period),
                      ),
                    )
                    .toList(),
              ),
              Text('Periode dan waktu laporan menggunakan WIB (UTC+7).',
                  style: Theme.of(context).textTheme.bodySmall),
              if (data.accounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('User / Kasir',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Semua'),
                          selected: _selectedCashierId == null,
                          onSelected: (_) => _setCashier(null),
                        ),
                      ),
                      for (final account in data.accounts)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(account.label),
                            selected: _selectedCashierId == account.id,
                            onSelected: (_) => _setCashier(account.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _TodayPaymentHero(
                amount: data.paymentsReceived,
                paymentCount: data.paymentCount,
              ),
              const SizedBox(height: 14),
              _PaymentTrendChart(points: data.chart, endDate: data.endDate),
              const SizedBox(height: 14),
              _PaymentMethodCard(
                cash: data.cashPayments,
                qris: data.qrisPayments,
                transfer: data.transferPayments,
              ),
              const SizedBox(height: 20),
              _ReportCard(
                label: 'Nilai pesanan',
                subtitle: '${data.orderCount} pesanan dibuat pada periode ini',
                value: _currency.format(data.orderValue),
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 10),
              _ReportCard(
                label: 'Pembayaran diterima',
                subtitle: 'Berdasarkan tanggal pembayaran dicatat',
                value: _currency.format(data.paymentsReceived),
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 10),
              _ReportCard(
                label: 'Tagihan belum lunas',
                subtitle: 'Sisa tagihan dari pesanan periode ini',
                value: _currency.format(data.outstandingAmount),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 10),
              _ReportCard(
                label: 'Pengeluaran',
                subtitle: '${data.expenseCount} catatan pada periode ini',
                value: _currency.format(data.expensesTotal),
                icon: Icons.trending_down_outlined,
              ),
              const SizedBox(height: 10),
              _ReportCard(
                label: 'Arus kas bersih',
                subtitle: 'Pembayaran diterima dikurangi pengeluaran',
                value: _currency.format(data.netCash),
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 24),
              Text(
                'Operasional',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Status pesanan yang dibuat pada periode terpilih.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _ReportRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Pesanan masuk',
                      value: '${data.ordersReceived}',
                    ),
                    const Divider(height: 1),
                    _ReportRow(
                      icon: Icons.local_laundry_service_outlined,
                      label: 'Laundry diproses',
                      value: '${data.inProgress}',
                    ),
                    const Divider(height: 1),
                    _ReportRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Selesai',
                      value: '${data.completed}',
                    ),
                    const Divider(height: 1),
                    _ReportRow(
                      icon: Icons.warning_amber_outlined,
                      label: 'Terlambat',
                      value: '${data.late}',
                    ),
                    const Divider(height: 1),
                    _ReportRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Belum diambil',
                      value: '${data.readyToPickup}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Layanan terlaris',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _BestSellerCard(services: data.services),
              const SizedBox(height: 24),
              Text('Rincian pembayaran',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _PaymentList(items: data.payments),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Rincian pengeluaran',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.expenses),
                    child: const Text('Kelola'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _ExpenseList(items: data.expenses),
              const SizedBox(height: 24),
              Text('Tagihan belum lunas',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _OutstandingList(items: data.outstandingItems),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.auditLogs),
                icon: const Icon(Icons.history_edu_outlined),
                label: const Text('Riwayat Perubahan'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportCsv,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  _isExporting
                      ? 'Menyiapkan CSV...'
                      : 'Export CSV periode aktif',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) => error is ServerException
      ? error.message
      : 'Tidak dapat memuat laporan. Periksa koneksi lalu coba lagi.';

  Future<void> _selectRange() async {
    final now = BusinessTime.calendarNow();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: now,
      ),
      helpText: 'Pilih periode laporan',
    );
    if (selected != null) {
      setState(() => _selectedPeriod = _ReportPeriod.custom);
      await ref.read(reportsOverviewProvider.notifier).setRange(selected);
    }
  }

  Future<void> _applyPeriod(_ReportPeriod period) async {
    if (period == _ReportPeriod.custom) return;
    final now = BusinessTime.calendarNow();
    final today = DateTime(now.year, now.month, now.day);
    final range = switch (period) {
      _ReportPeriod.today => DateTimeRange(start: today, end: now),
      _ReportPeriod.week =>
        DateTimeRange(start: today.subtract(const Duration(days: 6)), end: now),
      _ReportPeriod.month =>
        DateTimeRange(start: DateTime(now.year, now.month), end: now),
      _ReportPeriod.custom => throw StateError('Periode kustom dipilih'),
    };
    setState(() => _selectedPeriod = period);
    await ref.read(reportsOverviewProvider.notifier).setRange(range);
  }

  Future<void> _setCashier(String? cashierId) async {
    setState(() => _selectedCashierId = cashierId);
    await ref.read(reportsOverviewProvider.notifier).setCashier(cashierId);
  }

  Future<void> _exportCsv() async {
    final overview = ref.read(reportsOverviewProvider).valueOrNull;
    if (overview == null) return;

    setState(() => _isExporting = true);
    try {
      final bytes =
          await ref.read(reportsOverviewProvider.notifier).exportCsv();
      final fileName = 'laporan-pendapatan-'
          '${DateFormat('yyyyMMdd').format(overview.startDate)}-'
          '${DateFormat('yyyyMMdd').format(overview.endDate)}.csv';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
        subject: 'Laporan pendapatan laundry',
        text:
            'Laporan pendapatan ${DateFormat('d MMMM y', 'id_ID').format(overview.startDate)}'
            ' - ${DateFormat('d MMMM y', 'id_ID').format(overview.endDate)}',
        fileNameOverrides: [fileName],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV siap disimpan atau dibagikan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengekspor laporan CSV.')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

enum _ReportPeriod {
  today,
  week,
  month,
  custom;

  String get label => switch (this) {
        today => 'Hari ini',
        week => '7 hari',
        month => 'Bulan ini',
        custom => 'Kustom',
      };
}

class _TodayPaymentHero extends StatelessWidget {
  final int amount;
  final int paymentCount;

  const _TodayPaymentHero({required this.amount, required this.paymentCount});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pembayaran diterima',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _ReportsScreenState._currency.format(amount),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Text('$paymentCount pembayaran dicatat pada periode terpilih',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _PaymentTrendChart extends StatelessWidget {
  final List<ReportChartPoint> points;
  final DateTime endDate;

  const _PaymentTrendChart({required this.points, required this.endDate});

  @override
  Widget build(BuildContext context) {
    final maximum = points.fold<int>(
        0, (current, point) => point.value > current ? point.value : current);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tren pembayaran 7 hari',
                style: Theme.of(context).textTheme.titleSmall),
            Text(
              'Berakhir ${DateFormat('d MMM y', 'id_ID').format(endDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 132,
              child: points.isEmpty
                  ? const Center(child: Text('Belum ada data pembayaran.'))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final point in points)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) => Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Tooltip(
                                          message:
                                              '${point.label}: ${_ReportsScreenState._currency.format(point.value)}',
                                          child: Container(
                                            height: point.value == 0
                                                ? 4
                                                : 8 +
                                                    (constraints.maxHeight -
                                                            8) *
                                                        point.value /
                                                        maximum,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(5),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(point.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final int cash;
  final int qris;
  final int transfer;

  const _PaymentMethodCard({
    required this.cash,
    required this.qris,
    required this.transfer,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pembayaran menurut metode',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _methodRow('Tunai', cash),
              _methodRow('QRIS', qris),
              _methodRow('Transfer', transfer),
            ],
          ),
        ),
      );

  Widget _methodRow(String label, int amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(_ReportsScreenState._currency.format(amount),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _BestSellerCard extends StatelessWidget {
  final List<ServiceStatistic> services;

  const _BestSellerCard({required this.services});

  @override
  Widget build(BuildContext context) {
    final sorted = [...services]..sort((a, b) => b.count.compareTo(a.count));
    final bestseller = sorted.isEmpty ? null : sorted.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: bestseller == null
            ? const Text('Belum ada data transaksi.')
            : Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(bestseller.serviceName)),
                  Text(
                    '${bestseller.count} transaksi',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label),
          subtitle: Text(subtitle),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 155),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ),
        ),
      );
}

class _PaymentList extends StatelessWidget {
  final List<PaymentReportItem> items;

  const _PaymentList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Belum ada pembayaran diterima pada periode ini.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              title: Text(
                  '${items[index].invoice} • ${items[index].customerName}'),
              subtitle: Text(
                '${_reportPaymentDateLabel(items[index].paidAt)}\n'
                '${items[index].method.toUpperCase()} • ${items[index].recorderName ?? 'Pencatat tidak tersedia'}',
              ),
              isThreeLine: true,
              trailing: Text(
                  _ReportsScreenState._currency.format(items[index].amount),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

String _reportPaymentDateLabel(DateTime? value) => value == null
    ? 'Tanggal tidak tersedia'
    : '${DateFormat('d MMM y, HH:mm', 'id_ID').format(BusinessTime.wallTime(value))} WIB';

class _OutstandingList extends StatelessWidget {
  final List<OutstandingReportItem> items;

  const _OutstandingList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tidak ada tagihan tertunda pada periode ini.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              title: Text(
                  '${items[index].invoice} • ${items[index].customerName}'),
              subtitle: Text(
                'Total ${_ReportsScreenState._currency.format(items[index].total)} • '
                'Sudah dibayar ${_ReportsScreenState._currency.format(items[index].paid)}',
              ),
              trailing: Text(
                  _ReportsScreenState._currency
                      .format(items[index].outstanding),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  final List<ExpenseReportItem> items;

  const _ExpenseList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tidak ada pengeluaran pada periode dan akun ini.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              leading: const Icon(Icons.trending_down_outlined),
              title: Text(items[index].category),
              subtitle: Text(
                '${_expenseDateLabel(items[index].occurredAt)}'
                '${items[index].description?.trim().isNotEmpty == true ? '\n${items[index].description}' : ''}',
              ),
              isThreeLine: items[index].description?.trim().isNotEmpty == true,
              trailing: Text(
                _ReportsScreenState._currency.format(items[index].amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

String _expenseDateLabel(DateTime? value) => value == null
    ? 'Waktu tidak tersedia'
    : '${DateFormat('d MMM y, HH:mm', 'id_ID').format(BusinessTime.wallTime(value))} WIB';

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        trailing:
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
}
