import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../config/supabase_config.dart';

/// Monthly captain subscription ("اشتراك شهري"): browse approved online
/// captains, negotiate a flat monthly price over a realtime chat, and once
/// the captain accepts, request ordinary rides with that specific captain
/// at no extra charge for 30 days. See
/// 20260812000056_captain_subscriptions.sql for the full negotiate/pay/
/// activate logic this only reads or triggers - this repository itself
/// does no pricing/eligibility math client-side.
class CaptainSubscriptionRepository {
  CaptainSubscriptionRepository._();

  static final CaptainSubscriptionRepository instance =
      CaptainSubscriptionRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<BrowsableCaptain>> fetchBrowsableCaptains() async {
    final rows = await _client.rpc('browsable_captains');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BrowsableCaptain.fromJson)
        .toList();
  }

  /// The signed-in customer's single most-relevant subscription (active if
  /// there is one, else the newest open negotiation), or `null` for none.
  Future<CaptainSubscription?> fetchMyStatus() async {
    if (_client.auth.currentUser == null) return null;
    final rows = await _client.rpc('customer_subscription_status');
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return CaptainSubscription.fromJson(list.first);
  }

  Future<String> startChat(String captainId, {String? initialMessage}) async {
    final id = await _client.rpc(
      'customer_start_subscription_chat',
      params: {
        'p_captain_id': captainId,
        'p_initial_message': initialMessage,
      },
    );
    return id as String;
  }

  Future<void> sendMessage(
    String subscriptionId,
    String body, {
    double? offerAmount,
  }) async {
    await _client.rpc(
      'send_subscription_message',
      params: {
        'p_subscription_id': subscriptionId,
        'p_body': body,
        'p_offer_amount': offerAmount,
      },
    );
  }

  Future<void> cancelSubscription(String subscriptionId) async {
    await _client.rpc(
      'customer_cancel_subscription',
      params: {'p_subscription_id': subscriptionId},
    );
  }

  /// Live messages for a negotiation thread, oldest first.
  Stream<List<SubscriptionMessage>> watchMessages(String subscriptionId) {
    return _client
        .from('captain_subscription_messages')
        .stream(primaryKey: ['id'])
        .eq('subscription_id', subscriptionId)
        .order('created_at')
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(SubscriptionMessage.fromJson)
              .toList(),
        );
  }

  // A trip-scoped or subscription-scoped relationship is enough for a
  // customer to read a captain's captains/profiles row (see the two new
  // policies in 20260812000056_captain_subscriptions.sql), independent of
  // whether that subscription is negotiating or active - so this embed
  // works throughout the whole chat lifecycle, not just once accepted.
  static const String _fullJoin =
      '*, captains(avatar_url, vehicle_brand, vehicle_model, vehicle_color, profiles(full_name, phone))';

  CaptainSubscription _rowToSubscription(Map<String, dynamic> row) {
    final captain = row['captains'] as Map<String, dynamic>?;
    final profile = captain?['profiles'] as Map<String, dynamic>?;
    return CaptainSubscription.fromJson({
      'id': row['id'],
      'captain_id': row['captain_id'],
      'captain_name': profile?['full_name'],
      'captain_avatar_url': captain?['avatar_url'],
      'captain_phone': profile?['phone'],
      'vehicle_brand': captain?['vehicle_brand'],
      'vehicle_model': captain?['vehicle_model'],
      'vehicle_color': captain?['vehicle_color'],
      'status': row['status'],
      'proposed_price': row['proposed_price'],
      'proposed_by': row['proposed_by'],
      'agreed_price': row['agreed_price'],
      'started_at': row['started_at'],
      'expires_at': row['expires_at'],
    });
  }

  Future<CaptainSubscription> _fetchSubscription(String subscriptionId) async {
    final row = await _client
        .from('captain_subscriptions')
        .select(_fullJoin)
        .eq('id', subscriptionId)
        .single();
    return _rowToSubscription(row);
  }

  /// Live status for a single thread - lets the chat screen react the
  /// moment the captain accepts/rejects without the customer having to
  /// leave and reopen it. Fetches this specific thread directly (not via
  /// [fetchMyStatus], which only ever surfaces the customer's single most
  /// relevant one and could point elsewhere if more than one negotiation
  /// is open at once).
  Stream<CaptainSubscription?> watchSubscription(String subscriptionId) {
    final controller = StreamController<CaptainSubscription?>.broadcast();
    CaptainSubscription? lastKnown;

    final sub = _client
        .from('captain_subscriptions')
        .stream(primaryKey: ['id'])
        .eq('id', subscriptionId)
        .listen((rows) async {
          if (rows.isEmpty) {
            controller.add(null);
            return;
          }
          try {
            lastKnown = await _fetchSubscription(subscriptionId);
            controller.add(lastKnown);
          } catch (_) {
            controller.add(lastKnown);
          }
        });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }
}
