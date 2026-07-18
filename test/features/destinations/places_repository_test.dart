import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alhudhud/features/destinations/data/datasources/destinations_remote_datasource.dart';
import 'package:alhudhud/features/destinations/data/repositories/places_repository.dart';

class MockDestinationsRemoteDataSource extends Mock
    implements DestinationsRemoteDataSource {}

void main() {
  late MockDestinationsRemoteDataSource dataSource;
  late PlacesRepository repository;

  setUp(() {
    dataSource = MockDestinationsRemoteDataSource();
    repository = PlacesRepository(dataSource: dataSource);
  });

  Map<String, dynamic> row(String id, {bool popular = false}) => {
    'id': id,
    'district_id': 'd1',
    'category_id': 'c1',
    'name_ar': 'مكان $id',
    'latitude': 18.0,
    'longitude': -15.9,
    'is_popular': popular,
  };

  test(
    'loadByDistrictAndCategory delegates straight through to the RPC datasource call',
    () async {
      when(
        () => dataSource.fetchPlacesByDistrictCategory(
          districtId: 'd1',
          categoryId: 'c1',
          limit: 50,
          offset: 0,
        ),
      ).thenAnswer((_) async => [row('p1', popular: true), row('p2')]);

      final places = await repository.loadByDistrictAndCategory(
        districtId: 'd1',
        categoryId: 'c1',
      );

      expect(places, hasLength(2));
      expect(places.first.id, 'p1');
      expect(places.first.isPopular, isTrue);
    },
  );

  test('search forwards the query and filters unchanged', () async {
    when(
      () => dataSource.searchPlaces(
        query: 'مطعم',
        districtId: 'd1',
        categoryId: 'c1',
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => [row('p3')]);

    final results = await repository.search(
      query: 'مطعم',
      districtId: 'd1',
      categoryId: 'c1',
    );

    expect(results.single.id, 'p3');
    verify(
      () => dataSource.searchPlaces(
        query: 'مطعم',
        districtId: 'd1',
        categoryId: 'c1',
        limit: 20,
        offset: 0,
      ),
    ).called(1);
  });

  group('admin helpers', () {
    test('adminVerifyPlace sets is_verified = true', () async {
      when(
        () => dataSource.updatePlace('p1', {'is_verified': true}),
      ).thenAnswer((_) async => row('p1'));

      final place = await repository.adminVerifyPlace('p1');

      expect(place.id, 'p1');
      verify(
        () => dataSource.updatePlace('p1', {'is_verified': true}),
      ).called(1);
    });

    test(
      'adminDeactivatePlace sets is_active = false (never deletes)',
      () async {
        when(
          () => dataSource.updatePlace('p1', {'is_active': false}),
        ).thenAnswer((_) async => row('p1'));

        await repository.adminDeactivatePlace('p1');

        verify(
          () => dataSource.updatePlace('p1', {'is_active': false}),
        ).called(1);
      },
    );
  });
}
