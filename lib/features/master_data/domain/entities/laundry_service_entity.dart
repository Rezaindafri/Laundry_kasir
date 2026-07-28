import 'package:equatable/equatable.dart';

enum PricingType { perKg, perItem }

class LaundryServiceEntity extends Equatable {
  final String id;
  final String name;
  final int price;
  final int estimatedHours;
  final PricingType pricingType;
  final bool isActive;

  const LaundryServiceEntity({
    required this.id,
    required this.name,
    required this.price,
    required this.estimatedHours,
    required this.pricingType,
    this.isActive = true,
  });

  String get pricingLabel =>
      pricingType == PricingType.perKg ? 'Per Kg' : 'Per Item';

  LaundryServiceEntity copyWith({
    String? name,
    int? price,
    int? estimatedHours,
    PricingType? pricingType,
    bool? isActive,
  }) =>
      LaundryServiceEntity(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        pricingType: pricingType ?? this.pricingType,
        isActive: isActive ?? this.isActive,
      );

  @override
  List<Object?> get props =>
      [id, name, price, estimatedHours, pricingType, isActive];
}
