import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/master_data/data/repositories/mock_master_data_repository.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/master_data/presentation/providers/master_data_providers.dart';
import 'package:laundry_management_system/features/master_data/presentation/screens/laundry_services_screen.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

class _Owner extends SessionNotifier {
  @override
  Future<UserEntity?> build() async => UserEntity(
      id: 'owner-a',
      name: 'Owner fixture',
      username: 'fixture',
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime(2026));
}

class _Repository extends MockMasterDataRepository {
  bool fail = false;
  int saves = 0;
  Completer<Result<LaundryServiceEntity>>? pending;
  @override
  Future<Result<LaundryServiceEntity>> saveService(
      LaundryServiceEntity item) async {
    saves++;
    if (pending != null) return pending!.future;
    return fail
        ? const Error(ServerFailure('Gagal menyimpan layanan.'))
        : Success(item);
  }
}

Future<void> _open(WidgetTester tester, _Repository repository) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    sessionProvider.overrideWith(_Owner.new),
    masterDataRepositoryProvider.overrideWithValue(repository),
  ], child: const MaterialApp(home: LaundryServicesScreen())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tambah'));
  await tester.pumpAndSettle();
}

void main() {
  for (final dirty in [false, true]) {
    for (final mode in ['Back', 'outside', 'button']) {
      testWidgets('new service confirms $mode; dirty=$dirty', (tester) async {
        final repository = _Repository();
        await _open(tester, repository);
        if (dirty)
          await tester.enterText(
              find.byType(TextFormField).first, 'Draf layanan');
        Future<void> close() async {
          if (mode == 'Back') {
            await tester.binding.handlePopRoute();
          } else if (mode == 'outside') {
            await tester.tapAt(const Offset(5, 5));
          } else {
            await tester.ensureVisible(find.text('Batal'));
            await tester.tap(find.text('Batal'));
          }
          await tester.pumpAndSettle();
        }

        await close();
        expect(find.text('Batalkan perubahan?'), findsOneWidget);
        await tester.tap(find.text('Lanjut mengisi'));
        await tester.pumpAndSettle();
        expect(find.text('Layanan Baru'), findsOneWidget);
        if (dirty) expect(find.text('Draf layanan'), findsOneWidget);
        await close();
        await tester.tap(find.text('Ya, batalkan'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(repository.saves, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('failed save retains service draft; success closes once',
      (tester) async {
    final repository = _Repository()..fail = true;
    await _open(tester, repository);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Layanan fixture');
    await tester.enterText(fields.at(1), '12000');
    await tester.enterText(fields.at(2), 'kg');
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Layanan Baru'), findsOneWidget);
    expect(find.text('Layanan fixture'), findsOneWidget);
    expect(find.text('Gagal menyimpan layanan.'), findsOneWidget);
    expect(repository.saves, 1);
    repository.fail = false;
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Data layanan berhasil disimpan.'), findsOneWidget);
    expect(repository.saves, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'double tap and Back cannot duplicate or discard an in-flight service save',
      (tester) async {
    final pending = Completer<Result<LaundryServiceEntity>>();
    final repository = _Repository()..pending = pending;
    await _open(tester, repository);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Layanan fixture');
    await tester.enterText(fields.at(1), '12000');
    await tester.enterText(fields.at(2), 'kg');
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(repository.saves, 1);
    expect(find.text('Menyimpan…'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Batalkan perubahan?'), findsNothing);
    pending.complete(const Error(ServerFailure('Gagal menyimpan layanan.')));
    await tester.pumpAndSettle();
    expect(find.text('Layanan fixture'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(repository.saves, 1);
    expect(tester.takeException(), isNull);
  });
}
