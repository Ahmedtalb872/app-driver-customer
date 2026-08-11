import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../constants/nouakchott_bounds.dart';
import 'google_api_android_headers.dart';
import '../../features/destinations/data/models/destination_suggestion.dart';

/// Widens destination search beyond this app's own places/districts/
/// neighborhoods registry (`search_destinations`,
/// 20260717000035_destination_search.sql) to everything Google Maps itself
/// knows about in Nouakchott - a business, address, or landmark that was
/// never manually added to that registry still needs to be found by name or
/// voice search. Purely additive: [DestinationSearchRepository.search]
/// merges this alongside the existing DB search rather than replacing it,
/// and this returns an empty list on any failure (missing/invalid key, no
/// network, no results, API error) instead of throwing, the same
/// never-block-the-primary-source pattern [GoogleDirectionsRouteEstimator]
/// already uses for routing.
///
/// Never attempts the call on web: like the Directions API, Google's Places
/// API sends no CORS headers, so a browser-side request would just fail
/// after a real network round trip for nothing.
///
/// Reuses the same Android-restricted Maps SDK key already used natively
/// (see android/app/build.gradle.kts and google_api_android_headers.dart)
/// for this direct REST call too - no separate Places-specific key needed,
/// only "Places API" added to the same key's API restrictions in Google
/// Cloud Console.
class GooglePlacesSearchService {
  const GooglePlacesSearchService({required this.apiKey});

  final String apiKey;

  /// Text Search (not Autocomplete) so a single call returns real
  /// lat/lng per result - Autocomplete would need a second Place Details
  /// call per suggestion just to get coordinates.
  Future<List<DestinationSuggestion>> search({
    required String query,
    int limit = 8,
  }) async {
    if (kIsWeb || apiKey.isEmpty || query.trim().isEmpty) return const [];

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {
          'query': query,
          // Biases (doesn't strictly restrict) results toward Nouakchott -
          // isWithinNouakchott below is the actual hard filter.
          'location': '$nouakchottCenterLat,$nouakchottCenterLng',
          'radius': '20000',
          'language': 'ar',
          'region': 'mr',
          'key': apiKey,
        },
      );
      final response = await http
          .get(uri, headers: googleApiAndroidHeaders())
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return const [];

      final results = body['results'] as List;
      final suggestions = <DestinationSuggestion>[];
      for (final result in results) {
        final row = result as Map<String, dynamic>;
        final location = row['geometry']?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        final placeId = row['place_id'] as String?;
        final name = row['name'] as String?;
        if (lat == null ||
            lng == null ||
            placeId == null ||
            name == null ||
            !isWithinNouakchott(lat, lng)) {
          continue;
        }
        suggestions.add(
          DestinationSuggestion(
            resultType: DestinationResultType.place,
            id: 'google_$placeId',
            title: name,
            subtitle: row['formatted_address'] as String?,
            latitude: lat,
            longitude: lng,
          ),
        );
        if (suggestions.length >= limit) break;
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }
}
