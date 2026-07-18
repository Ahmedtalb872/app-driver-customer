import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';

/// Thin wrapper around the raw Supabase calls backing the destinations
/// feature (Phase 2). Returns plain JSON maps/lists - the repositories in
/// `../repositories/` are responsible for turning these into typed models.
/// Keeping this as the single place that talks to `SupabaseConfig.client`
/// means UI widgets never call Supabase directly, per the Phase 2 spec.
class DestinationsRemoteDataSource {
  DestinationsRemoteDataSource({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  // ---------------------------------------------------------------------
  // Districts
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchActiveDistricts() async {
    final rows = await _client
        .from('districts')
        .select()
        .eq('is_active', true)
        .order('name_ar');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchAllDistricts() async {
    final rows = await _client.from('districts').select().order('name_ar');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> insertDistrict(
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('districts')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateDistrict(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('districts')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  // ---------------------------------------------------------------------
  // Neighborhoods
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchNeighborhoodsByDistrict(
    String districtId,
  ) async {
    final rows = await _client
        .from('neighborhoods')
        .select()
        .eq('district_id', districtId)
        .eq('is_active', true)
        .order('name_ar');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchAllNeighborhoods() async {
    final rows = await _client.from('neighborhoods').select().order('name_ar');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> insertNeighborhood(
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('neighborhoods')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateNeighborhood(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('neighborhoods')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  // ---------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchActiveCategories() async {
    final rows = await _client
        .from('place_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchAllCategories() async {
    final rows = await _client
        .from('place_categories')
        .select()
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> insertCategory(
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('place_categories')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateCategory(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('place_categories')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  /// category_id -> active place count, for the selected district.
  Future<Map<String, int>> fetchCategoryPlaceCounts(String districtId) async {
    final rows = await _client.rpc(
      'get_category_place_counts',
      params: {'p_district_id': districtId},
    );
    final counts = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      counts[row['category_id'] as String] = (row['place_count'] as num)
          .toInt();
    }
    return counts;
  }

  // ---------------------------------------------------------------------
  // Places
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchPlacesByDistrictCategory({
    required String districtId,
    required String categoryId,
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'get_places_by_district_category',
      params: {
        'p_district_id': districtId,
        'p_category_id': categoryId,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchPopularPlacesByDistrict({
    required String districtId,
    int limit = 10,
  }) async {
    final rows = await _client.rpc(
      'get_popular_places_by_district',
      params: {'p_district_id': districtId, 'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    String? districtId,
    String? categoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'search_places',
      params: {
        'p_query': query,
        'p_district_id': districtId,
        'p_category_id': categoryId,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Unified place/district/neighborhood search for the admin dispatch
  /// screen's autocomplete (search_destinations,
  /// 20260717000035_destination_search.sql). Unlike [searchPlaces], this
  /// isn't scoped to a district/category - it's a single free-text box
  /// meant to resolve any of place, address, district, neighborhood,
  /// street or landmark in one query.
  Future<List<Map<String, dynamic>>> searchDestinations({
    required String query,
    int limit = 15,
  }) async {
    final rows = await _client.rpc(
      'search_destinations',
      params: {'p_query': query, 'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchAllPlaces({
    String? districtId,
    String? categoryId,
  }) async {
    var query = _client.from('places').select();
    if (districtId != null) {
      query = query.eq('district_id', districtId);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    final rows = await query.order('name_ar');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> insertPlace(Map<String, dynamic> payload) async {
    final row = await _client.from('places').insert(payload).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updatePlace(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('places')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  /// How many users have this place saved / recently used it - a lightweight
  /// usage signal for the future admin dashboard.
  Future<Map<String, int>> fetchPlaceUsageStats(String placeId) async {
    final savedResponse = await _client
        .from('saved_places')
        .select()
        .eq('place_id', placeId)
        .count(CountOption.exact);
    final recentResponse = await _client
        .from('recent_places')
        .select()
        .eq('place_id', placeId)
        .count(CountOption.exact);
    return {
      'saved_count': savedResponse.count,
      'recent_count': recentResponse.count,
    };
  }

  // ---------------------------------------------------------------------
  // Saved places
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchSavedPlaces(String userId) async {
    final rows = await _client
        .from('saved_places')
        .select()
        .eq('user_id', userId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> saveOrUpdateSavedPlace(
    Map<String, dynamic> params,
  ) async {
    final row = await _client.rpc('save_or_update_saved_place', params: params);
    // rpc() for a function returning a single row gives back a Map already,
    // but be defensive in case the client surfaces a one-element list.
    if (row is List) {
      return Map<String, dynamic>.from(row.first as Map);
    }
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> deleteSavedPlace(String id) async {
    await _client.from('saved_places').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------
  // Recent places
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchRecentPlaces(
    String userId, {
    int limit = 10,
  }) async {
    final rows = await _client
        .from('recent_places')
        .select()
        .eq('user_id', userId)
        .order('last_used_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> recordRecentDestination(
    Map<String, dynamic> params,
  ) async {
    final row = await _client.rpc('record_recent_destination', params: params);
    if (row is List) {
      return Map<String, dynamic>.from(row.first as Map);
    }
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> clearRecentPlaces(String userId) async {
    await _client.from('recent_places').delete().eq('user_id', userId);
  }

  // ---------------------------------------------------------------------
  // Custom destinations
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchCustomDestinations(
    String userId,
  ) async {
    final rows = await _client
        .from('custom_destinations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> insertCustomDestination(
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('custom_destinations')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateCustomDestination(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('custom_destinations')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> deleteCustomDestination(String id) async {
    await _client.from('custom_destinations').delete().eq('id', id);
  }
}
