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

  /// [nearLat]/[nearLng], when both given (typically the customer's current
  /// location), rank results closest-first ahead of popularity, once text
  /// relevance is already accounted for - passed straight through to
  /// search_destinations for the DB half, and used here to order the
  /// Google half the same way before it's merged in.
  Future<List<DestinationSuggestion>> search({
    required String query,
    int limit = 15,
    double? nearLat,
    double? nearLng,
  }) async {
    // Both started here, before either is awaited, so the two network
    // calls run concurrently rather than one after the other. If the local
    // search throws, that propagates immediately without waiting on
    // googleFuture - it never throws (see GooglePlacesSearchService), so
    // leaving it unawaited in that case is safe.
    final localFuture = _dataSource.searchDestinations(
      query: query,
      limit: limit,
      nearLat: nearLat,
      nearLng: nearLng,
    );
    final googleFuture = _placesSearch.search(query: query, limit: limit);

    final rows = await localFuture;
    final local = rows.map(DestinationSuggestion.fromJson).toList();

    final google = await googleFuture;
    if (google.isEmpty) return local;

    final sortedGoogle = [...google];
    if (nearLat != null && nearLng != null) {
      sortedGoogle.sort(
        (a, b) => _metersBetweenCoords(
          nearLat,
          nearLng,
          a.latitude,
          a.longitude,
        ).compareTo(
          _metersBetweenCoords(nearLat, nearLng, b.latitude, b.longitude),
        ),
      );
    }

    final merged = [...local];
    for (final candidate in sortedGoogle) {
      final isDuplicate = local.any(
        (existing) =>
            _metersBetweenCoords(
              existing.latitude,
              existing.longitude,
              candidate.latitude,
              candidate.longitude,
            ) <
            _duplicateRadiusMeters,
      );
      if (!isDuplicate) merged.add(candidate);
    }
    return merged.take(limit).toList();
  }

  double _metersBetweenCoords(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusM * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
