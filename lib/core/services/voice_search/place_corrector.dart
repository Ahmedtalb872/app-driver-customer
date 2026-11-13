import 'arabic_text_normalizer.dart';
import 'fuzzy_matcher.dart';
import 'place_alias_catalog.dart';

/// One accepted correction: [start]/[end] are token indices (end exclusive)
/// into the *input* token list that were replaced by [entry].canonical.
class PlaceMatch {
  const PlaceMatch({
    required this.start,
    required this.end,
    required this.entry,
    required this.score,
  });

  final int start;
  final int end;
  final PlaceAliasEntry entry;
  final double score;
}

class PlaceCorrectionResult {
  const PlaceCorrectionResult({required this.text, required this.matches});

  /// The input text with every recognized alias span replaced by its
  /// canonical spelling - safe to feed straight into [FromToExtractor] and
  /// then the real place search (Stage 5).
  final String text;

  /// Every span that was actually corrected; empty when nothing in
  /// [PlaceAliasCatalog] matched anything in the input.
  final List<PlaceMatch> matches;
}

/// Stage 3 of the voice-search pipeline: scans already-normalized text
/// (Stage 2) for spans that closely match a known local place name or one of
/// its recognized mis-transcriptions (`assets/data/places.json`), and
/// replaces them with the canonical spelling - entirely offline, before
/// anything is sent to the real place search (Stage 5). Handles the
/// "كرفور بكر" -> "كرفور بكار" class of fix explicitly, on top of whatever
/// tolerance the server's own trigram search already has.
///
/// Matching works window-by-window: for every catalog alias, every
/// contiguous run of input tokens the same length as that alias is compared
/// to it with [FuzzyMatcher]. This keeps the search space small (no
/// combinatorial cross-word-count comparisons) since the JSON dataset is
/// expected to already list the different word-count variants a place name
/// might be heard as (e.g. both "كرفور بكر" and the bare "بكر").
class PlaceCorrector {
  const PlaceCorrector({this.minSimilarity = 0.72});

  /// How close a window of the spoken text must be to a known alias before
  /// it's corrected. 0.72 tolerates a single substituted/dropped letter in
  /// a 4-5 letter word without firing on two genuinely different short
  /// place names.
  final double minSimilarity;

  PlaceCorrectionResult correct(
    String normalizedText,
    List<PlaceAliasEntry> catalog,
  ) {
    final tokens = ArabicTextNormalizer.tokenize(normalizedText);
    if (tokens.isEmpty || catalog.isEmpty) {
      return PlaceCorrectionResult(text: normalizedText, matches: const []);
    }

    final candidates = <PlaceMatch>[];
    for (final entry in catalog) {
      for (final form in entry.normalizedSurfaceForms) {
        if (form.isEmpty) continue;
        final formWordCount = form.split(' ').length;
        if (formWordCount > tokens.length) continue;

        for (
          var start = 0;
          start + formWordCount <= tokens.length;
          start++
        ) {
          final end = start + formWordCount;
          final window = tokens.sublist(start, end).join(' ');
          final score = FuzzyMatcher.similarity(window, form);
          if (score >= minSimilarity) {
            candidates.add(
              PlaceMatch(start: start, end: end, entry: entry, score: score),
            );
          }
        }
      }
    }

    // Longest, then highest-confidence spans first, so e.g. a full "كرفور
    // بكر" match wins over a shorter single-word "بكر" match at the same
    // spot.
    candidates.sort((a, b) {
      final lengthCompare = (b.end - b.start).compareTo(a.end - a.start);
      if (lengthCompare != 0) return lengthCompare;
      return b.score.compareTo(a.score);
    });

    final accepted = <PlaceMatch>[];
    bool overlapsAccepted(PlaceMatch candidate) => accepted.any(
      (a) => candidate.start < a.end && a.start < candidate.end,
    );
    for (final candidate in candidates) {
      if (!overlapsAccepted(candidate)) accepted.add(candidate);
    }
    accepted.sort((a, b) => a.start.compareTo(b.start));

    final outputTokens = <String>[];
    var cursor = 0;
    for (final match in accepted) {
      outputTokens.addAll(tokens.sublist(cursor, match.start));
      outputTokens.addAll(match.entry.canonical.split(' '));
      cursor = match.end;
    }
    outputTokens.addAll(tokens.sublist(cursor));

    return PlaceCorrectionResult(
      text: outputTokens.join(' '),
      matches: accepted,
    );
  }
}
