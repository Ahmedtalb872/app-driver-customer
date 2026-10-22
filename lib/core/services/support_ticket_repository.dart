import 'dart:async';

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

  /// [tripId], when given, refocuses the conversation on that specific ride
  /// request (e.g. "راسل لطلب مشوار") - set on a freshly created ticket, or
  /// updated on an existing one that's being reused, so the admin always
  /// sees which trip (if any) the thread is currently about.
  Future<String> getOrCreateMyTicket({String? tripId}) async {
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
    if (existing != null) {
      final id = existing['id'] as String;
      if (tripId != null) {
        // Direct UPDATE on support_tickets is admin-only by RLS (see
        // 20260924000098_support_tickets.sql) - this narrow, owner-checked
        // RPC is the one exception, added specifically for this.
        await _client.rpc(
          'set_my_ticket_trip',
          params: {'p_ticket_id': id, 'p_trip_id': tripId},
        );
      }
      return id;
    }

    final created = await _client
        .from('support_tickets')
        .insert({
          'user_id': uid,
          'subject': 'محادثة دعم',
          if (tripId != null) 'trip_id': tripId,
        })
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

  /// Live messages for a thread, oldest first. Backed by both the
  /// `.stream()` realtime mechanism and a 2s poll, same dual-path pattern
  /// as [CallSignalingService] in this exact project - Realtime
  /// postgres_changes has repeatedly proven unreliable here (see that
  /// class's own doc comment for the history), including, it turns out,
  /// for a message not echoing back to the very client that just sent it.
  /// Whichever path delivers a given message first wins; the other is a
  /// no-op once deduped by id.
  Stream<List<SupportTicketMessage>> watchMessages(String ticketId) {
    final controller = StreamController<List<SupportTicketMessage>>.broadcast();
    final byId = <String, SupportTicketMessage>{};
    Timer? pollTimer;
    StreamSubscription<List<Map<String, dynamic>>>? sub;

    void emit() {
      final list = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      controller.add(list);
    }

    void ingest(Iterable<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final message = SupportTicketMessage.fromJson(row);
        byId[message.id] = message;
      }
      emit();
    }

    Future<void> poll() async {
      try {
        final rows = await _client
            .from('support_ticket_messages')
            .select()
            .eq('ticket_id', ticketId);
        ingest(List<Map<String, dynamic>>.from(rows));
      } catch (_) {
        // Best effort - the realtime stream below is still live, and the
        // next poll tick tries again regardless.
      }
    }

    controller.onListen = () {
      sub = _client
          .from('support_ticket_messages')
          .stream(primaryKey: ['id'])
          .eq('ticket_id', ticketId)
          .listen(
            (rows) => ingest(rows.cast<Map<String, dynamic>>()),
            onError: (_) {},
          );
      poll();
      pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => poll());
    };
    controller.onCancel = () async {
      pollTimer?.cancel();
      await sub?.cancel();
    };

    return controller.stream;
  }
}
