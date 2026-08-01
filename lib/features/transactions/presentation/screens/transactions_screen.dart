import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../master_data/domain/entities/customer_entity.dart';
import '../../../master_data/domain/entities/laundry_service_entity.dart';
import '../../../master_data/presentation/providers/master_data_providers.dart';
import '../../../master_data/presentation/screens/customer_search_delegate.dart';
import '../../../master_data/presentation/screens/service_search_delegate.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/domain/entities/printer_device.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';
import 'transaction_search_delegate.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

enum TransactionListFilter {
  all,
  received,
  washing,
  completed,
  collected,
  paid,
  unpaid,
}

extension TransactionListFilterLabel on TransactionListFilter {
  String get label => switch (this) {
        TransactionListFilter.all => 'Semua',
        TransactionListFilter.received => 'Diterima',
        TransactionListFilter.washing => 'Diproses',
        TransactionListFilter.completed => 'Selesai',
        TransactionListFilter.collected => 'Sudah Diambil',
        TransactionListFilter.paid => 'Lunas',
        TransactionListFilter.unpaid => 'Belum Lunas',
      };

  bool matches(TransactionEntity transaction) {
    final resolvedStatus = transaction.resolveLaundryStatusAt(DateTime.now());

    return switch (this) {
      TransactionListFilter.all => true,
      TransactionListFilter.received =>
        resolvedStatus == LaundryStatus.received,
      TransactionListFilter.washing =>
        resolvedStatus == LaundryStatus.washing ||
            resolvedStatus == LaundryStatus.drying ||
            resolvedStatus == LaundryStatus.ironing,
      TransactionListFilter.completed =>
        resolvedStatus == LaundryStatus.completed,
      TransactionListFilter.collected =>
        resolvedStatus == LaundryStatus.collected,
      TransactionListFilter.paid =>
        transaction.paymentStatus == PaymentStatus.paid,
      TransactionListFilter.unpaid =>
        transaction.paymentStatus != PaymentStatus.paid,
    };
  }
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionListFilter _filter = TransactionListFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari transaksi',
            onPressed: transactions.maybeWhen(
              data: (items) => () {
                showSearch(
                  context: context,
                  delegate: TransactionSearchDelegate(items),
                );
              },
              orElse: () => null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Transaksi Baru'),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Transaksi gagal dimuat: $error')),
        data: (items) {
          if (items.isEmpty) return const _EmptyTransactions();
          final filtered = items.where(_filter.matches).toList();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, index) {
                    final item = TransactionListFilter.values[index];
                    return FilterChip(
                      selected: _filter == item,
                      label: Text(item.label),
                      onSelected: (_) => setState(() => _filter = item),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: TransactionListFilter.values.length,
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Tidak ada transaksi untuk filter "${_filter.label}".',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(transactionsProvider);
                          await ref.read(transactionsProvider.future);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _TransactionCard(transaction: filtered[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 52,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 12),
              Text('Belum ada transaksi', textAlign: TextAlign.center),
              SizedBox(height: 4),
              Text(
                'Buat transaksi baru untuk mulai mencatat laundry.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _TransactionCard extends ConsumerWidget {
  final TransactionEntity transaction;
  const _TransactionCard({required this.transaction});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: transaction),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.customerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _StatusChip(
                      label: transaction
                          .resolveLaundryStatusAt(DateTime.now())
                          .label,
                      color: _laundryColor(
                        transaction.resolveLaundryStatusAt(DateTime.now()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.invoice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 20),
                Text(
                  '${transaction.serviceName} • ${transaction.quantity} ${transaction.quantityUnit}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimasi selesai: ${_formatEstimateDate(transaction.estimatedFinishAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      TransactionsScreen._currency.format(transaction.total),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const Spacer(),
                    _StatusChip(
                      label: transaction.paymentStatus.label,
                      color: transaction.paymentStatus == PaymentStatus.paid
                          ? AppColors.statusSelesai
                          : AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

String _formatEstimateDate(DateTime dateTime) {
  final formatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  return formatter.format(dateTime);
}

Color _laundryColor(LaundryStatus status) => switch (status) {
      LaundryStatus.completed ||
      LaundryStatus.collected =>
        AppColors.statusSelesai,
      LaundryStatus.received => AppColors.info,
      _ => AppColors.statusDicuci
    };

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class NewTransactionScreen extends ConsumerStatefulWidget {
  const NewTransactionScreen({super.key});
  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  CustomerEntity? _customer;
  LaundryServiceEntity? _service;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  PaymentStatus _paymentStatus = PaymentStatus.unpaid;
  bool _express = false;
  bool _saving = false;
  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _subtotal => _service == null
      ? 0
      : ((_service!.price *
              (double.tryParse(_quantity.text.replaceAll(',', '.')) ?? 0))
          .round());
  int get _expressFee => _express ? (_subtotal * .25).round() : 0;
  DateTime? get _estimatedFinishAt => _service == null
      ? null
      : DateTime.now().add(Duration(hours: _service!.estimatedDurationInHours));
  Future<void> _showCreateCustomerSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    var gender = CustomerGender.male;

    final result = await showModalBottomSheet<CustomerEntity>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pelanggan Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Nama pelanggan'),
                  validator: (value) =>
                      Validators.required(value, field: 'Nama pelanggan'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Nomor HP (opsional)'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? null
                      : Validators.phone(value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: address,
                  decoration:
                      const InputDecoration(labelText: 'Alamat (opsional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomerGender>(
                  initialValue: gender,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kelamin (opsional)',
                  ),
                  items: CustomerGender.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => gender = value ?? CustomerGender.male),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(
                      sheetContext,
                      CustomerEntity(
                        id: '',
                        name: name.text.trim(),
                        phone: phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                        address: address.text.trim().isEmpty
                            ? null
                            : address.text.trim(),
                        gender: gender,
                      ),
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null) {
      name.dispose();
      phone.dispose();
      address.dispose();
      return;
    }

    final saved = await ref.read(customersProvider.notifier).save(result);
    if (!mounted) {
      name.dispose();
      phone.dispose();
      address.dispose();
      return;
    }

    saved.when(
      success: (customer) {
        setState(() => _customer = customer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelanggan berhasil ditambahkan.')),
        );
      },
      error: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );

    name.dispose();
    phone.dispose();
    address.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _customer == null ||
        _service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pelanggan dan layanan terlebih dahulu.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final total = _subtotal + _expressFee;
    final transaction = TransactionEntity(
      id: '',
      invoice:
          'INV-${DateFormat('yyyyMMdd').format(now)}-${now.millisecond.toString().padLeft(4, '0')}',
      customerId: _customer!.id,
      serviceId: _service!.id,
      customerName: _customer!.name,
      customerPhone: _customer!.phone ?? '',
      serviceName: _service!.name,
      quantity: double.parse(_quantity.text.replaceAll(',', '.')),
      quantityUnit: _service!.unit,
      unitPrice: _service!.price.round(),
      expressFee: _expressFee,
      total: total,
      paidAmount: _paymentStatus == PaymentStatus.paid ? total : 0,
      paymentMethod: _paymentMethod,
      paymentStatus: _paymentStatus,
      laundryStatus: LaundryStatus.received,
      createdAt: now,
      estimatedFinishAt: now.add(
        Duration(hours: _service!.estimatedDurationInHours),
      ),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    final result =
        await ref.read(transactionsProvider.notifier).create(transaction);
    if (!mounted) return;
    result.when(
      success: (_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dibuat.')),
        );
      },
      error: (failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: ${failure.message}'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? [];
    final services = ref
            .watch(laundryServicesProvider)
            .valueOrNull
            ?.where((item) => item.isActive)
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: () async {
                final selected = await showSearch<CustomerEntity?>(
                  context: context,
                  delegate: CustomerSearchDelegate(customers),
                );
                if (selected != null) {
                  setState(() => _customer = selected);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Pelanggan',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _customer == null ? 'Pilih pelanggan' : _customer!.name,
                  style: TextStyle(
                    color: _customer == null ? Colors.black54 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showCreateCustomerSheet(context, ref),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Tambah pelanggan baru'),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final selected = await showSearch<LaundryServiceEntity?>(
                  context: context,
                  delegate: ServiceSearchDelegate(services),
                );
                if (selected != null) {
                  setState(() => _service = selected);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Layanan',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _service == null
                      ? 'Pilih layanan'
                      : '${_service!.name} (${TransactionsScreen._currency.format(_service!.price)}/${_service!.pricingLabel})',
                  style: TextStyle(
                    color: _service == null ? Colors.black54 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_service != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estimasi selesai: ${_formatEstimateDate(_estimatedFinishAt!)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _service?.pricingType == PricingType.perItem
                    ? 'Jumlah item'
                    : 'Berat (Kg)',
              ),
              validator: (value) =>
                  Validators.positiveNumber(value, field: 'Jumlah'),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _express,
              title: const Text('Layanan Express'),
              subtitle: const Text('Tambahan biaya 25%'),
              onChanged: (value) => setState(() => _express = value),
            ),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 16),
            Text(
              'Pembayaran',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Metode pembayaran'),
              items: PaymentMethod.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentStatus>(
              initialValue: _paymentStatus,
              decoration: const InputDecoration(labelText: 'Status pembayaran'),
              items: PaymentStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _paymentStatus = value!),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.primary.withValues(alpha: .08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PriceRow(label: 'Subtotal', value: _subtotal),
                    _PriceRow(label: 'Express', value: _expressFee),
                    const Divider(),
                    _PriceRow(
                      label: 'Total',
                      value: _subtotal + _expressFee,
                      emphasis: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final int value;
  final bool emphasis;
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(
              label,
              style: emphasis ? Theme.of(context).textTheme.titleMedium : null,
            ),
            const Spacer(),
            Text(
              TransactionsScreen._currency.format(value),
              style: emphasis ? Theme.of(context).textTheme.titleMedium : null,
            ),
          ],
        ),
      );
}

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final TransactionEntity transaction;
  const TransactionDetailScreen({required this.transaction, super.key});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late TransactionEntity _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  Future<void> _saveUpdate(
    TransactionEntity updatedTransaction,
    String successMessage,
  ) async {
    final result = await ref
        .read(transactionsProvider.notifier)
        .updateTransaction(updatedTransaction);
    if (!mounted) return;
    result.when(
      success: (item) {
        setState(() => _transaction = item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      },
      error: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(sessionProvider).valueOrNull?.role;
    final canDelete =
        currentRole == UserRole.owner || currentRole == UserRole.superOwner;
    final canHandleTransaction = currentRole != null;
    final currentLaundryStatus =
        _transaction.resolveLaundryStatusAt(DateTime.now());
    final effectiveLaundryStatus =
        _transaction.laundryStatus == LaundryStatus.collected
            ? LaundryStatus.collected
            : currentLaundryStatus;
    final isCollected = effectiveLaundryStatus == LaundryStatus.collected;
    final isPaid = _transaction.paymentStatus == PaymentStatus.paid;

    return Scaffold(
      floatingActionButton: _PrintReceiptButton(transaction: _transaction),
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          if (canDelete)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Hapus transaksi'),
                      content: Text(
                        'Yakin ingin menghapus transaksi ${_transaction.invoice}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final result = await ref
                      .read(transactionsProvider.notifier)
                      .deleteTransaction(_transaction.id);
                  if (!context.mounted) return;
                  result.when(
                    success: (_) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaksi dihapus.')),
                      );
                    },
                    error: (failure) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal menghapus: ${failure.message}'),
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (menuContext) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('Hapus transaksi'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Text('KODE PENGAMBILAN'),
                        const SizedBox(height: 8),
                        QrImageView(data: _transaction.invoice, size: 130),
                        const SizedBox(height: 4),
                        Text(
                          _transaction.invoice,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 28),
                  Text(
                    _transaction.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _transaction.customerPhone.isNotEmpty
                        ? _transaction.customerPhone
                        : '-',
                  ),
                  const Divider(height: 28),
                  Text(
                    '${_transaction.serviceName} • ${_transaction.quantity} ${_transaction.quantityUnit}',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.login_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Masuk: ${_formatEstimateDate(_transaction.createdAt)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.schedule_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estimasi selesai: ${_formatEstimateDate(_transaction.estimatedFinishAt)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: _transaction.laundryStatus.label,
                        color: _laundryColor(_transaction.laundryStatus),
                      ),
                      _StatusChip(
                        label: _transaction.paymentStatus.label,
                        color: _transaction.paymentStatus == PaymentStatus.paid
                            ? AppColors.statusSelesai
                            : AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total: ${TransactionsScreen._currency.format(_transaction.total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _transaction.customerPhone.isNotEmpty
                ? () async {
                    final opened = await WhatsAppLauncher.open(
                      _transaction.customerPhone,
                      message:
                          'Halo ${_transaction.customerName}, mengenai transaksi ${_transaction.invoice} Anda.',
                    );
                    if (context.mounted && !opened) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Nomor WhatsApp tidak valid atau aplikasi tidak tersedia.',
                          ),
                        ),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Hubungi via WhatsApp'),
          ),
          if (canHandleTransaction) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isCollected && isPaid
                  ? null
                  : () => _saveUpdate(
                        _transaction.copyWith(
                          laundryStatus: LaundryStatus.collected,
                          paymentStatus:
                              _transaction.paymentStatus == PaymentStatus.paid
                                  ? PaymentStatus.paid
                                  : PaymentStatus.unpaid,
                          paidAmount:
                              _transaction.paymentStatus == PaymentStatus.paid
                                  ? _transaction.total
                                  : _transaction.paidAmount,
                        ),
                        _transaction.paymentStatus == PaymentStatus.paid
                            ? 'Transaksi ditandai sudah diambil pelanggan.'
                            : 'Transaksi ditandai sudah diambil pelanggan. Status pembayaran tetap sesuai kondisi sebelumnya.',
                      ),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: Text(
                isCollected && isPaid
                    ? 'Sudah Diambil'
                    : _transaction.paymentStatus == PaymentStatus.paid
                        ? 'Tandai Sudah Diambil'
                        : 'Tandai Lunas & Sudah Diambil',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Status pengerjaan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LaundryStatus>(
            initialValue: _transaction.laundryStatus,
            decoration: InputDecoration(
              labelText: 'Status laundry',
              helperText: canHandleTransaction
                  ? 'Gunakan juga untuk status barang sudah diambil pelanggan.'
                  : 'Anda belum memiliki akses mengubah status.',
            ),
            items: LaundryStatus.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: canHandleTransaction
                ? (value) {
                    if (value == null) return;
                    final updatedTransaction = _transaction.copyWith(
                      laundryStatus: value,
                      paymentStatus: value == LaundryStatus.collected
                          ? PaymentStatus.paid
                          : _transaction.paymentStatus,
                      paidAmount: value == LaundryStatus.collected
                          ? _transaction.total
                          : _transaction.paidAmount,
                    );
                    _saveUpdate(
                      updatedTransaction,
                      value == LaundryStatus.collected
                          ? 'Status diubah menjadi sudah diambil dan otomatis lunas.'
                          : 'Status laundry berhasil diperbarui.',
                    );
                  }
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentStatus>(
            initialValue: _transaction.paymentStatus,
            decoration: InputDecoration(
              labelText: 'Status pembayaran',
              helperText: canHandleTransaction
                  ? 'Saat lunas, nominal terbayar akan disamakan dengan total transaksi.'
                  : 'Anda belum memiliki akses mengubah status pembayaran.',
            ),
            items: PaymentStatus.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: canHandleTransaction
                ? (value) {
                    if (value == null) return;
                    final updatedPaidAmount = value == PaymentStatus.paid
                        ? _transaction.total
                        : value == PaymentStatus.unpaid
                            ? 0
                            : _transaction.paidAmount > 0
                                ? _transaction.paidAmount
                                : (_transaction.total / 2).round();
                    _saveUpdate(
                      _transaction.copyWith(
                        paymentStatus: value,
                        paidAmount: updatedPaidAmount,
                      ),
                      'Status pembayaran berhasil diperbarui.',
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _PrintReceiptButton extends ConsumerWidget {
  final TransactionEntity transaction;
  const _PrintReceiptButton({required this.transaction});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FloatingActionButton.extended(
        onPressed: () async {
          final settings = ref.read(laundrySettingsProvider).valueOrNull;
          final mac = settings?.defaultPrinter;
          if (mac == null || mac.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Atur alamat MAC printer terlebih dahulu di Pengaturan.',
                ),
              ),
            );
            return;
          }
          try {
            await ref.read(printerDeviceServiceProvider).ensureReady();
          } on PrinterException catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error.message)),
              );
            }
            return;
          }
          final result = await ref.read(thermalReceiptServiceProvider).print(
                transaction,
                macAddress: mac,
                businessName: settings?.businessName ?? 'CLEAN FRESH LAUNDRY',
              );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result
                    ? 'Bon berhasil dikirim ke printer.'
                    : 'Printer tidak dapat dihubungkan.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.print_outlined),
        label: const Text('Cetak Bon'),
      );
}
