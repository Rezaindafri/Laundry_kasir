import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../../../core/utils/whatsapp_launcher.dart';

enum TransactionListFilter {
  all,
  today,
  received,
  washing,
  completed,
  notCollected,
  collected,
  paid,
  unpaid,
}

extension TransactionListFilterLabel on TransactionListFilter {
  String get label => switch (this) {
        TransactionListFilter.all => 'Semua',
        TransactionListFilter.today => 'Hari Ini',
        TransactionListFilter.received => 'Diterima',
        TransactionListFilter.washing => 'Diproses',
        TransactionListFilter.completed => 'Selesai',
        TransactionListFilter.notCollected => 'Belum Diambil',
        TransactionListFilter.collected => 'Sudah Diambil',
        TransactionListFilter.paid => 'Lunas',
        TransactionListFilter.unpaid => 'Belum Lunas',
      };

  bool matches(TransactionEntity transaction) {
    final resolvedStatus = transaction.resolveLaundryStatusAt(DateTime.now());

    return switch (this) {
      TransactionListFilter.all => true,
      TransactionListFilter.today =>
        transaction.createdAt.year == DateTime.now().year &&
            transaction.createdAt.month == DateTime.now().month &&
            transaction.createdAt.day == DateTime.now().day,
      TransactionListFilter.received =>
        resolvedStatus == LaundryStatus.received,
      TransactionListFilter.washing =>
        resolvedStatus == LaundryStatus.washing ||
            resolvedStatus == LaundryStatus.drying ||
            resolvedStatus == LaundryStatus.ironing,
      TransactionListFilter.completed =>
        resolvedStatus == LaundryStatus.completed,
      TransactionListFilter.notCollected =>
        resolvedStatus != LaundryStatus.collected,
      TransactionListFilter.collected =>
        resolvedStatus == LaundryStatus.collected,
      TransactionListFilter.paid =>
        transaction.paymentStatus == PaymentStatus.paid,
      TransactionListFilter.unpaid =>
        transaction.paymentStatus != PaymentStatus.paid,
    };
  }

  static TransactionListFilter fromQuery(String? value) =>
      TransactionListFilter.values.firstWhere(
        (filter) => filter.name == value,
        orElse: () => TransactionListFilter.all,
      );
}

class TransactionsScreen extends ConsumerStatefulWidget {
  final TransactionListFilter initialFilter;
  final bool isCollectionMode;

  const TransactionsScreen({
    this.initialFilter = TransactionListFilter.all,
    this.isCollectionMode = false,
    super.key,
  });
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TransactionListFilter _filter;
  DateTimeRange? _dateRange;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  bool _matchesDateRange(TransactionEntity transaction) {
    final range = _dateRange;
    if (range == null) return true;
    final date = DateUtils.dateOnly(transaction.createdAt);
    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  bool _matchesSearch(TransactionEntity transaction) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return transaction.invoice.toLowerCase().contains(query) ||
        transaction.customerName.toLowerCase().contains(query) ||
        transaction.customerPhone.toLowerCase().contains(query) ||
        transaction.serviceName.toLowerCase().contains(query);
  }

  Future<void> _openFilterSheet(
    List<TransactionListFilter> availableFilters,
  ) async {
    final selection = await showModalBottomSheet<_TransactionFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TransactionFilterSheet(
        availableFilters: availableFilters,
        initialFilter: _filter,
        initialDateRange: _dateRange,
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _filter = selection.filter;
        _dateRange = selection.dateRange;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final availableFilters = TransactionListFilter.values
        .where(
          (filter) =>
              !widget.isCollectionMode ||
              (filter != TransactionListFilter.collected &&
                  filter != TransactionListFilter.notCollected),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCollectionMode ? 'Pengambilan' : 'Transaksi'),
        automaticallyImplyLeading: widget.isCollectionMode,
      ),
      floatingActionButton: widget.isCollectionMode
          ? null
          : FloatingActionButton.extended(
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
          final collectionItems = widget.isCollectionMode
              ? items.where(TransactionListFilter.notCollected.matches)
              : items;
          final filtered = collectionItems
              .where(_filter.matches)
              .where(_matchesDateRange)
              .where(_matchesSearch)
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari invoice, pelanggan, atau layanan',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _openFilterSheet(availableFilters),
                        icon: const Icon(Icons.filter_list_rounded),
                        label: const Text('Filter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(0, 42),
                          side: const BorderSide(color: AppColors.textSecondary),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
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
                              _TransactionCard(
                                transaction: filtered[index],
                                isCollectionMode: widget.isCollectionMode,
                              ),
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

class _TransactionFilterSelection {
  final TransactionListFilter filter;
  final DateTimeRange? dateRange;

  const _TransactionFilterSelection({
    required this.filter,
    required this.dateRange,
  });
}

class _TransactionFilterSheet extends StatefulWidget {
  final List<TransactionListFilter> availableFilters;
  final TransactionListFilter initialFilter;
  final DateTimeRange? initialDateRange;

  const _TransactionFilterSheet({
    required this.availableFilters,
    required this.initialFilter,
    required this.initialDateRange,
  });

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late TransactionListFilter _filter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _dateRange = widget.initialDateRange;
  }

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih rentang tanggal transaksi',
      saveText: 'Terapkan',
    );
    if (selected != null && mounted) setState(() => _dateRange = selected);
  }

  String get _dateRangeLabel {
    final range = _dateRange;
    if (range == null) return 'Semua tanggal';
    final formatter = DateFormat('d MMM yyyy', 'id_ID');
    return '${formatter.format(range.start)} - ${formatter.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter transaksi', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              DropdownButtonFormField<TransactionListFilter>(
                initialValue: _filter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status transaksi'),
                items: widget.availableFilters
                    .map(
                      (filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter.label),
                      ),
                    )
                    .toList(),
                onChanged: (filter) {
                  if (filter != null) setState(() => _filter = filter);
                },
              ),
              const SizedBox(height: 14),
              Text('Periode pembuatan transaksi',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_dateRangeLabel, overflow: TextOverflow.ellipsis),
              ),
              if (_dateRange != null)
                TextButton.icon(
                  onPressed: () => setState(() => _dateRange = null),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Hapus periode tanggal'),
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _TransactionFilterSelection(
                    filter: _filter,
                    dateRange: _dateRange,
                  ),
                ),
                child: const Text('Terapkan Filter'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  const _TransactionFilterSelection(
                    filter: TransactionListFilter.all,
                    dateRange: null,
                  ),
                ),
                child: const Text('Reset Filter'),
              ),
            ],
          ),
        ),
      );
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
  final bool isCollectionMode;

  const _TransactionCard({
    required this.transaction,
    this.isCollectionMode = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => isCollectionMode
                  ? CollectionSettlementScreen(transaction: transaction)
                  : TransactionDetailScreen(transaction: transaction),
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: FilledButton(
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

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(sessionProvider).valueOrNull?.role;
    final canDelete =
        currentRole == UserRole.owner || currentRole == UserRole.superOwner;
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
        ],
      ),
    );
  }
}

