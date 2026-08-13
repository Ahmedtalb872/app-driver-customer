import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Starts/stops a native Android foreground service (with a persistent,
/// low-priority "جارٍ تتبع مشوارك" notification - Android's own requirement
/// for any foreground service) while a trip is active, so the OS can't
/// kill the app process in the background and silently break trip
/// tracking/realtime updates - see TripTrackingScreen, the only caller,
/// and android/.../TripForegroundService.kt for the native side.
///
/// A no-op on every platform except Android - iOS has its own, far more
/// restrictive background-execution model with no equivalent to an
/// Android foreground service, and this app has no background story
/// there yet.
class TripForegroundService {
  TripForegroundService._();

  static const _channel = MethodChannel(
    'com.alhudhud.customerapp/trip_foreground_service',
  );

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start');
    } catch (_) {
      // Best effort - trip tracking still works while the app stays in the
      // foreground even if this fails.
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
