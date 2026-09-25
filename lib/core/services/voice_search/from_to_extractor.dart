/// Result of [FromToExtractor.extract]: the raw "from" and "to" phrases
/// pulled out of a spoken route sentence, still exactly as heard/corrected -
/// neither has been resolved to a real place yet (that's Stage 5).
class FromToResult {
  const FromToResult({required this.from, required this.to});

  final String from;
  final String to;
}

/// Stage 4 of the voice-search pipeline: splits a (normalized + place-
/// corrected) sentence into a "from" and "to" phrase. Kept as its own class,
/// independent of speech recognition or place search, so the pattern can be
/// unit-tested and extended (more connector words, a "فقط" single-point
/// phrasing, ...) without touching anything else in the pipeline.
///
/// IMPORTANT: this runs *after* [ArabicTextNormalizer.normalize] (Stage 2),
/// same as the rest of the corrected text it receives - so the connector
/// words below are written in their already-normalized form, not however
/// they'd naturally be typed/spelled. Both "إلى" and "الى" collapse to the
/// same normalized "الي" (hamza-below-alef -> alef, alef maksura -> ya), and
/// "حتى" collapses to "حتي" - see [ArabicTextNormalizer] for the exact
/// substitution table.
class FromToExtractor {
  const FromToExtractor();

  /// "من" is optional (some phrasings start straight with the pickup name);
  /// "الي" (normalized "إلى"/"الى") and "حتي" (normalized "حتى", a common
  /// spoken alternative in Hassaniya Arabic) are both accepted destination
  /// connectors. Loose on whitespace since speech-to-text output is
  /// inconsistent about it.
  static final RegExp _pattern = RegExp(
    '^(?:من\\s+)?(.+?)\\s+(?:الي|حتي)\\s+(.+)\$',
  );

  FromToResult? extract(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;
    final from = match.group(1)!.trim();
    final to = match.group(2)!.trim();
    if (from.isEmpty || to.isEmpty) return null;
    return FromToResult(from: from, to: to);
  }
}
