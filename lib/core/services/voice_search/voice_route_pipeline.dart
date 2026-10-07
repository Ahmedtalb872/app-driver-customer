import '../../../features/destinations/data/models/destination_suggestion.dart';
import '../../../features/destinations/data/repositories/destination_search_repository.dart';
import 'arabic_text_normalizer.dart';
import 'from_to_extractor.dart';
import 'fuzzy_matcher.dart';
import 'place_alias_catalog.dart';
import 'place_corrector.dart';

/// One resolved leg (pickup or destination) of a spoken route: the phrase
/// [FromToExtractor] pulled out (already place-corrected by Stage 3) and the
/// matched [DestinationSuggestion] from Stage 5 - null if nothing was found.
class ResolvedLeg {
  const ResolvedLeg({required this.text, this.suggestion});

  final String text;
  final DestinationSuggestion? suggestion;

  bool get isResolved => suggestion != null;
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
      from: ResolvedLeg(text: split.from, suggestion: results[0]),
      to: ResolvedLeg(text: split.to, suggestion: results[1]),
    );
  }

  /// Resolves one spoken leg against the real place search. Two tolerances
  /// on top of a plain top-1 lookup, both aimed at the "محرك البحث الصوتي
  /// كثيرا ما يظهر لم أجد مكان" complaint - speech-to-text mishears a word
  /// or two far more often than it mishears an entire phrase:
  ///
  ///  - Pulls a handful of candidates (not just 1) and picks whichever one's
  ///    *name* is actually closest to what was heard, rather than trusting
  ///    the server's relevance order alone - a short exact-ish name can
  ///    rank behind a longer loosely-related result otherwise.
  ///  - If the full phrase finds nothing at all, retries with shorter
  ///    suffixes of it (dropping leading words one at a time) - Arabic
  ///    place names are typically "[generic word] [proper noun]" ("موقف
  ///    الصوبة", "كرفور بكار"), and a mis-transcribed leading word can sink
  ///    the whole-phrase search even though the actual place name at the
  ///    end would have matched on its own.
  Future<DestinationSuggestion?> _searchOne(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final tokens = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (var start = 0; start < (tokens.isEmpty ? 1 : tokens.length); start++) {
      final attempt = tokens.isEmpty
          ? query
          : tokens.sublist(start).join(' ');
      if (attempt.trim().isEmpty) continue;

      final matches = await _searchRepository.search(
        query: attempt,
        limit: 5,
        nearLat: nearLat,
        nearLng: nearLng,
      );
      if (matches.isEmpty) continue;
      if (matches.length == 1) return matches.first;

      var best = matches.first;
      var bestScore = FuzzyMatcher.similarity(attempt, best.title);
      for (final candidate in matches.skip(1)) {
        final score = FuzzyMatcher.similarity(attempt, candidate.title);
        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
      return best;
    }
    return null;
  }
}
