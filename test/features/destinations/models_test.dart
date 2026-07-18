import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/features/destinations/data/models/district.dart';
import 'package:alhudhud/features/destinations/data/models/place.dart';
import 'package:alhudhud/features/destinations/data/models/place_category.dart';

void main() {
  group('District serialization', () {
    test(
      'fromJson parses a full row and applies defaults for missing fields',
      () {
        final district = District.fromJson({
          'id': 'd1',
          'name_ar': 'تفرغ زينة',
          'name_fr': 'Tevragh Zeina',
          'code': 'tevragh_zeina',
          'latitude': 18.1103,
          'longitude': -15.9683,
        });

        expect(district.id, 'd1');
        expect(district.nameAr, 'تفرغ زينة');
        expect(district.code, 'tevragh_zeina');
        expect(district.latitude, 18.1103);
        expect(district.mapZoom, 13); // default applied when map_zoom absent
        expect(
          district.isActive,
          isTrue,
        ); // default applied when is_active absent
      },
    );

    test('toJson round-trips the same values', () {
      const district = District(
        id: 'd1',
        nameAr: 'لكصر',
        code: 'ksar',
        latitude: 18.0858,
        longitude: -15.9700,
        mapZoom: 14,
        isActive: false,
      );
      final json = district.toJson();
      final parsed = District.fromJson(json);

      expect(parsed.id, district.id);
      expect(parsed.nameAr, district.nameAr);
      expect(parsed.mapZoom, 14);
      expect(parsed.isActive, isFalse);
    });
  });

  group('Place display helpers', () {
    Place buildPlace({
      String? nameAr,
      String? nameFr,
      String? addressAr,
      String? addressFr,
    }) {
      return Place(
        id: 'p1',
        districtId: 'd1',
        categoryId: 'c1',
        nameAr: nameAr ?? '',
        nameFr: nameFr,
        addressAr: addressAr,
        addressFr: addressFr,
        latitude: 18.0,
        longitude: -15.9,
      );
    }

    test('displayName prefers Arabic, falls back to French', () {
      expect(
        buildPlace(nameAr: 'المستشفى الوطني').displayName,
        'المستشفى الوطني',
      );
      expect(buildPlace(nameAr: '', nameFr: 'CHN').displayName, 'CHN');
    });

    test('displayAddress prefers Arabic, falls back to French', () {
      expect(
        buildPlace(
          addressAr: 'لكصر، نواكشوط',
          addressFr: 'Ksar',
        ).displayAddress,
        'لكصر، نواكشوط',
      );
      expect(
        buildPlace(addressAr: '', addressFr: 'Ksar').displayAddress,
        'Ksar',
      );
      expect(buildPlace().displayAddress, isNull);
    });

    test(
      'fromJson requires latitude/longitude and defaults booleans to false',
      () {
        final place = Place.fromJson({
          'id': 'p1',
          'district_id': 'd1',
          'category_id': 'c1',
          'name_ar': 'مطعم البركة',
          'latitude': 18.11,
          'longitude': -15.96,
        });
        expect(place.isPopular, isFalse);
        expect(place.isVerified, isFalse);
        expect(place.isActive, isTrue);
      },
    );
  });

  group('PlaceCategory place counts', () {
    test('copyWithPlaceCount keeps identity fields and swaps the count', () {
      const category = PlaceCategory(
        id: 'c1',
        code: 'hospitals',
        nameAr: 'مستشفيات',
        sortOrder: 30,
      );
      final withCount = category.copyWithPlaceCount(4);

      expect(withCount.id, 'c1');
      expect(withCount.code, 'hospitals');
      expect(withCount.placeCount, 4);
      expect(category.placeCount, 0); // original is untouched (immutable)
    });
  });
}
