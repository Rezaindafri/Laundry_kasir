import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/error/exceptions.dart';
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

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(reportsOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        automaticallyImplyLeading: false,
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
              Text(
                'Ringkasan pendapatan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ReportCard(
                      label: 'Hari ini',
                      value: _currency.format(data.today.revenue),
                      icon: Icons.today_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReportCard(
                      label: 'Bulan ini',
                      value: _currency.format(data.thisMonth.revenue),
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Operasional',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _ReportRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Total transaksi',
                      value: '${data.statistics.totalTransactions}',
                    ),
                    const Divider(height: 1),
                    _ReportRow(
                      icon: Icons.local_laundry_service_outlined,
                      label: 'Laundry diproses',
                      value: '${data.statistics.inProgress}',
                    ),
                    const Divider(height: 1),
                    _ReportRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Belum diambil',
                      value: '${data.statistics.readyToPickup}',
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
              _BestSellerCard(services: data.statistics.services),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportCsv,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(_isExporting ? 'Menyiapkan CSV...' : 'Export CSV'),
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

  Future<void> _exportCsv() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month, now.day),
    );
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
      helpText: 'Pilih periode laporan',
    );
    if (selected == null || !mounted) return;

    setState(() => _isExporting = true);
    try {
      final bytes = await ref.read(reportsOverviewProvider.notifier).exportCsv(
            startDate: selected.start,
            endDate: selected.end,
          );
      final fileName = 'laporan-pendapatan-'
          '${DateFormat('yyyyMMdd').format(selected.start)}-'
          '${DateFormat('yyyyMMdd').format(selected.end)}.csv';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
        subject: 'Laporan pendapatan laundry',
        text:
            'Laporan pendapatan ${DateFormat('d MMMM y', 'id_ID').format(selected.start)}'
            ' - ${DateFormat('d MMMM y', 'id_ID').format(selected.end)}',
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
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 14),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

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
