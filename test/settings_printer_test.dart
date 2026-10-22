import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundry_management_system/features/auth/data/models/user_model.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/printing/data/services/printer_device_service.dart';
import 'package:laundry_management_system/features/printing/domain/entities/printer_device.dart';
import 'package:laundry_management_system/features/printing/presentation/providers/printing_providers.dart';
import 'package:laundry_management_system/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:laundry_management_system/features/settings/data/repositories/local_settings_repository.dart';
import 'package:laundry_management_system/features/settings/domain/entities/laundry_settings.dart';
import 'package:laundry_management_system/features/settings/presentation/providers/settings_providers.dart';
import 'package:laundry_management_system/features/settings/presentation/screens/settings_screen.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

const _business = LaundrySettings(
  businessName: 'Usaha server',
  phone: '0800000000',
  address: 'Alamat server',
  paperSize: '58 mm',
);

final _owner = UserEntity(
  id: 'owner-a',
  name: 'Owner uji',
  username: 'owner',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
);

class _Session extends SessionNotifier {
  @override
  Future<UserEntity?> build() async => _owner;
}

class _Remote implements SettingsRemoteDataSource {
  int saves = 0;
  Completer<LaundrySettings>? pending;

  @override
  Future<LaundrySettings> getSettings() async =>
      pending == null ? _business : await pending!.future;

  @override
  Future<LaundrySettings> saveSettings(LaundrySettings settings) async {
    saves++;
    return settings;
  }

  @override
  Future<Uint8List> downloadBackup() async => Uint8List(0);

  @override
  Future<void> restoreBackup(Map<String, dynamic> backup) async {}
}

class _Printers extends PrinterDeviceService {
  @override
  Future<List<PrinterDevice>> getPairedDevices() async => List.generate(
        30,
        (index) => PrinterDevice(
          name: 'Printer $index',
          macAddress: 'AA:BB:CC:DD:EE:${index.toString().padLeft(2, '0')}',
        ),
      );
}

ProviderContainer _container(SharedPreferences preferences, _Remote remote) =>
    ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      currentOperationalOwnerScopeIdProvider.overrideWithValue('owner-a'),
      settingsRemoteDataSourceProvider.overrideWithValue(remote),
    ]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'device preferences survive repository recreation without saving business drafts',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalSettingsRepository(preferences);
    await repository.save(_business, ownerId: 'owner-a');
    await repository.saveDeviceSettings(_business.copyWith(
      businessName: 'Draf belum disimpan',
      defaultPrinter: 'AA:BB',
      defaultPrinterName: 'Printer kasir',
      paperSize: '80 mm',
    ));

    final recreated = LocalSettingsRepository(preferences);
    final ownerA = recreated.load(ownerId: 'owner-a');
    final ownerB = recreated.load(ownerId: 'owner-b');
    expect(ownerA.businessName, 'Usaha server');
    expect(ownerB.businessName, isNot('Usaha server'));
    for (final settings in [ownerA, ownerB]) {
      expect(settings.defaultPrinter, 'AA:BB');
      expect(settings.defaultPrinterName, 'Printer kasir');
      expect(settings.paperSize, '80 mm');
    }
  });

  test('notifier restores the last selected printer after app scope recreation',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final remote = _Remote();
    final first = _container(preferences, remote);
    final settings = await first.read(laundrySettingsProvider.future);
    await first.read(laundrySettingsProvider.notifier).saveDeviceSettings(
          settings.copyWith(
            businessName: 'Draf tidak boleh terkirim',
            defaultPrinter: 'AA:BB',
            defaultPrinterName: 'Printer terakhir',
          ),
        );
    expect(first.read(laundrySettingsProvider).requireValue.businessName,
        'Usaha server');
    first.dispose();

    final second = _container(preferences, remote);
    addTearDown(second.dispose);
    final restored = await second.read(laundrySettingsProvider.future);
    expect(restored.defaultPrinter, 'AA:BB');
    expect(restored.defaultPrinterName, 'Printer terakhir');
    expect(remote.saves, 0);
  });

  test('slow server refresh cannot overwrite a newly selected printer',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final remote = _Remote();
    final container = _container(preferences, remote);
    addTearDown(container.dispose);
    final settings = await container.read(laundrySettingsProvider.future);
    remote.pending = Completer<LaundrySettings>();
    final refresh = container.read(laundrySettingsProvider.notifier).refresh();
    await container.read(laundrySettingsProvider.notifier).saveDeviceSettings(
          settings.copyWith(defaultPrinter: 'NEW', defaultPrinterName: 'Baru'),
        );
    remote.pending!
        .complete(_business.copyWith(businessName: 'Usaha diperbarui'));
    await refresh;
    final restored = container.read(laundrySettingsProvider).requireValue;
    expect(restored.defaultPrinter, 'NEW');
    expect(restored.defaultPrinterName, 'Baru');
    expect(restored.businessName, 'Usaha diperbarui');
    expect(remote.saves, 0);
  });

  testWidgets('printer picker scrolls on small screens and saves immediately',
      (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    final remote = _Remote();

    Widget app() => ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            sessionProvider.overrideWith(_Session.new),
            settingsRemoteDataSourceProvider.overrideWithValue(remote),
            currentProfileProvider
                .overrideWith((ref) async => UserModel.fromEntity(_owner)),
            accountPasswordMinLengthProvider.overrideWith((ref) async => 12),
            printerDeviceServiceProvider.overrideWithValue(_Printers()),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).first, 'Usaha draf');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // Finish the focused field's scroll/keyboard animation before scrolling to
    // the printer control; otherwise it can move back off this small viewport.
    await tester.scrollUntilVisible(find.text('Pilih printer').hitTestable(), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Pilih printer').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Pilih printer'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    final printerList = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('Printer 29'), 180,
        scrollable: printerList);
    await tester.tap(find.text('Printer 29'));
    await tester.pumpAndSettle();
    final saved = LocalSettingsRepository(preferences).load(ownerId: 'owner-a');
    expect(saved.defaultPrinter, 'AA:BB:CC:DD:EE:29');
    expect(saved.defaultPrinterName, 'Printer 29');
    expect(saved.businessName, 'Usaha server');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Usaha draf');
    expect(remote.saves, 0);
    expect(tester.takeException(), isNull);

    // Simulate ending the app scope without pressing "Simpan pengaturan".
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Printer 29'));
    expect(find.text('Printer 29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
