import '../../../features/destinations/data/models/destination_suggestion.dart';
import '../../../features/destinations/data/repositories/destination_search_repository.dart';
import 'arabic_text_normalizer.dart';
import 'from_to_extractor.dart';
import 'fuzzy_matcher.dart';
import 'place_alias_catalog.dart';
import 'place_corrector.dart';

/// One resolved leg (pickup or destination) of a spoken route: the phrase
/// [FromToExtractor] pulled out (already place-corrected by Stage 3) and
/// every plausible [DestinationSuggestion] match from Stage 5, ranked
/// best-first - empty when nothing was found. Kept as a list rather than a
/// single pick so the caller can let the customer choose among genuinely
/// ambiguous candidates instead of silently committing to a guess that
/// might be wrong; [bestMatch] remains available for auto-filling the
/// single-candidate (or "good enough to not ask") case.
class ResolvedLeg {
  const ResolvedLeg({required this.text, this.candidates = const []});

  final String text;
  final List<DestinationSuggestion> candidates;

  bool get isResolved => candidates.isNotEmpty;
  DestinationSuggestion? get bestMatch =>
      candidates.isEmpty ? null : candidates.first;
}

class VoiceRouteResult {
  const VoiceRouteResult({required this.from, required this.to});

  final ResolvedLeg from;
  final ResolvedLeg to;

  bool get isComplete => from.isResolved && to.isResolved;
}

/// Thrown when Stage 4 (from/to extraction) can't find a "من X إلى Y" shape
/// in the transcript at all - distinct from a resolved-but-not-found leg
/// ([ResolvedLeg.isResolved] == false), which still returns a normal
/// [VoiceRouteResult] so the caller can show exactly which side failed.
class VoiceRouteParseException implements Exception {
  const VoiceRouteParseException(this.message);
  final String message;
}

/// Orchestrates the full pipeline described in the voice-search feature
/// spec:
///
///   Speech Recognition -> Text Normalization -> Place Correction ->
///   From/To Extraction -> Place Search
///
/// Deliberately takes plain recognized text as input rather than owning
/// speech recognition itself (Stage 1 stays in the UI layer - see
/// [VoiceRideRequestSheet]), so the recognizer backing it (today
/// `speech_to_text`, on-device and free) can be swapped for a stronger one
/// later (Whisper, Google Speech, ...) without touching this file or any
/// stage below it - only the UI's call to whatever produces the transcript
/// changes.
class VoiceRoutePipeline {
  VoiceRoutePipeline({
    DestinationSearchRepository? searchRepository,
    PlaceAliasCatalog? aliasCatalog,
    PlaceCorrector? corrector,
    FromToExtractor? extractor,
  }) : _searchRepository = searchRepository ?? DestinationSearchRepository(),
       _aliasCatalog = aliasCatalog ?? PlaceAliasCatalog.instance,
       _corrector = corrector ?? const PlaceCorrector(),
       _extractor = extractor ?? const FromToExtractor();

  final DestinationSearchRepository _searchRepository;
  final PlaceAliasCatalog _aliasCatalog;
  final PlaceCorrector _corrector;
  final FromToExtractor _extractor;

  /// Runs every stage on [rawTranscript] and resolves both legs against the
  /// real place search. [nearLat]/[nearLng], when known, bias search ranking
  /// the same way typed/manual search already does.
  Future<VoiceRouteResult> resolve(
    String rawTranscript, {
    double? nearLat,
    double? nearLng,
  }) async {
    // Stage 2: Text Normalization.
    final normalized = ArabicTextNormalizer.normalize(rawTranscript);

    // Stage 3: Place Correction.
    final catalog = await _aliasCatalog.load();
    final corrected = _corrector.correct(normalized, catalog);

    // Stage 4: From/To Extraction.
    final split = _extractor.extract(corrected.text);
    if (split == null) {
      throw const VoiceRouteParseException(
        'لم أفهم طلبك. قل مثلاً: "من السوق المركزي إلى المطار".',
      );
    }

    // Stage 5: Place Search - both legs concurrently.
    final results = await Future.wait([
      _searchOne(split.from, nearLat: nearLat, nearLng: nearLng),
      _searchOne(split.to, nearLat: nearLat, nearLng: nearLng),
    ]);

    return VoiceRouteResult(
      from: ResolvedLeg(text: split.from, candidates: results[0]),
      to: ResolvedLeg(text: split.to, candidates: results[1]),
    );
  }

