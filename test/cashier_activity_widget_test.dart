import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/network/dio_client.dart';
import 'package:laundry_management_system/features/audit/presentation/screens/audit_logs_screen.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('cashier preview labels each action and opens deletion details',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final dio = DioClient().dio;
    const cashier = {'name': 'Sari Kasir', 'username': 'sari', 'role': 'kasir'};
    const owner = {'name': 'Pemilik Laundry', 'role': 'owner'};
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        expect(options.path, '/audit-logs');
        expect(options.queryParameters['cashier_activity'], 1);
        expect(options.queryParameters['per_page'], 4);
        handler.resolve(Response(
          requestOptions: options,
          data: {
            'data': [
              {
                'action': 'transaction.deleted',
                'subject_type': 'transaction',
                'subject_id': 1,
                'metadata': {
                  'actor_snapshot': cashier,
                  'before': {'invoice_number': 'INV-HAPUS', 'total_price': 10000},
                  'reason': 'Bon tercatat dua kali',
                },
              },
              {
                'action': 'transaction.created',
                'subject_type': 'transaction',
                'subject_id': 2,
                'actor': cashier,
                'metadata': {'after': {'invoice_number': 'INV-BARU'}},
              },
              {
                'action': 'transaction.service_completed_manually',
                'subject_type': 'transaction',
                'subject_id': 3,
                'actor': owner,
                'metadata': {'after': {'invoice_number': 'INV-OWNER'}},
              },
            ],
          },
        ));
      },
    );
    dio.interceptors.add(interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));

    await tester.pumpWidget(ProviderScope(
      overrides: [currentSessionUserIdProvider.overrideWithValue('owner')],
      child: MaterialApp(
        home: Scaffold(body: CashierActivityCard(onOpen: () {})),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi INV-HAPUS'), findsOneWidget);
    expect(find.textContaining('Transaksi dihapus oleh Sari Kasir (@sari)'), findsOneWidget);
    expect(find.textContaining('Bon tercatat dua kali'), findsOneWidget);
    expect(find.textContaining('Transaksi dibuat oleh Sari Kasir'), findsOneWidget);
    expect(find.textContaining('INV-OWNER'), findsNothing);
    expect(find.textContaining('Layanan diselesaikan manual'), findsNothing);

    await tester.tap(find.text('Transaksi INV-HAPUS'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi dihapus'), findsOneWidget);
    expect(find.text('Alasan: Bon tercatat dua kali'), findsOneWidget);
    expect(find.text('Perubahan'), findsOneWidget);
  });
}
