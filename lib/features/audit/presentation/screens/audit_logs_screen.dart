import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';

class _AuditEntry {
  final String action;
  final String subjectType;
  final String actor;
  final DateTime createdAt;

  const _AuditEntry(
      {required this.action,
      required this.subjectType,
      required this.actor,
      required this.createdAt});

  factory _AuditEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    return _AuditEntry(
      action: json['action']?.toString() ?? '-',
      subjectType: json['subject_type']?.toString() ?? '-',
      actor: actor is Map ? actor['name']?.toString() ?? 'Sistem' : 'Sistem',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

final _auditLogsProvider = FutureProvider<List<_AuditEntry>>((ref) async {
  try {
    final response = await DioClient()
        .dio
        .get(ApiEndpoints.auditLogs, queryParameters: const {'per_page': 30});
    final payload = response.data;
    final rows = payload is Map && payload['data'] is List
        ? payload['data'] as List
        : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => _AuditEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  } on DioException catch (error) {
    throw Exception(error.response?.data is Map
        ? error.response?.data['message']?.toString() ?? 'Gagal memuat audit.'
        : 'Gagal memuat audit.');
  }
});

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(_auditLogsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Audit')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_auditLogsProvider.future),
        child: logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(children: [
            const SizedBox(height: 180),
            Center(child: Text('Gagal memuat riwayat: $error'))
          ]),
          data: (items) => items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Belum ada perubahan tercatat.'))
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final entry = items[index];
                    return ListTile(
                      leading: Icon(entry.subjectType == 'transaction'
                          ? Icons.receipt_long_outlined
                          : Icons.manage_accounts_outlined),
                      title: Text(_actionLabel(entry.action)),
                      subtitle: Text(
                          '${entry.actor} • ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(entry.createdAt.toLocal())}'),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _actionLabel(String action) => switch (action) {
        'transaction.created' => 'Transaksi dibuat',
        'transaction.updated' => 'Transaksi diperbarui',
        'transaction.status_updated' => 'Status laundry diperbarui',
        'transaction.payment_recorded' => 'Pembayaran dicatat',
        'transaction.collected' => 'Laundry diambil',
        'transaction.deleted' => 'Transaksi dihapus',
        'transaction.status_synchronized' => 'Status diperbarui otomatis',
        'user.created' => 'Akun dibuat',
        'user.updated' => 'Akun diperbarui',
        'user.status_toggled' => 'Status akun diubah',
        'user.deleted' => 'Akun dihapus',
        _ => action,
      };
}
