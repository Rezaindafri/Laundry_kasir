import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../../core/widgets/page_visibility_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/utils/name_sort.dart';
import '../../../../core/utils/receipt_text.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../master_data/domain/entities/customer_entity.dart';
import '../../../master_data/domain/entities/laundry_service_entity.dart';
import '../../../master_data/presentation/providers/master_data_providers.dart';
import '../../../master_data/presentation/screens/customer_search_delegate.dart';
import '../../../master_data/presentation/screens/service_search_delegate.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/domain/entities/printer_device.dart';
import '../../../settings/domain/entities/laundry_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/providers/payment_destination_providers.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_page_entity.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_evidence_section.dart';
import '../widgets/transaction_service_lines.dart';
import '../widgets/payment_entry_sheet.dart';
import '../widgets/payment_amount_field.dart';
import '../widgets/payment_destination_picker.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/utils/whatsapp_receipt_launcher.dart';

enum TransactionListFilter {
  all,
  today,
  received,
  washing,
  completed,
  late,
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
        TransactionListFilter.late => 'Terlambat',
        TransactionListFilter.notCollected => 'Belum Diambil',
        TransactionListFilter.collected => 'Sudah Diambil',
        TransactionListFilter.paid => 'Lunas',
        TransactionListFilter.unpaid => 'Belum Lunas',
      };

  static TransactionListFilter fromQuery(String? value) =>
      TransactionListFilter.values.firstWhere(
        (filter) => filter.name == value,
        orElse: () => TransactionListFilter.all,
      );
}

class TransactionsScreen extends ConsumerStatefulWidget {
  final TransactionListFilter initialFilter;
  final bool isCollectionMode;
  final DateTimeRange? initialDateRange;
  final String? initialCashierId;

  const TransactionsScreen({
    this.initialFilter = TransactionListFilter.all,
    this.isCollectionMode = false,
    this.initialDateRange,
    this.initialCashierId,
    super.key,
  });
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late Set<TransactionListFilter> _filters;
  DateTimeRange? _dateRange;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  AsyncValue<TransactionPageEntity> _pageState = const AsyncLoading();
  bool _loadingMore = false;
  int _queryVersion = 0;
  int? _coveredQueryVersion;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilter == TransactionListFilter.all
        ? <TransactionListFilter>{}
        : <TransactionListFilter>{widget.initialFilter};
    _dateRange = widget.initialDateRange;
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadFirstPage);
  }

  Map<String, dynamic> _queryForPage(int page) {
    final selected = _filters.contains(TransactionListFilter.all)
        ? <TransactionListFilter>{}
        : _filters;
    final laundryStatuses = <String>[];
    if (selected.contains(TransactionListFilter.received) &&
        !selected.contains(TransactionListFilter.washing)) {
      laundryStatuses.add('received');
    }
    if (selected.contains(TransactionListFilter.completed))
      laundryStatuses.add('completed');
    if (selected.contains(TransactionListFilter.late))
      laundryStatuses.add('late');
    final paymentStatuses = <String>[];
    if (selected.contains(TransactionListFilter.paid))
      paymentStatuses.add('paid');
    if (selected.contains(TransactionListFilter.unpaid)) {
      paymentStatuses.addAll(['unpaid', 'downPayment']);
    }
    final query = <String, dynamic>{
      'page': page,
      'per_page': 20,
    };
    if (selected.contains(TransactionListFilter.washing)) {
      // "Diproses" remains active only until its scheduled finish time.
      query['active_processing'] = 1;
    }
    if (selected.contains(TransactionListFilter.notCollected)) {
      // A mixed invoice can be partially ready while other services process.
      query['ready_for_collection'] = 1;
    }
    if (_searchQuery.trim().isNotEmpty) query['search'] = _searchQuery.trim();
    if (widget.initialCashierId != null) {
      query['cashier_id'] = widget.initialCashierId;
    }
    if (laundryStatuses.isNotEmpty) query['laundry_status'] = laundryStatuses;
    if (paymentStatuses.isNotEmpty) query['payment_status'] = paymentStatuses;
    if (selected.contains(TransactionListFilter.collected) &&
        !selected.contains(TransactionListFilter.notCollected)) {
      query['collected'] = 1;
    } else if (widget.isCollectionMode ||
        (selected.contains(TransactionListFilter.notCollected) &&
            !selected.contains(TransactionListFilter.collected))) {
      query['collected'] = 0;
    }
    final range = _dateRange;
    if (range != null) {
      query['from'] = BusinessTime.dateParameter(range.start);
      query['to'] = BusinessTime.dateParameter(range.end);
    } else if (selected.contains(TransactionListFilter.today)) {
      final today = BusinessTime.dateParameter(BusinessTime.calendarNow());
      query['from'] = today;
      query['to'] = today;
    }
    return query;
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    _searchDebounce?.cancel();
    final version = ++_queryVersion;
    setState(() {
      _pageState = const AsyncLoading();
      _loadingMore = false;
    });
    final result =
        await ref.read(transactionRepositoryProvider).getTransactionsPage(
              _queryForPage(1),
            );
    if (!mounted || version != _queryVersion) return;
    setState(() => _pageState = result.when(
          success: AsyncData.new,
          error: (failure) => AsyncError(failure, StackTrace.current),
        ));
  }

  Future<void> _loadMore() async {
    final page = _pageState.valueOrNull;
    if (_loadingMore || page == null || !page.hasMore) return;
    final version = _queryVersion;
    setState(() => _loadingMore = true);
    final result =
        await ref.read(transactionRepositoryProvider).getTransactionsPage(
              _queryForPage(page.currentPage + 1),
            );
    if (!mounted || version != _queryVersion) return;
    result.when(
      success: (next) => setState(() {
        _pageState = AsyncData(TransactionPageEntity(
          items: [...page.items, ...next.items],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        ));
        _loadingMore = false;
      }),
      error: (_) => setState(() => _loadingMore = false),
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 240) {
      _loadMore();
    }
  }

  Widget _refreshableNotice(Widget child) => RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: LayoutBuilder(
          builder: (_, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24), child: child)),
              ),
            ],
          ),
        ),
      );

  Future<void> _openFilterSheet(
    List<TransactionListFilter> availableFilters,
  ) async {
    final selection = await showModalBottomSheet<_TransactionFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TransactionFilterSheet(
        availableFilters: availableFilters,
        initialFilters: _filters,
        initialDateRange: _dateRange,
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _filters = selection.filters;
        _dateRange = selection.dateRange;
      });
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _pageState;
    final user = ref.watch(sessionProvider).valueOrNull;
    ref.listen(transactionListRefreshProvider, (_, __) => _loadFirstPage());
    final availableFilters = TransactionListFilter.values
        .where(
          (filter) =>
              !widget.isCollectionMode ||
              (filter != TransactionListFilter.collected &&
                  filter != TransactionListFilter.notCollected),
        )
        .toList();
    return PageVisibilityRefresh(
      onCovered: () => _coveredQueryVersion = _queryVersion,
      onVisible: () async {
        // An awaited card result or successful payment may already have reloaded
        // this query before the page becomes visible. Do not request it twice.
        if (_coveredQueryVersion == _queryVersion) await _loadFirstPage();
      },
      child: Scaffold(
      drawer: widget.isCollectionMode || user == null
          ? null
          : AppNavigationDrawer(user: user),
      appBar: AppBar(
        title: Text(widget.isCollectionMode ? 'Pengambilan' : 'Transaksi'),
        automaticallyImplyLeading: true,
      ),
      floatingActionButton: widget.isCollectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NewTransactionScreen()),
                );
                if (mounted) await _loadFirstPage();
              },
              icon: const Icon(Icons.add),
              label: const Text('Transaksi Baru'),
            ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _refreshableNotice(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Transaksi gagal dimuat: $error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadFirstPage, child: const Text('Coba lagi')),
          ],
        )),
        data: (page) {
          final items = page.items;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          _loadFirstPage,
                        );
                      },
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
                                  _searchDebounce?.cancel();
                                  _loadFirstPage();
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
                          side:
                              const BorderSide(color: AppColors.textSecondary),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? _refreshableNotice(const Text(
                        'Tidak ada transaksi untuk filter yang dipilih.',
                        textAlign: TextAlign.center,
                      ))
                    : RefreshIndicator(
                        onRefresh: _loadFirstPage,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          controller: _scrollController,
                          itemCount: items.length + (page.hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            if (index == items.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : TextButton(onPressed: _loadMore,
                                        child: const Text('Muat transaksi lainnya'))),
                              );
                            }
                            return _TransactionCard(
                              transaction: items[index],
                              isCollectionMode: widget.isCollectionMode,
                              onReturn: _loadFirstPage,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ));
  }
}

