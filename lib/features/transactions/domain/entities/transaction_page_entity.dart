import 'transaction_entity.dart';

class TransactionPageEntity {
  final List<TransactionEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const TransactionPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}
