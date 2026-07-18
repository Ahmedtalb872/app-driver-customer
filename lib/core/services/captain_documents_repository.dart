import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../auth/auth_service.dart';
import '../config/supabase_config.dart';

/// Real (Supabase-backed) captain document upload/list/signed-URL access.
/// Every write goes through the `captain_upload_document` SECURITY DEFINER
/// RPC (20260717000034_captain_documents.sql) - this class never inserts
/// into or updates `captain_documents` directly, matching the project-wide
/// singleton-repository convention (RideRepository, AuthService).
class CaptainDocumentsRepository {
  CaptainDocumentsRepository._();

  static final CaptainDocumentsRepository instance =
      CaptainDocumentsRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  static const String bucket = 'captain-documents';
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'application/pdf',
  ];

  Future<List<CaptainDocument>> listMyDocuments() async {
    final captainId = AuthService.instance.currentUser?.id;
    if (captainId == null) return [];
    final rows = await _client
        .from('captain_documents')
        .select()
        .eq('captain_id', captainId);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(CaptainDocument.fromRow).toList();
  }

  /// Uploads [bytes] to Storage at the required
  /// `captains/{captain_id}/{document_type}/{timestamp}_{filename}` path,
  /// then registers/replaces the metadata row via `captain_upload_document`
  /// (which resets status to 'pending' on replace - see the migration).
  /// Throws [ArgumentError] for a client-side-catchable size/type problem,
  /// or the raw Supabase exception for anything else - the caller is
  /// responsible for showing a clear Arabic error, never swallowing it.
  Future<CaptainDocument> uploadDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    DateTime? expiresAt,
  }) async {
    final captainId = AuthService.instance.currentUser?.id;
    if (captainId == null) {
      throw StateError('No signed-in captain to upload a document for');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw ArgumentError('File exceeds the 10MB limit');
    }
    if (!allowedMimeTypes.contains(mimeType)) {
      throw ArgumentError('Unsupported file type: $mimeType');
    }

    final sanitizedFileName = fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'captains/$captainId/${documentType.dbValue}/${timestamp}_$sanitizedFileName';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final row = await _client.rpc(
      'captain_upload_document',
      params: {
        'p_document_type': documentType.dbValue,
        'p_file_path': path,
        'p_file_name': fileName,
        'p_mime_type': mimeType,
        'p_file_size': bytes.length,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      },
    );
    return CaptainDocument.fromRow(Map<String, dynamic>.from(row as Map));
  }

  /// Short-lived signed URL for previewing/downloading a private document.
  /// Respects `storage.objects` RLS - only the owning captain or an admin
  /// can successfully obtain one for a given [path].
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 300}) {
    return _client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }
}
