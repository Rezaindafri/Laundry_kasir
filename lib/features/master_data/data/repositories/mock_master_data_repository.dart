import 'package:uuid/uuid.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../../domain/repositories/master_data_repository.dart';

/// Sumber data sementara yang sengaja berada di repository. UI dapat tetap
/// digunakan saat backend Laravel belum tersedia dan dapat ditukar tanpa
/// mengubah domain maupun presentation layer.
class MockMasterDataRepository implements MasterDataRepository {
  final _uuid = const Uuid();
  final List<CustomerEntity> _customers = [
    const CustomerEntity(
        id: 'cust-001',
        name: 'Andi Pratama',
        phone: '081234567890',
        address: 'Jl. Melati No. 12',),
    const CustomerEntity(
        id: 'cust-002', name: 'Dewi Lestari', phone: '081298765432',),
  ];
  final List<LaundryServiceEntity> _services = [
    const LaundryServiceEntity(
        id: 'svc-001',
        name: 'Cuci Lipat',
        price: 7000,
        estimatedHours: 48,
        pricingType: PricingType.perKg,),
    const LaundryServiceEntity(
        id: 'svc-002',
        name: 'Cuci Setrika',
        price: 9000,
        estimatedHours: 48,
        pricingType: PricingType.perKg,),
    const LaundryServiceEntity(
        id: 'svc-003',
        name: 'Setrika',
        price: 6000,
        estimatedHours: 24,
        pricingType: PricingType.perKg,),
    const LaundryServiceEntity(
        id: 'svc-004',
        name: 'Dry Cleaning',
        price: 25000,
        estimatedHours: 72,
        pricingType: PricingType.perItem,),
  ];

  @override
  Future<Result<List<CustomerEntity>>> getCustomers() async =>
      Success(List.unmodifiable(_customers));

  @override
  Future<Result<CustomerEntity>> saveCustomer(CustomerEntity customer) async {
    final item = customer.id.isEmpty
        ? CustomerEntity(
            id: _uuid.v4(),
            name: customer.name,
            phone: customer.phone,
            address: customer.address,
            notes: customer.notes,)
        : customer;
    final index = _customers.indexWhere((value) => value.id == item.id);
    if (index < 0) {
      _customers.add(item);
    } else {
      _customers[index] = item;
    }
    return Success(item);
  }

  @override
  Future<Result<List<LaundryServiceEntity>>> getServices() async =>
      Success(List.unmodifiable(_services));

  @override
  Future<Result<LaundryServiceEntity>> saveService(
      LaundryServiceEntity service,) async {
    final item = service.id.isEmpty
        ? LaundryServiceEntity(
            id: _uuid.v4(),
            name: service.name,
            price: service.price,
            estimatedHours: service.estimatedHours,
            pricingType: service.pricingType,
            isActive: service.isActive,)
        : service;
    final index = _services.indexWhere((value) => value.id == item.id);
    if (index < 0) {
      _services.add(item);
    } else {
      _services[index] = item;
    }
    return Success(item);
  }
}
