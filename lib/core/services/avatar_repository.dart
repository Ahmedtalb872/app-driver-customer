import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../config/supabase_config.dart';

/// Uploads a customer's own profile photo to the public `customer-avatars`
/// Storage bucket (20260812000068_customer_avatar_upload.sql) and points
/// `customers.avatar_url` at it. Unlike [CaptainDocumentsRepository]'s
/// private, signed-URL bucket for sensitive verification files, this
/// bucket is public - a profile photo is meant to be freely viewable, the
/// same way `captains.avatar_url` already works.
class AvatarRepository {
  AvatarRepository._();

  static final AvatarRepository instance = AvatarRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  static const String bucket = 'customer-avatars';
  static const int maxFileSizeBytes = 5 * 1024 * 1024;
  static const Map<String, String> _extensionByMimeType = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  /// Uploads [bytes] and updates `customers.avatar_url` in one call,
  /// returning the new public URL. Throws [ArgumentError] for a client-
  /// side-catchable size/type problem, or the raw Supabase exception for
  /// anything else - the caller shows a clear Arabic error either way,
  /// never swallows it.
  Future<String> uploadCustomerAvatar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final customerId = AuthService.instance.currentUser?.id;
    if (customerId == null) {
      throw StateError('No signed-in customer to upload an avatar for');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw ArgumentError('File exceeds the 5MB limit');
    }
    final extension = _extensionByMimeType[mimeType];
    if (extension == null) {
      throw ArgumentError('Unsupported file type: $mimeType');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'customers/$customerId/$timestamp.$extension';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

    await _client
        .from('customers')
        .update({'avatar_url': publicUrl})
        .eq('id', customerId);

    return publicUrl;
  }

  /// The signed-in customer's current avatar URL, or null if never set.
  Future<String?> fetchMyAvatarUrl() async {
    final customerId = AuthService.instance.currentUser?.id;
    if (customerId == null) return null;
    final row = await _client
        .from('customers')
        .select('avatar_url')
        .eq('id', customerId)
        .maybeSingle();
    return row?['avatar_url'] as String?;
  }
}
