import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';

const List<String> _cancellationReasons = [
  'الزبون لم يحضر في الوقت المحدد',
  'تعذر الوصول لموقع الزبون',
  'الزبون طلب إلغاء الرحلة',
  'ظروف طارئة أو عطل في السيارة',
  'سبب آخر',
];

/// Shows the cancel-trip reason picker; on confirm, cancels the active trip
/// and pops back to the captain's home screen.
void showCancelTripDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _CancelTripSheet(),
  );
}

class _CancelTripSheet extends StatefulWidget {
  const _CancelTripSheet();

  @override
  State<_CancelTripSheet> createState() => _CancelTripSheetState();
}

class _CancelTripSheetState extends State<_CancelTripSheet> {
  String? _selectedReason;
  final _otherReasonController = TextEditingController();

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _confirmCancel() {
    final isOther = _selectedReason == 'سبب آخر';
    final reason = isOther
        ? (_otherReasonController.text.trim().isEmpty
              ? 'سبب آخر'
              : _otherReasonController.text.trim())
        : _selectedReason;
    if (reason == null) return;

    Provider.of<AppStateProvider>(
      context,
      listen: false,
    ).captainCancelActiveTrip(reason);

    Navigator.of(context).pop(); // close the sheet
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم إلغاء المشوار.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إلغاء المشوار',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر سبب الإلغاء قبل المتابعة',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              ..._cancellationReasons.map(
                (reason) => RadioListTile<String>(
                  value: reason,
                  groupValue: _selectedReason,
                  activeColor: AppColors.error,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    reason,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                  ),
                  onChanged: (value) => setState(() => _selectedReason = value),
                ),
              ),
              if (_selectedReason == 'سبب آخر') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherReasonController,
                  decoration: const InputDecoration(
                    hintText: 'اكتب السبب هنا...',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('تراجع'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedReason == null
                          ? null
                          : _confirmCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('تأكيد الإلغاء'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
