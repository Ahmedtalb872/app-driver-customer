import '../config/supabase_config.dart';
import '../../features/destinations/data/models/destination_suggestion.dart';

/// Widens destination search beyond this app's own places/districts/
/// neighborhoods registry (`search_destinations`,
/// 20260717000035_destination_search.sql) to everything Google Maps itself
/// knows about in Nouakchott - a business, address, or landmark that was
/// never manually added to that registry still needs to be found by name or
/// voice search. Purely additive: [DestinationSearchRepository.search]
/// merges this alongside the existing DB search rather than replacing it,
/// and this returns an empty list on any failure (no network, no results,
/// API error) instead of throwing, the same never-block-the-primary-source
/// pattern [GoogleDirectionsRouteEstimator] already uses for routing.
///
/// Always routed through the `places-search` Supabase Edge Function rather
/// than calling Google directly from the device. Originally this only
/// applied to web (a direct browser call hits Google's missing CORS
/// headers), with mobile calling maps.googleapis.com directly using a Maps
/// SDK key baked into the app at build time - but that meant a missing or
/// since-revoked client-side key silently broke search for every installed
/// copy of the app, fixable only by shipping and waiting out a full store
/// release. Routing every platform through this same server-side function
/// means the one key that matters (GOOGLE_PLACES_SERVER_API_KEY, a Supabase
/// Edge Function secret) can be fixed or rotated instantly for every
/// already-installed app, with no rebuild or store update needed.
class GooglePlacesSearchService {
  const GooglePlacesSearchService();

  Future<List<DestinationSuggestion>> search({
    required String query,
    int limit = 8,
  }) async {
    if (query.trim().isEmpty) return const [];

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
