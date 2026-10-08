import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminCallLogsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// The `trips` join is only there for a readable customer label (see
  /// AdminCallLogsScreen._customerLabel) - the same fallback-to-guest-phone
  /// shape as TripDetailPanel._customerLabel/AdminTripsRepository.loadActiveTrips,
  /// not a new pattern.
  Future<List<Map<String, dynamic>>> loadLogs({
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('call_logs')
        .select(
          '*, trips(guest_customer_phone, customers(profiles(full_name)))',
        )
        .order('started_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }
}
