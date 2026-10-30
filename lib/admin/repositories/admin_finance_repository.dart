import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminFinanceRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// [vehicleTypeFilter] narrows to captains of one vehicle type (e.g.
  /// 'motorcycle') - a customer wallet, or a captain of any other type, is
  /// excluded. `captains(vehicle_type)` is a reverse embed through
  /// `captains.id references profiles(id)`; `!inner` is required for the
  /// `.eq('profiles.captains.vehicle_type', ...)` filter below to actually
  /// drop non-matching rows instead of just nulling the embed.
  Future<List<Map<String, dynamic>>> loadWallets({
    String? searchQuery,
    String? vehicleTypeFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = vehicleTypeFilter == null
        ? _client.from('wallets').select('*, profiles!inner(*, captains(vehicle_type))')
        : _client
              .from('wallets')
              .select('*, profiles!inner(*, captains!inner(vehicle_type))')
              .eq('profiles.captains.vehicle_type', vehicleTypeFilter);
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or(
        'full_name.ilike.%$q%,phone.ilike.%$q%',
        referencedTable: 'profiles',
      );
    }
    final rows = await query
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadTransactions({
    String? typeFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client.from('wallet_transactions').select();
    if (typeFilter != null && typeFilter.isNotEmpty) {
      query = query.eq('type', typeFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// [vehicleTypeFilter] narrows to requests from captains of one vehicle
  /// type (e.g. 'motorcycle'). Unlike [loadWallets], `recharge_requests`
  /// has no foreign key to `profiles` (only to `auth.users`), so PostgREST
  /// can't embed the requester - [_attachRequesters] resolves and attaches
  /// `profile`/`vehicle_type` for each row in a second round-trip instead.
  Future<List<Map<String, dynamic>>> loadRechargeRequests({
    String? statusFilter,
    String? vehicleTypeFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('recharge_requests').select();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    if (vehicleTypeFilter != null) {
      final ids = await _captainIdsOfType(vehicleTypeFilter);
      if (ids.isEmpty) return [];
      query = query.inFilter('user_id', ids);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _attachRequesters(List<Map<String, dynamic>>.from(rows));
  }

  Future<List<Map<String, dynamic>>> loadWithdrawalRequests({
    String? statusFilter,
    String? vehicleTypeFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('withdrawal_requests').select();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    if (vehicleTypeFilter != null) {
      final ids = await _captainIdsOfType(vehicleTypeFilter);
      if (ids.isEmpty) return [];
      query = query.inFilter('user_id', ids);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _attachRequesters(List<Map<String, dynamic>>.from(rows));
  }

  Future<List<String>> _captainIdsOfType(String vehicleType) async {
    final rows = await _client
        .from('captains')
        .select('id')
        .eq('vehicle_type', vehicleType);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((r) => r['id'] as String).toList();
  }

  /// Attaches `profile` (full_name, phone, role) and `vehicle_type` (null
  /// for a customer) to each row, keyed by its `user_id`.
  Future<List<Map<String, dynamic>>> _attachRequesters(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;
    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();

    final profileRows = await _client
        .from('profiles')
        .select('id, full_name, phone, role')
        .inFilter('id', userIds);
    final profilesById = {
      for (final p in List<Map<String, dynamic>>.from(profileRows))
        p['id'] as String: p,
    };

    final captainRows = await _client
        .from('captains')
        .select('id, vehicle_type')
        .inFilter('id', userIds);
    final vehicleTypeById = {
      for (final c in List<Map<String, dynamic>>.from(captainRows))
        c['id'] as String: c['vehicle_type'] as String?,
    };

    for (final row in rows) {
      final userId = row['user_id'] as String;
      row['profile'] = profilesById[userId];
      row['vehicle_type'] = vehicleTypeById[userId];
    }
    return rows;
  }

  Future<void> approveRecharge(String requestId, {String? notes}) async {
    await _client.rpc(
      'admin_approve_recharge',
      params: {'p_request_id': requestId, 'p_notes': notes},
    );
  }

  Future<void> rejectRecharge(String requestId, String reason) async {
    await _client.rpc(
      'admin_reject_recharge',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
  }

  Future<void> approveWithdrawal(String requestId, {String? notes}) async {
    await _client.rpc(
      'admin_approve_withdrawal',
      params: {'p_request_id': requestId, 'p_notes': notes},
    );
  }

  Future<void> rejectWithdrawal(String requestId, String reason) async {
    await _client.rpc(
      'admin_reject_withdrawal',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
  }

  Future<void> adjustWalletBalance(
    String userId,
    double amount,
    bool isCredit,
    String reason,
  ) async {
    await _client.rpc(
      'admin_adjust_wallet_balance',
      params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_is_credit': isCredit,
        'p_reason': reason,
      },
    );
  }

  /// Captain-subscription cycles flagged for manual review (an early
  /// cancellation before the captain's escrowed share was fully paid out,
  /// or a trusted-mode renewal neither side confirmed in time) - see
  /// admin_list_subscription_disputes(),
  /// 20260812000057_subscription_staged_payout.sql. The actual wallet fix
  /// is made separately via [adjustWalletBalance]; this dispute row just
  /// tracks that something needs a human decision.
  Future<List<Map<String, dynamic>>> loadSubscriptionDisputes() async {
    final rows = await _client.rpc('admin_list_subscription_disputes');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> dismissSubscriptionDispute(
    String subscriptionId,
    String notes,
  ) async {
    await _client.rpc(
      'admin_dismiss_subscription_dispute',
      params: {'p_subscription_id': subscriptionId, 'p_notes': notes},
    );
  }
}
