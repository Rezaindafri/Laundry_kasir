class ExpenseEntry {
  final String id;
  final int amount;
  final String category;
  final String? description;
  final DateTime occurredAt;
  final String? recorderName;

  const ExpenseEntry({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.occurredAt,
    required this.recorderName,
  });

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    final recorder = json['recorder'];
    return ExpenseEntry(
      id: json['id']?.toString() ?? '',
      amount: _asInt(json['amount']),
      category: json['category']?.toString() ?? 'Lainnya',
      description: json['description']?.toString(),
      occurredAt: DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
          DateTime.now(),
      recorderName: recorder is Map ? recorder['name']?.toString() : null,
    );
  }
}

class ExpenseInput {
  final int amount;
  final String category;
  final String? description;
  final DateTime occurredAt;

  const ExpenseInput({
    required this.amount,
    required this.category,
    required this.description,
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() {
    final trimmedDescription = description?.trim();
    return {
      'amount': amount,
      'category': category,
      'description': trimmedDescription == null || trimmedDescription.isEmpty
          ? null
          : trimmedDescription,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    };
  }
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
