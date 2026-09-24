import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../models/models.dart';

class AdminSupportRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<SupportTicket>> loadTickets({String? statusFilter}) async {
    var query = _client
        .from('support_tickets')
        .select('*, profiles!inner(full_name, phone)');
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query.order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportTicket.fromJson).toList();
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
