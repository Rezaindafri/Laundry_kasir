import '../../../../core/utils/result.dart';
import '../entities/customer_entity.dart';
import '../entities/laundry_service_entity.dart';

abstract class MasterDataRepository {
  Future<Result<List<CustomerEntity>>> getCustomers();
  Future<Result<CustomerEntity>> saveCustomer(CustomerEntity customer);
  Future<Result<List<LaundryServiceEntity>>> getServices();
  Future<Result<LaundryServiceEntity>> saveService(
      LaundryServiceEntity service,);
}
