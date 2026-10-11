import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Reads `app_settings.min_supported_version`/`force_update` and compares
/// against the installed app's own version (ignoring the build-number
/// suffix, same as [PackageInfo.version]) to decide whether the splash
/// screen should block navigation behind an update prompt instead of
/// letting the user into the app. The admin dashboard's "إجباري" toggle
/// (AdminSettingsScreen) already wrote these two columns - this is the
/// previously-missing client-side half that actually enforces them.
class VersionGateService {
  VersionGateService._();

  /// Null when no update is required (either `force_update` is off, the
  /// installed version already meets the minimum, or the check itself
  /// failed - e.g. no network yet - in which case the splash screen should
  /// just proceed rather than get stuck).
  static Future<String?> requiredMinVersionOrNull() async {
    try {
      final row = await SupabaseConfig.client
          .from('app_settings')
          .select('min_supported_version, force_update')
          .eq('id', true)
          .single();

      final forceUpdate = row['force_update'] as bool? ?? false;
      final minVersion = row['min_supported_version'] as String?;
      if (!forceUpdate || minVersion == null || minVersion.trim().isEmpty) {
        return null;
      }

      final info = await PackageInfo.fromPlatform();
      if (_isLower(info.version, minVersion)) return minVersion;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Compares two "x.y.z"-style version strings numerically, part by part
  /// (a plain string compare would wrongly put "1.9.0" after "1.10.0").
  /// Missing trailing parts count as 0, so "1.2" == "1.2.0".
  static bool _isLower(String current, String minimum) {
    final a = current.split('.').map(int.tryParse).toList();
    final b = minimum.split('.').map(int.tryParse).toList();
    for (var i = 0; i < a.length || i < b.length; i++) {
      final ai = i < a.length ? (a[i] ?? 0) : 0;
      final bi = i < b.length ? (b[i] ?? 0) : 0;
      if (ai != bi) return ai < bi;
    }
    return false;
  }
}
