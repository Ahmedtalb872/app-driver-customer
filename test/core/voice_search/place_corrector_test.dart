import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/core/services/voice_search/arabic_text_normalizer.dart';
import 'package:alhudhud/core/services/voice_search/place_alias_catalog.dart';
import 'package:alhudhud/core/services/voice_search/place_corrector.dart';

void main() {
  // Built directly rather than via PlaceAliasCatalog (which reads the real
  // asset) - keeps this test independent of the asset bundle and of
  // whatever seed entries assets/data/places.json happens to contain.
  final catalog = [
    PlaceAliasEntry(
      id: 'carrefour_lekbeidat',
      canonical: 'كرفور لكبيد',
      aliases: const ['كرفور الكبيد', 'الكبيد', 'لكبيد'],
    ),
    PlaceAliasEntry(
      id: 'carrefour_bakar',
      canonical: 'كرفور بكار',
      aliases: const ['كرفور بكر', 'بكار', 'بكر', 'لبكار'],
    ),
  ];

  const corrector = PlaceCorrector();

  group('PlaceCorrector.correct', () {
    test('fixes the exact example from the feature spec', () {
      final normalized = ArabicTextNormalizer.normalize(
        'من كرفور لكبيد إلى كرفور بكر',
      );
      final result = corrector.correct(normalized, catalog);

      expect(result.text, ArabicTextNormalizer.normalize('من كرفور لكبيد الي كرفور بكار'));
      expect(result.matches, hasLength(2));
    });

    test('"الكبيد" corrects to "لكبيد"', () {
      final normalized = ArabicTextNormalizer.normalize('الكبيد');
      final result = corrector.correct(normalized, catalog);
      expect(result.text, 'كرفور لكبيد');
    });

    test('"لبكار" corrects to "بكار"', () {
      final normalized = ArabicTextNormalizer.normalize('لبكار');
      final result = corrector.correct(normalized, catalog);
      expect(result.text, 'كرفور بكار');
    });

    test('a longer catalog phrase wins over a shorter overlapping one', () {
      // "كرفور بكر" should correct as the 2-word alias, not just "بكر" -
      // leaving "كرفور" untouched and duplicated.
      final normalized = ArabicTextNormalizer.normalize('كرفور بكر');
      final result = corrector.correct(normalized, catalog);
      expect(result.text, 'كرفور بكار');
      expect(result.matches, hasLength(1));
    });

    test('places not in the catalog are left untouched', () {
      final normalized = ArabicTextNormalizer.normalize(
        'من مستشفى الشيخ زايد إلى تفرغ زينة',
      );
      final result = corrector.correct(normalized, catalog);
      expect(result.matches, isEmpty);
      expect(result.text, normalized);
    });

    test('an empty catalog is a no-op', () {
      final normalized = ArabicTextNormalizer.normalize('كرفور بكر');
      final result = corrector.correct(normalized, const []);
      expect(result.text, normalized);
      expect(result.matches, isEmpty);
    });
  });
}
