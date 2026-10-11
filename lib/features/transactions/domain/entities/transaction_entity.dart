import 'package:equatable/equatable.dart';

enum LaundryStatus {
  received,
  washing,
  drying,
  ironing,
  completed,
  collected,
  late
}

enum PaymentMethod { cash, qris, transfer }

enum PaymentStatus { unpaid, downPayment, paid }

extension LaundryStatusLabel on LaundryStatus {
  String get label => switch (this) {
        LaundryStatus.received => 'Diterima',
        LaundryStatus.washing => 'Dicuci',
        LaundryStatus.drying => 'Dikeringkan',
        LaundryStatus.ironing => 'Disetrika',
        LaundryStatus.completed => 'Selesai',
        LaundryStatus.collected => 'Sudah Diambil',
        LaundryStatus.late => 'Telat',
      };
}

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Tunai',
        PaymentMethod.qris => 'QRIS',
        PaymentMethod.transfer => 'Transfer',
      };
}

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.unpaid => 'Belum Bayar',
        PaymentStatus.downPayment => 'DP',
        PaymentStatus.paid => 'Lunas',
      };
}

class TransactionEntity extends Equatable {
  final String id;
  final String invoice;
  final String customerId;
  final String? serviceId;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final double quantity;
  final String quantityUnit;
  final int unitPrice;
  final int expressFee;
  final int total;
  final int paidAmount;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final LaundryStatus laundryStatus;
  final DateTime createdAt;
  final DateTime estimatedFinishAt;
  final String? notes;
  final bool hasProofImage;
  final bool hasEstimatedFinish;
  final List<TransactionLineEntity> details;

  const TransactionEntity({
    required this.id,
    required this.invoice,
    required this.customerId,
    this.serviceId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.quantity,
    required this.quantityUnit,
    required this.unitPrice,
    required this.expressFee,
    required this.total,
    required this.paidAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.laundryStatus,
    required this.createdAt,
    required this.estimatedFinishAt,
    this.notes,
    this.hasProofImage = false,
    this.hasEstimatedFinish = true,
    this.details = const [],
  });

  int get remainingPayment => total - paidAmount;

  List<TransactionLineEntity> get serviceLines => details.isNotEmpty
      ? details
      : [
          TransactionLineEntity(
              id: '',
              serviceId: serviceId ?? '',
              name: serviceName,
              quantity: quantity,
              unit: quantityUnit,
              unitPrice: unitPrice,
              subtotal: total,
              expressFee: expressFee,
              estimatedFinishAt: hasEstimatedFinish ? estimatedFinishAt : null,
              status: laundryStatus,
              hasProofImage: hasProofImage),
        ];
  String get serviceSummary =>
      serviceLines.map((line) => line.name).join(' + ');
  bool get hasReadyItems => serviceLines.any((line) => line.isReady);
  bool get isProcessing =>
      serviceLines.any((line) => !line.isReady && !line.isCollected);
  int minimumPaymentFor(Iterable<TransactionLineEntity> selected) {
    final chosen = selected.toList();
    final remaining = serviceLines.where((line) => !line.isCollected).length;
    final required = chosen.length == remaining
        ? total
        : serviceLines
                .where((line) => line.isCollected)
                .fold<int>(0, (sum, line) => sum + line.subtotal) +
            chosen.fold<int>(0, (sum, line) => sum + line.subtotal);
    return (required - paidAmount)
        .clamp(0, remainingPayment.clamp(0, total))
        .toInt();
  }

  LaundryStatus resolveLaundryStatusAt(DateTime currentTime) {
    return laundryStatus;
  }

  TransactionEntity copyWith({
    int? paidAmount,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    LaundryStatus? laundryStatus,
    String? notes,
    bool? hasProofImage,
  }) =>
      TransactionEntity(
        id: id,
        invoice: invoice,
        customerId: customerId,
        serviceId: serviceId,
        customerName: customerName,
        customerPhone: customerPhone,
        serviceName: serviceName,
        quantity: quantity,
        quantityUnit: quantityUnit,
        unitPrice: unitPrice,
        expressFee: expressFee,
        total: total,
        paidAmount: paidAmount ?? this.paidAmount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        laundryStatus: laundryStatus ?? this.laundryStatus,
        createdAt: createdAt,
        estimatedFinishAt: estimatedFinishAt,
        notes: notes ?? this.notes,
        hasProofImage: hasProofImage ?? this.hasProofImage,
        hasEstimatedFinish: hasEstimatedFinish,
        details: details,
      );

  @override
  List<Object?> get props => [
        id,
        invoice,
        customerId,
        total,
        paidAmount,
        paymentStatus,
        laundryStatus,
        hasProofImage,
        hasEstimatedFinish,
        details,
      ];
}

class TransactionLineEntity extends Equatable {
  final String id;
  final String serviceId;
  final String name;
  final double quantity;
  final String unit;
  final int unitPrice;
  final int subtotal;
  final int expressFee;
  final DateTime? estimatedFinishAt;
  final LaundryStatus status;
  final DateTime? collectedAt;
  final bool hasProofImage;
  final bool hasKnownTiming;

  const TransactionLineEntity(
      {required this.id,
      required this.serviceId,
      required this.name,
      required this.quantity,
      required this.unit,
      required this.unitPrice,
      required this.subtotal,
      this.expressFee = 0,
      this.estimatedFinishAt,
      this.status = LaundryStatus.received,
      this.collectedAt,
      this.hasProofImage = false,
      this.hasKnownTiming = true});

  bool get isCollected => status == LaundryStatus.collected;
  bool get isReady =>
      status == LaundryStatus.completed || status == LaundryStatus.late;

  @override
  List<Object?> get props => [
        id,
        serviceId,
        name,
        quantity,
        unit,
        unitPrice,
        subtotal,
        expressFee,
        estimatedFinishAt,
        status,
        collectedAt,
        hasProofImage,
        hasKnownTiming
      ];
}
