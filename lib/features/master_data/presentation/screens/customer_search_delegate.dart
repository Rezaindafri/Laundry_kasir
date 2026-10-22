import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/customer_entity.dart';
import '../providers/master_data_providers.dart';

class CustomerSearchDelegate extends SearchDelegate<CustomerEntity?> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
        Consumer(
          builder: (context, ref, _) => IconButton(
            tooltip: 'Perbarui daftar pelanggan',
            icon: const Icon(Icons.refresh),
            onPressed: ref.watch(customersProvider).isLoading
                ? null
                : () => ref.read(customersProvider.notifier).refresh(),
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
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  // Watch the provider in the search route, not a snapshot taken before its
  // request finishes. Loading/failure must not look like an empty catalogue.
  Widget _list(BuildContext context) => Consumer(
        builder: (context, ref, _) => ref.watch(customersProvider).when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Data pelanggan gagal dimuat.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(customersProvider.notifier).refresh(),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (customers) => _customerList(context, customers),
            ),
      );

  Widget _customerList(BuildContext context, List<CustomerEntity> customers) {
    final needle = query.trim().toLowerCase();
    final results = customers
        .where((item) =>
            '${item.name} ${item.phone ?? ''} ${item.address ?? ''}'
                .toLowerCase()
                .contains(needle))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            customers.isEmpty
                ? 'Pelanggan belum tersedia'
                : 'Pelanggan tidak ditemukan',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, index) {
        final customer = results[index];
        return ListTile(
          title: Text(customer.name),
          subtitle: Text(customer.phone?.trim().isNotEmpty == true
              ? customer.phone!
              : 'Tanpa nomor HP'),
          onTap: () => close(context, customer),
        );
      },
    );
  }
}
