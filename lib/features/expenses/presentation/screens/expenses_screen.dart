import 'package:flutter/material.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../reports/presentation/providers/report_providers.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_providers.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final expenses = ref.watch(expensesProvider);
    return NavigationWriteGuard(
        child: Scaffold(
      drawer: user == null ? null : AppNavigationDrawer(user: user),
      appBar: AppBar(title: const Text('Pengeluaran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Catat pengeluaran'),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ExpenseError(
          message: _errorMessage(error),
          onRetry: () => ref.read(expensesProvider.notifier).refresh(),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(expensesProvider.notifier).refresh(),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 150),
                    Icon(Icons.receipt_long_outlined, size: 48),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Pengeluaran belum tersedia',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final total = items.fold<int>(
                        0,
                        (sum, expense) => sum + expense.amount,
                      );
                      return _ExpenseTotalCard(
                          total: total, count: items.length);
                    }
                    final expense = items[index - 1];
                    return _ExpenseTile(
                      expense: expense,
                      onTap: () => _openForm(context, ref, expense: expense),
                      onDelete: () => _confirmDelete(context, ref, expense),
                    );
                  },
                ),
        ),
      ),
    ));
  }

  static String _errorMessage(Object error) => error is ServerException
      ? error.message
      : 'Pengeluaran tidak dapat dimuat. Periksa koneksi lalu coba lagi.';

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    ExpenseEntry? expense,
  }) async {
    final input = await showSafeModalBottomSheet<ExpenseInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => _ExpenseFormSheet(expense: expense),
    );
    if (input == null || !isCurrentPage(context)) return;

    try {
      await withNavigationWriteLock(
          ref,
          () =>
              ref.read(expensesProvider.notifier).save(input, id: expense?.id));
      _invalidateFinancialViews(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expense == null
              ? 'Pengeluaran berhasil dicatat.'
              : 'Pengeluaran berhasil diperbarui.'),
        ),
      );
    } on ServerException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran tidak dapat disimpan.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ExpenseEntry expense,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: Text(
          '${expense.category} sebesar ${_currency.format(expense.amount)} akan dihapus dari catatan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    try {
      await withNavigationWriteLock(
          ref, () => ref.read(expensesProvider.notifier).remove(expense.id));
      _invalidateFinancialViews(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran berhasil dihapus.')),
      );
    } on ServerException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran tidak dapat dihapus.')),
      );
    }
  }

  void _invalidateFinancialViews(WidgetRef ref) {
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(reportsOverviewProvider);
  }
}

class _ExpenseTotalCard extends StatelessWidget {
  final int total;
  final int count;

  const _ExpenseTotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFEDD5),
              foregroundColor: Color(0xFFC2410C),
              child: Icon(Icons.trending_down_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total catatan pengeluaran'),
                  const SizedBox(height: 3),
                  Text(
                    ExpensesScreen._currency.format(total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF9A3412),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            Text('$count catatan',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _ExpenseTile extends StatelessWidget {
  final ExpenseEntry expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFF7ED),
            foregroundColor: Color(0xFFC2410C),
            child: Icon(Icons.remove_circle_outline),
          ),
          title: Text(expense.category),
          subtitle: Text(
            '${DateFormat('d MMM y, HH:mm', 'id_ID').format(BusinessTime.wallTime(expense.occurredAt))} WIB'
            '${expense.description?.trim().isNotEmpty == true ? '\n${expense.description}' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: expense.description?.trim().isNotEmpty == true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ExpensesScreen._currency.format(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      );
}

class _ExpenseFormSheet extends StatefulWidget {
  final ExpenseEntry? expense;

  const _ExpenseFormSheet({this.expense});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late DateTime _occurredAt;
  late DateTime _initialOccurredAt;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amountController = TextEditingController(
      text: expense?.amount.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: expense?.category ?? 'Operasional',
    );
    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    _occurredAt = expense == null
        ? BusinessTime.calendarNow()
        : BusinessTime.wallTime(expense.occurredAt);
    _initialOccurredAt = _occurredAt;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return UnsavedChangesGuard(
      hasUnsavedChanges: () =>
          _amountController.text != (widget.expense?.amount.toString() ?? '') ||
          _categoryController.text != (widget.expense?.category ?? 'Operasional') ||
          _descriptionController.text != (widget.expense?.description ?? '') ||
          _occurredAt != _initialOccurredAt,
      listenables: [_amountController, _categoryController, _descriptionController],
      child: Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.expense == null
                    ? 'Catat pengeluaran'
                    : 'Ubah pengeluaran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nominal pengeluaran',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0
                      ? 'Masukkan nominal pengeluaran yang valid.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  hintText: 'Contoh: Operasional, Perlengkapan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Kategori perlu diisi.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickOccurredAt,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  'Waktu pengeluaran (WIB): ${DateFormat('d MMM y, HH:mm', 'id_ID').format(_occurredAt)}',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.expense == null
                      ? 'Simpan pengeluaran'
                      : 'Simpan perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _pickOccurredAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: BusinessTime.calendarNow().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ExpenseInput(
        amount: int.parse(_amountController.text),
        category: _categoryController.text.trim(),
        description: _descriptionController.text,
        occurredAt: BusinessTime.utcFromWallTime(_occurredAt),
      ),
    );
  }
}

class _ExpenseError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ExpenseError({required this.message, required this.onRetry});

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
                  onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
}
