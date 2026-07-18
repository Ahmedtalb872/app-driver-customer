import 'package:flutter/material.dart';

/// Shows a Yes/No confirmation dialog, returning true if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a dialog collecting a mandatory free-text reason, returning it
/// (trimmed, non-empty) or null if cancelled. Used everywhere the spec
/// requires a "mandatory reason" (reject, suspend, cancel, wallet
/// adjustment, ...).
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String hint = 'اكتب السبب هنا...',
  String confirmLabel = 'تأكيد',
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'هذا الحقل مطلوب'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result;
}
