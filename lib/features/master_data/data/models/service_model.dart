import '../../domain/entities/laundry_service_entity.dart';

class ServiceModel {
  final String id;
  final String name;
  final double price;
  final String unit;
  final int estimationHours;
  final String estimationUnit;

  const ServiceModel(
      {required this.id,
      required this.name,
      required this.price,
      required this.unit,
      required this.estimationHours,
      this.estimationUnit = 'hours'});

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        unit: json['unit']?.toString() ?? '',
        estimationHours:
            int.tryParse(json['estimation_hours']?.toString() ?? '') ?? 0,
        estimationUnit: json['estimation_unit']?.toString() ?? 'hours',
      );

  LaundryServiceEntity toEntity() => LaundryServiceEntity(
      id: id,
      name: name,
      price: price,
      unit: unit,
      estimatedHours: estimationHours,
      estimateUnit: estimationUnit == 'days'
          ? EstimateDurationUnit.days
          : EstimateDurationUnit.hours);

  static Map<String, dynamic> toRequest(LaundryServiceEntity entity) => {
        'name': entity.name,
        'price': entity.price,
        'unit': entity.unit,
        'estimation_hours': entity.estimatedDurationInHours,
      };
}
