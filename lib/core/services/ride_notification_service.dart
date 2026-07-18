import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background/lock-screen ride-request notifications, backed by
/// `flutter_local_notifications` (no notification service existed anywhere
/// in this codebase before - see the architecture report). Owns the single
/// "hudhud_ride_requests" Android notification channel.
///
/// The channel-level sound is the platform default notification sound: a
/// custom tone for a *background* Android notification requires bundling a
/// native `res/raw` resource (a build-time asset, not something this
/// environment can add sight-unseen). The *foreground* alert
/// ([RideAlertService]) does play the real bundled Hudhud tone - see the
/// final implementation report for this split and how to add the native
/// raw-resource sound later if desired.
class RideNotificationService {
  RideNotificationService._();

  static final RideNotificationService instance = RideNotificationService._();

  static const String channelId = 'hudhud_ride_requests';
  static const String channelName = 'طلبات المشاوير';
  static const String channelDescription =
      'إشعارات طلبات المشاوير الجديدة للكباتن';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Web-safe Android check (no `dart:io`/`Platform` - this app also ships
  /// a web build for the admin dashboard, and `dart:io` doesn't compile for
  /// web at all, even on a code path that's only ever reached on mobile at
  /// runtime).
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Called (from the incoming-ride dialog flow) when the user taps a
  /// delivered notification, with the trip id as payload, so the captain
  /// home screen can reopen the incoming-ride dialog for that trip.
  void Function(String tripId)? onNotificationTapped;

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) {
      _initialized = true;
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final tripId = response.payload;
        if (tripId != null && tripId.isNotEmpty) {
          onNotificationTapped?.call(tripId);
        }
      },
    );

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: null,
      showBadge: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showIncomingRide({
    required String tripId,
    required String passengerName,
    required String pickupAddress,
    required String destinationLabel,
    double? estimatedFare,
  }) async {
    if (!_isAndroid) return;
    await initialize();

    final fareText = estimatedFare != null && estimatedFare > 0
        ? ' • ${estimatedFare.toStringAsFixed(0)} أوقية'
        : '';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        ongoing: false,
        autoCancel: true,
      ),
    );

    await _plugin.show(
      tripId.hashCode,
      'مشوار ركاب جديد من $passengerName',
      '$pickupAddress ← $destinationLabel$fareText',
      details,
      payload: tripId,
    );
  }

  Future<void> cancelIncomingRide(String tripId) async {
    if (!_isAndroid) return;
    await _plugin.cancel(tripId.hashCode);
  }
}
