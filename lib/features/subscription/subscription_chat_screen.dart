import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/captain_subscription_repository.dart';
import '../../models/models.dart';

/// Negotiation chat for a single "اشتراك شهري" thread - free-text messages
/// plus optional structured price offers, live-updated via
/// [CaptainSubscriptionRepository.watchMessages]/[watchSubscription]. The
/// captain's own accept/reject happens in the captain app; this screen only
/// ever reacts to the thread's status changing underneath it.
class SubscriptionChatScreen extends StatefulWidget {
  final String subscriptionId;
  const SubscriptionChatScreen({super.key, required this.subscriptionId});

  @override
  State<SubscriptionChatScreen> createState() =>
      _SubscriptionChatScreenState();
}

class _SubscriptionChatScreenState extends State<SubscriptionChatScreen> {
  final _repository = CaptainSubscriptionRepository.instance;
  final _messageController = TextEditingController();
  final _offerController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<CaptainSubscription?>? _statusSub;
  StreamSubscription<List<SubscriptionMessage>>? _messagesSub;

  CaptainSubscription? _status;
  List<SubscriptionMessage> _messages = [];
  bool _isSending = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _statusSub = _repository
        .watchSubscription(widget.subscriptionId)
        .listen((status) {
          if (mounted) setState(() => _status = status);
        });
    _messagesSub = _repository
        .watchMessages(widget.subscriptionId)
        .listen((messages) {
          if (!mounted) return;
          setState(() => _messages = messages);
          _scrollToBottom();
        });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _messagesSub?.cancel();
    _messageController.dispose();
    _offerController.dispose();
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

  Future<void> _handleSend() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(widget.subscriptionId, body);
      _messageController.clear();
    } catch (_) {
      _showError('تعذر إرسال الرسالة الآن.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleSendOffer() async {
    final amount = double.tryParse(_offerController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغاً صحيحاً للعرض أولاً.');
      return;
    }
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(
        widget.subscriptionId,
        'أقترح اشتراكاً شهرياً بمبلغ ${amount.toStringAsFixed(0)} أوقية.',
        offerAmount: amount,
      );
      _offerController.clear();
    } catch (_) {
      _showError('تعذر إرسال العرض الآن.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء المحادثة', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text(
          'هل تريد إنهاء هذه المحادثة قبل الاتفاق على اشتراك؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'إلغاء المحادثة',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isCancelling = true);
    try {
      await _repository.cancelSubscription(widget.subscriptionId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('تعذر إلغاء المحادثة الآن.');
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final canChat = status == null || status.isNegotiating;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          status?.captainName ?? 'اشتراك شهري',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      body: Column(
        children: [
          if (status != null) _buildStatusBanner(status),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'ابدأ المحادثة واقترح سعراً شهرياً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.secondaryText,
                      ),
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
          if (canChat) _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(CaptainSubscription status) {
    late final Color color;
    late final String text;
    switch (status.status) {
      case SubscriptionStatus.active:
        color = AppColors.success;
        final days = status.daysRemaining;
        text = status.agreedPrice != null
            ? 'الاشتراك نشط بمبلغ ${status.agreedPrice!.toStringAsFixed(0)} أوقية شهرياً'
                '${days != null ? ' - باقي $days يوماً' : ''}'
            : 'الاشتراك نشط';
        break;
      case SubscriptionStatus.rejected:
        color = AppColors.error;
        text = 'اعتذر الكابتن عن هذا الاشتراك';
        break;
      case SubscriptionStatus.cancelled:
        color = AppColors.secondaryText;
        text = 'تم إلغاء هذه المحادثة';
        break;
      case SubscriptionStatus.negotiating:
        color = AppColors.accent;
        text = status.proposedPrice != null
            ? 'آخر عرض: ${status.proposedPrice!.toStringAsFixed(0)} أوقية شهرياً'
                '${status.proposedBy == 'customer' ? ' (منك)' : ' (من الكابتن)'}'
            : 'لم يُقترح سعر بعد';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBubble(SubscriptionMessage message) {
    final isMine = message.senderRole == 'customer';
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
          color: message.isOffer
              ? AppColors.accent.withOpacity(0.15)
              : (isMine ? AppColors.primary : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: message.isOffer
              ? Border.all(color: AppColors.accent.withOpacity(0.4))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isOffer)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'عرض سعر',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: message.isOffer
                    ? AppColors.darkText
                    : (isMine ? Colors.white : AppColors.darkText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _offerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'اقترح سعراً شهرياً (أوقية)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isSending ? null : _handleSendOffer,
                  child: const Text('إرسال عرض'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _handleSend,
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
            TextButton(
              onPressed: _isCancelling ? null : _handleCancel,
              child: Text(
                _isCancelling ? 'جارٍ الإلغاء...' : 'إلغاء المحادثة',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
