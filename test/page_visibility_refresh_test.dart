import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/widgets/page_visibility_refresh.dart';

void main() {
  testWidgets(
      'refresh occurs on page return, not sheet/dialog dismissal or rebuild',
      (tester) async {
    var refreshed = 0;
    var covered = 0;
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [pageRefreshObserver],
        home: PageVisibilityRefresh(
            onVisible: () async => refreshed++,
            onCovered: () => covered++,
            child: Builder(
                builder: (context) => Scaffold(
                        body: Column(children: [
                      TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              builder: (_) => const SizedBox(
                                  height: 100, child: Text('Popup'))),
                          child: const Text('Sheet')),
                      TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const AlertDialog(content: Text('Dialog'))),
                          child: const Text('Buka dialog')),
                      TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const Scaffold(
                                      body: Text('Halaman kedua')))),
                          child: const Text('Halaman')),
                    ]))))));
    await tester.pumpAndSettle();
    for (final name in ['Sheet', 'Buka dialog']) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(refreshed, 0);
      expect(covered, 0);
    }
    await tester.tap(find.text('Halaman'));
    await tester.pumpAndSettle();
    expect(covered, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cached first activation refreshes once and retains draft controller',
      (tester) async {
    var refreshed = 0;
    final draft = TextEditingController(text: 'Input belum disimpan');
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [pageRefreshObserver],
        home: PageVisibilityRefresh(
            refreshOnMount: true,
            onVisible: () async => refreshed++,
            child: Builder(
                builder: (context) => Scaffold(
                        body: Column(children: [
                      TextField(controller: draft),
                      TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const Scaffold(body: Text('Lain')))),
                          child: const Text('Pindah')),
                    ]))))));
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    await tester.tap(find.text('Pindah'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(refreshed, 2);
    expect(draft.text, 'Input belum disimpan');
    await tester.pumpWidget(const SizedBox.shrink());
    draft.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refresh exception does not crash navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [pageRefreshObserver],
        home: PageVisibilityRefresh(
            refreshOnMount: true,
            onVisible: () async => throw StateError('fixture offline'),
            child: const Scaffold(body: Text('Data sebelumnya')))));
    await tester.pumpAndSettle();
    expect(find.text('Data sebelumnya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
