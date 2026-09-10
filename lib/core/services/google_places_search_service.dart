import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';
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
/// On mobile this calls Google directly, reusing the same
/// Android-restricted Maps SDK key already used natively (see
/// android/app/build.gradle.kts and google_api_android_headers.dart) - no
/// separate Places-specific key needed, only "Places API" added to the
/// same key's API restrictions in Google Cloud Console.
///
/// On web (the admin dashboard - this is what
/// operator_dispatch_screen.dart's address search runs under) a direct
/// browser call is impossible: Google's Places REST API sends no CORS
/// headers, so the request would just fail after a real network round
/// trip for nothing, which is exactly why this used to return empty on
/// web unconditionally and the dashboard's search only ever found this
/// app's own registered places. Routed instead through the
/// `places-search` Supabase Edge Function, which makes the same Google
/// call server-side (no CORS between two servers) and returns plain JSON.
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
    if (query.trim().isEmpty) return const [];
    if (kIsWeb) return _searchViaEdgeFunction(query: query, limit: limit);
    if (apiKey.isEmpty) return const [];

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

  Future<List<DestinationSuggestion>> _searchViaEdgeFunction({
    required String query,
    required int limit,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'places-search',
        body: {'query': query, 'limit': limit},
      );
      final data = response.data;
      if (data is! Map || data['results'] is! List) return const [];

      final suggestions = <DestinationSuggestion>[];
      for (final row in data['results'] as List) {
        if (row is! Map) continue;
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        final id = row['id'] as String?;
        final title = row['title'] as String?;
        if (lat == null || lng == null || id == null || title == null) {
          continue;
        }
        suggestions.add(
          DestinationSuggestion(
            resultType: DestinationResultType.place,
            id: id,
            title: title,
            subtitle: row['subtitle'] as String?,
            latitude: lat,
            longitude: lng,
          ),
        );
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }
}
