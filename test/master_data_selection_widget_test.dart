import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/utils/name_sort.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/master_data/data/repositories/mock_master_data_repository.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/customer_entity.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/master_data/presentation/providers/master_data_providers.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';

const _customers = [
  CustomerEntity(id: 'z', name: 'Zaki', phone: '081234567890'),
  CustomerEntity(id: 'b', name: ' budi', address: 'Jalan Mawar'),
  CustomerEntity(id: 'a', name: 'Ana'),
];
const _services = [
  LaundryServiceEntity(
      id: 's', name: 'Setrika', price: 6000, unit: 'kg', estimatedHours: 4),
  LaundryServiceEntity(
      id: 'b', name: 'barang', price: 5000, unit: 'item', estimatedHours: 0),
  LaundryServiceEntity(
      id: 'c', name: ' Cuci', price: 10000, unit: 'kg', estimatedHours: 2),
  LaundryServiceEntity(
      id: 'old',
      name: 'Arsip',
      price: 1000,
      unit: 'item',
      estimatedHours: 0,
      isActive: false),
];

// No HTTP, database or device plugins: exercise the actual form/providers.
class _CatalogFixture extends MockMasterDataRepository {
  _CatalogFixture({this.loadCustomers, this.loadServices});
  final Future<Result<List<CustomerEntity>>> Function(int)? loadCustomers;
  final Future<Result<List<LaundryServiceEntity>>> Function(int)? loadServices;
  int customerLoads = 0;
  int serviceLoads = 0;

  @override
  Future<Result<List<CustomerEntity>>> getCustomers() async {
    customerLoads++;
    return loadCustomers == null
        ? const Success(_customers)
        : await loadCustomers!(customerLoads);
  }

  @override
  Future<Result<List<LaundryServiceEntity>>> getServices() async {
    serviceLoads++;
    return loadServices == null
        ? const Success(_services)
        : await loadServices!(serviceLoads);
  }

  @override
  Future<Result<CustomerEntity>> saveCustomer(CustomerEntity customer) async =>
      Success(customer);

  @override
  Future<Result<LaundryServiceEntity>> saveService(
          LaundryServiceEntity service) async =>
      Success(service);
}

Future<void> _open(WidgetTester tester, _CatalogFixture repository) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentSessionUserIdProvider.overrideWithValue('fixture-owner'),
      masterDataRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: NewTransactionScreen()),
  ));
  await tester.pump();
}

