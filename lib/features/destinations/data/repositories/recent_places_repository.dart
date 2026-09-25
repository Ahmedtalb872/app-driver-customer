import '../../../../core/config/supabase_config.dart';
import '../datasources/destinations_remote_datasource.dart';
import '../models/destination_suggestion.dart';

/// A signed-in customer's own recently-requested destinations - shown
/// before they type anything in [DestinationSearchScreen], since most real
/// searches just repeat a handful of familiar places (home, work, a usual
/// errand) rather than discovering somewhere new every time.
///
/// [fetchRecentPlaces]/[recordRecentDestination] already existed on
/// [DestinationsRemoteDataSource] but had no repository or UI wired up to
/// them - recent destinations were recorded nowhere, so the list was
/// always empty in practice.
class RecentPlacesRepository {
  RecentPlacesRepository({DestinationsRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? DestinationsRemoteDataSource();

  final DestinationsRemoteDataSource _dataSource;

  /// Empty (not an error) for a signed-out session - recent places are
  /// private per customer, so there's nothing meaningful to show.
  Future<List<DestinationSuggestion>> loadRecent({int limit = 6}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _dataSource.fetchRecentPlaces(userId, limit: limit);
    return rows.map(DestinationSuggestion.fromRecentPlaceJson).toList();
  }

  /// Records [destination] as a recently-used destination for the
  /// signed-in customer. Called once a trip actually requests it (see
  /// RequestRideScreen/DeliveryRequestScreen), not on every search result
  /// tap, so "recent" reflects real trips rather than idle browsing.
  ///
  /// Best-effort: never throws. This is a convenience feature, not core
  /// trip flow - a request that already succeeded must never be treated as
  /// failed just because this bookkeeping call did.
  Future<void> recordVisit(DestinationSuggestion destination) async {
    if (SupabaseConfig.client.auth.currentUser == null) return;
    try {
      // A real DB place has a genuine places.id (a plain uuid) -
      // record_recent_destination's place_id column has a foreign key to
      // public.places, so only pass it when that's actually true. A
      // Google-sourced result ("google_<place_id>") or a map-tapped point
      // ("map_<lat>_<lng>") still gets recorded, just without a place_id.
      final isOfficialPlace =
          destination.resultType == DestinationResultType.place &&
          !destination.id.startsWith('google_') &&
          !destination.id.startsWith('map_');
      await _dataSource.recordRecentDestination({
        'p_destination_type': isOfficialPlace
            ? 'official_place'
            : 'custom_location',
        'p_address': destination.displayLabel,
        'p_latitude': destination.latitude,
        'p_longitude': destination.longitude,
        'p_place_id': isOfficialPlace ? destination.id : null,
        'p_district_id': destination.districtId,
      });
    } catch (_) {
      // Best effort - see the doc comment above.
    }
  }
}
