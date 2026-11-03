import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/support_ticket_repository.dart';
import '../../../models/models.dart';
import '../../core/business_colors.dart';

/// Support chat for the business portal - same `support_tickets`/
/// `support_ticket_messages` system the mobile customer app's "محادثة
/// مباشرة" uses (a business account is a plain customer account under the
/// hood), reused here unchanged via [SupportTicketRepository].
class BusinessSupportScreen extends StatefulWidget {
  const BusinessSupportScreen({super.key});

  @override
  State<BusinessSupportScreen> createState() => _BusinessSupportScreenState();
}

class _BusinessSupportScreenState extends State<BusinessSupportScreen> {
  final _repository = SupportTicketRepository.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _ticketId;
  StreamSubscription<List<SupportTicketMessage>>? _messagesSub;
  List<SupportTicketMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ticketId = await _repository.getOrCreateMyTicket();
    if (!mounted) return;
    setState(() {
      _ticketId = ticketId;
      _loading = false;
    });
    _messagesSub = _repository.watchMessages(ticketId).listen((messages) {
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    final ticketId = _ticketId;
    if (body.isEmpty || _sending || ticketId == null) return;
    setState(() => _sending = true);
    try {
      await _repository.sendMessage(ticketId, body);
      _messageController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة الآن.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الدعم',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'اكتب رسالتك وسيرد عليك فريق الدعم في أقرب وقت',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Cairo', color: BusinessColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) => _buildBubble(_messages[index]),
                          ),
                  ),
                  _buildComposer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(SupportTicketMessage message) {
    final isMine = !message.isAdminReply;
    return Align(
      alignment: isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isMine ? BusinessColors.primary : BusinessColors.accentLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'فريق الدعم',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: BusinessColors.primary),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isMine ? Colors.white : BusinessColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BusinessColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(hintText: 'اكتب رسالة...', isDense: true),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded, color: BusinessColors.primary),
          ),
        ],
      ),
    );
  }
}
