import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  group('AuthRemoteDataSourceImpl', () {
    test('tidak menimpa nilai is_active yang dikirim server ketika false', () {
      final normalized = AuthRemoteDataSourceImpl.normalizeUserJson({
        'id': 9,
        'name': 'Kasir Nonaktif',
        'username': 'kasir_inactive',
        'role': 'kasir',
        'is_active': false,
      });

      expect(normalized['id'], '9');
      expect(normalized['is_active'], isFalse);
    });

    test('mengisi default is_active true hanya saat field tidak ada', () {
      final normalized = AuthRemoteDataSourceImpl.normalizeUserJson({
        'id': 'u-1',
        'name': 'Owner',
        'username': 'owner',
        'role': 'owner',
      });

      expect(normalized['is_active'], isTrue);
    });
  });
}
