import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../config/supabase_config.dart';

/// Backs the customer app's "محادثة مباشرة" support button (see
/// support_screen.dart / support_ticket_chat_screen.dart). Unlike a
/// classic multi-ticket helpdesk, a customer only ever has one live thread
/// at a time - [getOrCreateMyTicket] reuses any existing open/in_progress
/// ticket instead of starting a new one each time the button is tapped.
class SupportTicketRepository {
  SupportTicketRepository._();

  static final SupportTicketRepository instance = SupportTicketRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  Future<String> getOrCreateMyTicket() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');

    final existing = await _client
        .from('support_tickets')
        .select('id')
        .eq('user_id', uid)
        .inFilter('status', ['open', 'in_progress'])
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await _client
        .from('support_tickets')
        .insert({'user_id': uid, 'subject': 'محادثة دعم'})
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<void> sendMessage(String ticketId, String body) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    await _client.from('support_ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': uid,
      'is_admin_reply': false,
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
