import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/widgets/navigation_write_guard.dart';
import 'package:laundry_management_system/core/widgets/safe_modal_sheet.dart';
import 'package:laundry_management_system/core/widgets/unsaved_changes_guard.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required void Function(String?) onResult,
  ProviderContainer? container,
}) async {
  final app = MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      final draft = TextEditingController();
                      final result = await showSafeModalBottomSheet<String>(
                        context: context,
                        controllers: [draft],
                        hasUnsavedChanges: () => draft.text.isNotEmpty,
                        discardListenables: [draft],
                        builder: (sheetContext) => Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            TextFormField(
                                controller: draft,
                                decoration:
                                    const InputDecoration(labelText: 'Draft')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.maybePop(sheetContext),
                                child: const Text('Batal')),
                            FilledButton(
                                onPressed: () =>
                                    Navigator.pop(sheetContext, draft.text),
                                child: const Text('Simpan')),
                          ]),
                        ),
                      );
                      onResult(result);
                    },
                    child: const Text('Buka form')),
              )));
  await tester.pumpWidget(container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app));
  await tester.tap(find.text('Buka form'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('destructive action confirmation reports false until approved',
      (tester) async {
    var actions = 0;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        if (await showActionConfirmation(
                            context: context,
                            title: 'Hapus data?',
                            message: 'Apakah Anda yakin?',
                            confirmLabel: 'Hapus')) actions++;
                      },
                      child: const Text('Hapus data')),
                ))));
    await tester.tap(find.text('Hapus data'));
    await tester.pumpAndSettle();
    expect(actions, 0);
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(actions, 0);
    await tester.tap(find.text('Hapus data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['Back', 'outside', 'button']) {
    testWidgets('empty draft closes without confirmation: $mode',
        (tester) async {
      var results = 0;
      await _openSheet(tester, onResult: (_) => results++);
      if (mode == 'Back') {
        await tester.binding.handlePopRoute();
      } else if (mode == 'outside') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text('Batal'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(results, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in ['Back', 'outside', 'button']) {
    testWidgets('changed draft can continue or confirm discard: $mode',
        (tester) async {
      var results = 0;
      await _openSheet(tester, onResult: (_) => results++);
      await tester.enterText(find.byType(TextFormField), 'Belum disimpan');
      Future<void> cancel() async {
        if (mode == 'Back') {
          await tester.binding.handlePopRoute();
        } else if (mode == 'outside') {
          await tester.tapAt(const Offset(5, 5));
        } else {
          await tester.tap(find.text('Batal'));
        }
        await tester.pumpAndSettle();
      }

      await cancel();
      expect(find.text('Batalkan perubahan?'), findsOneWidget);
      expect(results, 0);
      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          'Belum disimpan');
      await cancel();
      await tester.tap(find.text('Ya, batalkan'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(results, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'guarded sheet disables drag; saving result never asks to discard',
      (tester) async {
    String? result;
    await _openSheet(tester, onResult: (value) => result = value);
    await tester.enterText(find.byType(TextFormField), 'Tersimpan');
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
        isFalse);
    await tester.drag(find.byType(BottomSheet), const Offset(0, 450));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(result, 'Tersimpan');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back during write does not compete with discard confirmation',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var results = 0;
    await _openSheet(tester, container: container, onResult: (_) => results++);
    await tester.enterText(find.byType(TextFormField), 'Tetap ada');
    container.read(navigationWritesProvider.notifier).state = 1;
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(results, 0);
    container.read(navigationWritesProvider.notifier).state = 0;
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Batalkan perubahan?'), findsOneWidget);
    await tester.tap(find.text('Ya, batalkan'));
    await tester.pumpAndSettle();
    expect(results, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dropdown-only changes in a nested builder are checked at Back time',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () {
                            var changed = false;
                            showSafeModalBottomSheet<void>(
                              context: context,
                              hasUnsavedChanges: () => changed,
                              builder: (_) => StatefulBuilder(
                                  builder: (_, setState) => SwitchListTile(
                                        title: const Text('Pilihan draft'),
                                        value: changed,
                                        onChanged: (value) =>
                                            setState(() => changed = value),
                                      )),
                            );
                          },
                          child: const Text('Buka')),
                    )))));
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Batalkan perubahan?'), findsOneWidget);
    await tester.tap(find.text('Ya, batalkan'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
