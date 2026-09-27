import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/admin_sms_campaigns_repository.dart';
import '../../widgets/confirm_dialog.dart';

/// Recruits captains (or anyone else) who have never signed up: the admin
/// pastes a raw phone list and presses send - no message text, link, or
/// discount code to fill in, since Chinguisoft's campaign account this
/// dashboard uses only has send permission, with the actual SMS content
/// fixed on Chinguisoft's own side.
class SmsCampaignsScreen extends StatefulWidget {
  const SmsCampaignsScreen({super.key});

  @override
  State<SmsCampaignsScreen> createState() => _SmsCampaignsScreenState();
}

class _SmsCampaignsScreenState extends State<SmsCampaignsScreen> {
  final _repository = AdminSmsCampaignsRepository();
  final _titleController = TextEditingController();
  final _customPhonesController = TextEditingController();
  bool _sending = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _history = [];

  /// Parses the pasted phone list textarea: one number per line, or
  /// separated by commas/spaces - whatever the admin copy-pasted from a
  /// spreadsheet or contacts export. The Edge Function itself strips all
  /// punctuation and any '222' country code before calling Chinguisoft, so
  /// this just needs to isolate each individual number.
  List<String> _parseCustomPhones() {
    return _customPhonesController.text
        .split(RegExp(r'[\s,;]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customPhonesController.dispose();
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
    final phones = _parseCustomPhones();
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الصق رقماً واحداً على الأقل قبل الإرسال.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    final title = _titleController.text.trim().isEmpty
        ? 'حملة ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'
        : _titleController.text.trim();

    final ok = await showConfirmDialog(
      context,
      title: 'إرسال حملة SMS',
      message:
          'ستُرسل الرسالة فوراً إلى ${phones.length} رقم. كل رسالة تُخصم '
          'من رصيد حملات Chinguisoft. هل تريد المتابعة؟',
      confirmLabel: 'إرسال',
    );
    if (!ok) return;

    setState(() => _sending = true);
    try {
      final sent = await _repository.sendCampaign(
        title: title,
        audience: 'custom',
        phones: phones,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الإرسال إلى $sent رقم',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      _titleController.clear();
      _customPhonesController.clear();
      _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر إرسال الحملة: $e',
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
                    'إرسال حملة SMS',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'الصق أرقام هواتف (لا تحتاج أن تكون مسجّلة في التطبيق - '
                    'مثل كباتن جدد تريد استقطابهم) وستصلهم رسالة نصية '
                    'حقيقية عبر Chinguisoft فوراً.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customPhonesController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'أرقام الهواتف (رقم في كل سطر، أو مفصولة بفاصلة)',
                      hintText: '22244800028\n22244800029\n...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الحملة (اختياري، للسجل الداخلي فقط)',
                    ),
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
            'سجل الحملات المرسلة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'لا توجد حملات مُرسلة بعد',
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${row['recipient_count'] ?? 0} رقم',
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
