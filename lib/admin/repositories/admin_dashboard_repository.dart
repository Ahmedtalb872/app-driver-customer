import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/dashboard_stats.dart';

/// Aggregates real counts from the existing customers/captains/trips/
/// wallet tables - nothing here is simulated. Trip/revenue figures will
/// legitimately read 0 until the mobile app is wired to write real trips
/// (Phase 2 stopped short of trip creation on purpose), which is expected,
/// not a bug.
class AdminDashboardRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<DashboardStats> loadStats() async {
    final todayStart = DateTime.now().toUtc();
    final todayStartIso = DateTime.utc(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    ).toIso8601String();

    final results = await Future.wait([
      _client.from('captains').select().count(CountOption.exact),
      _client
          .from('captains')
          .select()
          .eq('status', 'approved')
          .count(CountOption.exact),
      _client
          .from('captains')
          .select()
          .eq('status', 'pending')
          .count(CountOption.exact),
      _client
          .from('captains')
          .select()
          .eq('is_online', true)
          .count(CountOption.exact),
      _client.from('trips').select().count(CountOption.exact),
      _client
          .from('trips')
          .select()
          .inFilter('status', [
            'searching',
            'accepted',
            'arrived',
            'boarded',
            'in_progress',
          ])
          .count(CountOption.exact),
      _client
          .from('trips')
          .select()
          .eq('status', 'completed')
          .count(CountOption.exact),
      _client
          .from('trips')
          .select()
          .eq('status', 'cancelled')
          .count(CountOption.exact),
      _client
          .from('trips')
          .select()
          .gte('requested_at', todayStartIso)
          .count(CountOption.exact),
      _client
          .from('captains')
          .select()
          .gte('created_at', todayStartIso)
          .count(CountOption.exact),
      _client
          .from('recharge_requests')
          .select()
          .eq('status', 'pending')
          .count(CountOption.exact),
      _client
          .from('withdrawal_requests')
          .select()
          .eq('status', 'pending')
          .count(CountOption.exact),
    ]);

    final revenueRows = await _client
        .from('trips')
        .select('final_price, commission_amount, captain_net_earnings')
        .eq('status', 'completed');

    double revenue = 0, commission = 0, captainEarnings = 0;
    for (final row in List<Map<String, dynamic>>.from(revenueRows)) {
      revenue += (row['final_price'] as num?)?.toDouble() ?? 0;
      commission += (row['commission_amount'] as num?)?.toDouble() ?? 0;
      captainEarnings += (row['captain_net_earnings'] as num?)?.toDouble() ?? 0;
    }

    return DashboardStats(
      totalCaptains: results[0].count,
      approvedCaptains: results[1].count,
      pendingCaptains: results[2].count,
      onlineCaptains: results[3].count,
      totalTrips: results[4].count,
      activeTrips: results[5].count,
      completedTrips: results[6].count,
      cancelledTrips: results[7].count,
      tripsToday: results[8].count,
      newCaptainsToday: results[9].count,
      pendingRechargeRequests: results[10].count,
      pendingWithdrawalRequests: results[11].count,
      platformRevenue: revenue,
      commissionCollected: commission,
      captainEarnings: captainEarnings,
    );
  }

  Future<List<Map<String, dynamic>>> loadTripsPerDay({int days = 7}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows = await _client
        .from('trips')
        .select('requested_at')
        .gte('requested_at', since.toIso8601String());

    final counts = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final date = DateTime.parse(row['requested_at'] as String);
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts.entries.map((e) => {'date': e.key, 'count': e.value}).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Future<List<Map<String, dynamic>>> loadRecentTrips({int limit = 5}) async {
    final rows = await _client
        .from('trips')
        .select()
        .order('requested_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }
}
