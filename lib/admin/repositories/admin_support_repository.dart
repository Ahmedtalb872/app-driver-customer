import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../models/models.dart';

class AdminSupportRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<SupportTicket>> loadTickets({String? statusFilter}) async {
    var query = _client
        .from('support_tickets')
        .select('*, profiles!inner(full_name, phone, role)');
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query.order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportTicket.fromJson).toList();
  }

  /// Lets an admin start/resume a conversation with a specific customer
  /// (replacing the old "اتصال بالزبون" call button) - reuses that
  /// customer's existing open/in_progress ticket if there is one, same
  /// "at most one live thread" rule SupportTicketRepository.getOrCreateMyTicket
  /// enforces on the customer side, just initiated from here instead.
  /// [tripId], when given, refocuses the thread on that specific trip.
  Future<SupportTicket> getOrCreateTicketForCustomer({
    required String userId,
    String? tripId,
  }) async {
    final existing = await _client
        .from('support_tickets')
        .select('*, profiles!inner(full_name, phone, role)')
        .eq('user_id', userId)
        .inFilter('status', ['open', 'in_progress'])
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      if (tripId != null && existing['trip_id'] != tripId) {
        await _client
            .from('support_tickets')
            .update({'trip_id': tripId})
            .eq('id', existing['id'] as String);
        existing['trip_id'] = tripId;
      }
      return SupportTicket.fromJson(existing);
    }

    final created = await _client
        .from('support_tickets')
        .insert({
          'user_id': userId,
          'subject': 'محادثة دعم',
          if (tripId != null) 'trip_id': tripId,
        })
        .select('*, profiles!inner(full_name, phone, role)')
        .single();
    return SupportTicket.fromJson(created);
  }

  Future<void> setStatus(String ticketId, String status) async {
    await _client
        .from('support_tickets')
        .update({'status': status})
        .eq('id', ticketId);
  }

  Future<void> sendReply(String ticketId, String body) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    await _client.from('support_ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': uid,
      'is_admin_reply': true,
      'body': body,
    });
  }

  /// Live messages for a thread, oldest first.
  Stream<List<SupportTicketMessage>> watchMessages(String ticketId) {
    return _client
        .from('support_ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at')
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(SupportTicketMessage.fromJson)
              .toList(),
        );
  }
}
