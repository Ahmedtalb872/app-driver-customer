import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/services/captain_documents_repository.dart';
import '../../models/models.dart';
import 'document_upload_sheet.dart';

/// Real (Supabase-backed) document upload/status screen - lists all 10
/// document slots (9 mandatory + 1 optional), each independently uploaded/
/// replaced via [showDocumentUploadSheet] and reviewed by an admin through
/// the `admin_approve_document`/`admin_reject_document` RPCs.
class CaptainDocumentsStatusScreen extends StatefulWidget {
  const CaptainDocumentsStatusScreen({super.key});

  @override
  State<CaptainDocumentsStatusScreen> createState() =>
      _CaptainDocumentsStatusScreenState();
}

class _CaptainDocumentsStatusScreenState
    extends State<CaptainDocumentsStatusScreen> {
  bool _loading = true;
  String? _error;
  Map<DocumentType, CaptainDocument> _documents = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await CaptainDocumentsRepository.instance.listMyDocuments();
      if (!mounted) return;
      setState(() {
        _documents = {for (final d in docs) d.documentType: d};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المستندات، حاول مجدداً';
        _loading = false;
      });
    }
  }

  Future<void> _upload(DocumentType type) async {
    final uploaded = await showDocumentUploadSheet(context, documentType: type);
    if (uploaded) _load();
  }

  int get _approvedMandatoryCount => CaptainDocument.mandatoryTypes
      .where((t) => _documents[t]?.status == DocumentStatus.approved)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('حالة المستندات المرفوعة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _CompletionBanner(
                    approved: _approvedMandatoryCount,
                    total: CaptainDocument.mandatoryTypes.length,
                  ),
                  const SizedBox(height: 16),
                  for (final type in CaptainDocument.allTypes) ...[
                    _DocumentCard(
                      documentType: type,
                      document: _documents[type],
                      onUpload: () => _upload(type),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.error),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  final int approved;
  final int total;

  const _CompletionBanner({required this.approved, required this.total});

  @override
  Widget build(BuildContext context) {
    final complete = approved == total;
    final color = complete ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              complete
                  ? 'تم رفع واعتماد جميع المستندات الإلزامية ($approved/$total)'
                  : 'المستندات الإلزامية المعتمدة: $approved/$total - أكمل الرفع لتفعيل حسابك',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentType documentType;
  final CaptainDocument? document;
  final VoidCallback onUpload;

  const _DocumentCard({
    required this.documentType,
    required this.document,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final expired = doc?.isEffectivelyExpired ?? false;
    final effectiveStatus = expired ? DocumentStatus.expired : doc?.status;

    final (color, icon, label) = switch (effectiveStatus) {
      DocumentStatus.approved => (
        AppColors.success,
        Icons.check_circle_outline,
        'مقبول',
      ),
      DocumentStatus.rejected => (
        AppColors.error,
        Icons.cancel_outlined,
        'مرفوض',
      ),
      DocumentStatus.expired => (
        AppColors.secondaryText,
        Icons.timer_off_outlined,
        'منتهي الصلاحية',
      ),
      DocumentStatus.pending => (
        AppColors.warning,
        Icons.hourglass_empty_rounded,
        'قيد المراجعة',
      ),
      null => (
        AppColors.secondaryText,
        Icons.upload_file_rounded,
        'لم يُرفع بعد',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    documentType.labelArabic,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (doc != null) ...[
              const SizedBox(height: 12),
              _DocumentPreview(document: doc),
              if (doc.status == DocumentStatus.rejected &&
                  (doc.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'سبب الرفض: ${doc.rejectionReason}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (doc != null)
                        Text(
                          'تم الرفع: ${DateFormat('yyyy-MM-dd').format(doc.uploadedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      if (doc?.expiresAt != null)
                        Text(
                          'ينتهي في: ${DateFormat('yyyy-MM-dd').format(doc!.expiresAt!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: expired
                                ? AppColors.error
                                : AppColors.secondaryText,
                            fontWeight: expired
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    doc == null ? Icons.upload_rounded : Icons.refresh_rounded,
                    size: 16,
                  ),
                  label: Text(
                    doc == null ? 'رفع المستند' : 'استبدال المستند',
                    style: const TextStyle(fontSize: 11, fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lazily fetches a signed URL and shows an image thumbnail, or a PDF icon
/// with an "open" action for non-image documents - both bucket reads
/// respect `storage.objects` RLS (owner or admin only).
class _DocumentPreview extends StatelessWidget {
  final CaptainDocument document;

  const _DocumentPreview({required this.document});

  bool get _isImage => document.mimeType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: CaptainDocumentsRepository.instance.getSignedUrl(
        document.filePath,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final url = snapshot.data!;
        if (_isImage) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox(
                height: 60,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          );
        }
        return InkWell(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  document.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}
