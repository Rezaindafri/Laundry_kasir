import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';

class _AuditEntry {
  final String action;
  final String subjectType;
  final String subjectId;
  final String actor;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  const _AuditEntry({
    required this.action,
    required this.subjectType,
    required this.subjectId,
    required this.actor,
    required this.createdAt,
    required this.metadata,
  });

  factory _AuditEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    final metadata = json['metadata'];
    return _AuditEntry(
      action: json['action']?.toString() ?? '-',
      subjectType: json['subject_type']?.toString() ?? '-',
      subjectId: json['subject_id']?.toString() ?? '-',
      actor: actor is Map
          ? '${actor['name']?.toString() ?? 'Sistem'}'
              '${actor['role'] == null ? '' : ' (${actor['role']})'}'
          : 'Sistem',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> get before => _object(metadata['before']);
  Map<String, dynamic> get after => _object(metadata['after']);

  String get subjectLabel {
    final snapshot = after.isNotEmpty ? after : before;
    if (subjectType == 'transaction') {
      return 'Transaksi ${snapshot['invoice_number']?.toString() ?? '#$subjectId'}';
    }
    if (subjectType == 'user') {
      final username = snapshot['username']?.toString();
      return username == null || username.isEmpty
          ? 'Akun #$subjectId'
          : 'Akun @$username';
    }
    if (subjectType == 'expense') {
      return 'Pengeluaran ${snapshot['category']?.toString() ?? '#$subjectId'}';
    }
    return '$subjectType #$subjectId';
  }
}

class _AuditLogPage {
  final List<_AuditEntry> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const _AuditLogPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

final _auditLogsProvider =
    FutureProvider.family<_AuditLogPage, int>((ref, page) async {
  // Menjamin data audit dimuat ulang saat akun Owner berganti.
  ref.watch(currentSessionUserIdProvider);
  try {
    final response = await DioClient().dio.get(
      ApiEndpoints.auditLogs,
      queryParameters: {'per_page': 30, 'page': page},
    );
    final payload = response.data;
    final rows = payload is Map && payload['data'] is List
        ? payload['data'] as List
        : const <dynamic>[];
    final meta = payload is Map && payload['meta'] is Map
        ? Map<String, dynamic>.from(payload['meta'] as Map)
        : const <String, dynamic>{};
    return _AuditLogPage(
      items: rows
          .whereType<Map>()
          .map((row) => _AuditEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
    );
  } on DioException catch (error) {
    throw Exception(error.response?.data is Map
        ? error.response?.data['message']?.toString() ?? 'Gagal memuat audit.'
        : 'Gagal memuat audit.');
  }
});

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  int _page = 1;

  Future<void> _refresh() async {
    setState(() => _page = 1);
    await ref.refresh(_auditLogsProvider(1).future);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final logs = ref.watch(_auditLogsProvider(_page));
    return Scaffold(
      drawer: user == null ? null : AppNavigationDrawer(user: user),
      appBar: AppBar(title: const Text('Riwayat Perubahan')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 180),
              Center(child: Text('Gagal memuat riwayat: $error')),
            ],
          ),
          data: (data) => data.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('Belum ada perubahan tercatat.')),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${data.total} perubahan tercatat',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    for (final entry in data.items) ...[
                      _AuditTile(
                        entry: entry,
                        onTap: () => _showDetails(context, entry),
                      ),
                      const Divider(height: 1),
                    ],
                    if (data.lastPage > 1) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: data.currentPage <= 1
                                  ? null
                                  : () => setState(() => _page--),
                              child: const Text('Sebelumnya'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('${data.currentPage}/${data.lastPage}'),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: data.currentPage >= data.lastPage
                                  ? null
                                  : () => setState(() => _page++),
                              child: const Text('Berikutnya'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final _AuditEntry entry;
  final VoidCallback onTap;

  const _AuditTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(entry.subjectType == 'transaction'
            ? Icons.receipt_long_outlined
            : entry.subjectType == 'expense'
                ? Icons.trending_down_outlined
                : Icons.manage_accounts_outlined),
        title: Text(_actionLabel(entry.action)),
        subtitle: Text(
          '${entry.subjectLabel}\n${entry.actor} • ${_dateLabel(entry.createdAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

void _showDetails(BuildContext context, _AuditEntry entry) {
  final changes = _changes(entry.before, entry.after);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.35,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(_actionLabel(entry.action),
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(entry.subjectLabel),
            Text('${entry.actor} • ${_dateLabel(entry.createdAt)}'),
            const SizedBox(height: 20),
            Text('Perubahan',
                style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (changes.isEmpty)
              const Text('Nilai rinci tidak tersedia untuk perubahan ini.')
            else
              for (final change in changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(change.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${change.before ?? '-'} → ${change.after ?? '-'}'),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class _AuditChange {
  final String label;
  final String? before;
  final String? after;

  const _AuditChange(this.label, this.before, this.after);
}

List<_AuditChange> _changes(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  const labels = {
    'invoice_number': 'Invoice',
    'customer_id': 'Pelanggan',
    'cashier_id': 'Penanggung jawab transaksi',
    'total_price': 'Total tagihan',
    'paid_amount': 'Nominal dibayar',
    'payment_status': 'Status pembayaran',
    'payment_method': 'Metode pembayaran',
    'laundry_status': 'Status laundry',
    'order_status': 'Status pesanan',
    'estimated_finish_at': 'Estimasi selesai',
    'details': 'Layanan dan pengambilan',
    'name': 'Nama',
    'username': 'Username',
    'email': 'Email',
    'role': 'Role',
    'owner_id': 'Owner penanggung jawab',
    'is_active': 'Status aktif',
    'amount': 'Nominal',
    'category': 'Kategori',
    'description': 'Keterangan',
    'occurred_at': 'Waktu pengeluaran',
  };
  final keys = {...before.keys, ...after.keys};
  return keys
      .where(labels.containsKey)
      .map((key) => _AuditChange(
            labels[key]!,
            before.containsKey(key) ? _auditDisplay(before[key]) : null,
            after.containsKey(key) ? _auditDisplay(after[key]) : null,
          ))
      .where((change) => change.before != change.after)
      .toList();
}

String? _auditDisplay(dynamic value) {
  if (value is! List) return value?.toString();
  return value
      .whereType<Map>()
      .map((line) =>
          '${line['service_name'] ?? 'Layanan'} (#${line['id']}): ${line['qty']} ${line['service_unit'] ?? ''}; '
          'harga ${line['price']}; subtotal ${line['subtotal']}; '
          '${line['is_collected'] == true ? 'Sudah diambil' : 'Belum diambil'}'
          '${line['collected_at'] == null ? '' : ' · ${_dateLabel(DateTime.tryParse(line['collected_at'].toString()))}'}')
      .join('\n');
}

Map<String, dynamic> _object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

String _dateLabel(DateTime? value) => value == null
    ? 'Waktu tidak tersedia'
    : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value.toLocal());

String _actionLabel(String action) => switch (action) {
      'transaction.created' => 'Transaksi dibuat',
      'transaction.updated' => 'Transaksi diperbarui',
      'transaction.status_updated' => 'Status laundry diperbarui',
      'transaction.payment_recorded' => 'Pembayaran dicatat',
      'transaction.collected' => 'Laundry diambil',
      'transaction.partially_collected' => 'Sebagian layanan diambil',
      'transaction.proof_uploaded_and_collected' =>
        'Bukti pengambilan diunggah',
      'transaction.deleted' => 'Transaksi dihapus',
      'transaction.status_synchronized' => 'Status diperbarui otomatis',
      'user.created' => 'Akun dibuat',
      'user.updated' => 'Akun diperbarui',
      'user.credentials_updated' => 'Kredensial akun diperbarui',
      'user.status_toggled' => 'Status akun diubah',
      'user.deleted' => 'Akun dihapus',
      'user.profile_updated' => 'Profil akun diperbarui',
      'user.password_changed' => 'Password akun diubah',
      'expense.created' => 'Pengeluaran dicatat',
      'expense.updated' => 'Pengeluaran diperbarui',
      'expense.deleted' => 'Pengeluaran dihapus',
      _ => action,
    };
