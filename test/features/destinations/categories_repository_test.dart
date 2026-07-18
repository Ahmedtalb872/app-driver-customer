import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alhudhud/features/destinations/data/datasources/destinations_remote_datasource.dart';
import 'package:alhudhud/features/destinations/data/repositories/categories_repository.dart';

class MockDestinationsRemoteDataSource extends Mock
    implements DestinationsRemoteDataSource {}

void main() {
  late MockDestinationsRemoteDataSource dataSource;
  late CategoriesRepository repository;

  setUp(() {
    dataSource = MockDestinationsRemoteDataSource();
    repository = CategoriesRepository(dataSource: dataSource);
  });

  group('loadActiveCategories', () {
    test('maps raw rows to PlaceCategory, ordered as returned', () async {
      when(() => dataSource.fetchActiveCategories()).thenAnswer(
        (_) async => [
          {
            'id': 'c1',
            'code': 'restaurants',
            'name_ar': 'مطاعم',
            'sort_order': 10,
            'is_active': true,
          },
          {
            'id': 'c2',
            'code': 'hospitals',
            'name_ar': 'مستشفيات',
            'sort_order': 30,
            'is_active': true,
          },
        ],
      );

      final categories = await repository.loadActiveCategories();

      expect(categories, hasLength(2));
      expect(categories.first.code, 'restaurants');
      expect(categories.first.placeCount, 0); // no counts merged in yet
    });
  });

  group('loadCategoriesWithPlaceCounts', () {
    test(
      'merges per-category counts and defaults missing categories to 0',
      () async {
        when(() => dataSource.fetchActiveCategories()).thenAnswer(
          (_) async => [
            {
              'id': 'c1',
              'code': 'restaurants',
              'name_ar': 'مطاعم',
              'sort_order': 10,
            },
            {
              'id': 'c2',
              'code': 'hospitals',
              'name_ar': 'مستشفيات',
              'sort_order': 30,
            },
            {'id': 'c3', 'code': 'cafes', 'name_ar': 'مقاهي', 'sort_order': 20},
          ],
        );
        when(
          () => dataSource.fetchCategoryPlaceCounts('d1'),
        ).thenAnswer((_) async => {'c1': 5, 'c2': 2});

        final categories = await repository.loadCategoriesWithPlaceCounts('d1');
        final byCode = {for (final c in categories) c.code: c.placeCount};

        expect(byCode['restaurants'], 5);
        expect(byCode['hospitals'], 2);
        expect(
          byCode['cafes'],
          0,
        ); // no entry in the counts map -> defaults to 0
      },
    );
  });
}
