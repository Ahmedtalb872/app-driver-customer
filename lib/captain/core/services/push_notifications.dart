import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../supabase/supabase_config.dart';
import 'new_trip_alert.dart';

/// Rings/full-screens the captain for a new-trip push even when the app was
/// fully killed - Android spins up a separate headless Dart isolate to run
/// this, which is the only way an alert can fire without the app already
/// running (in-app Supabase Realtime only works while some Dart code is
/// actually alive). Must stay a top-level function, not a class method, and
/// keep the @pragma so the engine can find it from a cold isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final type = message.data['type'];
  if (type == 'new_trip') {
    await NewTripAlert.initialize();
    await NewTripAlert.play(
      customerName: message.data['customerName'],
      pickup: message.data['pickup'],
    );
  } else if (type == 'trip_cancelled') {
    // The customer cancelled (or another captain claimed it) before this
    // one answered - silences the ring/full-screen alert from the
    // 'new_trip' push above so it doesn't keep going for a request that no
    // longer exists. Harmless no-op if this device was never ringing for
    // it in the first place.
    await NewTripAlert.stop();
  }
}

/// Registers this device for push notifications and keeps
/// `captains.fcm_token` in sync with the server, which is where
/// send-trip-push (see supabase/functions/send-trip-push) looks up who to
/// notify for a new request. Purely additive to the existing in-app
/// Realtime alert (NewTripAlert via AppStateProvider) - that one still
/// covers the app-already-open case; this covers backgrounded/killed.
class PushNotifications {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      await FirebaseMessaging.instance.requestPermission();
      _initialized = true;
    } catch (_) {
      // Firebase not configured on this build (e.g. google-services.json
      // missing) or platform doesn't support it (web/desktop) - push
      // alerts stay off, in-app Realtime alerts still work.
    }
  }

  /// Saves this captain's current FCM token and keeps it fresh on rotation.
  /// Call once after a successful login.
  static Future<void> syncToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    } catch (_) {
      // Best-effort - a missed sync just means push alerts lag behind
      // until the next successful one; Realtime alerts are unaffected.
    }
  }

  static Future<void> _saveToken(String token) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseConfig.client
          .from('captains')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (_) {
      // Best-effort, see syncToken above.
    }
  }
}
