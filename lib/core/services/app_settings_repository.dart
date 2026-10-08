import '../config/supabase_config.dart';

/// Thin reader for the admin-configured `app_settings` singleton row (see
/// AdminSettingsRepository/AdminSettingsScreen, which already let an admin
/// set "هاتف الدعم") - just the one field the customer app needs so far:
/// a real phone number to offer as the "مكالمة عادية" fallback next to
/// every in-app call button, in case the WebRTC call can't connect (no
/// mic permission, a restrictive network, no TURN server configured).
class AppSettingsRepository {
  AppSettingsRepository._();
  static final instance = AppSettingsRepository._();

  /// Null for "not configured" and for any fetch failure alike - every
  /// caller already treats a null phone as "no regular-call fallback to
  /// offer", not an error to surface to the customer.
  Future<String?> fetchSupportPhone() async {
    try {
      final row = await SupabaseConfig.client
          .from('app_settings')
          .select('support_phone')
          .eq('id', true)
          .maybeSingle();
      final phone = row?['support_phone'] as String?;
      if (phone == null || phone.trim().isEmpty) return null;
      return phone.trim();
    } catch (_) {
      return null;
    }
  }
}
