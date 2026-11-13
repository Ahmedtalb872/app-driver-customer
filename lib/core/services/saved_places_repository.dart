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

  /// Saves [address]/[lat]/[lng] under [label] ('home'/'work'/'other'),
  /// named by [customName] (e.g. "بيت الوالد", "مكتب الفرع الثاني"). A
  /// customer can save any number of places under the same label - this
  /// always inserts a new row rather than overwriting a previous one (see
  /// 20261003000109_saved_places_all_multiple.sql, which lifted the
  /// one-per-label limit that used to apply to 'work'/'other').
  Future<void> savePlace({
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? customName,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await SupabaseConfig.client.from('saved_places').insert({
      'customer_id': userId,
      'label': label,
      'custom_name': customName,
      'address': address,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<void> deletePlace(String id) async {
    await SupabaseConfig.client.from('saved_places').delete().eq('id', id);
  }
}
