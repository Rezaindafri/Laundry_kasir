import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../master_data/presentation/screens/customers_screen.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/screens/transactions_screen.dart';
import '../widgets/dashboard_shell.dart';
import '../widgets/dashboard_stat_card.dart';

class KasirDashboardScreen extends ConsumerStatefulWidget {
  final UserEntity user;
  const KasirDashboardScreen({required this.user, super.key});

  @override
  ConsumerState<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends ConsumerState<KasirDashboardScreen> {
  bool _showReady = false;

  Future<void> _refresh() async {
    ref.invalidate(transactionsProvider);
    await ref.read(transactionsProvider.future);
  }

  Future<void> _showCollectionOptions() async {
    final action = await showModalBottomSheet<_CollectionAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Ambil / Pelunasan'),
                subtitle: Text('Pilih cara menemukan transaksi'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: const Text('Scan QR'),
                subtitle: const Text('Scan kode pada bon laundry'),
                onTap: () => Navigator.of(sheetContext).pop(_CollectionAction.scan),
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: const Text('Cari Transaksi'),
                subtitle: const Text('Pilih dari daftar cucian belum diambil'),
                onTap: () => Navigator.of(sheetContext).pop(_CollectionAction.search),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _CollectionAction.scan) {
      context.push(AppRoutes.qrScanner);
    } else {
      context.push(AppRoutes.collections);
    }
  }

  Future<bool> _markCollected(TransactionEntity transaction) async {
    final result = await ref.read(transactionsProvider.notifier).updateTransaction(
          transaction.copyWith(
            laundryStatus: LaundryStatus.collected,
            paymentStatus: PaymentStatus.paid,
            paidAmount: transaction.total,
          ),
        );
    if (!mounted) return false;
    return result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cucian ditandai sudah diambil.')),
        );
        return true;
      },
      error: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        return false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(transactionsProvider);
    final now = DateTime.now();
    return DashboardShell(
      user: widget.user,
      title: 'Dashboard Kasir',
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: OutlinedButton(onPressed: _refresh, child: const Text('Coba lagi')),
        ),
        data: (items) {
          final ready = _ready(items, now);
          final due = _due(items, now);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Text(
                  'Halo, ${widget.user.name.split(' ').first} ${String.fromCharCode(0x1F44B)}',
                  style: AppTextStyles.displayLarge.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  'Berikut ringkasan aktivitas laundry hari ini.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.48,
                  children: [
                    DashboardStatCard(
                      label: 'Transaksi Hari Ini',
                      value: items.where((item) => _sameDay(item.createdAt, now)).length.toString(),
                      icon: Icons.receipt_long_outlined,
                      compact: true,
                      onTap: () => _openFilteredTransactions(
                        TransactionListFilter.today,
                      ),
                    ),
                    DashboardStatCard(
                      label: 'Laundry Diproses',
                      value: _inProgress(items, now).toString(),
                      icon: Icons.local_laundry_service_outlined,
                      color: AppColors.statusDicuci,
                      compact: true,
                      onTap: () => _openFilteredTransactions(
                        TransactionListFilter.washing,
                      ),
                    ),
                    DashboardStatCard(
                      label: 'Laundry Selesai',
                      value: ready.length.toString(),
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.statusSelesai,
                      compact: true,
                      onTap: () => _openFilteredTransactions(
                        TransactionListFilter.completed,
                      ),
                    ),
                    DashboardStatCard(
                      label: 'Belum Diambil',
                      value: ready.length.toString(),
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.warning,
                      compact: true,
                      onTap: () => _openFilteredTransactions(
                        TransactionListFilter.notCollected,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Ketuk kartu untuk melihat detail', style: AppTextStyles.bodyMuted),
                  ],
                ),
                const SizedBox(height: 22),
                const _Header(title: 'Aksi Cepat', trailing: 'Pilih aksi utama'),
                const SizedBox(height: 14),
                SizedBox(
                  height: 172,
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.add_rounded,
                          title: 'Transaksi\nBaru',
                          subtitle: 'Pesanan masuk',
                          primary: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NewTransactionScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Ambil /\nPelunasan',
                          subtitle: 'Scan / cari invoice',
                          onTap: _showCollectionOptions,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'Pelanggan\nBaru',
                          subtitle: 'Tambah data',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CustomersScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                _ActiveQueue(
                  showReady: _showReady,
                  due: due,
                  ready: ready,
                  onTabChanged: (value) => setState(() => _showReady = value),
                  onSeeAll: () => context.push(AppRoutes.transactions),
                  onOpen: (transaction) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(transaction: transaction),
                    ),
                  ),
                  onMarkCollected: _markCollected,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _inProgress(List<TransactionEntity> items, DateTime now) => items.where((item) {
        final status = item.resolveLaundryStatusAt(now);
        return status == LaundryStatus.received ||
            status == LaundryStatus.washing ||
            status == LaundryStatus.drying ||
            status == LaundryStatus.ironing;
      }).length;

  List<TransactionEntity> _ready(List<TransactionEntity> items, DateTime now) =>
      items.where((item) => item.resolveLaundryStatusAt(now) == LaundryStatus.completed).toList()
        ..sort((a, b) => a.estimatedFinishAt.compareTo(b.estimatedFinishAt));

  List<TransactionEntity> _due(List<TransactionEntity> items, DateTime now) =>
      items.where((item) {
        final status = item.resolveLaundryStatusAt(now);
        return status != LaundryStatus.collected &&
            status != LaundryStatus.completed &&
            _sameDay(item.estimatedFinishAt, now);
      }).toList()..sort((a, b) => a.estimatedFinishAt.compareTo(b.estimatedFinishAt));

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openFilteredTransactions(TransactionListFilter filter) {
    context.go('${AppRoutes.transactions}?filter=${filter.name}');
  }
}

enum _CollectionAction { scan, search }

class _Header extends StatelessWidget {
  final String title;
  final String trailing;
  const _Header({required this.title, required this.trailing});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(title, style: AppTextStyles.headline),
          const Spacer(),
          Text(trailing, style: AppTextStyles.bodyMuted),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) => Material(
        color: primary ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: primary ? null : Border.all(color: AppColors.divider),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary ? Colors.white : AppColors.secondary.withValues(alpha: .55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: primary ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: primary ? Colors.white.withValues(alpha: .78) : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ActiveQueue extends StatelessWidget {
  final bool showReady;
  final List<TransactionEntity> due;
  final List<TransactionEntity> ready;
  final ValueChanged<bool> onTabChanged;
  final VoidCallback onSeeAll;
  final ValueChanged<TransactionEntity> onOpen;
  final Future<bool> Function(TransactionEntity) onMarkCollected;
  const _ActiveQueue({
    required this.showReady,
    required this.due,
    required this.ready,
    required this.onTabChanged,
    required this.onSeeAll,
    required this.onOpen,
    required this.onMarkCollected,
  });
  @override
  Widget build(BuildContext context) {
    final items = (showReady ? ready : due).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Antrean Aktif', style: AppTextStyles.headline),
                  const SizedBox(height: 4),
                  Text('Pekerjaan yang perlu perhatian', style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onSeeAll,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _QueueTabs(
          showReady: showReady,
          dueCount: due.length,
          readyCount: ready.length,
          onChanged: onTabChanged,
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptyQueue()
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (showReady)
                    Dismissible(
                      key: ValueKey('collect-${items[index].id}'),
                      direction: DismissDirection.endToStart,
                      background: const _CollectBackground(),
                      confirmDismiss: (_) => onMarkCollected(items[index]),
                      child: _QueueItem(transaction: items[index], isReady: true, onTap: () => onOpen(items[index])),
                    )
                  else
                    _QueueItem(transaction: items[index], onTap: () => onOpen(items[index])),
                  if (index < items.length - 1) const Divider(indent: 76, endIndent: 16),
                ],
              ],
            ),
          ),
        if (showReady && items.isNotEmpty) ...[
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(Icons.swipe_left_rounded, size: 20, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Geser item untuk menandai sudah diambil', style: AppTextStyles.bodyMuted),
            ],
          ),
        ],
      ],
    );
  }
}

