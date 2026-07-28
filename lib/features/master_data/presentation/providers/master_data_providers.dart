import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../data/repositories/mock_master_data_repository.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../../domain/repositories/master_data_repository.dart';

final masterDataRepositoryProvider =
    Provider<MasterDataRepository>((ref) => MockMasterDataRepository());

final customersProvider =
    AsyncNotifierProvider<CustomersNotifier, List<CustomerEntity>>(
        CustomersNotifier.new,);

class CustomersNotifier extends AsyncNotifier<List<CustomerEntity>> {
  @override
  Future<List<CustomerEntity>> build() async {
    final result = await ref.read(masterDataRepositoryProvider).getCustomers();
    return result.when(
        success: (data) => data, error: (failure) => throw failure,);
  }

  Future<Result<CustomerEntity>> save(CustomerEntity customer) async {
    final result =
        await ref.read(masterDataRepositoryProvider).saveCustomer(customer);
    result.when(
      success: (item) {
        final items = <CustomerEntity>[...(state.valueOrNull ?? [])];
        final index = items.indexWhere((value) => value.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        state = AsyncData(items);
      },
      error: (_) {},
    );
    return result;
  }

  Future<void> refresh() async {
    final result = await ref.read(masterDataRepositoryProvider).getCustomers();
    result.when(
      success: (data) => state = AsyncData(data),
      error: (failure) => state = AsyncError(failure, StackTrace.current),
    );
  }
}

final laundryServicesProvider =
    AsyncNotifierProvider<LaundryServicesNotifier, List<LaundryServiceEntity>>(
        LaundryServicesNotifier.new,);

class LaundryServicesNotifier
    extends AsyncNotifier<List<LaundryServiceEntity>> {
  @override
  Future<List<LaundryServiceEntity>> build() async {
    final result = await ref.read(masterDataRepositoryProvider).getServices();
    return result.when(
        success: (data) => data, error: (failure) => throw failure,);
  }

  Future<Result<LaundryServiceEntity>> save(
      LaundryServiceEntity service,) async {
    final result =
        await ref.read(masterDataRepositoryProvider).saveService(service);
    result.when(
      success: (item) {
        final items = <LaundryServiceEntity>[...(state.valueOrNull ?? [])];
        final index = items.indexWhere((value) => value.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        state = AsyncData(items);
      },
      error: (_) {},
    );
    return result;
  }

  Future<void> refresh() async {
    final result = await ref.read(masterDataRepositoryProvider).getServices();
    result.when(
      success: (data) => state = AsyncData(data),
      error: (failure) => state = AsyncError(failure, StackTrace.current),
    );
  }
}
