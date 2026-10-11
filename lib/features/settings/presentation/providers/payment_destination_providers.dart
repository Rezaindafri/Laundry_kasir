import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/payment_destination_datasource.dart';
import '../../domain/entities/payment_destination.dart';

final paymentDestinationDataSourceProvider =
    Provider((ref) => PaymentDestinationDataSource(DioClient().dio));

// Do not persist decrypted account numbers in preferences, logs or backups.
final paymentDestinationsProvider =
    FutureProvider.autoDispose<List<PaymentDestination>>((ref) {
  ref.watch(currentSessionUserIdProvider);
  ref.watch(currentOperationalOwnerScopeIdProvider);
  return ref.watch(paymentDestinationDataSourceProvider).list();
});

final paymentDestinationImageProvider =
    FutureProvider.autoDispose.family<Uint8List, int>((ref, id) {
  ref.watch(currentSessionUserIdProvider);
  ref.watch(currentOperationalOwnerScopeIdProvider);
  return ref.watch(paymentDestinationDataSourceProvider).image(id);
});
