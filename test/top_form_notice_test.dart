import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/widgets/top_notice.dart';
import 'package:laundry_management_system/features/auth/presentation/widgets/login_form.dart';

void main() {
  testWidgets('invalid login shows field errors and a single notice at the top',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: LoginForm())))));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('Periksa isian yang ditandai.'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MaterialBanner)).dy, lessThan(100));
    // Close before retrying, since the top banner deliberately overlays header controls.
    await tester.tap(find.byTooltip('Tutup notifikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid form does not show a validation failure or block submit',
      (tester) async {
    final key = GlobalKey<FormState>();
    var submitted = 0;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: Form(
                      key: key,
                      child: Column(children: [
                        TextFormField(
                            initialValue: 'Isi valid',
                            validator: (value) =>
                                value?.isEmpty == true ? 'Wajib diisi' : null),
                        FilledButton(
                            onPressed: () {
                              if (validateFormWithNotice(context, key))
                                submitted++;
                            },
                            child: const Text('Simpan')),
                      ])),
                ))));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(submitted, 1);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
