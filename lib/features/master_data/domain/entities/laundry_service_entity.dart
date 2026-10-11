import 'package:equatable/equatable.dart';

enum PricingType { perKg, perItem }

enum EstimateDurationUnit { hours, days }

class LaundryServiceEntity extends Equatable {
  final String id;
  final String name;
  final double price;
  final String unit;
  final int estimatedHours;
  final EstimateDurationUnit estimateUnit;
  final bool isActive;

  const LaundryServiceEntity(
      {required this.id,
      required this.name,
      required this.price,
      required this.unit,
      required this.estimatedHours,
      this.estimateUnit = EstimateDurationUnit.hours,
      this.isActive = true});

  String get pricingLabel => unit;
  PricingType get pricingType => unit.trim().toLowerCase() == 'kg'
      ? PricingType.perKg
      : PricingType.perItem;
  int get estimatedDurationInHours => estimateUnit == EstimateDurationUnit.days
      ? estimatedHours * 24
      : estimatedHours;
  String get estimatedDurationLabel => estimatedHours == 0
      ? 'Tanpa estimasi'
      : estimateUnit == EstimateDurationUnit.days
          ? '$estimatedHours hari'
          : '$estimatedHours jam';

  LaundryServiceEntity copyWith(
          {String? name,
          double? price,
          String? unit,
          int? estimatedHours,
          EstimateDurationUnit? estimateUnit,
          bool? isActive}) =>
      LaundryServiceEntity(
          id: id,
          name: name ?? this.name,
          price: price ?? this.price,
          unit: unit ?? this.unit,
          estimatedHours: estimatedHours ?? this.estimatedHours,
          estimateUnit: estimateUnit ?? this.estimateUnit,
          isActive: isActive ?? this.isActive);

  @override
  List<Object?> get props =>
      [id, name, price, unit, estimatedHours, estimateUnit, isActive];
}
