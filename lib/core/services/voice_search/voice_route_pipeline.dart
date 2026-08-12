import '../../../features/destinations/data/models/destination_suggestion.dart';
import '../../../features/destinations/data/repositories/destination_search_repository.dart';
import 'arabic_text_normalizer.dart';
import 'from_to_extractor.dart';
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

  Future<DestinationSuggestion?> _searchOne(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final matches = await _searchRepository.search(
      query: query,
      limit: 1,
      nearLat: nearLat,
      nearLng: nearLng,
    );
    return matches.isEmpty ? null : matches.first;
  }
}
