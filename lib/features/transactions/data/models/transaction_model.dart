import '../../domain/entities/transaction_entity.dart';
import 'transaction_detail_model.dart';

class TransactionModel {
  final int id;
  final String invoice;
  final int customerId;
  final int serviceId;
  final String? customerName;
  final String? customerPhone;
  final String? serviceName;
  final double quantity;
  final String quantityUnit;
  final double unitPrice;
  final double expressFee;
  final double total;
  final double paidAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String laundryStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime? estimatedFinishAt;
  final List<TransactionDetailModel> details;
  final bool hasProofImage;

  const TransactionModel({
    required this.id,
    required this.invoice,
    required this.customerId,
    this.serviceId = 0,
    this.customerName,
    this.customerPhone,
    this.serviceName,
    required this.quantity,
    required this.quantityUnit,
    required this.unitPrice,
    required this.expressFee,
    required this.total,
    required this.paidAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.laundryStatus,
    this.notes,
    required this.createdAt,
    this.estimatedFinishAt,
    required this.details,
    this.hasProofImage = false,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final detailsSource = json['details'] ??
        json['transaction_details'] ??
        json['transactionDetails'];
    final detailsJson =
        detailsSource is List ? detailsSource : const <dynamic>[];
    final details = detailsJson
        .whereType<Map<String, dynamic>>()
        .map(TransactionDetailModel.fromJson)
        .toList();
    final firstDetail = details.isNotEmpty ? details.first : null;
    final customer = json['customer'] is Map<String, dynamic>
        ? json['customer'] as Map<String, dynamic>
        : null;
    final service = json['service'] is Map<String, dynamic>
        ? json['service'] as Map<String, dynamic>
        : null;
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    final estimatedFinishAt = json['estimated_finish_at'] != null
        ? DateTime.tryParse(json['estimated_finish_at'].toString())
        : null;
    final estimatedHours = _readNum(service, ['estimation_hours']) ??
        _readNum(_firstDetailService(json), ['estimation_hours']);
    final estimateUnit = _readString(service, ['estimation_unit']) ??
        _readString(_firstDetailService(json), ['estimation_unit']);
    final normalizedEstimatedHours =
        estimateUnit == 'days' && estimatedHours != null
            ? estimatedHours.round() * 24
            : estimatedHours?.round();

    return TransactionModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      invoice: _readString(json, ['invoice', 'invoice_number']) ?? '',
      customerId: int.tryParse(json['customer_id']?.toString() ?? '') ?? 0,
      serviceId: int.tryParse(json['service_id']?.toString() ?? '') ??
          firstDetail?.serviceId ??
          0,
      customerName: _readString(json, ['customer_name', 'customerName']) ??
          _readString(customer, ['name', 'full_name', 'customer_name']),
      customerPhone: _readString(json, ['customer_phone', 'customerPhone']) ??
          _readString(customer, ['phone', 'phone_number']),
      serviceName: _readString(json, ['service_name', 'serviceName']) ??
          _readString(service, ['name', 'service_name']) ??
          firstDetail?.serviceName,
      quantity: (_readNum(json, ['quantity', 'qty', 'weight']) ??
              firstDetail?.qty ??
              0.0)
          .toDouble(),
      quantityUnit: _readString(json, ['quantity_unit']) ??
          _readString(service, ['unit']) ??
          firstDetail?.serviceUnit ??
          'kg',
      unitPrice: (_readNum(json, ['unit_price', 'price', 'service_price']) ??
              firstDetail?.price ??
              0.0)
          .toDouble(),
      expressFee:
          (_readNum(json, ['express_fee', 'expressFee']) ?? 0.0).toDouble(),
      total:
          (_readNum(json, ['total', 'grand_total', 'amount', 'total_price']) ??
                  0.0)
              .toDouble(),
      paidAmount: (_readNum(json, ['paid_amount', 'paidAmount']) ??
              ((_readString(json, ['payment_status']) == 'paid')
                  ? (_readNum(json,
                          ['total', 'grand_total', 'amount', 'total_price']) ??
                      0.0)
                  : 0.0))
          .toDouble(),
      paymentMethod: _readString(json, ['payment_method']) ?? 'cash',
      paymentStatus: _mapPaymentStatus(
        _readString(json, ['payment_status']) ?? 'unpaid',
      ),
      laundryStatus: _mapLaundryStatus(
        _readString(json, ['laundry_status', 'order_status']) ?? 'received',
      ),
      notes: json['notes']?.toString(),
      createdAt: createdAt,
      estimatedFinishAt: estimatedFinishAt ??
          (normalizedEstimatedHours != null
              ? createdAt.add(Duration(hours: normalizedEstimatedHours))
              : null),
      details: details,
      hasProofImage: json['has_proof_image'] == true ||
          (json['has_proof_image'] == null &&
              (json['proof_image_path']?.toString().isNotEmpty ?? false)),
    );
  }

