class TransactionDetailModel {
  final int id;
  final int serviceId;
  final String? serviceName;
  final String? serviceUnit;
  final double qty;
  final double price;

  const TransactionDetailModel({
    required this.id,
    required this.serviceId,
    this.serviceName,
    this.serviceUnit,
    required this.qty,
    required this.price,
  });

  factory TransactionDetailModel.fromJson(Map<String, dynamic> json) {
    final service = json['service'] is Map<String, dynamic>
        ? json['service'] as Map<String, dynamic>
        : null;

    return TransactionDetailModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      serviceId: int.tryParse(json['service_id']?.toString() ?? '') ?? 0,
      serviceName: json['service_name']?.toString() ??
          service?['name']?.toString(),
      serviceUnit: json['service_unit']?.toString() ??
          service?['unit']?.toString(),
      qty: _readNum(json['qty']) ?? 0.0,
      price: _readNum(json['price']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'service_id': serviceId,
        'qty': qty,
        'price': price,
      };
}

double? _readNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}
