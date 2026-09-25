import '../config/supabase_config.dart';
import '../../models/models.dart';

/// A signed-in customer's labeled places (`home`/`work`/`school`) - saved
/// once (typically prompted from [TripSummaryScreen] right after a trip
/// ends) and reused from then on instead of searching for the same address
/// every time.
class SavedPlacesRepository {
  SavedPlacesRepository._();
  static final instance = SavedPlacesRepository._();

  Future<List<SavedPlace>> fetchMine() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await SupabaseConfig.client
        .from('saved_places')
        .select()
        .eq('customer_id', userId)
        .order('label');
    return (rows as List)
        .map((row) => SavedPlace.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Saves [address]/[lat]/[lng] under [label] ('home'/'work'/'school').
  /// Overwrites any previous place saved under that same label (see the
  /// unique constraint in 20260816000074_saved_places.sql) - a customer
  /// only ever has one "home", saving a new one replaces the old.
  Future<void> savePlace({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await SupabaseConfig.client.from('saved_places').upsert(
      {
        'customer_id': userId,
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
      },
      onConflict: 'customer_id,label',
    );
  }

  Future<void> deletePlace(String id) async {
    await SupabaseConfig.client.from('saved_places').delete().eq('id', id);
  }
}