class CollectionSettlementScreen extends ConsumerStatefulWidget {
  final TransactionEntity transaction;

  const CollectionSettlementScreen({required this.transaction, super.key});

  @override
  ConsumerState<CollectionSettlementScreen> createState() =>
      _CollectionSettlementScreenState();
}

class _CollectionSettlementScreenState
    extends ConsumerState<CollectionSettlementScreen> {
  final _imagePicker = ImagePicker();
  Uint8List? _proofImage;
  bool _saving = false;

  String get _evidenceKey => 'collection_proof_${widget.transaction.id}';

  @override
  void initState() {
    super.initState();
    _restoreProofImage();
  }

  Future<void> _restoreProofImage() async {
    final preferences = await SharedPreferences.getInstance();
    final savedImage = preferences.getString(_evidenceKey);
    if (savedImage == null || !mounted) return;
    setState(() => _proofImage = base64Decode(savedImage));
  }

  Future<void> _takeProofImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (image == null || !mounted) return;

    final proof = await image.readAsBytes();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_evidenceKey, base64Encode(proof));
    if (!mounted) return;
    setState(() => _proofImage = proof);
  }

  Future<void> _completeCollection({required bool settlePayment}) async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambil foto bukti pengambilan terlebih dahulu.')),
      );
      return;
    }

    final actionLabel = settlePayment ? 'lunasi dan serahkan' : 'serahkan saja';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi pengambilan'),
        content: Text(
          'Yakin ingin $actionLabel transaksi ${widget.transaction.invoice}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final paymentStatus = settlePayment
        ? PaymentStatus.paid
        : widget.transaction.paymentStatus;
    final paidAmount = settlePayment
        ? widget.transaction.total
        : widget.transaction.paidAmount;
    final result = await ref.read(transactionsProvider.notifier).updateTransaction(
          widget.transaction.copyWith(
            laundryStatus: LaundryStatus.collected,
            paymentStatus: paymentStatus,
            paidAmount: paidAmount,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settlePayment
                  ? 'Transaksi telah lunas dan berhasil diambil.'
                  : 'Transaksi berhasil ditandai sudah diambil.',
            ),
          ),
        );
      },
      error: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final remaining =
        transaction.remainingPayment.clamp(0, transaction.total).toInt();
    final isCollected = transaction.laundryStatus == LaundryStatus.collected;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengambilan / Pelunasan')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving || isCollected
                    ? null
                    : () => _completeCollection(settlePayment: false),
                child: const Text('Ambil Saja'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving || isCollected
                    ? null
                    : () => _completeCollection(settlePayment: true),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lunasi'),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bukti pengambilan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: _proofImage == null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.add_a_photo_outlined, size: 42),
                        const SizedBox(height: 10),
                        const Text('Foto penerima atau bukti pengambilan.'),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _takeProofImage,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Ambil Foto'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.memory(_proofImage!, fit: BoxFit.cover),
                      ),
                      TextButton.icon(
                        onPressed: _takeProofImage,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Ambil Ulang Foto'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text('Kode transaksi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.invoice, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(transaction.customerName),
                  if (transaction.customerPhone.isNotEmpty)
                    Text(transaction.customerPhone, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Detail tagihan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PriceRow(label: '${transaction.serviceName} (${transaction.quantity} ${transaction.quantityUnit})', value: transaction.total),
                  const Divider(height: 20),
                  _PriceRow(label: 'Total tagihan', value: transaction.total),
                  _PriceRow(label: 'Sudah dibayar', value: transaction.paidAmount),
                  const Divider(height: 20),
                  _PriceRow(label: 'Sisa tagihan', value: remaining, emphasis: true),
                ],
              ),
            ),
          ),
          if (isCollected) ...[
            const SizedBox(height: 16),
            const _StatusChip(label: 'Sudah Diambil', color: AppColors.statusSelesai),
          ],
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
