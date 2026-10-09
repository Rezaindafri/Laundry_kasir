import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/auth/presentation/widgets/login_form.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/customer_entity.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/master_data/domain/repositories/master_data_repository.dart';
import 'package:laundry_management_system/features/master_data/presentation/providers/master_data_providers.dart';
import 'package:laundry_management_system/features/master_data/presentation/screens/customers_screen.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

// These UI tests never open a socket, printer, camera or the application's DB.
class _AuditAuthRepository implements AuthRepository {
  _AuditAuthRepository({this.user, this.failure});

  final UserEntity? user;
  final Failure? failure;

  @override
  Future<Result<UserEntity?>> getCurrentUser() async => Success(user);

  @override
  Future<bool> hasActiveSession() async => user != null;

  @override
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async =>
      Error(failure ?? const UnauthorizedFailure());

  @override
  Future<Result<void>> logout() async => const Success(null);
}

class _AuditMasterRepository implements MasterDataRepository {
  final List<CustomerEntity> customers = [];
  int saves = 0;

  @override
  Future<Result<List<CustomerEntity>>> getCustomers() async =>
      Success(List.of(customers));

  @override
  Future<Result<CustomerEntity>> saveCustomer(CustomerEntity customer) async {
    saves++;
    final saved = CustomerEntity(id: 'customer-$saves', name: customer.name);
    customers.add(saved);
    return Success(saved);
  }

  @override
  Future<Result<void>> deleteCustomer(String id) async => const Success(null);

  @override
  Future<Result<List<LaundryServiceEntity>>> getServices() async =>
      const Success([]);

  @override
  Future<Result<LaundryServiceEntity>> saveService(
    LaundryServiceEntity service,
  ) async =>
      Success(service);

  @override
  Future<Result<void>> deleteService(String id) async => const Success(null);
}

Future<void> _openQuickCustomerForm(
  WidgetTester tester,
  _AuditMasterRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/customers?create=true',
    routes: [
      GoRoute(
        path: '/customers',
        builder: (_, state) => CustomersScreen(
          key: ValueKey(state.uri.toString()),
          openCreateForm: state.uri.queryParameters['create'] == 'true',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _AuditAuthRepository(
            user: UserEntity(
              id: 'audit-cashier',
              name: 'Audit Cashier',
              username: 'audit-cashier',
              role: UserRole.kasir,
              ownerId: 'audit-owner',
              isActive: true,
              createdAt: DateTime(2026),
            ),
          ),
        ),
        masterDataRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Pelanggan Baru'), findsOneWidget);
}

void main() {
  for (final failure in [
    const UnauthorizedFailure('Username atau password salah.'),
    const ServerFailure('Akun dinonaktifkan.'),
    const ServerFailure('Terjadi kesalahan, coba lagi nanti.'),
    const ServerFailure('Terlalu banyak percobaan login. Coba lagi sebentar.'),
  ]) {
    testWidgets('Login shows inline notice and snackbar: ${failure.message}',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _AuditAuthRepository(failure: failure),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: LoginForm())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'audit-user');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrong-password',
      );
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      expect(find.text(failure.message), findsNWidgets(2));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Quick customer modal closes on outside tap without saving',
      (tester) async {
    final repository = _AuditMasterRepository();
    await _openQuickCustomerForm(tester, repository);
    await tester.enterText(find.byType(TextFormField).first, 'Not saved');
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(find.text('Pelanggan Baru'), findsNothing);
    expect(
      find.text('Data pelanggan saat ini belum tersedia.'),
      findsOneWidget,
    );
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick customer modal closes on system Back without saving',
      (tester) async {
    final repository = _AuditMasterRepository();
    await _openQuickCustomerForm(tester, repository);
    await tester.enterText(find.byType(TextFormField).first, 'Not saved');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pelanggan Baru'), findsNothing);
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick customer form saves once and returns to customer list',
      (tester) async {
    final repository = _AuditMasterRepository();
    await _openQuickCustomerForm(tester, repository);
    await tester.enterText(find.byType(TextFormField).first, 'Audit customer');
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Pelanggan Baru'), findsNothing);
    expect(find.text('Audit customer'), findsOneWidget);
    expect(repository.saves, 1);
    expect(find.text('Data pelanggan berhasil disimpan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
