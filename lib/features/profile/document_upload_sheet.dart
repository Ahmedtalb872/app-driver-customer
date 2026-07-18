import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/services/captain_documents_repository.dart';
import '../../models/models.dart';

/// Shared camera/gallery/PDF picker + upload flow for one document slot.
/// Used by both [CaptainDocumentsStatusScreen] (post-registration) and the
/// registration stepper's document step, so there is exactly one real
/// upload implementation instead of two separate fakes. Returns true if a
/// document was successfully uploaded (caller should refresh its list).
Future<bool> showDocumentUploadSheet(
  BuildContext context, {
  required DocumentType documentType,
}) async {
  final picked = await showModalBottomSheet<_PickedFile>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _PickerOptionsSheet(documentType: documentType),
  );
  if (picked == null || !context.mounted) return false;

  DateTime? expiresAt;
  if (documentType.typicallyHasExpiry) {
    expiresAt = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'تاريخ انتهاء الصلاحية (اختياري)',
      cancelText: 'تخطي',
      confirmText: 'تأكيد',
    );
    if (!context.mounted) return false;
  }

  final progress = ValueNotifier<String>('جارٍ الرفع...');
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _UploadProgressDialog(progress: progress),
  );

  try {
    progress.value = 'جارٍ الرفع...';
    final upload = CaptainDocumentsRepository.instance.uploadDocument(
      documentType: documentType,
      bytes: picked.bytes,
      fileName: picked.fileName,
      mimeType: picked.mimeType,
      expiresAt: expiresAt,
    );
    // The Storage upload and the RPC metadata write happen sequentially
    // inside uploadDocument - flip the label partway through so the
    // operator sees two distinct stages instead of one frozen spinner.
    unawaited(
      Future.delayed(const Duration(milliseconds: 900), () {
        progress.value = 'جارٍ الحفظ...';
      }),
    );
    await upload;

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم رفع ${documentType.labelArabic} بنجاح، بانتظار المراجعة.',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return true;
  } catch (e, st) {
    debugPrint('[DocumentUpload] failed for ${documentType.dbValue}: $e');
    debugPrint('$st');
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _describeUploadError(e, documentType),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return false;
  }
}

String _describeUploadError(Object e, DocumentType type) {
  if (e is ArgumentError) {
    final message = e.message?.toString() ?? '';
    if (message.contains('10MB')) {
      return 'حجم الملف أكبر من الحد المسموح به (10 ميغابايت)';
    }
    if (message.contains('Unsupported')) {
      return 'صيغة الملف غير مدعومة - يُسمح فقط بـ JPG أو PNG أو PDF';
    }
  }
  return 'تعذر رفع ${type.labelArabic}، حاول مجدداً';
}

class _PickedFile {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const _PickedFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

class _PickerOptionsSheet extends StatelessWidget {
  final DocumentType documentType;

  const _PickerOptionsSheet({required this.documentType});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? xfile;
    try {
      xfile = await picker.pickImage(source: source, imageQuality: 85);
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final ext = xfile.name.contains('.')
        ? xfile.name.split('.').last.toLowerCase()
        : 'jpg';
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    if (context.mounted) {
      Navigator.of(context).pop(
        _PickedFile(bytes: bytes, fileName: xfile.name, mimeType: mimeType),
      );
    }
  }

  Future<void> _pickPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (context.mounted) {
      Navigator.of(context).pop(
        _PickedFile(
          bytes: file.bytes!,
          fileName: file.name,
          mimeType: 'application/pdf',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              documentType.labelArabic,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.camera_alt_rounded,
              label: 'التقاط صورة بالكاميرا',
              onTap: () => _pickImage(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.photo_library_rounded,
              label: 'اختيار من المعرض',
              onTap: () => _pickImage(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.picture_as_pdf_rounded,
              label: 'اختيار ملف PDF',
              onTap: () => _pickPdf(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadProgressDialog extends StatelessWidget {
  final ValueNotifier<String> progress;

  const _UploadProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: progress,
              builder: (context, value, _) => Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.darkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
