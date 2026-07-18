import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alhudhud/features/destinations/data/datasources/destinations_remote_datasource.dart';
import 'package:alhudhud/features/destinations/data/models/district.dart';
import 'package:alhudhud/features/destinations/data/repositories/districts_repository.dart';

class MockDestinationsRemoteDataSource extends Mock
    implements DestinationsRemoteDataSource {}

void main() {
  late MockDestinationsRemoteDataSource dataSource;
  late DistrictsRepository repository;

  setUp(() {
    dataSource = MockDestinationsRemoteDataSource();
    repository = DistrictsRepository(dataSource: dataSource);
  });

  test('loadActiveDistricts maps raw rows to District', () async {
    when(() => dataSource.fetchActiveDistricts()).thenAnswer(
      (_) async => [
        {
          'id': 'd1',
          'name_ar': 'تفرغ زينة',
          'code': 'tevragh_zeina',
          'latitude': 18.1103,
          'longitude': -15.9683,
        },
      ],
    );

    final districts = await repository.loadActiveDistricts();

    expect(districts, hasLength(1));
    expect(districts.single.code, 'tevragh_zeina');
  });

  group('resolveDistrictFromCoordinates', () {
    final districts = [
      const District(
        id: 'd1',
        nameAr: 'تفرغ زينة',
        code: 'tevragh_zeina',
        latitude: 18.1103,
        longitude: -15.9683,
      ),
      const District(
        id: 'd2',
        nameAr: 'الميناء',
        code: 'el_mina',
        latitude: 18.0631,
        longitude: -16.0122,
      ),
      // No coordinates - must never be picked as "closest".
      const District(id: 'd3', nameAr: 'بدون إحداثيات', code: 'no_coords'),
    ];

    test('picks the district whose center is nearest the given point', () {
      // Very close to Tevragh Zeina's seeded center.
      final result = repository.resolveDistrictFromCoordinates(
        districts,
        18.1105,
        -15.9680,
      );
      expect(result?.code, 'tevragh_zeina');
    });

    test('picks El Mina when the point is near the port instead', () {
      final result = repository.resolveDistrictFromCoordinates(
        districts,
        18.0459,
        -16.0301,
      );
      expect(result?.code, 'el_mina');
    });

    test('returns null when no district has coordinates', () {
      final result = repository.resolveDistrictFromCoordinates(
        [const District(id: 'd3', nameAr: 'بدون إحداثيات', code: 'no_coords')],
        18.0,
        -15.9,
      );
      expect(result, isNull);
    });
  });
}
