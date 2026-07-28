import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../master_data/domain/entities/customer_entity.dart';
import '../../../master_data/domain/entities/laundry_service_entity.dart';
import '../../../master_data/presentation/providers/master_data_providers.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/domain/entities/printer_device.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
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
        data: (items) => items.isEmpty
            ? const _EmptyTransactions()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) =>
                    _TransactionCard(transaction: items[index]),
              ),
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
                      label: transaction.laundryStatus.label,
                      color: _laundryColor(transaction.laundryStatus),
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
      customerName: _customer!.name,
      customerPhone: _customer!.phone,
      serviceName: _service!.name,
      quantity: double.parse(_quantity.text.replaceAll(',', '.')),
      quantityUnit: _service!.pricingType == PricingType.perKg ? 'Kg' : 'Item',
      unitPrice: _service!.price,
      expressFee: _expressFee,
      total: total,
      paidAmount: _paymentStatus == PaymentStatus.paid ? total : 0,
      paymentMethod: _paymentMethod,
      paymentStatus: _paymentStatus,
      laundryStatus: LaundryStatus.received,
      createdAt: now,
      estimatedFinishAt: now.add(Duration(hours: _service!.estimatedHours)),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await ref.read(transactionsProvider.notifier).create(transaction);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil dibuat.')),
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
            DropdownButtonFormField<CustomerEntity>(
              initialValue: _customer,
              decoration: const InputDecoration(labelText: 'Pelanggan'),
              items: customers
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text('${item.name} — ${item.phone}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _customer = value),
              validator: (value) =>
                  value == null ? 'Pelanggan wajib dipilih' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LaundryServiceEntity>(
              initialValue: _service,
              decoration: const InputDecoration(labelText: 'Layanan'),
              items: services
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        '${item.name} (${TransactionsScreen._currency.format(item.price)}/${item.pricingLabel})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _service = value),
              validator: (value) =>
                  value == null ? 'Layanan wajib dipilih' : null,
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

class TransactionDetailScreen extends ConsumerWidget {
  final TransactionEntity transaction;
  const TransactionDetailScreen({required this.transaction, super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        floatingActionButton: _PrintReceiptButton(transaction: transaction),
        appBar: AppBar(title: const Text('Detail Transaksi')),
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
                          QrImageView(data: transaction.invoice, size: 130),
                          const SizedBox(height: 4),
                          Text(
                            transaction.invoice,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 28),
                    Text(
                      transaction.customerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(transaction.customerPhone),
                    const Divider(height: 28),
                    Text(
                      '${transaction.serviceName} • ${transaction.quantity} ${transaction.quantityUnit}',
                    ),
                    Text(
                      'Total: ${TransactionsScreen._currency.format(transaction.total)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Status pengerjaan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LaundryStatus>(
              initialValue: transaction.laundryStatus,
              decoration: const InputDecoration(labelText: 'Status laundry'),
              items: LaundryStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                        value: value, child: Text(value.label)),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                await ref.read(transactionsProvider.notifier).updateTransaction(
                      transaction.copyWith(laundryStatus: value),
                    );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentStatus>(
              initialValue: transaction.paymentStatus,
              decoration: const InputDecoration(labelText: 'Status pembayaran'),
              items: PaymentStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                        value: value, child: Text(value.label)),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                await ref.read(transactionsProvider.notifier).updateTransaction(
                      transaction.copyWith(
                        paymentStatus: value,
                        paidAmount: value == PaymentStatus.paid
                            ? transaction.total
                            : transaction.paidAmount,
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      );
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
