import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/laundry_service_entity.dart';
import '../providers/master_data_providers.dart';

class ServiceSearchDelegate extends SearchDelegate<LaundryServiceEntity?> {
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        Consumer(
          builder: (context, ref, _) => IconButton(
            tooltip: 'Perbarui daftar layanan',
            icon: const Icon(Icons.refresh),
            onPressed: ref.watch(laundryServicesProvider).isLoading
                ? null
                : () => ref.read(laundryServicesProvider.notifier).refresh(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) => Consumer(
        builder: (context, ref, _) => ref.watch(laundryServicesProvider).when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Data layanan gagal dimuat.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(laundryServicesProvider.notifier).refresh(),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (services) => _serviceList(
                context,
                services.where((item) => item.isActive).toList(),
              ),
            ),
      );

  Widget _serviceList(
      BuildContext context, List<LaundryServiceEntity> services) {
    final needle = query.trim().toLowerCase();
    final results = services
        .where((item) => '${item.name} ${item.unit} ${item.price}'
            .toLowerCase()
            .contains(needle))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            services.isEmpty
                ? 'Layanan aktif belum tersedia'
                : 'Layanan tidak ditemukan',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, index) {
        final service = results[index];
        return ListTile(
          title: Text(service.name),
          subtitle: Text(
            '${_currency.format(service.price)} / ${service.pricingLabel}',
          ),
          onTap: () => close(context, service),
        );
      },
    );
  }
}
