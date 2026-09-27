import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../repositories/admin_sms_campaigns_repository.dart';
import '../../widgets/confirm_dialog.dart';

/// Recruits captains (or anyone else) who have never signed up: the admin
/// pastes a raw phone list and presses send - no message text, link, or
/// discount code to fill in, since Chinguisoft's campaign account this
/// dashboard uses only has send permission, with the actual SMS content
/// fixed on Chinguisoft's own side.
///
/// The list below is pre-filled with the first recruitment batch handed
/// over on 2026-09-27 so it doesn't need to be re-pasted - clear it (or
/// just select-all and overwrite) for any later batch.
const _prefilledRecruitmentPhones = '''
+22249494933
+22246468302
+22234899846
+22238660438
+22233314232
+22233046963
+22238273836
+22227642001
+22236419191
+22234391865
+22226520082
+22244056860
+22248274818
+22241109618
+22248154295
+22232902014
+22224350000
+22244243523
+22236965996
+22241853161
+22233392080
+22237163001
+22237412565
+22237571839
+22236384748
+22234389888
+22247393631
+22241308190
+22238381959
+22236115838
+22249729500
+22241860383
+22241089776
+22220256359
+22232761102
+22236104869
+22220120150
+22244223629
+22227874007
+22249846049
+22226799334
+22248784817
+22241947484
+22226463605
+22237460199
+22246824545
+22233601326
+22222116099
+22246551564
+22243888180
+22243330333
+22242634936
+22242202292
+22246987474
+22233774097
+22236088097
+22236162413
+22242721039
+22236002922
+22247000069
+22236614323
+22241425524
+22227684176
+22233343580
+22242590404
+22236406768
+22236919999
+22232000909
+22244504030
+22248803010
+22232107646
+22233665500
+22246767878
+22222085159
+22222759799
+22242535352
+22238454647
+22232828336
+22238777191
+22233260066
+22234868000
+22234000100
+22233131737
+22241093909
+22243108789
+22236465055
+22248586363
+22220609006
+22244565505
+22241736713
+22233203322
+22232343526
+22244340010
+22226276723
+22224603012
+22233530101
+22226332171
+22220500458
+22236162699
+22234121832
+22241111707
+22227473141
+22248793900
+22242726051
+22233887270
+22232241010
+22234942697
+22233833338
+22246247273
+22237212224
+22248681110
+22232303033
+22237787767
+22232924751
+22234116996
+22238201782
+22220207989
+22233209394
+22232356171
+22222235917
+22220702073
+22248484714
+22222279193
+22246853015
+22242115591
+22226243646
+22249768598
+22246588898
+22244425837
+22233876070
+22236060669
+22246282790
+22226261128
+22246451077
+22249987895
+22242619329
+22241377902
+22220876070
+22232020233
+22247800847
+22241118128
+22244524295
+22243232351
+22222663252
+22227559434
+22249351313
+22234485030
+22231202099
+22246470566
+22220311818
+22242422422
+22233373036
+22231013201
+22236222916
+22236192083
+22246044680
+22233344040
+22231090445
+22237202727
+22220444875
+22248385738
+22227951909
+22248177536
+22226691683
+22231405036
+22237374009
+22231486803
+22236941621
+22232333306''';

class SmsCampaignsScreen extends StatefulWidget {
  const SmsCampaignsScreen({super.key});

  @override
  State<SmsCampaignsScreen> createState() => _SmsCampaignsScreenState();
}

class _SmsCampaignsScreenState extends State<SmsCampaignsScreen> {
  final _repository = AdminSmsCampaignsRepository();
  final _titleController = TextEditingController();
  late final TextEditingController _customPhonesController;
  final _delayController = TextEditingController(text: '0.5');
  bool _sending = false;
  int _progressSent = 0;
  int _progressRemaining = 0;
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
    _customPhonesController = TextEditingController(
      text: _prefilledRecruitmentPhones,
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customPhonesController.dispose();
    _delayController.dispose();
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
    final delaySeconds = double.tryParse(_delayController.text.trim()) ?? 0.5;
    final estimatedSeconds = (phones.length * delaySeconds).round();

    final ok = await showConfirmDialog(
      context,
      title: 'إرسال حملة SMS',
      message:
          'ستُرسل الرسالة إلى ${phones.length} رقم بفاصل $delaySeconds ثانية '
          'بين كل رسالة (حوالي $estimatedSeconds ثانية إجمالاً). كل رسالة '
          'تُخصم من رصيد حملات Chinguisoft. هل تريد المتابعة؟',
      confirmLabel: 'إرسال',
    );
    if (!ok) return;

    setState(() {
      _sending = true;
      _progressSent = 0;
      _progressRemaining = phones.length;
    });
    try {
      final sent = await _repository.sendCampaign(
        title: title,
        audience: 'custom',
        phones: phones,
        delaySeconds: delaySeconds,
        onProgress: (sentSoFar, remaining) {
          if (!mounted) return;
          setState(() {
            _progressSent = sentSoFar;
            _progressRemaining = remaining;
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اكتملت الحملة: قبلت Chinguisoft إرسال $sent من ${phones.length} '
            'رقم (راجع سجل الحملة أدناه لتفاصيل كل رقم).',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      _titleController.clear();
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
                    'حقيقية عبر Chinguisoft.\n'
                    'ملاحظة مهمة: "نجاح" الإرسال هنا يعني أن Chinguisoft '
                    'قَبِلت الرسالة وخصمت رصيدها - وليس تأكيداً بوصولها فعلياً '
                    'لهاتف المستلم (لا يوجد لدينا تقرير تسليم من المزوّد).',
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان الحملة (اختياري، للسجل الداخلي فقط)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _delayController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'الفاصل بين كل رسالة (ثانية)',
                            hintText: '0.5',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('إرسال'),
                      ),
                      if (_sending) ...[
                        const SizedBox(width: 16),
                        Text(
                          'أُرسل: $_progressSent — متبقٍ: $_progressRemaining',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ],
                    ],
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
