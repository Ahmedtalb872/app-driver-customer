import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/captain_documents_repository.dart';
import '../../../models/models.dart';
import '../../core/admin_colors.dart';
import '../../models/captain_admin_view.dart';
import '../../repositories/admin_captains_repository.dart';
import '../../widgets/confirm_dialog.dart';

class CaptainDetailPanel extends StatefulWidget {
  final CaptainAdminView captain;
  final VoidCallback onChanged;

  const CaptainDetailPanel({
    super.key,
    required this.captain,
    required this.onChanged,
  });

  @override
  State<CaptainDetailPanel> createState() => _CaptainDetailPanelState();
}

class _CaptainDetailPanelState extends State<CaptainDetailPanel> {
  final _repository = AdminCaptainsRepository();
  late final TextEditingController _notesController;
  List<Map<String, dynamic>> _trips = [];
  bool _loadingTrips = true;

  Map<DocumentType, CaptainDocument> _documents = {};
  bool _loadingDocuments = true;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.captain.adminNotes ?? '',
    );
    _loadTrips();
    _loadDocuments();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    final trips = await _repository.loadTripHistory(widget.captain.id);
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _loadingTrips = false;
    });
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocuments = true);
    try {
      final docs = await _repository.loadDocuments(widget.captain.id);
      if (!mounted) return;
      setState(() {
        _documents = {for (final d in docs) d.documentType: d};
        _loadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _saveNotes() async {
    await _repository.updateAdminNotes(
      widget.captain.id,
      _notesController.text.trim(),
    );
    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  /// Only refuses server-side when the captain has trip history (see
  /// admin_delete_captain / [CaptainHasTripHistoryException]).
  Future<void> _deleteCaptain() async {
    final reason = await showReasonDialog(
      context,
      title: 'حذف ملف ${widget.captain.fullName} نهائياً - سبب الحذف (إلزامي)',
      hint: 'هذا الإجراء لا يمكن التراجع عنه',
    );
    if (reason == null) return;
    try {
      await _repository.delete(widget.captain.id, reason);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } on CaptainHasTripHistoryException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن حذف كابتن له سجل رحلات سابقة - استخدم إيقاف الحساب بدلاً من ذلك.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر حذف الملف، تحقق من صلاحياتك وحاول مجدداً.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _approveDocument(CaptainDocument doc) async {
    final ok = await showConfirmDialog(
      context,
      title: 'اعتماد المستند',
      message: 'هل تريد اعتماد "${doc.documentType.labelArabic}"؟',
    );
    if (!ok) return;
    try {
      await _repository.approveDocument(doc.id);
      _loadDocuments();
    } catch (_) {
      _showDocError();
    }
  }

  Future<void> _rejectDocument(CaptainDocument doc) async {
    final reason = await showReasonDialog(
      context,
      title: 'سبب رفض "${doc.documentType.labelArabic}" (إلزامي)',
    );
    if (reason == null) return;
    try {
      await _repository.rejectDocument(doc.id, reason);
      _loadDocuments();
    } catch (_) {
      _showDocError();
    }
  }

  /// Same reject RPC as [_rejectDocument] - the 4 stored statuses don't
  /// include a separate "replacement requested" state, so this is a reject
  /// with dialog copy that tells the captain to re-upload.
  Future<void> _requestReplacement(CaptainDocument doc) async {
    final reason = await showReasonDialog(
      context,
      title: 'طلب استبدال "${doc.documentType.labelArabic}" - وضّح السبب',
      hint: 'مثال: الصورة غير واضحة، يرجى إعادة الرفع',
    );
    if (reason == null) return;
    try {
      await _repository.rejectDocument(doc.id, reason);
      _loadDocuments();
    } catch (_) {
      _showDocError();
    }
  }

  void _showDocError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تعذر تنفيذ الإجراء، تحقق من صلاحياتك وحاول مجدداً.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  int get _approvedMandatoryCount => CaptainDocument.mandatoryTypes
      .where((t) => _documents[t]?.status == DocumentStatus.approved)
      .length;

  @override
  Widget build(BuildContext context) {
    final captain = widget.captain;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                captain.fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                captain.phone ?? '-',
                style: const TextStyle(
                  color: AdminColors.textSecondary,
                  fontFamily: 'Cairo',
                ),
              ),
              const Divider(height: 32),

              _sectionTitle('البيانات الشخصية'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DocumentThumbnail(
                    document: _documents[DocumentType.profilePhoto],
                    fallbackIcon: Icons.person_rounded,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _infoTile('رقم الهاتف', captain.phone ?? '-'),
                        _infoTile('البريد الإلكتروني', captain.email ?? '-'),
                        _infoTile(
                          'تاريخ الميلاد',
                          captain.dateOfBirth != null
                              ? DateFormat(
                                  'yyyy-MM-dd',
                                ).format(captain.dateOfBirth!)
                              : '-',
                        ),
                        _infoTile('المدينة', captain.city ?? '-'),
                        _infoTile('العنوان', captain.address ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'لا يوجد رقم بطاقة هوية نصي منفصل في النظام - راجع صور بطاقة '
                'الهوية في قسم المستندات أدناه.',
                style: TextStyle(
                  fontSize: 11,
                  color: AdminColors.textSecondary,
                  fontFamily: 'Cairo',
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle('معلومات السيارة'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DocumentThumbnail(
                    document: _documents[DocumentType.vehiclePhoto],
                    fallbackIcon: Icons.directions_car_rounded,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _infoTile('النوع', captain.vehicleType ?? '-'),
                        _infoTile('الماركة', captain.vehicleBrand ?? '-'),
                        _infoTile('الموديل', captain.vehicleModel ?? '-'),
                        _infoTile('السنة', '${captain.vehicleYear ?? '-'}'),
                        _infoTile('اللون', captain.vehicleColor ?? '-'),
                        _infoTile('اللوحة', captain.vehiclePlate ?? '-'),
                        _infoTile('المقاعد', '${captain.vehicleSeats ?? '-'}'),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _sectionTitle('المستندات'),
              const SizedBox(height: 8),
              if (_loadingDocuments)
                const Center(child: CircularProgressIndicator())
              else ...[
                _CompletionTile(
                  approved: _approvedMandatoryCount,
                  total: CaptainDocument.mandatoryTypes.length,
                ),
                const SizedBox(height: 12),
                ...CaptainDocument.allTypes.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdminDocumentCard(
                      documentType: type,
                      document: _documents[type],
                      onApprove: _documents[type] == null
                          ? null
                          : () => _approveDocument(_documents[type]!),
                      onReject: _documents[type] == null
                          ? null
                          : () => _rejectDocument(_documents[type]!),
                      onRequestReplacement: _documents[type] == null
                          ? null
                          : () => _requestReplacement(_documents[type]!),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                      'رصيد المحفظة',
                      captain.walletBalance.toStringAsFixed(0),
                    ),
                  ),
                ],
              ),
              if (captain.rejectionReason != null) ...[
                const SizedBox(height: 12),
                _infoTile('سبب آخر رفض/إيقاف', captain.rejectionReason!),
              ],
              const SizedBox(height: 24),
              _sectionTitle('ملاحظات إدارية'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'أضف ملاحظة...'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _saveNotes,
                  child: const Text('حفظ الملاحظة'),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('آخر الرحلات'),
              const SizedBox(height: 8),
              if (_loadingTrips)
                const Center(child: CircularProgressIndicator())
              else if (_trips.isEmpty)
                const Text(
                  'لا توجد رحلات بعد.',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontFamily: 'Cairo',
                  ),
                )
              else
                ..._trips.map(
                  (trip) => ListTile(
                    dense: true,
                    title: Text(
                      trip['destination_address'] as String? ?? 'غير محدد',
                    ),
                    subtitle: Text(trip['status'] as String? ?? ''),
                    trailing: Text('${trip['captain_net_earnings'] ?? '-'}'),
                  ),
                ),
              const Divider(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _deleteCaptain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.error,
                    side: const BorderSide(color: AdminColors.error),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف ملف الكابتن نهائياً'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
    );
  }

  Widget _infoTile(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AdminColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  final int approved;
  final int total;

  const _CompletionTile({required this.approved, required this.total});

  @override
  Widget build(BuildContext context) {
    final complete = approved == total;
    final color = complete ? AdminColors.success : AdminColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$approved/$total مستندات إلزامية معتمدة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDocumentCard extends StatelessWidget {
  final DocumentType documentType;
  final CaptainDocument? document;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRequestReplacement;

  const _AdminDocumentCard({
    required this.documentType,
    required this.document,
    required this.onApprove,
    required this.onReject,
    required this.onRequestReplacement,
  });

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final expired = doc?.isEffectivelyExpired ?? false;
    final effectiveStatus = expired ? DocumentStatus.expired : doc?.status;

    final (color, label) = switch (effectiveStatus) {
      DocumentStatus.approved => (AdminColors.success, 'مقبول'),
      DocumentStatus.rejected => (AdminColors.error, 'مرفوض'),
      DocumentStatus.expired => (AdminColors.textSecondary, 'منتهي الصلاحية'),
      DocumentStatus.pending => (AdminColors.warning, 'قيد المراجعة'),
      null => (AdminColors.textSecondary, 'لم يُرفع بعد'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocumentThumbnail(document: doc, fallbackIcon: Icons.description),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        documentType.labelArabic,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (doc != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'رُفع: ${DateFormat('yyyy-MM-dd').format(doc.uploadedAt)}'
                    '${doc.expiresAt != null ? ' • ينتهي: ${DateFormat('yyyy-MM-dd').format(doc.expiresAt!)}' : ''}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AdminColors.textSecondary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (doc.reviewedAt != null)
                    Text(
                      'روجع: ${DateFormat('yyyy-MM-dd').format(doc.reviewedAt!)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AdminColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  if (doc.status == DocumentStatus.rejected &&
                      (doc.rejectionReason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'السبب: ${doc.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.error,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (doc.status != DocumentStatus.approved)
                        _actionChip('اعتماد', AdminColors.success, onApprove),
                      if (doc.status != DocumentStatus.rejected)
                        _actionChip('رفض', AdminColors.error, onReject),
                      _actionChip(
                        'طلب استبدال',
                        AdminColors.warning,
                        onRequestReplacement,
                      ),
                      _actionChip(
                        'تنزيل',
                        AdminColors.textSecondary,
                        () => _openDocument(context, doc),
                      ),
                    ],
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'لم يقم الكابتن برفع هذا المستند بعد.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AdminColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, Color color, VoidCallback? onTap) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: color),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      onPressed: onTap,
    );
  }

  /// Opens the document's signed URL in a new browser tab so the admin can
  /// view it full-size and use the browser's own save/download control
  /// (images and PDFs both render natively there) - the same signed-URL
  /// mechanism `_DocumentThumbnail` uses, just reachable from an explicit
  /// action instead of only the PDF thumbnail tap.
  Future<void> _openDocument(BuildContext context, CaptainDocument doc) async {
    try {
      final url = await CaptainDocumentsRepository.instance.getSignedUrl(
        doc.filePath,
      );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح المستند: $e')),
        );
      }
    }
  }
}

/// Lazily fetches a signed URL and shows an image thumbnail, or a document
/// icon with an "open" action for PDFs/missing uploads - same signed-URL
/// mechanism the mobile status screen uses; `storage.objects` RLS grants
/// admins read access to every captain's documents.
class _DocumentThumbnail extends StatelessWidget {
  final CaptainDocument? document;
  final IconData fallbackIcon;

  const _DocumentThumbnail({
    required this.document,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final doc = document;
    if (doc == null) {
      return _placeholder();
    }
    final isImage = doc.mimeType.startsWith('image/');
    return FutureBuilder<String>(
      future: CaptainDocumentsRepository.instance.getSignedUrl(doc.filePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final url = snapshot.data!;
        if (isImage) {
          return InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(24),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    InteractiveViewer(
                      child: Image.network(url, fit: BoxFit.contain),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _placeholder(),
              ),
            ),
          );
        }
        return InkWell(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminColors.border),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AdminColors.error,
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Icon(fallbackIcon, color: AdminColors.textSecondary),
    );
  }
}
