import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/core/services/voice_search/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher.similarity', () {
    test('identical strings score 1.0', () {
      expect(FuzzyMatcher.similarity('بكار', 'بكار'), 1.0);
    });

    test('empty strings score 0.0 unless both empty', () {
      expect(FuzzyMatcher.similarity('', 'بكار'), 0.0);
      expect(FuzzyMatcher.similarity('بكار', ''), 0.0);
    });

    test('a single dropped letter still scores highly', () {
      // "بكر" -> "بكار": one inserted alef, edit distance 1, length 4.
      expect(FuzzyMatcher.similarity('بكر', 'بكار'), closeTo(0.75, 1e-9));
    });

    test('completely different short strings score low', () {
      expect(FuzzyMatcher.similarity('مطار', 'سوق'), lessThan(0.4));
    });

    test('is symmetric', () {
      expect(
        FuzzyMatcher.similarity('كرفور', 'كرفوز'),
        FuzzyMatcher.similarity('كرفوز', 'كرفور'),
      );
    });
  });
}
