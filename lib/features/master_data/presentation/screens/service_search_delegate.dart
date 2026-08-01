import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/laundry_service_entity.dart';

class ServiceSearchDelegate extends SearchDelegate<LaundryServiceEntity?> {
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  final List<LaundryServiceEntity> services;

  ServiceSearchDelegate(this.services);

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
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final needle = query.toLowerCase();
    final results = services
        .where((item) =>
            '${item.name} ${item.unit} ${item.price}'.toLowerCase()
                .contains(needle))
        .toList();

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