  /// Resolves one spoken leg against the real place search, returning every
  /// plausible candidate (best-first, capped at [_maxCandidates]) rather
  /// than committing to a single pick - a misheard word or two is far more
  /// common than a misheard whole phrase, so the few candidates closest to
  /// what was actually heard are usually either the right place or contain
  /// it, and the caller can offer them as a pick list instead of silently
  /// trusting a possibly-wrong top-1 guess (the "من أين تريد؟" voice sheet)
  /// or failing outright.
  ///
  /// If the full phrase finds nothing at all, retries with shorter suffixes
  /// of it (dropping leading words one at a time) - Arabic place names are
  /// typically "[generic word] [proper noun]" ("موقف الصوبة", "كرفور
  /// بكار"), and a mis-transcribed leading word can sink the whole-phrase
  /// search even though the actual place name at the end would have
  /// matched on its own.
  Future<List<DestinationSuggestion>> _searchOne(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    for (var start = 0; start < (tokens.isEmpty ? 1 : tokens.length); start++) {
      final attempt = tokens.isEmpty ? query : tokens.sublist(start).join(' ');
      if (attempt.trim().isEmpty) continue;

      final matches = await _searchRepository.search(
        query: attempt,
        limit: 8,
        nearLat: nearLat,
        nearLng: nearLng,
      );
      if (matches.isEmpty) continue;
      if (matches.length == 1) return matches;

      return _promoteClearlyBetterMatch(matches, attempt)
          .take(_maxCandidates)
          .toList();
    }
    return const [];
  }

  /// [matches] arrives already ordered by the server's own relevance +
  /// *proximity* ranking (search_destinations orders by sim_score then
  /// distance from nearLat/nearLng - see 20260811000053_fuzzy_proximity_search.sql) -
  /// for the pickup leg, nearLat/nearLng is the customer's real location, so
  /// that order already favors a place actually near them over a
  /// same/similar-named one across town.
  ///
  /// Re-sorting purely by text similarity to [attempt] (an earlier version
  /// of this method) threw that proximity signal away entirely - a
  /// text-perfect match three suburbs over could out-rank a nearby
  /// close-enough one, silently creating a trip with a pickup point no
  /// captain anywhere near the customer would ever see. Promoting a
  /// candidate now requires its text match to beat the server's top pick by
  /// a clear margin ([_promotionMargin]) - enough to fix a genuinely
  /// mis-ranked short name (the original motivating case), not enough for
  /// a marginal text difference to override real distance.
  List<DestinationSuggestion> _promoteClearlyBetterMatch(
    List<DestinationSuggestion> matches,
    String attempt,
  ) {
    final topScore = FuzzyMatcher.similarity(attempt, matches.first.title);
    DestinationSuggestion? promoted;
    var bestScore = topScore;
    for (final candidate in matches.skip(1)) {
      final score = FuzzyMatcher.similarity(attempt, candidate.title);
      if (score > bestScore + _promotionMargin) {
        promoted = candidate;
        bestScore = score;
      }
    }
    if (promoted == null) return matches;
    return [promoted, ...matches.where((m) => m != promoted)];
  }

  static const _maxCandidates = 4;

  /// How much higher a candidate's text-similarity score must be than the
  /// server-ranked top pick's before it's promoted ahead of it - see
  /// [_promoteClearlyBetterMatch].
  static const _promotionMargin = 0.15;
}
