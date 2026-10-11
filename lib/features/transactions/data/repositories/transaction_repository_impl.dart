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

  @override
  Future<Result<TransactionEntity>> getById(String id) async {
    try {
      return Success((await remoteDataSource.getTransaction(id)).toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

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
  Future<Result<TransactionEntity>> create(
      TransactionEntity transaction) async {
    try {
      final model = _toModel(transaction);
      final created =
          await remoteDataSource.createTransaction(transaction: model);
      return Success(created.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<TransactionEntity>> update(
      TransactionEntity transaction) async {
    try {
      final model = _toModel(transaction);
      final updated =
          await remoteDataSource.updateTransaction(transaction: model);
      return Success(updated.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<TransactionEntity>> pay(
      {required TransactionEntity transaction,
      required int amount,
      required PaymentMethod method,
      String? note,
      required String requestId}) async {
    try {
      final updated = await remoteDataSource.recordPayment(
          id: transaction.id,
          amount: amount,
          method: method.name,
          destinationId: transaction.paymentDestinationId,
          note: note,
          requestId: requestId);
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
    List<String>? detailIds,
    int? paymentAmount,
    String? paymentNote,
  }) async {
    try {
      final updated = await remoteDataSource.collectTransaction(
        transaction: _toModel(transaction),
        settlePayment: settlePayment,
        proofImage: proofImage,
        detailIds: detailIds,
        paymentAmount: paymentAmount,
        paymentNote: paymentNote,
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
        paymentDestinationId: transaction.paymentDestinationId,
        payments: transaction.payments,
        paymentStatus: transaction.paymentStatus.name,
        laundryStatus: transaction.laundryStatus.name,
        createdAt: transaction.createdAt,
        estimatedFinishAt: transaction.hasEstimatedFinish
            ? transaction.estimatedFinishAt
            : null,
        details: transaction.details.isNotEmpty
            ? transaction.details
                .map((line) => TransactionDetailModel(
                      id: int.tryParse(line.id) ?? 0,
                      serviceId: int.tryParse(line.serviceId) ?? 0,
                      serviceName: line.name,
                      serviceUnit: line.unit,
                      qty: line.quantity,
                      price: line.unitPrice.toDouble(),
                      subtotal: line.subtotal.toDouble(),
                      expressFee: line.expressFee.toDouble(),
                      estimatedFinishAt: line.estimatedFinishAt,
                      status: line.status,
                      collectedAt: line.collectedAt,
                      hasProofImage: line.hasProofImage,
                      timingConfigured: line.hasKnownTiming,
                    ))
                .toList()
            : [
                TransactionDetailModel(
                  id: 0,
                  serviceId: int.tryParse(transaction.serviceId ?? '') ?? 0,
                  serviceName: transaction.serviceName,
                  serviceUnit: transaction.quantityUnit,
                  qty: transaction.quantity,
                  price: transaction.unitPrice.toDouble(),
                  expressFee: transaction.expressFee.toDouble(),
                ),
              ],
      );
}
