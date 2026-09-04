import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../models/models.dart';
import '../models/captain_admin_view.dart';

class AdminCaptainsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<Map<String, double>> _walletBalances(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('wallets')
        .select('user_id, balance')
        .inFilter('user_id', userIds);
    return {
      for (final row in List<Map<String, dynamic>>.from(rows))
        row['user_id'] as String: (row['balance'] as num).toDouble(),
    };
  }

  Future<List<CaptainAdminView>> loadCaptains({
    String? searchQuery,
    String? statusFilter,
    bool? onlineFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('captains').select('*, profiles!inner(*)');

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    if (onlineFilter != null) {
      query = query.eq('is_online', onlineFilter);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or(
        'full_name.ilike.%$q%,phone.ilike.%$q%',
        referencedTable: 'profiles',
      );
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final list = List<Map<String, dynamic>>.from(rows);

    final balances = await _walletBalances(
      list.map((r) => r['id'] as String).toList(),
    );

    return list
        .map(
          (row) => CaptainAdminView.fromJson(
            row,
            walletBalance: balances[row['id']] ?? 0,
          ),
        )
        .toList();
  }

  Future<CaptainAdminView?> loadCaptainById(String id) async {
    final row = await _client
        .from('captains')
        .select('*, profiles!inner(*)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final balances = await _walletBalances([id]);
    return CaptainAdminView.fromJson(row, walletBalance: balances[id] ?? 0);
  }

  Future<List<Map<String, dynamic>>> loadTripHistory(
    String captainId, {
    int limit = 20,
  }) async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('captain_id', captainId)
        .order('requested_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateAdminNotes(String captainId, String notes) async {
    await _client
        .from('captains')
        .update({'admin_notes': notes})
        .eq('id', captainId);
  }

  /// Throws [CaptainDocumentsIncompleteException] when
  /// `admin_approve_captain` rejects the approval because not all 9
  /// mandatory documents are approved yet (see
  /// 20260717000034_captain_documents.sql) - callers should show that
  /// specific reason rather than a generic failure message.
  Future<void> approve(String captainId) async {
    try {
      await _client.rpc(
        'admin_approve_captain',
        params: {'p_captain_id': captainId},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('CAPTAIN_DOCUMENTS_INCOMPLETE')) {
        throw CaptainDocumentsIncompleteException(e.message);
      }
      rethrow;
    }
  }

  Future<void> reject(String captainId, String reason) async {
    await _client.rpc(
      'admin_reject_captain',
      params: {'p_captain_id': captainId, 'p_reason': reason},
    );
  }

  /// All documents (any status) a captain has uploaded, keyed for the
  /// review UI's completion grid - missing types simply have no entry.
  Future<List<CaptainDocument>> loadDocuments(String captainId) async {
    final rows = await _client
        .from('captain_documents')
        .select()
        .eq('captain_id', captainId);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(CaptainDocument.fromRow).toList();
  }

  Future<void> approveDocument(String documentId) async {
    await _client.rpc(
      'admin_approve_document',
      params: {'p_document_id': documentId},
    );
  }

  /// Also used for the "request replacement" action - same RPC, the
  /// dashboard just shows a different dialog title/copy for it (see
  /// captain_detail_panel.dart).
  Future<void> rejectDocument(String documentId, String reason) async {
    await _client.rpc(
      'admin_reject_document',
      params: {'p_document_id': documentId, 'p_reason': reason},
    );
  }

  /// Copies an approved "profile_photo" document (private captain-documents
  /// bucket, owner-or-admin only) into the public captain-avatars bucket and
  /// points captains.avatar_url at it - the customer-facing trip-tracking
  /// screen only ever reads that column, which has otherwise never had
  /// anything write to it (see 20260812000054_captain_avatar_url.sql /
  /// 20260813000069_captain_avatar_from_profile_photo.sql). A no-op for any
  /// other document type. Best-effort by design - callers should treat a
  /// failure here as separate from the document approval itself succeeding.
  Future<void> syncApprovedProfilePhotoToAvatar(CaptainDocument doc) async {
    if (doc.documentType != DocumentType.profilePhoto) return;

    final signedUrl = await _client.storage
        .from('captain-documents')
        .createSignedUrl(doc.filePath, 300);
    final response = await http.get(Uri.parse(signedUrl));
    if (response.statusCode != 200) {
      throw StateError(
        'Failed to download profile photo (${response.statusCode})',
      );
    }

    final contentType = response.headers['content-type'] ?? 'image/jpeg';
    final extension = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
        ? 'webp'
        : 'jpg';
    final path =
        'captains/${doc.captainId}/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage
        .from('captain-avatars')
        .uploadBinary(
          path,
          response.bodyBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final publicUrl = _client.storage.from('captain-avatars').getPublicUrl(path);
    await _client
        .from('captains')
        .update({'avatar_url': publicUrl})
        .eq('id', doc.captainId);
  }

  Future<void> setSuspended(
    String captainId,
    bool suspended, {
    String? reason,
  }) async {
    await _client.rpc(
      'admin_set_captain_suspension',
      params: {
        'p_captain_id': captainId,
        'p_suspended': suspended,
        'p_reason': reason,
      },
    );
  }

  /// Deletes the captain's profile (see
  /// 20260802000050_admin_delete_captain.sql) - the uploaded document
  /// *rows* cascade-delete with it, but the underlying files stay in
  /// Storage (no admin DELETE policy exists on that bucket, and it's the
  /// captain's own account either way - see the migration's comment for why
  /// a full account/file wipe isn't in scope here). Throws
  /// [CaptainHasTripHistoryException] when the captain was ever assigned a
  /// trip - the database itself refuses the delete in that case.
  Future<void> delete(String captainId, String reason) async {
    try {
      await _client.rpc(
        'admin_delete_captain',
        params: {'p_captain_id': captainId, 'p_reason': reason},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('CAPTAIN_HAS_TRIP_HISTORY')) {
        throw CaptainHasTripHistoryException();
      }
      rethrow;
    }
  }

  /// Live version of [loadCaptains](onlineFilter: true): emits the online
  /// captains list immediately, then again on every `captains` row change
  /// (debounced), so Live Operations reflects online/offline toggles
  /// instantly instead of on the next poll.
  Stream<List<CaptainAdminView>> watchOnlineCaptains({int limit = 50}) {
    final controller = StreamController<List<CaptainAdminView>>.broadcast();
    Timer? debounce;

    Future<void> refresh() async {
      try {
        controller.add(await loadCaptains(onlineFilter: true, limit: limit));
      } catch (_) {
        // Transient fetch failure: keep showing the last emitted list.
      }
    }

    final sub = _client.from('captains').stream(primaryKey: ['id']).listen((_) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), refresh);
    });

    refresh();

    controller.onCancel = () async {
      debounce?.cancel();
      await sub.cancel();
    };

    return controller.stream;
  }
}

/// Thrown when `admin_approve_captain` refuses because not every mandatory
/// document is approved yet.
class CaptainDocumentsIncompleteException implements Exception {
  final String rawMessage;

  const CaptainDocumentsIncompleteException(this.rawMessage);
}

/// Thrown when `admin_delete_captain` refuses because the captain has trip
/// history - suspend the account instead of deleting it.
class CaptainHasTripHistoryException implements Exception {}
