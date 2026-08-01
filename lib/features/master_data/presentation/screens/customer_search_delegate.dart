import 'package:flutter/material.dart';

import '../../domain/entities/customer_entity.dart';

class CustomerSearchDelegate extends SearchDelegate<CustomerEntity?> {
  final List<CustomerEntity> customers;
  CustomerSearchDelegate(this.customers);
  @override
  List<Widget>? buildActions(BuildContext context) => [
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

  Widget _list(BuildContext context) {
    final needle = query.toLowerCase();
    final results = customers
        .where((item) => '${item.name} ${item.phone ?? ''} ${item.address ?? ''}'
            .toLowerCase()
            .contains(needle))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, index) {
        final customer = results[index];
        return ListTile(
          title: Text(customer.name),
          subtitle: Text(customer.phone ?? 'Tanpa nomor HP'),
          onTap: () => close(context, customer),
        );
      },
    );
  }
}