  TransactionEntity toEntity() => TransactionEntity(
        id: id.toString(),
        invoice: invoice,
        customerId: customerId.toString(),
        serviceId: serviceId.toString(),
        customerName: customerName ?? '',
        customerPhone: customerPhone ?? '',
        serviceName: serviceName ?? '',
        quantity: quantity,
        quantityUnit: quantityUnit,
        unitPrice: unitPrice.round(),
        expressFee: expressFee.round(),
        total: total.round(),
        paidAmount: paidAmount.round(),
        paymentMethod: PaymentMethod.values.firstWhere(
          (value) => value.name == paymentMethod,
          orElse: () => PaymentMethod.cash,
        ),
        paymentStatus: PaymentStatus.values.firstWhere(
          (value) => value.name == paymentStatus,
          orElse: () => PaymentStatus.unpaid,
        ),
        laundryStatus: LaundryStatus.values.firstWhere(
          (value) => value.name == laundryStatus,
          orElse: () => LaundryStatus.received,
        ),
        createdAt: createdAt,
        estimatedFinishAt: estimatedFinishAt ?? createdAt,
        notes: notes,
        hasProofImage: hasProofImage,
      );

  Map<String, dynamic> toJson({required bool forRequest}) {
    if (forRequest) {
      return {
        'customer_id': customerId,
        'payment_status': paymentStatus,
        'payment_method': paymentMethod,
        'paid_amount': paidAmount,
        'estimated_finish_at': estimatedFinishAt?.toUtc().toIso8601String(),
        'notes': notes,
        'services': [
          {
            'service_id': serviceId,
            'qty': quantity,
            'price': unitPrice,
          },
        ],
      };
    }

    return {
      'id': id,
      'invoice': invoice,
      'invoice_number': invoice,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'service_name': serviceName,
      'quantity': quantity,
      'quantity_unit': quantityUnit,
      'unit_price': unitPrice,
      'express_fee': expressFee,
      'total': total,
      'total_price': total,
      'paid_amount': paidAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'laundry_status': laundryStatus,
      'order_status': _mapOrderStatus(laundryStatus),
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'estimated_finish_at': estimatedFinishAt?.toUtc().toIso8601String(),
      'has_proof_image': hasProofImage,
      'details': details.map((item) => item.toJson()).toList(),
      'transaction_details': details.map((item) => item.toJson()).toList(),
    };
  }
}

String? _readString(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) return null;
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    if (value != null && value.toString().trim().isNotEmpty)
      return value.toString();
  }
  return null;
}

num? _readNum(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) return null;
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value;
    if (value is String && value.trim().isNotEmpty) {
      return num.tryParse(value);
    }
  }
  return null;
}

Map<String, dynamic>? _firstDetailService(Map<String, dynamic> json) {
  final detailsSource = json['details'] ??
      json['transaction_details'] ??
      json['transactionDetails'];
  if (detailsSource is! List) return null;
  for (final item in detailsSource) {
    if (item is Map<String, dynamic> &&
        item['service'] is Map<String, dynamic>) {
      return item['service'] as Map<String, dynamic>;
    }
  }
  return null;
}

String _mapPaymentStatus(String value) {
  switch (value) {
    case 'paid':
      return 'paid';
    case 'dp':
    case 'down_payment':
    case 'downPayment':
      return 'downPayment';
    default:
      return 'unpaid';
  }
}

String _mapLaundryStatus(String value) {
  switch (value) {
    case 'new':
    case 'received':
      return 'received';
    case 'processing':
    case 'washing':
      return 'washing';
    case 'drying':
      return 'drying';
    case 'ironing':
      return 'ironing';
    case 'delivered':
    case 'collected':
      return 'collected';
    case 'completed':
      return 'completed';
    case 'late':
      return 'late';
    default:
      return 'received';
  }
}

String _mapOrderStatus(String value) {
  switch (value) {
    case 'washing':
    case 'drying':
    case 'ironing':
      return 'processing';
    case 'completed':
      return 'completed';
    case 'collected':
      return 'delivered';
    default:
      return 'new';
  }
}