class _QueueTabs extends StatelessWidget {
  final bool showReady;
  final int dueCount;
  final int readyCount;
  final ValueChanged<bool> onChanged;
  const _QueueTabs({
    required this.showReady,
    required this.dueCount,
    required this.readyCount,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            _Tab(
              icon: Icons.schedule_outlined,
              label: 'Tenggat Hari Ini',
              count: dueCount,
              selected: !showReady,
              onTap: () => onChanged(false),
            ),
            _Tab(
              icon: Icons.inventory_2_outlined,
              label: 'Siap Diambil',
              count: readyCount,
              selected: showReady,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      );
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.icon, required this.label, required this.count, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.secondary.withValues(alpha: .45) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.label.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _QueueItem extends StatelessWidget {
  final TransactionEntity transaction;
  final bool isReady;
  final VoidCallback onTap;
  const _QueueItem({required this.transaction, required this.onTap, this.isReady = false});
  @override
  Widget build(BuildContext context) {
    final status = isReady ? _Status.ready : _StatusDetails.from(transaction);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(status.icon, color: status.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${transaction.invoice.replaceFirst('INV-', '')}',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(transaction.customerName, style: AppTextStyles.body),
                  const SizedBox(height: 2),
                  Text('${transaction.serviceName} • ${_quantity(transaction)}', style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(status.label(transaction.estimatedFinishAt),
                    style: AppTextStyles.label.copyWith(color: status.color, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text('Est. ${_time(transaction.estimatedFinishAt)}', style: AppTextStyles.bodyMuted),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
  String _quantity(TransactionEntity item) =>
      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.quantityUnit}';
  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

enum _Status { late, soon, safe, ready }
extension _StatusDetails on _Status {
  Color get color => switch (this) {
        _Status.late => AppColors.error,
        _Status.soon => AppColors.warning,
        _Status.safe => AppColors.info,
        _Status.ready => AppColors.statusSelesai,
      };
  IconData get icon => this == _Status.ready ? Icons.inventory_2_outlined : Icons.schedule_rounded;
  static _Status from(TransactionEntity item) {
    final remaining = item.estimatedFinishAt.difference(DateTime.now());
    if (remaining.isNegative) return _Status.late;
    if (remaining.inHours <= 3) return _Status.soon;
    return _Status.safe;
  }
  String label(DateTime value) {
    if (this == _Status.ready) return 'Siap diambil';
    final remaining = value.difference(DateTime.now());
    if (remaining.isNegative) return 'Lewat ${remaining.inHours.abs()} jam';
    if (remaining.inHours < 1) return 'Kurang dari 1 jam';
    return 'Tersisa ${remaining.inHours} jam';
  }
}

class _CollectBackground extends StatelessWidget {
  const _CollectBackground();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.statusSelesai,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white),
      );
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text('Tidak ada antrean pada kategori ini.', style: AppTextStyles.bodyMuted),
      );
}
