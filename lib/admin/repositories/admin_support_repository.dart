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
