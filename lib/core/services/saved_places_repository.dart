import '../config/supabase_config.dart';
import '../../models/models.dart';

/// A signed-in customer's labeled places (`home`/`work`/`other`) - saved
/// once (typically prompted from [TripSummaryScreen] right after a trip
/// ends) and reused from then on instead of searching for the same address
/// every time. Also surfaced as one-tap destination shortcuts on
/// [TripPlannerScreen].
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

  /// Saves [address]/[lat]/[lng] under [label] ('home'/'work'/'other').
  ///
  /// 'work'/'other' stay single-slot - overwrites any previous place saved
  /// under that same label (see the partial unique index in
  /// 20261003000108_saved_places_multiple_homes.sql), same as before.
  ///
  /// 'home' is different: a customer can save any number of them (e.g.
  /// "بيت الوالد" and "بيت الزوجة"), each identified by [customName] - that
  /// index doesn't govern 'home' rows at all, so this always inserts a new
  /// one rather than overwriting.
  Future<void> savePlace({
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? customName,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final row = {
      'customer_id': userId,
      'label': label,
      'custom_name': label == 'home' ? customName : null,
      'address': address,
      'lat': lat,
      'lng': lng,
    };
    if (label == 'home') {
      await SupabaseConfig.client.from('saved_places').insert(row);
    } else {
      await SupabaseConfig.client
          .from('saved_places')
          .upsert(row, onConflict: 'customer_id,label');
    }
  }

  Future<void> deletePlace(String id) async {
    await SupabaseConfig.client.from('saved_places').delete().eq('id', id);
  }
}
