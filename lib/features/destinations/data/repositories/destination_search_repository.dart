import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../core/services/google_places_search_service.dart';
import '../datasources/destinations_remote_datasource.dart';
import '../models/destination_suggestion.dart';

/// Backs the admin dispatch screen's autocomplete and the customer app's
/// destination search (typed and voice) - a single free-text search across
/// this app's own places, districts, and neighborhoods (search_destinations,
/// 20260717000035_destination_search.sql), unlike [PlacesRepository.search]
/// which only searches places.
///
/// Also merges in [GooglePlacesSearchService] results, so a business or
/// address that was never manually added to this app's own registry can
/// still be found - the DB search stays authoritative (its own errors still
/// propagate to the caller, same as before this merge existed) while Google
/// is purely additive best-effort, matching how [GoogleDirectionsRouteEstimator]
/// treats the same API family.
class DestinationSearchRepository {
  DestinationSearchRepository({
    DestinationsRemoteDataSource? dataSource,
    GooglePlacesSearchService? placesSearch,
  }) : _dataSource = dataSource ?? DestinationsRemoteDataSource(),
       _placesSearch =
           placesSearch ??
           GooglePlacesSearchService(
             apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
           );

  final DestinationsRemoteDataSource _dataSource;
  final GooglePlacesSearchService _placesSearch;

  /// Two results within this distance of each other are treated as the same
  /// place (e.g. a business already in this app's registry that Google also
  /// returns under a slightly different name/transliteration), so it isn't
  /// shown twice.
  static const _duplicateRadiusMeters = 150.0;

  Future<List<DestinationSuggestion>> search({
    required String query,
    int limit = 15,
  }) async {
    // Both started here, before either is awaited, so the two network
    // calls run concurrently rather than one after the other. If the local
    // search throws, that propagates immediately without waiting on
    // googleFuture - it never throws (see GooglePlacesSearchService), so
    // leaving it unawaited in that case is safe.
    final localFuture = _dataSource.searchDestinations(
      query: query,
      limit: limit,
    );
    final googleFuture = _placesSearch.search(query: query, limit: limit);

    final rows = await localFuture;
    final local = rows.map(DestinationSuggestion.fromJson).toList();

    final google = await googleFuture;
    if (google.isEmpty) return local;

    final merged = [...local];
    for (final candidate in google) {
      final isDuplicate = local.any(
        (existing) => _metersBetween(existing, candidate) < _duplicateRadiusMeters,
      );
      if (!isDuplicate) merged.add(candidate);
    }
    return merged.take(limit).toList();
  }

  double _metersBetween(DestinationSuggestion a, DestinationSuggestion b) {
    const earthRadiusM = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(a.latitude)) *
            math.cos(_degToRad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusM * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