class _TransactionFilterSelection {
  final Set<TransactionListFilter> filters;
  final DateTimeRange? dateRange;

  const _TransactionFilterSelection({
    required this.filters,
    required this.dateRange,
  });
}

class _TransactionFilterSheet extends StatefulWidget {
  final List<TransactionListFilter> availableFilters;
  final Set<TransactionListFilter> initialFilters;
  final DateTimeRange? initialDateRange;

  const _TransactionFilterSheet({
    required this.availableFilters,
    required this.initialFilters,
    required this.initialDateRange,
  });

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late Set<TransactionListFilter> _filters;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _filters = {...widget.initialFilters};
    _dateRange = widget.initialDateRange;
  }

  void _toggleFilter(TransactionListFilter filter, bool selected) {
    setState(() {
      if (filter == TransactionListFilter.all) {
        _filters = selected
            ? widget.availableFilters.toSet()
            : <TransactionListFilter>{};
        return;
      }

      _filters.remove(TransactionListFilter.all);
      if (selected) {
        _filters.add(filter);
      } else {
        _filters.remove(filter);
      }

      final individualFilters = widget.availableFilters
          .where((item) => item != TransactionListFilter.all)
          .toSet();
      if (_filters.containsAll(individualFilters)) {
        _filters = widget.availableFilters.toSet();
      }
    });
  }

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: BusinessTime.calendarNow(),
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

  List<Widget> _filterTiles(Iterable<TransactionListFilter> filters) => filters
      .where(widget.availableFilters.contains)
      .map(
        (filter) => CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(filter.label),
          value: _filters.contains(filter),
          onChanged: (selected) => _toggleFilter(filter, selected ?? false),
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * .82;
    return SafeArea(
      child: SizedBox(
        height: maxSheetHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter transaksi',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ..._filterTiles([TransactionListFilter.all]),
                    const SizedBox(height: 12),
                    Text('Status laundry',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._filterTiles([
                      TransactionListFilter.today,
                      TransactionListFilter.received,
                      TransactionListFilter.washing,
                      TransactionListFilter.completed,
                      TransactionListFilter.late,
                      TransactionListFilter.notCollected,
                      TransactionListFilter.collected,
                    ]),
                    const SizedBox(height: 12),
                    Text('Status pembayaran',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._filterTiles([
                      TransactionListFilter.paid,
                      TransactionListFilter.unpaid,
                    ]),
                    const SizedBox(height: 14),
                    Text('Periode pembuatan transaksi',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(_dateRangeLabel,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_dateRange != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _dateRange = null),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Hapus periode tanggal'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _TransactionFilterSelection(
                    filters: {..._filters},
                    dateRange: _dateRange,
                  ),
                ),
                child: const Text('Terapkan Filter'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  const _TransactionFilterSelection(
                    filters: <TransactionListFilter>{},
                    dateRange: null,
                  ),
                ),
                child: const Text('Reset Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  final TransactionEntity transaction;
  final bool isCollectionMode;
  final Future<void> Function() onReturn;

  const _TransactionCard({
    required this.transaction,
    required this.onReturn,
    this.isCollectionMode = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final refreshed = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => isCollectionMode
                    ? CollectionSettlementScreen(
                        transaction: transaction, returnToCollectionList: true)
                    : TransactionDetailScreen(transaction: transaction),
              ),
            );
            if (context.mounted && refreshed != true) await onReturn();
          },
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
                  transaction.serviceSummary,
                ),
                const SizedBox(height: 6),
                Text(
                  transaction.hasEstimatedFinish
                      ? 'Estimasi terakhir: ${_formatEstimateDate(transaction.estimatedFinishAt)}'
                      : 'Tanpa estimasi proses',
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
  return '${formatter.format(BusinessTime.wallTime(dateTime))} WIB';
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

class _ServiceDraft {
  _ServiceDraft({String initialQuantity = '1'})
      : quantity = TextEditingController(text: initialQuantity);
  LaundryServiceEntity? service;
  final TextEditingController quantity;
  int get subtotal => ((service?.price ?? 0) *
          (double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0))
      .round();
}

class NewTransactionScreen extends ConsumerStatefulWidget {
  final CustomerEntity? initialCustomer;

  const NewTransactionScreen({this.initialCustomer, super.key});
  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _initialPayment = PaymentAmountController(defaultAmount: 0);
  final _lines = <_ServiceDraft>[_ServiceDraft(initialQuantity: '')];
  final _retired = <_ServiceDraft>[];
  CustomerEntity? _customer;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  int? _paymentDestinationId;
  PaymentStatus _paymentStatus = PaymentStatus.unpaid;
  bool _express = false;
  bool _saving = false;
  bool _customerFormOpen = false;
  late final bool _catalogCached;

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer;
    _catalogCached = ref.exists(customersProvider) || ref.exists(laundryServicesProvider);
  }

  @override
  void dispose() {
    _notes.dispose();
    _initialPayment.dispose();
    for (final line in [..._lines, ..._retired]) {
      line.quantity.dispose();
    }
    super.dispose();
  }

  int get _subtotal => _lines.fold(0, (sum, line) => sum + line.subtotal);
  int get _expressFee => _express
      ? _lines.fold(0, (sum, line) => sum + (line.subtotal * .25).round())
      : 0;

  int get _total => _subtotal + _expressFee;

  bool get _hasDraft =>
      _customer?.id != widget.initialCustomer?.id ||
      _lines.any((line) => line.service != null ||
          line.quantity.text.isNotEmpty && line.quantity.text != '1') ||
      _notes.text.isNotEmpty || _express ||
      _paymentMethod != PaymentMethod.cash ||
      _paymentStatus != PaymentStatus.unpaid;

  Future<void> _removeServiceLine(_ServiceDraft line) async {
    final confirmed = await showActionConfirmation(
      context: context,
      title: 'Hapus layanan dari bon?',
      message: '${line.service?.name ?? 'Baris layanan ini'} akan dihapus dari draft transaksi. Apakah Anda yakin?',
      confirmLabel: 'Hapus layanan',
    );
    if (!confirmed || !mounted || _saving || !_lines.contains(line)) return;
    FocusScope.of(context).unfocus();
    _updateBill(() {
      _lines.remove(line);
      _retired.add(line);
    });
  }

  Future<void> _refreshCatalog() async {
    if (_saving) return;
    ref.invalidate(paymentDestinationsProvider);
    await Future.wait([
      if (!ref.read(customersProvider).isLoading) ref.read(customersProvider.notifier).refresh(),
      if (!ref.read(laundryServicesProvider).isLoading) ref.read(laundryServicesProvider.notifier).refresh(),
    ]);
  }

  void _updateBill(VoidCallback change) => setState(() {
        change();
        _initialPayment.updateDefaultAmount(_total);
        _syncPaymentStatus();
      });

  void _syncPaymentStatus() {
    if (_paymentStatus == PaymentStatus.unpaid) return;
    final amount = int.tryParse(_initialPayment.text);
    if (amount != null && amount > 0 && amount <= _total) {
      _paymentStatus = amount == _total
          ? PaymentStatus.paid
          : PaymentStatus.downPayment;
    }
  }

  void _choosePaymentStatus(PaymentStatus status) => setState(() {
        _paymentStatus = status;
        if (status == PaymentStatus.paid) {
          // Choosing Lunas explicitly restores the current full bill.
          _initialPayment.resetToDefault(_total);
        } else if (status == PaymentStatus.downPayment) {
          _initialPayment.updateDefaultAmount(_total);
        }
        _syncPaymentStatus();
      });

  void _sortServiceLines() {
    final selected = sortedByName(_lines.where((line) => line.service != null),
        (line) => line.service!.name);
    final unselected = _lines.where((line) => line.service == null).toList();
    // Move the draft itself so its quantity/controller stays with its service.
    // Unfilled cards stay at the bottom in their existing order.
    _lines
      ..clear()
      ..addAll(selected)
      ..addAll(unselected);
  }

  Widget _serviceLine(_ServiceDraft line, int index) => Card(
        key: ObjectKey(line),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Layanan ${index + 1}',
                            style: Theme.of(context).textTheme.titleSmall)),
                    if (_lines.length > 1)
                      IconButton(
                          tooltip: 'Hapus layanan dari bon',
                          onPressed: _saving
                              ? null
                              : () => _removeServiceLine(line),
                          icon: const Icon(Icons.remove_circle_outline))
                  ]),
                  const SizedBox(height: 8),
                  FormField<LaundryServiceEntity>(
                      initialValue: line.service,
                      validator: (_) => line.service == null
                          ? 'Pilih layanan untuk baris ini.'
                          : null,
                      builder: (field) => InkWell(
                          key: ValueKey('transaction-service-picker-$index'),
                          onTap: _saving
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();
                                  final selected =
                                      await showSearch<LaundryServiceEntity?>(
                                          context: context,
                                          delegate: ServiceSearchDelegate());
                                  if (selected == null ||
                                      !mounted ||
                                      !_lines.contains(line)) return;
                                  if (field.mounted) field.didChange(selected);
                                  _updateBill(() {
                                    line.service = selected;
                                    _sortServiceLines();
                                  });
                                },
                          child: InputDecorator(
                              decoration: InputDecoration(
                                  labelText: 'Pilih layanan',
                                  errorText: field.errorText,
                                  enabled: !_saving,
                                  border: const OutlineInputBorder()),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(line.service?.name ??
                                          'Belum dipilih'),
                                      if (line.service != null)
                                        Text(
                                            '${TransactionsScreen._currency.format(line.service!.price)}/${line.service!.pricingLabel}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                    ])),
                                const Icon(Icons.expand_more),
                              ])))),
                  const SizedBox(height: 12),
                  TextFormField(
                      key: ValueKey('transaction-service-quantity-$index'),
                      controller: line.quantity,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: line.service == null
                              ? 'Jumlah / berat'
                              : line.service!.pricingType == PricingType.perKg
                                  ? 'Berat (${line.service!.unit})'
                                  : 'Jumlah (${line.service!.unit})'),
                      validator: (value) =>
                          Validators.positiveNumber(value, field: 'Jumlah'),
                      onChanged: (_) => _updateBill(() {})),
                  if (line.service != null) ...[
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            line.service!.estimatedDurationInHours == 0
                                ? 'Langsung siap diambil · tanpa estimasi'
                                : 'Estimasi: ${_formatEstimateDate(DateTime.now().add(Duration(hours: line.service!.estimatedDurationInHours)))}',
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ])),
      );
  Future<void> _showCreateCustomerSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_saving || _customerFormOpen) return;
    _customerFormOpen = true;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    var gender = CustomerGender.male;

    final result = await showSafeModalBottomSheet<CustomerEntity>(
      context: context,
      isScrollControlled: true,
      controllers: [name, phone, address],
      hasUnsavedChanges: () => name.text.isNotEmpty || phone.text.isNotEmpty ||
          address.text.isNotEmpty || gender != CustomerGender.male,
      discardListenables: [name, phone, address],
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => SingleChildScrollView(
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

    _customerFormOpen = false;
    if (!isCurrentPage(context) || result == null) return;

    final saved = await withNavigationWriteLock(
        ref, () => ref.read(customersProvider.notifier).save(result));
    if (!mounted) return;

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
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate() ||
        _customer == null ||
        _lines.isEmpty ||
        _lines.any((line) =>
            line.service == null ||
            Validators.positiveNumber(line.quantity.text, field: 'Jumlah') !=
                null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Pilih pelanggan dan lengkapi layanan beserta jumlahnya.'),
        ),
      );
      return;
    }
    // Validate controller values too: rows scrolled out of a lazy ListView
    // may not have an active FormField when the fixed Save button is pressed.
    if (_paymentStatus != PaymentStatus.unpaid &&
        _validateInitialPayment(_initialPayment.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_validateInitialPayment(_initialPayment.text)!)));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final total = _total;
    final paidAmount = _paymentStatus == PaymentStatus.unpaid
        ? 0
        : int.parse(_initialPayment.text);
    final drafts = _lines
        .map((line) => (
              line.service!,
              double.parse(line.quantity.text.replaceAll(',', '.'))
            ))
        .toList();
    final first = drafts.first;
    final lines = drafts.map((draft) {
      final service = draft.$1;
      final base = (service.price * draft.$2).round();
      final fee = _express ? (base * .25).round() : 0;
      return TransactionLineEntity(
          id: '',
          serviceId: service.id,
          name: service.name,
          quantity: draft.$2,
          unit: service.unit,
          unitPrice: service.price.round(),
          subtotal: base + fee,
          expressFee: fee,
          estimatedFinishAt: service.estimatedDurationInHours == 0
              ? null
              : now.add(Duration(hours: service.estimatedDurationInHours)));
    }).toList();
    final deadlines = lines
        .map((line) => line.estimatedFinishAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    final transaction = TransactionEntity(
      id: '',
      invoice:
          'INV-${DateFormat('yyyyMMdd').format(now)}-${now.millisecond.toString().padLeft(4, '0')}',
      customerId: _customer!.id,
      serviceId: first.$1.id,
      customerName: _customer!.name,
      customerPhone: _customer!.phone ?? '',
      serviceName: first.$1.name,
      quantity: first.$2,
      quantityUnit: first.$1.unit,
      unitPrice: first.$1.price.round(),
      expressFee: _expressFee,
      total: total,
      paidAmount: paidAmount,
      paymentMethod: _paymentMethod,
      paymentDestinationId: paidAmount > 0 ? _paymentDestinationId : null,
      paymentStatus: paidAmount >= total
          ? PaymentStatus.paid
          : paidAmount > 0
              ? PaymentStatus.downPayment
              : PaymentStatus.unpaid,
      laundryStatus: LaundryStatus.received,
      createdAt: now,
      estimatedFinishAt: deadlines.isEmpty ? now : deadlines.last,
      hasEstimatedFinish: deadlines.isNotEmpty,
      details: lines,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    final result = await withNavigationWriteLock(
        ref, () => ref.read(transactionsProvider.notifier).create(transaction));
    if (!mounted) return;
    result.when(
      success: (created) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: created),
          ),
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

  String? _validateInitialPayment(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    return amount == null || amount <= 0 || amount > _total
        ? 'Pembayaran harus lebih dari 0 dan tidak melebihi total tagihan.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    // Prefetch both catalogues. Search routes observe their live loading/data
    // states independently, so opening one early cannot freeze an empty list.
    ref.watch(customersProvider);
    ref.watch(laundryServicesProvider);
    return PageVisibilityRefresh(refreshOnMount: _catalogCached,
        onVisible: _refreshCatalog, child: NavigationWriteGuard(
        child: UnsavedChangesGuard(
        hasUnsavedChanges: () => _hasDraft,
        listenables: [_notes, _initialPayment, ..._lines.map((line) => line.quantity)],
        child: Scaffold(
      appBar: AppBar(title: const Text('Transaksi Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _saving
                  ? null
                  : () async {
                      final selected = await showSearch<CustomerEntity?>(
                        context: context,
                        delegate: CustomerSearchDelegate(),
                      );
                      if (selected != null && mounted) {
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
                onPressed: _saving
                    ? null
                    : () => _showCreateCustomerSheet(context, ref),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Tambah pelanggan baru'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Layanan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var index = 0; index < _lines.length; index++)
              _serviceLine(_lines[index], index),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('transaction-add-service'),
              onPressed: _saving || _lines.length >= 50
                  ? null
                  : () => setState(() => _lines.add(_ServiceDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah layanan'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _express,
              title: const Text('Layanan Express'),
              subtitle: const Text(
                  'Tambahan 25% per layanan'),
              onChanged:
                  _saving ? null : (value) => _updateBill(() => _express = value),
            ),
            const SizedBox(height: 12),
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
              onChanged: (value) => setState(() {
                _paymentMethod = value!;
                _paymentDestinationId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentStatus>(
              key: ValueKey(_paymentStatus),
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
              onChanged: (value) => _choosePaymentStatus(value!),
            ),
            if (_paymentStatus != PaymentStatus.unpaid) ...[
              PaymentDestinationPicker(method: _paymentMethod, value: _paymentDestinationId,
                  onChanged: (id) => setState(() => _paymentDestinationId = id)),
              const SizedBox(height: 12),
              PaymentAmountField(
                  controller: _initialPayment,
                  helperText:
                      'Otomatis; ketik untuk mengganti',
                  validator: _validateInitialPayment,
                  onChanged: (_) => setState(_syncPaymentStatus)),
            ],
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
    ))));
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
            Expanded(
                child: Text(
              label,
              style: emphasis ? Theme.of(context).textTheme.titleMedium : null,
            )),
            const SizedBox(width: 12),
            Flexible(
                child: Text(
              TransactionsScreen._currency.format(value),
              textAlign: TextAlign.right,
              style: emphasis ? Theme.of(context).textTheme.titleMedium : null,
            )),
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
  late final bool _detailCached;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _detailCached = ref.exists(transactionDetailProvider(widget.transaction.id));
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(sessionProvider).valueOrNull?.role;
    final fresh = ref.watch(transactionDetailProvider(widget.transaction.id));
    ref.listen(transactionDetailProvider(widget.transaction.id), (_, next) {
      if (next.hasValue && mounted) setState(() => _transaction = next.requireValue);
    });
    final canDelete = currentRole == UserRole.owner &&
        _transaction.laundryStatus != LaundryStatus.collected &&
        _transaction.paidAmount == 0 &&
        !_transaction.serviceLines.any((line) => line.isCollected);
    ref.listen(transactionsProvider, (_, next) {
      final matches =
          next.valueOrNull?.where((item) => item.id == _transaction.id);
      if (matches != null && matches.isNotEmpty && mounted)
        setState(() => _transaction = matches.first);
    });
    return PageVisibilityRefresh(refreshOnMount: _detailCached, onVisible: () async {
      ref.invalidate(transactionProofProvider(_transaction.id));
      ref.invalidate(transactionLineProofProvider);
      ref.invalidate(transactionDetailProvider(_transaction.id));
      await ref.read(transactionDetailProvider(_transaction.id).future);
    }, child: NavigationWriteGuard(
        child: Scaffold(
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
                  if (confirmed != true || !mounted) return;
                  final result = await withNavigationWriteLock(
                      ref,
                      () => ref
                          .read(transactionsProvider.notifier)
                          .deleteTransaction(_transaction.id));
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
          if (fresh.isLoading) const LinearProgressIndicator(),
          if (fresh.hasError) ListTile(title: const Text('Detail terbaru belum dapat dimuat.'),
              trailing: TextButton(onPressed: () => ref.invalidate(transactionDetailProvider(_transaction.id)),
                  child: const Text('Coba lagi'))),
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
                  TransactionServiceLines(transaction: _transaction),
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
                                _transaction.hasEstimatedFinish
                                    ? 'Estimasi terakhir: ${_formatEstimateDate(_transaction.estimatedFinishAt)}'
                                    : 'Tanpa estimasi proses',
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
          TransactionEvidenceSection(transaction: _transaction),
          const SizedBox(height: 12),
          TransactionPaymentHistory(transaction: _transaction),
          const SizedBox(height: 12),
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _transaction.laundryStatus == LaundryStatus.collected
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CollectionSettlementScreen(
                          transaction: _transaction,
                        ),
                      ),
                    ),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Pengambilan / Pembayaran'),
          ),
        ],
      ),
    )));
  }
}

class CollectionSettlementScreen extends ConsumerStatefulWidget {
  final TransactionEntity transaction;
  final bool returnToCollectionList;

  const CollectionSettlementScreen({
    required this.transaction,
    this.returnToCollectionList = false,
    super.key,
  });

  @override
  ConsumerState<CollectionSettlementScreen> createState() =>
      _CollectionSettlementScreenState();
}

class _CollectionSettlementScreenState
    extends ConsumerState<CollectionSettlementScreen> {
  final _imagePicker = ImagePicker();
  Uint8List? _proofImage;
  bool _saving = false;
  late TransactionEntity _transaction;

  final _selectedIds = <String>{};
  PaymentEntry? _failedPayment;

  void _returnToCollectionSearch(String message) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    ref.read(transactionListRefreshProvider.notifier).state++;
    ref.invalidate(transactionDetailProvider(_transaction.id));
    if (widget.returnToCollectionList) {
      // Reuse the existing search page and its filters. The revision reloads
      // its Laravel query; true prevents the card from issuing a second load.
      navigator.pop(true);
    } else {
      final router = GoRouter.maybeOf(context);
      if (router == null) {
        navigator.pushReplacement(MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.collections),
            builder: (_) => const TransactionsScreen(isCollectionMode: true)));
      } else {
        Route<dynamic>? destination;
        // Drop temporary detail/settlement pages without discarding the tab
        // that opened them. QR/direct entry may have no search page yet.
        navigator.popUntil((route) {
          destination = route;
          return route.settings.name == AppRoutes.collections ||
              route.isFirst ||
              (route.settings is Page<dynamic> &&
                  route.settings.name != AppRoutes.collectionSettlement);
        });
        if (destination?.settings.name != AppRoutes.collections) {
          if (destination?.settings.name == AppRoutes.collectionSettlement) {
            unawaited(router.pushReplacement<void>(AppRoutes.collections));
          } else {
            unawaited(router.push<void>(AppRoutes.collections));
          }
        }
      }
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _selectedIds.addAll(_transaction.serviceLines
        .where((line) => line.isReady)
        .map((line) => line.id));
  }

  Future<void> _takeProofImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (image == null || !mounted) return;

    final proof = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _proofImage = proof);
  }

  Future<void> _refreshTransaction() async {
    if (_saving) return;
    final result = await ref
        .read(transactionRepositoryProvider)
        .getById(_transaction.id);
    if (!mounted) return;
    result.when(
        success: (current) {
          setState(() {
            _transaction = current;
            final ready = _transaction.serviceLines
                .where((line) => line.isReady)
                .map((line) => line.id)
                .toSet();
            _selectedIds.retainAll(ready);
            if (_selectedIds.isEmpty) _selectedIds.addAll(ready);
          });
        },
        error: (failure) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message))));
  }

  Future<void> _completeCollection() async {
    if (_saving) return;
    final selected = _transaction.serviceLines
        .where((line) => _selectedIds.contains(line.id) && line.isReady)
        .toList();
    if (selected.isEmpty) return;
    final entry = await showSafeModalBottomSheet<PaymentEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentEntrySheet(
          minimum: _transaction.minimumPaymentFor(selected),
          maximum: _transaction.remainingPayment
              .clamp(0, _transaction.total)
              .toInt(),
          method: _transaction.paymentMethod,
          forCollection: true),
      enableDrag: false,
    );
    if (entry == null || !isCurrentPage(context)) return;

    setState(() => _saving = true);
    final result = await withNavigationWriteLock(
        ref,
        () => ref.read(transactionsProvider.notifier).collectTransaction(
              transaction: _transaction.copyWith(paymentMethod: entry.method,
                  paymentDestinationId: entry.destinationId),
              settlePayment: false,
              proofImage: _proofImage,
              detailIds: _transaction.details.isEmpty
                  ? null
                  : selected.map((line) => line.id).toList(),
              paymentAmount: entry.amount,
              paymentNote: entry.note,
            ));
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (updated) {
        _returnToCollectionSearch(updated.laundryStatus == LaundryStatus.collected
            ? 'Seluruh layanan berhasil diambil.'
            : 'Layanan terpilih berhasil diambil. Layanan lainnya tetap pada transaksi ini.');
      },
      error: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  Future<void> _settlePayment() async {
    if (_saving) return;
    final entry = await showSafeModalBottomSheet<PaymentEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentEntrySheet(
          minimum: 1,
          maximum: _transaction.remainingPayment,
          method: _transaction.paymentMethod,
          previous: _failedPayment),
      enableDrag: false,
    );
    if (entry == null || !isCurrentPage(context)) return;

    setState(() => _saving = true);
    _failedPayment = entry;
    final result = await withNavigationWriteLock(
        ref,
        () => ref.read(transactionsProvider.notifier).pay(
            transaction: _transaction.copyWith(paymentDestinationId: entry.destinationId),
            amount: entry.amount,
            method: entry.method,
            note: entry.note,
            requestId: entry.requestId));
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (updated) {
        _returnToCollectionSearch(
            'Pembayaran berhasil dicatat. Barang tidak otomatis diambil.');
      },
      error: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;
    final remaining =
        transaction.remainingPayment.clamp(0, transaction.total).toInt();
    final isCollected = transaction.laundryStatus == LaundryStatus.collected;
    final canCollect = transaction.hasReadyItems;

    return PageVisibilityRefresh(onVisible: _refreshTransaction, child: NavigationWriteGuard(
        child: UnsavedChangesGuard(
        hasUnsavedChanges: () => _proofImage != null,
        child: Scaffold(
      appBar: AppBar(title: const Text('Pengambilan / Pembayaran')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ||
                        isCollected ||
                        !canCollect ||
                        _selectedIds.isEmpty
                    ? null
                    : _completeCollection,
                child: Text(
                  remaining > 0 ? 'Bayar & Ambil' : 'Ambil',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving || isCollected || remaining <= 0
                    ? null
                    : _settlePayment,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(remaining <= 0 ? 'Sudah Lunas' : 'Bayar Saja'),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
          onRefresh: _refreshTransaction,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('Layanan pada transaksi',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TransactionServiceLines(
                  transaction: transaction,
                  selectedIds: _selectedIds,
                  enabled: !_saving,
                  onToggle: (id, selected) => setState(() {
                        if (selected) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      })),
              const Text(
                  'Ambil seluruh layanan terpilih'),
              const SizedBox(height: 20),
              Text(
                'Bukti pengambilan (opsional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                              onPressed: _saving ? null : _takeProofImage,
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
                            child:
                                Image.memory(_proofImage!, fit: BoxFit.cover),
                          ),
                          TextButton.icon(
                            onPressed: _saving ? null : _takeProofImage,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Ambil Ulang Foto'),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              if (!isCollected && !canCollect) ...[
                const Text(
                  'Laundry belum selesai sehingga belum dapat diserahkan.',
                  style: TextStyle(color: AppColors.warning),
                ),
                const SizedBox(height: 20),
              ],
              Text('Kode transaksi',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.invoice,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(transaction.customerName),
                      if (transaction.customerPhone.isNotEmpty)
                        Text(transaction.customerPhone,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Detail tagihan',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final line in transaction.serviceLines)
                        _PriceRow(
                            label:
                                '${line.name} (${line.quantity} ${line.unit})',
                            value: line.subtotal),
                      const Divider(height: 20),
                      _PriceRow(
                          label: 'Total tagihan', value: transaction.total),
                      _PriceRow(
                          label: 'Sudah dibayar',
                          value: transaction.paidAmount),
                      const Divider(height: 20),
                      _PriceRow(
                          label: 'Sisa tagihan',
                          value: remaining,
                          emphasis: true),
                      if (remaining <= 0) ...[
                        const SizedBox(height: 12),
                        const _StatusChip(
                          label: 'Sudah Lunas',
                          color: AppColors.statusSelesai,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isCollected) ...[
                const SizedBox(height: 16),
                const _StatusChip(
                    label: 'Sudah Diambil', color: AppColors.statusSelesai),
              ],
            ],
          )),
    ))));
  }
}

class _PrintReceiptButton extends ConsumerWidget {
  final TransactionEntity transaction;
  const _PrintReceiptButton({required this.transaction});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrinting = ref.watch(receiptPrintingProvider);
    final isSharing = ref.watch(receiptSharingProvider);
    final isBusy = isPrinting || isSharing;
    return FloatingActionButton.extended(
      onPressed: isBusy ? null : () => _chooseReceiptAction(context, ref),
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined),
      label: Text(isBusy ? 'Memproses...' : 'Cetak Bon'),
    );
  }

  Future<void> _chooseReceiptAction(BuildContext context, WidgetRef ref) async {
    if (!isCurrentPage(context) || ref.read(receiptPrintingProvider) ||
        ref.read(receiptSharingProvider)) return;
    final preparing = ref.read(receiptSharingProvider.notifier);
    preparing.state = true;
    late final LaundrySettings settings;
    try {
      // Do not capture null on the first tap while settings are still loading:
      // both the receipt and its caption must use this business's actual name.
      settings = await ref.read(laundrySettingsProvider.future);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pengaturan usaha belum dapat dimuat. Silakan coba lagi.')));
      }
      return;
    } finally {
      if (preparing.mounted) preparing.state = false;
    }
    if (!isCurrentPage(context)) return;
    final canPrint = settings.defaultPrinter?.isNotEmpty ?? false;
    final canShareWhatsApp = WhatsAppLauncher.hasValidPhone(
      transaction.customerPhone,
    );
    final action = await showModalBottomSheet<_ReceiptAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Bon transaksi'),
              subtitle: Text('Pilih pengiriman bon'),
            ),
            ListTile(
              enabled: canPrint,
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print bon'),
              subtitle: Text(canPrint
                  ? settings.defaultPrinterName ?? 'Printer aplikasi'
                  : 'Pilih printer di Pengaturan'),
              onTap: canPrint
                  ? () => Navigator.pop(sheetContext, _ReceiptAction.print)
                  : null,
            ),
            ListTile(
              enabled: canShareWhatsApp,
              leading: const Icon(Icons.image_outlined),
              title: const Text('Kirim bon ke WhatsApp'),
              subtitle: Text(canShareWhatsApp
                  ? 'Kirim foto struk'
                  : 'Nomor WhatsApp belum valid'),
              onTap: canShareWhatsApp
                  ? () => Navigator.pop(sheetContext, _ReceiptAction.whatsApp)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _ReceiptAction.print:
        await _printReceipt(
          context,
          ref,
          settings.defaultPrinter ?? '',
          settings,
        );
        break;
      case _ReceiptAction.whatsApp:
        await _shareReceiptImage(context, ref, settings);
        break;
    }
  }

  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    String mac,
    LaundrySettings? settings,
  ) async {
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
    ref.read(receiptPrintingProvider.notifier).state = true;
    try {
      final result = await ref.read(thermalReceiptServiceProvider).print(
            transaction,
            macAddress: mac,
            businessName: settings?.businessName ?? 'CLEAN FRESH LAUNDRY',
            paperSize: settings?.paperSize ?? '58 mm',
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Bon berhasil dikirim ke printer.'
                : 'Printer tidak dapat dihubungkan. Pastikan printer menyala dan sudah dipasangkan.',
          ),
        ),
      );
    } on PrinterException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      ref.read(receiptPrintingProvider.notifier).state = false;
    }
  }

  Future<void> _shareReceiptImage(
    BuildContext context,
    WidgetRef ref,
    LaundrySettings? settings,
  ) async {
    ref.read(receiptSharingProvider.notifier).state = true;
    try {
      final image = await ScreenshotController().captureFromWidget(
        Material(
          color: Colors.white,
          child: Center(
            child: ReceiptImage(
              transaction: transaction,
              businessName: settings?.businessName ?? 'CLEAN FRESH LAUNDRY',
              businessPhone: settings?.phone ?? '',
            ),
          ),
        ),
        pixelRatio: 2,
      );
      if (!context.mounted) return;
      final opened = await WhatsAppReceiptLauncher.open(
        phone: transaction.customerPhone,
        image: image,
        filename: 'bon-${transaction.invoice}.png',
        message: ReceiptText.whatsAppCaption(
          customerName: transaction.customerName,
          businessName: settings?.businessName ?? 'CLEAN FRESH LAUNDRY',
          invoice: transaction.invoice,
          total: transaction.total,
        ),
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp tidak tersedia. Pastikan aplikasi WhatsApp telah terpasang.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bon gambar gagal dibuat untuk dibagikan.')),
        );
      }
    } finally {
      ref.read(receiptSharingProvider.notifier).state = false;
    }
  }
}

