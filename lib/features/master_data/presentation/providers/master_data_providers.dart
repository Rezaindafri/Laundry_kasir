import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/name_sort.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/customer_remote_datasource.dart';
import '../../data/datasources/service_remote_datasource.dart';
import '../../data/repositories/master_data_repository_impl.dart';
import '../../data/repositories/mock_master_data_repository.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../../domain/repositories/master_data_repository.dart';

final customerRemoteDataSourceProvider = Provider<CustomerRemoteDataSource>(
    (ref) => CustomerRemoteDataSourceImpl(DioClient().dio));
final serviceRemoteDataSourceProvider = Provider<ServiceRemoteDataSource>(
    (ref) => ServiceRemoteDataSourceImpl(DioClient().dio));

final masterDataRepositoryProvider = Provider<MasterDataRepository>((ref) {
  if (AppConstants.useMockApi) return MockMasterDataRepository();
  return MasterDataRepositoryImpl(
    customerRemoteDataSource: ref.watch(customerRemoteDataSourceProvider),
    serviceRemoteDataSource: ref.watch(serviceRemoteDataSourceProvider),
  );
});

final customersProvider =
    AsyncNotifierProvider<CustomersNotifier, List<CustomerEntity>>(
        CustomersNotifier.new);

class CustomersNotifier extends AsyncNotifier<List<CustomerEntity>> {
  @override
  Future<List<CustomerEntity>> build() async {
    ref.watch(currentSessionUserIdProvider);
    return _load();
  }

  Future<List<CustomerEntity>> _load() async {
    final result = await ref.read(masterDataRepositoryProvider).getCustomers();
    return result.when(
      success: (data) => sortedByName(data, (item) => item.name),
      error: (failure) => throw failure,
    );
  }

  Future<Result<CustomerEntity>> save(CustomerEntity customer) async {
    final result =
        await ref.read(masterDataRepositoryProvider).saveCustomer(customer);
    result.when(
        success: (item) {
          final items = <CustomerEntity>[...(state.valueOrNull ?? [])];
          final index = items.indexWhere((value) => value.id == item.id);
          if (index < 0)
            items.add(item);
          else
            items[index] = item;
          state = AsyncData(sortedByName(items, (item) => item.name));
        },
        error: (_) {});
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result =
        await ref.read(masterDataRepositoryProvider).deleteCustomer(id);
    result.when(
        success: (_) => state = AsyncData(
            (state.valueOrNull ?? []).where((item) => item.id != id).toList()),
        error: (_) {});
    return result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final laundryServicesProvider =
    AsyncNotifierProvider<LaundryServicesNotifier, List<LaundryServiceEntity>>(
        LaundryServicesNotifier.new);

class LaundryServicesNotifier
    extends AsyncNotifier<List<LaundryServiceEntity>> {
  @override
  Future<List<LaundryServiceEntity>> build() async {
    ref.watch(currentSessionUserIdProvider);
    return _load();
  }

  Future<List<LaundryServiceEntity>> _load() async {
    final result = await ref.read(masterDataRepositoryProvider).getServices();
    return result.when(
        success: (data) => sortedByName(data, (item) => item.name),
        error: (failure) => throw failure);
  }

  Future<Result<LaundryServiceEntity>> save(
      LaundryServiceEntity service) async {
    final result =
        await ref.read(masterDataRepositoryProvider).saveService(service);
    result.when(
        success: (item) {
          final items = <LaundryServiceEntity>[...(state.valueOrNull ?? [])];
          final index = items.indexWhere((value) => value.id == item.id);
          if (index < 0)
            items.add(item);
          else
            items[index] = item;
          state = AsyncData(sortedByName(items, (item) => item.name));
        },
        error: (_) {});
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result =
        await ref.read(masterDataRepositoryProvider).deleteService(id);
    result.when(
        success: (_) => state = AsyncData(
            (state.valueOrNull ?? []).where((item) => item.id != id).toList()),
        error: (_) {});
    return result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
