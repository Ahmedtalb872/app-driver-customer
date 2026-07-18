import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

enum RideAlertVolume { low, medium, high }

/// Single source of truth for the captain "new ride request" alert
/// (sound + vibration). A singleton so there can only ever be one
/// [AudioPlayer]/vibration pattern active at a time, however many places in
/// the app might ask for an alert to start - `start()` is a no-op while
/// already running, and every stop path funnels through [stop] so sound and
/// vibration are always cancelled together.
class RideAlertService {
  RideAlertService._();

  static final RideAlertService instance = RideAlertService._();

  static const String _assetPath = 'audio/hudhud_ride_request.wav';

  final AudioPlayer _player = AudioPlayer();
  Timer? _repeatTimer;
  bool _isAlerting = false;

  bool get isAlerting => _isAlerting;

  double _volumeToLevel(RideAlertVolume volume) {
    switch (volume) {
      case RideAlertVolume.low:
        return 0.35;
      case RideAlertVolume.medium:
        return 0.7;
      case RideAlertVolume.high:
        return 1.0;
    }
  }

  /// Starts repeating sound + vibration for an active incoming request.
  /// Safe to call multiple times in a row - only the first call while
  /// already alerting has any effect, preventing overlapping sounds.
  Future<void> start({
    required bool soundEnabled,
    required bool vibrationEnabled,
    required RideAlertVolume volume,
  }) async {
    if (_isAlerting) return;
    _isAlerting = true;

    if (soundEnabled) {
      await _playOnce(volume);
      _repeatTimer?.cancel();
      _repeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_isAlerting) _playOnce(volume);
      });
    }

    if (vibrationEnabled) {
      await _startVibration();
    }
  }

  Future<void> _playOnce(RideAlertVolume volume) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(_volumeToLevel(volume));
      await _player.play(AssetSource(_assetPath));
    } catch (_) {
      // A missing/broken asset or platform audio failure must never crash
      // the incoming-ride flow - the dialog and vibration still work.
    }
  }

  Future<void> _startVibration() async {
    try {
      // Cancel any leftover pattern before starting a new one.
      Vibration.cancel();
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400], repeat: 0);
      }
    } catch (_) {
      // Vibration is a nice-to-have; never fatal if unsupported.
    }
  }

  /// Stops sound and vibration immediately. Called from every exit path:
  /// accept, ignore, countdown expiry, passenger cancellation, another
  /// captain accepting, logout, and switching offline.
  Future<void> stop() async {
    _isAlerting = false;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  /// Plays the alert once at the given volume, for the settings screen's
  /// preview button. Stops any currently-looping alert or previous preview
  /// first so previews never overlap each other or a live alert.
  Future<void> previewOnce(RideAlertVolume volume) async {
    await stop();
    await _playOnce(volume);
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
