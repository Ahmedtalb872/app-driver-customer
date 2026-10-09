/// Stage 2 of the voice-search pipeline (Speech Recognition -> **Text
/// Normalization** -> Place Correction -> From/To Extraction -> Place
/// Search - see [VoiceRoutePipeline] for the full chain).
///
/// This is the Dart-side counterpart of `public.normalize_arabic_text`
/// (`supabase/migrations/20260811000053_fuzzy_proximity_search.sql`):
/// lowercases, strips diacritics/tatweel, and unifies hamza (أ/إ/آ/ٱ -> ا),
/// alef maksura (ى -> ي), and ta marbuta (ة -> ه) so common spelling/ASR
/// variants of the same word compare equal. Kept in sync with the SQL
/// version deliberately - both exist because place correction needs to run
/// entirely offline on-device (Stage 3, before any network call), while the
/// SQL version backs the server-side fuzzy search the corrected text is
/// eventually sent to (Stage 5).
///
/// Unicode escapes are used throughout instead of literal Arabic characters
/// so the exact codepoints (several of these are easy to visually confuse -
/// hamza-above vs hamza-below alef, alef maksura vs plain ya) are
/// unambiguous on any editor/terminal.
class ArabicTextNormalizer {
  const ArabicTextNormalizer._();

  // FATHATAN, DAMMATAN, KASRATAN, FATHA, DAMMA, KASRA, SHADDA, SUKUN,
  // SUPERSCRIPT ALEF, TATWEEL.
  static final RegExp _diacritics = RegExp(
    '[ًٌٍَُِّْٰـ]',
  );

  // ALEF WITH HAMZA ABOVE (أ), ALEF WITH HAMZA BELOW (إ), ALEF WITH MADDA
  // ABOVE (آ), ALEF WASLA (ٱ), ALEF MAKSURA (ى), TEH MARBUTA (ة).
  static const _hamzaAndVariants =
      'أإآٱىة';
  // ALEF (ا) x5, YEH (ي), HEH (ه) - same length/order as above.
  static const _unified = 'اااايه';

  static final RegExp _whitespace = RegExp(r'\s+');

  static String normalize(String input) {
    var text = input.trim().toLowerCase();
    text = text.replaceAll(_diacritics, '');
    for (var i = 0; i < _hamzaAndVariants.length; i++) {
      text = text.replaceAll(_hamzaAndVariants[i], _unified[i]);
    }
    return text.replaceAll(_whitespace, ' ').trim();
  }

  /// Splits already-[normalize]d text on whitespace into word tokens.
  static List<String> tokenize(String normalized) {
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((t) => t.isNotEmpty).toList();
  }
}
