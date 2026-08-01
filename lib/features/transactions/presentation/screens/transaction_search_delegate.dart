import 'package:flutter/material.dart';

import '../../domain/entities/transaction_entity.dart';
import 'transactions_screen.dart';

class TransactionSearchDelegate extends SearchDelegate<void> {
  final List<TransactionEntity> transactions;
  TransactionSearchDelegate(this.transactions);
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
    final matches = transactions
        .where(
          (item) =>
              '${item.invoice} ${item.customerName} ${item.customerPhone} ${item.serviceName}'
                  .toLowerCase()
                  .contains(needle),
        )
        .toList();
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (_, index) {
        final item = matches[index];
        return ListTile(
          title: Text(item.customerName),
          subtitle: Text(item.invoice),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(transaction: item),
              ),
            );
          },
        );
      },
    );
  }
}
