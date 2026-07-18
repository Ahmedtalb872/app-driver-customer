import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/features/destinations/data/models/destination_suggestion.dart';

void main() {
  group('DestinationSuggestion', () {
    test('parses a place row with subtitle into displayLabel', () {
      final suggestion = DestinationSuggestion.fromJson({
        'result_type': 'place',
        'id': 'p1',
        'title': 'مطعم الوفاء',
        'subtitle': 'تفرغ زينة',
        'district_id': 'd1',
        'category_code': 'restaurant',
        'is_verified': true,
        'is_popular': true,
        'latitude': 18.11,
        'longitude': -15.97,
      });

      expect(suggestion.resultType, DestinationResultType.place);
      expect(suggestion.isVerified, isTrue);
      expect(suggestion.isPopular, isTrue);
      expect(suggestion.displayLabel, 'مطعم الوفاء - تفرغ زينة');
    });

    test('district/neighborhood rows default verified/popular to false', () {
      final suggestion = DestinationSuggestion.fromJson({
        'result_type': 'district',
        'id': 'd1',
        'title': 'تفرغ زينة',
        'subtitle': null,
        'latitude': 18.11,
        'longitude': -15.97,
      });

      expect(suggestion.resultType, DestinationResultType.district);
      expect(suggestion.isVerified, isFalse);
      expect(suggestion.isPopular, isFalse);
      // No subtitle - displayLabel falls back to just the title.
      expect(suggestion.displayLabel, 'تفرغ زينة');
    });

    test('unknown result_type falls back to place', () {
      final suggestion = DestinationSuggestion.fromJson({
        'result_type': 'something_else',
        'id': 'x1',
        'title': 'X',
        'latitude': 0.0,
        'longitude': 0.0,
      });

      expect(suggestion.resultType, DestinationResultType.place);
    });
  });
}
