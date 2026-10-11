import '../../domain/entities/transaction_entity.dart';

class TransactionDetailModel {
  final int id;
  final int serviceId;
  final String? serviceName;
  final String? serviceUnit;
  final double qty;
  final double price;
  final double? subtotal;
  final double expressFee;
  final DateTime? estimatedFinishAt;
  final LaundryStatus status;
  final DateTime? collectedAt;
  final bool hasProofImage;
  final bool timingConfigured;

  const TransactionDetailModel({
    required this.id,
    required this.serviceId,
    this.serviceName,
    this.serviceUnit,
    required this.qty,
    required this.price,
    this.subtotal,
    this.expressFee = 0,
    this.estimatedFinishAt,
    this.status = LaundryStatus.received,
    this.collectedAt,
    this.hasProofImage = false,
    this.timingConfigured = false,
  });

  factory TransactionDetailModel.fromJson(Map<String, dynamic> json) {
    final service = json['service'] is Map<String, dynamic>
        ? json['service'] as Map<String, dynamic>
        : null;

    return TransactionDetailModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      serviceId: int.tryParse(json['service_id']?.toString() ?? '') ?? 0,
      serviceName:
          json['service_name']?.toString() ?? service?['name']?.toString(),
      serviceUnit:
          json['service_unit']?.toString() ?? service?['unit']?.toString(),
      qty: _readNum(json['qty']) ?? 0.0,
      price: _readNum(json['price']) ?? 0.0,
      subtotal: _readNum(json['subtotal']),
      expressFee: _readNum(json['express_fee']) ?? 0,
      estimatedFinishAt:
          DateTime.tryParse(json['estimated_finish_at']?.toString() ?? ''),
      status: LaundryStatus.values.firstWhere(
          (value) => value.name == json['laundry_status'],
          orElse: () => json['is_collected'] == true
              ? LaundryStatus.collected
              : LaundryStatus.received),
      collectedAt: DateTime.tryParse(json['collected_at']?.toString() ?? ''),
      hasProofImage: json['has_proof_image'] == true,
      timingConfigured: json['timing_configured'] == true ||
          (json['timing_configured'] == null &&
              json['estimated_finish_at'] != null),
    );
  }

  TransactionLineEntity toEntity() => TransactionLineEntity(
      id: id.toString(),
      serviceId: serviceId.toString(),
      name: serviceName ?? 'Layanan',
      quantity: qty,
      unit: serviceUnit ?? 'kg',
      unitPrice: price.round(),
      subtotal: (subtotal ?? qty * price + expressFee).round(),
      expressFee: expressFee.round(),
      estimatedFinishAt: estimatedFinishAt,
      status: status,
      collectedAt: collectedAt,
      hasProofImage: hasProofImage,
      hasKnownTiming: timingConfigured);

  Map<String, dynamic> toJson({bool forRequest = true}) => {
        'service_id': serviceId,
        'qty': qty,
        'price': price,
        'express': expressFee > 0,
        if (!forRequest) ...{
          'id': id,
          'service_name': serviceName,
          'service_unit': serviceUnit,
          'subtotal': subtotal ?? qty * price + expressFee,
          'express_fee': expressFee,
          'estimated_finish_at': estimatedFinishAt?.toUtc().toIso8601String(),
          'laundry_status': status.name,
          'collected_at': collectedAt?.toUtc().toIso8601String(),
          'has_proof_image': hasProofImage,
          'timing_configured': timingConfigured,
        },
      };
}

double? _readNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}
