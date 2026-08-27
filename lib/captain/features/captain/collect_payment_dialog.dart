import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

/// Shows a bottom sheet asking the captain for the amount actually
/// collected from the customer in cash - which may differ from the
/// estimated fare shown during the trip - before the trip is marked
/// complete. Calls [onConfirm] with the entered amount.
void showCollectPaymentDialog(
  BuildContext context, {
  required double suggestedAmount,
  required void Function(double amountPaid) onConfirm,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _CollectPaymentSheet(
      suggestedAmount: suggestedAmount,
      onConfirm: onConfirm,
    ),
  );
}

class _CollectPaymentSheet extends StatefulWidget {
  final double suggestedAmount;
  final void Function(double amountPaid) onConfirm;

  const _CollectPaymentSheet({
    required this.suggestedAmount,
    required this.onConfirm,
  });

  @override
  State<_CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<_CollectPaymentSheet> {
  late final TextEditingController _amountController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.suggestedAmount > 0
          ? widget.suggestedAmount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'أدخل مبلغًا صحيحًا');
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm(amount);
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
                'إنهاء المشوار',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'أدخل المبلغ الذي استلمته فعليًا من الزبون',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'المبلغ',
                  suffixText: 'أوقية',
                  errorText: _errorText,
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
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
                      onPressed: _confirm,
                      child: const Text('تأكيد وإنهاء الرحلة'),
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
