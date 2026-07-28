import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final today = transactions
        .where((item) =>
            item.createdAt.year == now.year &&
            item.createdAt.month == now.month &&
            item.createdAt.day == now.day,)
        .toList();
    final thisMonth = transactions
        .where((item) =>
            item.createdAt.year == now.year &&
            item.createdAt.month == now.month,)
        .toList();
    final todayRevenue =
        today.fold<int>(0, (sum, item) => sum + item.paidAmount);
    final monthRevenue =
        thisMonth.fold<int>(0, (sum, item) => sum + item.paidAmount);
    final inProgress = transactions
        .where((item) =>
            item.laundryStatus != LaundryStatus.completed &&
            item.laundryStatus != LaundryStatus.collected,)
        .length;
    final uncollected = transactions
        .where((item) => item.laundryStatus == LaundryStatus.completed)
        .length;
    final services = <String, int>{};
    for (final item in transactions) {
      services.update(item.serviceName, (count) => count + 1,
          ifAbsent: () => 1,);
    }
    final bestseller = services.entries.isEmpty
        ? null
        : (services.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ringkasan pendapatan',
              style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _ReportCard(
                    label: 'Hari ini',
                    value: _currency.format(todayRevenue),
                    icon: Icons.today_outlined,),),
            const SizedBox(width: 12),
            Expanded(
                child: _ReportCard(
                    label: 'Bulan ini',
                    value: _currency.format(monthRevenue),
                    icon: Icons.calendar_month_outlined,),),
          ],),
          const SizedBox(height: 24),
          Text('Operasional', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
              child: Column(children: [
            _ReportRow(
                icon: Icons.receipt_long_outlined,
                label: 'Total transaksi',
                value: '${transactions.length}',),
            const Divider(height: 1),
            _ReportRow(
                icon: Icons.local_laundry_service_outlined,
                label: 'Laundry diproses',
                value: '$inProgress',),
            const Divider(height: 1),
            _ReportRow(
                icon: Icons.inventory_2_outlined,
                label: 'Belum diambil',
                value: '$uncollected',),
          ],),),
          const SizedBox(height: 24),
          Text('Layanan terlaris',
              style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: bestseller == null
                      ? const Text('Belum ada data transaksi.')
                      : Row(children: [
                          const Icon(Icons.workspace_premium_outlined,
                              color: AppColors.warning,),
                          const SizedBox(width: 12),
                          Expanded(child: Text(bestseller.key)),
                          Text('${bestseller.value} transaksi',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),),
                        ],),),),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Export PDF/Excel akan tersedia saat backend dan layanan file dihubungkan.',),),),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export laporan'),),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReportCard(
      {required this.label, required this.value, required this.icon,});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],),),);
}

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReportRow(
      {required this.icon, required this.label, required this.value,});
  @override
  Widget build(BuildContext context) => ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing:
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),);
}
