import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';

class CaptainDocumentsStatusScreen extends StatefulWidget {
  const CaptainDocumentsStatusScreen({super.key});

  @override
  State<CaptainDocumentsStatusScreen> createState() => _CaptainDocumentsStatusScreenState();
}

class _CaptainDocumentsStatusScreenState extends State<CaptainDocumentsStatusScreen> {
  String? _updatingDoc;

  void _simulateUpdateDoc(String docKey, String docName) {
    setState(() {
      _updatingDoc = docKey;
    });

    // Simulate upload and switch status to under review
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        final provider = Provider.of<AppStateProvider>(context, listen: false);
        provider.updateCaptainDoc(docKey, 'under_review');
        setState(() {
          _updatingDoc = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث $docName بنجاح وهو قيد المراجعة الآن.', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final docStatuses = provider.captainDocsStatus;

    final List<Map<String, String>> docsList = [
      {'key': 'personal_photo', 'name': 'الصورة الشخصية للبروفايل'},
      {'key': 'national_id', 'name': 'بطاقة الهوية الوطنية'},
      {'key': 'driver_license', 'name': 'رخصة السياقة المهنية'},
      {'key': 'car_card', 'name': 'البطاقة الرمادية للسيارة'},
      {'key': 'car_photo', 'name': 'صورة السيارة باللوحة'},
      {'key': 'car_insurance', 'name': 'تأمين السيارة الساري'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حالة المستندات المرفوعة'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24.0),
        itemCount: docsList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final doc = docsList[index];
          final docKey = doc['key']!;
          final docName = doc['name']!;
          
          // Map doc state to visual properties
          // Default mock values if not in state:
          String rawStatus = docStatuses[docKey] ?? 'accepted';
          if (docKey == 'car_insurance' && docStatuses[docKey] == 'accepted') {
            // Let's make some files show expired/rejected for realism
            rawStatus = 'expired';
          }
          if (docKey == 'personal_photo' && docStatuses[docKey] == 'accepted') {
            rawStatus = 'rejected';
          }

          Color statusColor = AppColors.success;
          String statusText = 'تم القبول';
          IconData statusIcon = Icons.check_circle_outline;

          if (rawStatus == 'under_review') {
            statusColor = AppColors.warning;
            statusText = 'قيد المراجعة';
            statusIcon = Icons.hourglass_empty_rounded;
          } else if (rawStatus == 'rejected') {
            statusColor = AppColors.error;
            statusText = 'مرفوض';
            statusIcon = Icons.cancel_outlined;
          } else if (rawStatus == 'expired') {
            statusColor = AppColors.secondaryText;
            statusText = 'منتهي الصلاحية';
            statusIcon = Icons.timer_off_outlined;
          }

          final isThisUpdating = _updatingDoc == docKey;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        docName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تم الرفع: 2026-07-05',
                        style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      ),
                      if (isThisUpdating)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      else if (rawStatus != 'accepted' && rawStatus != 'under_review')
                        ElevatedButton.icon(
                          onPressed: () => _simulateUpdateDoc(docKey, docName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(120, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('تحديث المستند', style: TextStyle(fontSize: 11)),
                        )
                      else
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.success,
                          size: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