enum _ReceiptAction { print, whatsApp }

class ReceiptImage extends StatelessWidget {
  final TransactionEntity transaction;
  final String businessName;
  final String businessPhone;

  const ReceiptImage({
    required this.transaction,
    required this.businessName,
    required this.businessPhone,
  });

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  static final _dateTime = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  Widget build(BuildContext context) => Container(
        width: 420,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        color: Colors.white,
        child: DefaultTextStyle(
          style: const TextStyle(
              color: Colors.black87, fontSize: 14, fontFamily: 'monospace'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                businessName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (businessPhone.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(businessPhone, textAlign: TextAlign.center),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: Colors.black54),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                QrImageView(data: transaction.invoice, size: 148,
                    semanticsLabel: 'Kode transaksi ${transaction.invoice}',
                    backgroundColor: Colors.white, padding: const EdgeInsets.all(20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.customerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (transaction.customerPhone.trim().isNotEmpty)
                        Text(transaction.customerPhone),
                    ])),
              ]),
              Text(
                transaction.invoice,
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: Colors.black54),
              ),
              _ReceiptLine(
                label: 'Tanggal masuk',
                value:
                    '${_dateTime.format(BusinessTime.wallTime(transaction.createdAt))} WIB',
              ),
              _ReceiptLine(
                label: 'Estimasi terakhir',
                value: transaction.hasEstimatedFinish
                    ? '${_dateTime.format(BusinessTime.wallTime(transaction.estimatedFinishAt))} WIB'
                    : 'Tanpa estimasi',
              ),
              const SizedBox(height: 6),
              const Text('Layanan', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final line in transaction.serviceLines) ...[
                const SizedBox(height: 6),
                _ReceiptLine(
                    label: line.name,
                    small: true,
                    value: line.estimatedFinishAt == null
                        ? (line.hasKnownTiming
                            ? 'Tanpa estimasi'
                            : 'Estimasi tidak tersedia')
                        : '${DateFormat('dd/MM HH:mm', 'id_ID').format(BusinessTime.wallTime(line.estimatedFinishAt!))} WIB'),
                _ReceiptLine(
                    label: '${line.quantity} ${line.unit}',
                    value: _currency.format(line.subtotal)),
                if (line.isCollected)
                  const Text('Sudah diambil', style: TextStyle(fontSize: 11)),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.black54),
              ),
              _ReceiptLine(
                label: 'Total',
                value: _currency.format(transaction.total),
                emphasis: true,
              ),
              _ReceiptLine(
                label: 'Sudah dibayar',
                value: _currency.format(transaction.paidAmount),
              ),
              _ReceiptLine(
                  label: 'Sisa tagihan',
                  value: _currency.format(transaction.remainingPayment
                      .clamp(0, transaction.total))),
              _ReceiptLine(
                label: 'Status pembayaran',
                value: transaction.paymentStatus.label,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: Colors.black54),
              ),
              const Text(
                '${ReceiptText.collectionPaymentNote}\nTerima kasih.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _ReceiptLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;

  final bool small;

  const _ReceiptLine({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Text(label,
                    style: small ? const TextStyle(fontSize: 11) : null)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: emphasis
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : small
                        ? const TextStyle(fontSize: 11)
                        : null,
              ),
            ),
          ],
        ),
      );
}
