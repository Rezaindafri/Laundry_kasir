import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_page_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_detail_model.dart';
import '../models/transaction_model.dart';

import 'dart:typed_data';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  const TransactionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<TransactionEntity>>> getTransactions() async {
    try {
      final models = await remoteDataSource.getTransactions();
      return Success(models.map((item) => item.toEntity()).toList());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<TransactionPageEntity>> getTransactionsPage(
    Map<String, dynamic> query,
  ) async {
    try {
      final page = await remoteDataSource.getTransactionsPage(query);
      return Success(page.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<TransactionEntity>> create(TransactionEntity transaction) async {
    try {
      final model = _toModel(transaction);
      final created = await remoteDataSource.createTransaction(transaction: model);
      return Success(created.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<TransactionEntity>> update(TransactionEntity transaction) async {
    try {
      final model = _toModel(transaction);
      final updated = await remoteDataSource.updateTransaction(transaction: model);
      return Success(updated.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<TransactionEntity>> collect({
    required TransactionEntity transaction,
    required bool settlePayment,
    Uint8List? proofImage,
  }) async {
    try {
      final updated = await remoteDataSource.collectTransaction(
        transaction: _toModel(transaction),
        settlePayment: settlePayment,
        proofImage: proofImage,
      );
      return Success(updated.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await remoteDataSource.deleteTransaction(id);
      return const Success(null);
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  TransactionModel _toModel(TransactionEntity transaction) => TransactionModel(
        id: int.tryParse(transaction.id) ?? 0,
        invoice: transaction.invoice,
        customerId: int.tryParse(transaction.customerId) ?? 0,
        serviceId: int.tryParse(transaction.serviceId ?? '') ?? 0,
        customerName: transaction.customerName,
        customerPhone: transaction.customerPhone,
        serviceName: transaction.serviceName,
        quantity: transaction.quantity,
        quantityUnit: transaction.quantityUnit,
        unitPrice: transaction.unitPrice.toDouble(),
        expressFee: transaction.expressFee.toDouble(),
        total: transaction.total.toDouble(),
        paidAmount: transaction.paidAmount.toDouble(),
        paymentMethod: transaction.paymentMethod.name,
        paymentStatus: transaction.paymentStatus.name,
        laundryStatus: transaction.laundryStatus.name,
        createdAt: transaction.createdAt,
        estimatedFinishAt: transaction.estimatedFinishAt,
        details: [
          TransactionDetailModel(
            id: 0,
            serviceId: int.tryParse(transaction.serviceId ?? '') ?? 0,
            serviceName: transaction.serviceName,
            serviceUnit: transaction.quantityUnit,
            qty: transaction.quantity,
            price: transaction.unitPrice.toDouble(),
          ),
        ],
      );
}
