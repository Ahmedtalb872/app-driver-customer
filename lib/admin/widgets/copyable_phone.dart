import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A phone number with a small inline copy button next to it - the admin
/// dashboard's tables show phone numbers constantly (captains, customers,
/// money requests, ...) and copying one always meant manually selecting the
/// text first. Shown as "-" with no button when [phone] is null/empty.
class CopyablePhone extends StatelessWidget {
  final String? phone;

  const CopyablePhone(this.phone, {super.key});

  @override
  Widget build(BuildContext context) {
    final value = phone;
    if (value == null || value.isEmpty) {
      return const Text('-', style: TextStyle(fontFamily: 'Cairo'));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontFamily: 'Cairo')),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نسخ الرقم', style: TextStyle(fontFamily: 'Cairo')),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy_rounded, size: 15),
          ),
        ),
      ],
    );
  }
}
