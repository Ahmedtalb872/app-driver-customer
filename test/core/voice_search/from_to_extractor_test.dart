import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/core/services/voice_search/from_to_extractor.dart';

void main() {
  group('FromToExtractor.extract', () {
    // Every input here is already normalized (see ArabicTextNormalizer) -
    // "الي"/"حتي" rather than "إلى"/"الى"/"حتى" - matching what this stage
    // actually receives from the pipeline.
    const extractor = FromToExtractor();

    test('splits a plain "من X الي Y" sentence', () {
      final result = extractor.extract('من كرفور لكبيد الي كرفور بكار');
      expect(result, isNotNull);
      expect(result!.from, 'كرفور لكبيد');
      expect(result.to, 'كرفور بكار');
    });

    test('the leading "من" is optional', () {
      final result = extractor.extract('كرفور لكبيد الي كرفور بكار');
      expect(result, isNotNull);
      expect(result!.from, 'كرفور لكبيد');
      expect(result.to, 'كرفور بكار');
    });

    test('accepts "حتي" as a destination connector', () {
      final result = extractor.extract('من بيتي حتي العمل');
      expect(result, isNotNull);
      expect(result!.from, 'بيتي');
      expect(result.to, 'العمل');
    });

    test('returns null when there is no connector at all', () {
      expect(extractor.extract('كرفور بكار'), isNull);
    });

    test('returns null for empty input', () {
      expect(extractor.extract(''), isNull);
      expect(extractor.extract('   '), isNull);
    });
  });
}
