import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';

class ChatScreen extends StatefulWidget {
  final bool showAppBar;
  const ChatScreen({super.key, this.showAppBar = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      Provider.of<AppStateProvider>(context, listen: false).sendChatMessage(text);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _shareLocation() {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    
    // Simulate sending location card
    provider.sendChatMessage('📍 مشاركة موقعي الحالي: (18.1025, -15.9754)');
    _scrollToBottom();
  }

  void _simulateCall() {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final targetName = provider.userType == UserType.customer 
        ? (provider.activeTrip?.captainName ?? 'الكابتن') 
        : (provider.activeTrip?.customerName ?? 'الزبون');
        
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'اتصال هاتفي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'جاري الاتصال بـ $targetName...',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم فتح تطبيق الاتصال الافتراضي في جهازك.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('إنهاء المكالمة'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final messages = provider.chatMessages;
    final isCustomer = provider.userType == UserType.customer;
    
    final targetName = isCustomer
        ? (provider.activeTrip?.captainName ?? 'كابتن الهدهد')
        : (provider.activeTrip?.customerName ?? 'الزبون');

    // Trigger scroll to bottom on load
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  const Text(
                    'نشط الآن',
                    style: TextStyle(fontSize: 10, color: AppColors.success, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            onPressed: _simulateCall,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Chat messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                bool isMe = msg.isMe;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 18),
                      ),
                      border: isMe ? null : Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.darkText,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.time,
                              style: TextStyle(
                                color: isMe ? Colors.white70 : AppColors.secondaryText,
                                fontSize: 9,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.done_all_rounded, color: Colors.white70, size: 12),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Chat Input panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Location Share button
                  IconButton(
                    icon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                    onPressed: _shareLocation,
                  ),
                  
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  
                  // Send button
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
