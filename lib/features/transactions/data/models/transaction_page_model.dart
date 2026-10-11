import '../../domain/entities/transaction_page_entity.dart';
import 'transaction_model.dart';

class TransactionPageModel {
  final List<TransactionModel> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const TransactionPageModel({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory TransactionPageModel.fromResponse(Map<String, dynamic> response) {
    final data = response['data'] as List<dynamic>? ?? const [];
    final meta = Map<String, dynamic>.from(response['meta'] as Map? ?? {});
    return TransactionPageModel(
      items: data
          .whereType<Map>()
          .map((item) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }

  TransactionPageEntity toEntity() => TransactionPageEntity(
        items: items.map((item) => item.toEntity()).toList(),
        currentPage: currentPage,
        lastPage: lastPage,
        total: total,
      );
}
