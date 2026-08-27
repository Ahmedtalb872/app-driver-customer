import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Rings, vibrates, and posts a full-screen-style system notification when a
/// new trip request appears for the captain — mirrors the "new ride" alert
/// in real ride-hailing driver apps: it keeps ringing (not just a single
/// chime) and, on Android, the notification is flagged as a full-screen
/// intent so it pops the app to the front even over the lock screen, the
/// same mechanism used for incoming calls and alarms. Call [stop] the
/// moment the request is accepted, ignored, or times out.
class NewTripAlert {
  static final AudioPlayer _player = AudioPlayer();
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _ringChannel = AndroidNotificationDetails(
    'new_trip_requests',
    'طلبات المشاوير الجديدة',
    channelDescription: 'إشعار عند وصول طلب مشوار جديد',
    importance: Importance.max,
    priority: Priority.high,
    // Pops the app to the foreground over the lock screen/other apps,
    // instead of waiting for the captain to pull down the notification
    // shade - the same category Android gives incoming calls/alarms.
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    ongoing: true,
    autoCancel: false,
  );

  static const _reminderChannel = AndroidNotificationDetails(
    'trip_step_reminders',
    'تذكيرات خطوات المشوار',
    channelDescription: 'تذكير بإكمال خطوة المشوار الحالي',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _initialized = true;
    } catch (_) {
      // Not supported on this platform (e.g. web); notifications stay off.
    }
  }

  // Android 14+ (API 34) added a *separate* permission from the ordinary
  // notification permission for a full-screen-intent notification to
  // actually pop the app open - without it, the new-trip alert still rings
  // and shows a normal heads-up notification, but never wakes/opens the
  // screen like the "درجة الأولوية" call/alarm behavior it's meant to
  // mimic. Older Android versions no-op this call harmlessly. Call once
  // (e.g. from the onboarding permissions screen) - it opens a system
  // settings screen if the permission isn't already granted.
  static Future<void> requestFullScreenIntentPermission() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestFullScreenIntentPermission();
    } catch (_) {
      // Not Android, or plugin doesn't support this on the current OS
      // version - the regular notification still works either way.
    }
  }

  // Keeps ringing/vibrating until stop() is called - callers must stop it
  // once the captain accepts, ignores, or the request times out, or it'll
  // ring indefinitely.
  static Future<void> play({String? customerName, String? pickup}) async {
    unawaited(_vibrateLoop());
    unawaited(_playChimeLoop());
    unawaited(
      _notify(
        id: 0,
        channel: _ringChannel,
        title: 'مشوار ركاب جديد!',
        body: customerName != null && pickup != null
            ? '$customerName - $pickup'
            : 'اضغط لعرض تفاصيل الطلب قبل انتهاء الوقت.',
      ),
    );
  }

  // Stops the ringtone/vibration and clears the ongoing notification -
  // call this the instant the incoming request is accepted, ignored, or
  // its countdown expires.
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
    if (_initialized) {
      try {
        await _notifications.cancel(0);
      } catch (_) {}
    }
  }

  // Nudges the captain (chime + vibration + notification) to complete the
  // current step of an already-active trip, fired every couple of minutes
  // from AppStateProvider so a step doesn't get left hanging unnoticed.
  // Single chime, not a loop - this isn't a time-boxed request to answer.
  static Future<void> playStepReminder(String message) async {
    unawaited(_vibrateOnce());
    unawaited(_playChimeOnce());
    unawaited(
      _notify(
        id: 1,
        channel: _reminderChannel,
        title: 'تذكير بخطوة المشوار',
        body: message,
      ),
    );
  }

  static Future<void> _vibrateOnce() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 350, 150, 350]);
      }
    } catch (_) {
      // No vibration hardware/permission on this platform; ignore.
    }
  }

  static Future<void> _vibrateLoop() async {
    try {
      if (await Vibration.hasVibrator()) {
        // Repeats the buzz-pause pattern from index 0 until Vibration.cancel()
        // is called, like a phone ringing.
        Vibration.vibrate(pattern: [0, 500, 300, 500, 300], repeat: 0);
      }
    } catch (_) {
      // No vibration hardware/permission on this platform; ignore.
    }
  }

  static Future<void> _playChimeOnce() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource('sounds/new_trip_chime.wav'));
    } catch (_) {
      // No audio output available in this environment; ignore.
    }
  }

  static Future<void> _playChimeLoop() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/new_trip_chime.wav'));
    } catch (_) {
      // No audio output available in this environment; ignore.
    }
  }

  static Future<void> _notify({
    required int id,
    required AndroidNotificationDetails channel,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    try {
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(android: channel),
      );
    } catch (_) {
      // Notifications not permitted/available; the in-app alert still shows.
    }
  }
}