Future<void> _pickCustomer(WidgetTester tester) async {
  await tester.tap(find.text('Pilih pelanggan'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pickService(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('transaction-service-picker-0')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

List<String> _visibleNames(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title! as Text).data!)
    .toList();

void main() {
  testWidgets('customers arriving after picker opens become selectable',
      (tester) async {
    final pending = Completer<Result<List<CustomerEntity>>>();
    await _open(tester, _CatalogFixture(loadCustomers: (_) => pending.future));
    await _pickCustomer(tester);
    pending.complete(const Success(_customers));
    await tester.pumpAndSettle();
    expect(_visibleNames(tester), ['Ana', ' budi', 'Zaki']);
    await tester.tap(find.widgetWithText(ListTile, 'Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer picker shows loading and retains search after arrival',
      (tester) async {
    final pending = Completer<Result<List<CustomerEntity>>>();
    await _open(tester, _CatalogFixture(loadCustomers: (_) => pending.future));
    await _pickCustomer(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();
    pending.complete(const Success(_customers));
    await tester.pumpAndSettle();
    expect(_visibleNames(tester), ['Ana']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed customer load is not silently empty; retry keeps query',
      (tester) async {
    final repository = _CatalogFixture(
        loadCustomers: (attempt) async => attempt == 1
            ? const Error(ServerFailure('Fixture connection failure'))
            : const Success(_customers));
    await _open(tester, repository);
    await _pickCustomer(tester);
    await tester.pumpAndSettle();
    expect(find.text('Data pelanggan gagal dimuat.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'mawar');
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(repository.customerLoads, 2);
    expect(_visibleNames(tester), [' budi']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty customer catalogue is different from no search matches',
      (tester) async {
    await _open(
        tester, _CatalogFixture(loadCustomers: (_) async => const Success([])));
    await _pickCustomer(tester);
    await tester.pumpAndSettle();
    expect(
        find.text('Data pelanggan saat ini belum tersedia.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester, _CatalogFixture());
    await _pickCustomer(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tidak cocok');
    await tester.pumpAndSettle();
    expect(find.text('Pelanggan tidak ditemukan untuk pencarian ini.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('service picker updates after loading, sorts A-Z, hides inactive',
      (tester) async {
    final pending = Completer<Result<List<LaundryServiceEntity>>>();
    await _open(tester, _CatalogFixture(loadServices: (_) => pending.future));
    await _pickService(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const Success(_services));
    await tester.pumpAndSettle();
    expect(_visibleNames(tester), ['barang', ' Cuci', 'Setrika']);
    expect(find.text('Arsip'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Transaksi Baru'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh finds newly available customers without closing search',
      (tester) async {
    var catalogue = _customers;
    final repository = _CatalogFixture(
        loadCustomers: (_) async => Success(List.of(catalogue)));
    await _open(tester, repository);
    await _pickCustomer(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dina');
    await tester.pumpAndSettle();
    expect(find.text('Pelanggan tidak ditemukan untuk pencarian ini.'),
        findsOneWidget);
    catalogue = [..._customers, const CustomerEntity(id: 'd', name: 'Dina')];
    await tester.tap(find.byTooltip('Perbarui daftar pelanggan'));
    await tester.pumpAndSettle();
    expect(repository.customerLoads, 2);
    expect(_visibleNames(tester), ['Dina']);
    await tester.tap(find.widgetWithText(ListTile, 'Dina'));
    await tester.pumpAndSettle();
    expect(find.text('Dina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('service picker shows a retry for failures and no-match notice',
      (tester) async {
    final repository = _CatalogFixture(
        loadServices: (attempt) async => attempt == 1
            ? const Error(ServerFailure('Fixture connection failure'))
            : const Success(_services));
    await _open(tester, repository);
    await _pickService(tester);
    await tester.pumpAndSettle();
    expect(find.text('Data layanan gagal dimuat.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(repository.serviceLoads, 2);
    expect(_visibleNames(tester), ['barang', ' Cuci', 'Setrika']);
    await tester.enterText(find.byType(TextField), 'tidak cocok');
    await tester.pumpAndSettle();
    expect(find.text('Layanan tidak ditemukan untuk pencarian ini.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open picker never displays cached customers of another session',
      (tester) async {
    final identity = StateProvider<String?>((_) => 'owner-a');
    final pending = Completer<Result<List<CustomerEntity>>>();
    final repository = _CatalogFixture(
        loadCustomers: (attempt) => attempt == 1
            ? Future.value(const Success(_customers))
            : pending.future);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentSessionUserIdProvider.overrideWith((ref) => ref.watch(identity)),
        masterDataRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: NewTransactionScreen()),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(NewTransactionScreen)));
    await _pickCustomer(tester);
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    container.read(identity.notifier).state = 'owner-b';
    await tester.pump();
    expect(find.text('Ana'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const Success([
      CustomerEntity(id: 'owner-b-customer', name: 'Dina'),
    ]));
    await tester.pumpAndSettle();
    expect(_visibleNames(tester), ['Dina']);
    expect(tester.takeException(), isNull);
  });

  test('equal normalized names keep their order without mutating input', () {
    const names = ['Zaki', ' ana ', 'ANA', 'Ana', 'budi'];
    expect(sortedByName(names, (name) => name),
        [' ana ', 'ANA', 'Ana', 'budi', 'Zaki']);
    expect(names, ['Zaki', ' ana ', 'ANA', 'Ana', 'budi']);
  });

  test('customer provider sorts load and save by name, not phone presence',
      () async {
    final container = ProviderContainer(overrides: [
      currentSessionUserIdProvider.overrideWithValue('fixture-owner'),
      masterDataRepositoryProvider.overrideWithValue(_CatalogFixture()),
    ]);
    addTearDown(container.dispose);
    final loaded = await container.read(customersProvider.future);
    expect(loaded.map((item) => item.id), ['a', 'b', 'z']);
    await container
        .read(customersProvider.notifier)
        .save(const CustomerEntity(id: 'aa', name: ' aaron'));
    expect(
        container.read(customersProvider).requireValue.map((item) => item.id),
        ['aa', 'a', 'b', 'z']);
  });

  test('service provider sorts initial data and edits without dropping entries',
      () async {
    final container = ProviderContainer(overrides: [
      currentSessionUserIdProvider.overrideWithValue('fixture-owner'),
      masterDataRepositoryProvider.overrideWithValue(_CatalogFixture()),
    ]);
    addTearDown(container.dispose);
    final loaded = await container.read(laundryServicesProvider.future);
    expect(loaded.map((item) => item.id), ['old', 'b', 'c', 's']);
    await container
        .read(laundryServicesProvider.notifier)
        .save(_services.first.copyWith(name: 'A baru'));
    expect(
        container
            .read(laundryServicesProvider)
            .requireValue
            .map((item) => item.id),
        ['s', 'old', 'b', 'c']);
    expect(_services.first.name, 'Setrika');
  });
}
