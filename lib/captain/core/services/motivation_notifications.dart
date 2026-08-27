import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Two daily motivational notifications for the captain - one in the
/// morning, one in the evening - even while the app is closed. Mauritania
/// has a single fixed UTC+0 offset year-round (no DST), so there's no need
/// for device-timezone detection; UTC is used directly as "local" time.
class MotivationNotifications {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _morningId = 1001;
  static const _eveningId = 1002;
  static const _morningHour = 8;
  static const _eveningHour = 19;

  static const _channel = AndroidNotificationDetails(
    'daily_motivation',
    'رسائل تحفيزية',
    channelDescription: 'رسالة تحفيزية صباحية ومسائية للكابتن',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const List<String> _morningMessages = [
    'صباح الخير يا كابتن الهدهد! يوم جديد مليء بالفرص، نتمنى لك رحلة آمنة ومباركة.',
    'صباح النشاط! كل مشوار اليوم خطوة نحو هدفك - بالتوفيق يا كابتن.',
    'صباح الخير! ابدأ يومك بثقة، الطريق أمامك مفتوح والرزق بيد الله.',
    'يوم جديد، فرصة جديدة. نتمنى لك صباحًا هادئًا ومشاوير موفقة.',
    'صباح الخير يا شريك الهدهد! جهدك اليوم لا يضيع، بالتوفيق.',
  ];

  static const List<String> _eveningMessages = [
    'مساء الخير يا كابتن الهدهد! شكرًا لجهدك اليوم، نتمنى لك أمسية هادئة وراحة مستحقة.',
    'مساء الخير! يوم آخر أنجزته بجد - فخورين بك شريك الهدهد.',
    'مساء الخير يا كابتن، إلى الراحة الآن، وغدًا يوم جديد بإذن الله.',
    'شكرًا على تعبك اليوم يا كابتن الهدهد، مساءً طيبًا لك ولعائلتك.',
    'مساء الخير! كل مشوار قدّمته اليوم كان فرقًا لأحدهم - بالتوفيق دائمًا.',
  ];

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _initialized = true;
      await _reschedule();
    } catch (_) {
      // Not supported on this platform (e.g. web); notifications stay off.
    }
  }

  // Cancels and re-creates both daily notifications with a freshly-picked
  // message each time the app launches - they still fire daily via the OS
  // (matchDateTimeComponents.time) even if the captain doesn't reopen the
  // app for a while, just with whatever message was picked last time.
  static Future<void> _reschedule() async {
    final random = Random();
    await _notifications.cancel(_morningId);
    await _notifications.cancel(_eveningId);
    await _scheduleDaily(
      id: _morningId,
      hour: _morningHour,
      title: 'صباح الخير يا كابتن',
      body: _morningMessages[random.nextInt(_morningMessages.length)],
    );
    await _scheduleDaily(
      id: _eveningId,
      hour: _eveningHour,
      title: 'مساء الخير يا كابتن',
      body: _eveningMessages[random.nextInt(_eveningMessages.length)],
    );
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Exact/inexact alarm scheduling not permitted on this device; the
      // captain just won't get the daily nudge, nothing else is affected.
    }
  }
}
