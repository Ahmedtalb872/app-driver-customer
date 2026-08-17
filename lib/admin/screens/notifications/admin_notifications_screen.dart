import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/admin_notifications_repository.dart';
import '../../widgets/confirm_dialog.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _repository = AdminNotificationsRepository();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final history = await _repository.loadHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _loadingHistory = false;
    });
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    final ok = await showConfirmDialog(
      context,
      title: 'إرسال إشعار لجميع الزبائن',
      message:
          'سيصل هذا الإشعار فوراً لكل زبون لديه التطبيق مثبتاً على هاتفه. '
          'هل تريد المتابعة؟',
      confirmLabel: 'إرسال',
    );
    if (!ok) return;

    setState(() => _sending = true);
    try {
      final sent = await _repository.sendBroadcast(title: title, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الإرسال إلى $sent جهاز',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      _titleController.clear();
      _bodyController.clear();
      _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر إرسال الإشعار: $e',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إرسال إشعار جماعي لكل الزبائن',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'يصل كإشعار حقيقي حتى لو كان التطبيق مغلقاً - لمن ثبّت '
                    'التطبيق على هاتفه فقط.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'نص الرسالة'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('إرسال'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'سجل الإشعارات المرسلة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'لا توجد إشعارات مُرسلة بعد',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            )
          else
            ..._history.map(_buildHistoryTile),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> row) {
    final sentAt = row['sent_at'] == null
        ? null
        : DateTime.tryParse(row['sent_at'] as String);
    return Card(
      child: ListTile(
        title: Text(
          row['title'] as String? ?? '',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          row['body'] as String? ?? '',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${row['recipient_count'] ?? 0} جهاز',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
            if (sentAt != null)
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(sentAt),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
