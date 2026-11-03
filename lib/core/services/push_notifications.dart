import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/supabase_config.dart';

/// Registers this device for admin-broadcast push notifications (see
/// supabase/functions/send-broadcast-push and /admin/notifications) and
/// keeps `customers.fcm_token` in sync with the server. Every broadcast is
/// sent as a real FCM *notification* (title + body, not data-only), so the
/// OS shows it in the system tray on its own even while the app is
/// backgrounded or fully killed - no custom background handler needed
/// here, unlike the captain app's ring/full-screen new-trip alert.
class PushNotifications {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      _initialized = true;
    } catch (_) {
      // Firebase not configured on this build (e.g. google-services.json
      // missing) or platform doesn't support it (web/desktop) - the app
      // works fine without push, this is purely additive.
    }
  }

  /// Saves this customer's current FCM token and keeps it fresh on
  /// rotation. Call once after a successful login.
  static Future<void> syncToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    } catch (_) {
      // Best-effort - a missed sync just means this device stops
      // receiving broadcasts until the next successful one.
    }
  }

  static Future<void> _saveToken(String token) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseConfig.client
          .from('customers')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (_) {
      // Best-effort, see syncToken above.
    }
  }
}
