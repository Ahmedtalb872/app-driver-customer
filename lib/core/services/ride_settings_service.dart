import 'package:shared_preferences/shared_preferences.dart';

import 'ride_alert_service.dart';

/// Persisted captain alert preferences (sound/vibration/volume). Stored
/// locally via `shared_preferences` - no prior settings persistence existed
/// anywhere in this app (the existing `settings_screen.dart` switches are
/// all in-memory-only `setState`, per the architecture report), so this is
/// the first real persisted-settings surface, kept intentionally scoped to
/// just these ride-alert preferences rather than generalizing the whole
/// settings screen.
class RideSettingsService {
  RideSettingsService._();

  static final RideSettingsService instance = RideSettingsService._();

  static const _kSoundEnabled = 'ride_alert_sound_enabled';
  static const _kVibrationEnabled = 'ride_alert_vibration_enabled';
  static const _kVolume = 'ride_alert_volume';

  bool soundEnabled = true;
  bool vibrationEnabled = true;
  RideAlertVolume volume = RideAlertVolume.medium;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    soundEnabled = prefs.getBool(_kSoundEnabled) ?? true;
    vibrationEnabled = prefs.getBool(_kVibrationEnabled) ?? true;
    final volumeName = prefs.getString(_kVolume);
    volume = RideAlertVolume.values.firstWhere(
      (v) => v.name == volumeName,
      orElse: () => RideAlertVolume.medium,
    );
    _loaded = true;
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSoundEnabled, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrationEnabled, value);
  }

  Future<void> setVolume(RideAlertVolume value) async {
    volume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVolume, value.name);
  }
}
