import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../core/admin_colors.dart';
import '../../repositories/admin_support_repository.dart';

/// Reply chat + status controls for one support ticket, opened as a
/// bottom sheet from AdminSupportScreen's ticket list.
class AdminSupportTicketPanel extends StatefulWidget {
  final SupportTicket ticket;
  final VoidCallback onChanged;

  const AdminSupportTicketPanel({
    super.key,
    required this.ticket,
    required this.onChanged,
  });

  @override
  State<AdminSupportTicketPanel> createState() =>
      _AdminSupportTicketPanelState();
}

class _AdminSupportTicketPanelState extends State<AdminSupportTicketPanel> {
  final _repository = AdminSupportRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<SupportTicketMessage>>? _messagesSub;
  List<SupportTicketMessage> _messages = [];
  bool _isSending = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
    _messagesSub = _repository.watchMessages(widget.ticket.id).listen((
      messages,
    ) {
      if (!mounted) return;
      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendReply(widget.ticket.id, body);
      _messageController.clear();
      widget.onChanged();
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _setStatus(String status) async {
    final previous = _status;
    setState(() => _status = status);
    try {
      await _repository.setStatus(widget.ticket.id, status);
      widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => _status = previous);
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('حدث خطأ، حاول مرة أخرى.', style: TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }

  static const _statusLabels = {
    'open': 'مفتوحة',
    'in_progress': 'قيد المعالجة',
    'resolved': 'محلولة',
    'closed': 'مغلقة',
  };

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.userFullName?.isNotEmpty == true
                                ? ticket.userFullName!
                                : '-',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            ticket.userPhone ?? '-',
                            style: const TextStyle(
                              color: AdminColors.textSecondary,
                              fontFamily: 'Cairo',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _status,
                      items: _statusLabels.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _setStatus(value);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد رسائل بعد.',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildBubble(_messages[index]),
                      ),
              ),
              _buildComposer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubble(SupportTicketMessage message) {
    final isMine = message.isAdminReply;
    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? AdminColors.primary : AdminColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.body,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: isMine ? Colors.white : AdminColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'اكتب ردك...',
                  isDense: true,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _handleSend,
              icon: const Icon(Icons.send_rounded, color: AdminColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
