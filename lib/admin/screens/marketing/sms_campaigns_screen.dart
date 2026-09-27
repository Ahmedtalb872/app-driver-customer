import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/admin_sms_campaigns_repository.dart';
import '../../widgets/confirm_dialog.dart';

class SmsCampaignsScreen extends StatefulWidget {
  const SmsCampaignsScreen({super.key});

  @override
  State<SmsCampaignsScreen> createState() => _SmsCampaignsScreenState();
}

class _SmsCampaignsScreenState extends State<SmsCampaignsScreen> {
  final _repository = AdminSmsCampaignsRepository();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _codeController = TextEditingController();
  final _customPhonesController = TextEditingController();
  String _audience = 'customers';
  bool _sending = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _history = [];

  static const _audienceLabels = {
    'customers': 'الزبائن المسجلين',
    'captains': 'الكباتن المسجلين',
    'both': 'الجميع المسجلين',
    'custom': 'قائمة أرقام مخصصة',
  };

  /// Parses the pasted phone list textarea: one number per line, or
  /// separated by commas/spaces - whatever the admin copy-pasted from a
  /// spreadsheet or contacts export. Digits and a leading '+' only; the
  /// Edge Function itself strips all punctuation and any '222' country
  /// code before calling Chinguisoft, so this just needs to isolate each
  /// individual number.
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
    _urlController.dispose();
    _codeController.dispose();
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
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    final code = _codeController.text.trim();
    if (title.isEmpty || url.isEmpty || code.isEmpty) return;

    final isCustom = _audience == 'custom';
    final customPhones = isCustom ? _parseCustomPhones() : null;
    if (isCustom && (customPhones == null || customPhones.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الصق رقماً واحداً على الأقل في قائمة الأرقام المخصصة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final recipientDescription = isCustom
        ? '${customPhones!.length} رقم في القائمة المخصصة'
        : 'كل "${_audienceLabels[_audience]}" لديه رقم هاتف مسجّل';
    final ok = await showConfirmDialog(
      context,
      title: 'إرسال حملة SMS',
      message:
          'سيصل رابط "$url" مع كود "$code" فوراً برسالة نصية إلى '
          '$recipientDescription. كل رسالة تُخصم من رصيد حملات Chinguisoft. '
          'هل تريد المتابعة؟',
      confirmLabel: 'إرسال',
    );
    if (!ok) return;

    setState(() => _sending = true);
    try {
      final sent = await _repository.sendCampaign(
        title: title,
        url: url,
        code: code,
        audience: _audience,
        phones: customPhones,
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
      _urlController.clear();
      _codeController.clear();
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
                    'رسالة نصية حقيقية (رابط + كود خصم) عبر Chinguisoft - '
                    'تصل حتى لمن لم يثبّت التطبيق، وتُخصم من رصيد الحملات.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'إرسال إلى',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'customers',
                        label: Text('الزبائن', style: TextStyle(fontFamily: 'Cairo')),
                        icon: Icon(Icons.groups_rounded),
                      ),
                      ButtonSegment(
                        value: 'captains',
                        label: Text('الكباتن', style: TextStyle(fontFamily: 'Cairo')),
                        icon: Icon(Icons.local_taxi_rounded),
                      ),
                      ButtonSegment(
                        value: 'both',
                        label: Text('الجميع', style: TextStyle(fontFamily: 'Cairo')),
                        icon: Icon(Icons.diversity_3_rounded),
                      ),
                      ButtonSegment(
                        value: 'custom',
                        label: Text('قائمة مخصصة', style: TextStyle(fontFamily: 'Cairo')),
                        icon: Icon(Icons.playlist_add_check_rounded),
                      ),
                    ],
                    selected: {_audience},
                    onSelectionChanged: (selection) =>
                        setState(() => _audience = selection.first),
                  ),
                  if (_audience == 'custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customPhonesController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'أرقام الهواتف (رقم في كل سطر، أو مفصولة بفاصلة)',
                        hintText: '22244800028\n22244800029\n...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'مخصصة لإرسال دعوات لأرقام غير مسجّلة في التطبيق (مثل '
                      'كباتن جدد تريد استقطابهم) - لا تحتاج أن تكون '
                      'مسجّلة كزبون أو كابتن مسبقاً.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الحملة (للسجل الداخلي فقط)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'رابط العرض',
                      hintText: 'https://example.com/promo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود الخصم',
                      hintText: 'PROMO10',
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
    final audienceLabel =
        _audienceLabels[row['audience'] as String?] ?? _audienceLabels['customers'];
    return Card(
      child: ListTile(
        title: Text(
          row['title'] as String? ?? '',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${row['promo_url'] as String? ?? ''} — ${row['promo_code'] as String? ?? ''}\n$audienceLabel',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        isThreeLine: true,
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
