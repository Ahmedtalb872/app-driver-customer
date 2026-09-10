import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/core/services/voice_search/arabic_text_normalizer.dart';

void main() {
  group('ArabicTextNormalizer.normalize', () {
    test('unifies hamza variants to a plain alef', () {
      expect(ArabicTextNormalizer.normalize('أحمد'), 'احمد');
      expect(ArabicTextNormalizer.normalize('إلى'), 'الي');
      expect(ArabicTextNormalizer.normalize('آسف'), 'اسف');
    });

    test('unifies alef maksura to ya and ta marbuta to ha', () {
      expect(ArabicTextNormalizer.normalize('مصطفى'), 'مصطفي');
      expect(ArabicTextNormalizer.normalize('مدرسة'), 'مدرسه');
    });

    test('strips diacritics and tatweel', () {
      expect(ArabicTextNormalizer.normalize('مَرْحَبًا'), 'مرحبا');
      expect(ArabicTextNormalizer.normalize('كبيــر'), 'كبير');
    });

    test('collapses repeated whitespace and trims', () {
      expect(ArabicTextNormalizer.normalize('  من   هنا  '), 'من هنا');
    });

    test('"إلى" and "الى" normalize to the same form', () {
      expect(
        ArabicTextNormalizer.normalize('إلى'),
        ArabicTextNormalizer.normalize('الى'),
      );
    });
  });

  group('ArabicTextNormalizer.tokenize', () {
    test('splits normalized text on single spaces', () {
      expect(ArabicTextNormalizer.tokenize('من كرفور بكار'), [
        'من',
        'كرفور',
        'بكار',
      ]);
    });

    test('empty input yields an empty list', () {
      expect(ArabicTextNormalizer.tokenize(''), isEmpty);
    });
  });
}
