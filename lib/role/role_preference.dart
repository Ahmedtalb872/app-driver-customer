import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which side of the unified app (customer or captain) the user
/// last chose, so a returning user is not asked again unnecessarily.
///
/// This is only a UX convenience for the signed-out cold start. The
/// authoritative source of truth is always the signed-in account's `role`
/// (see [RoleGate]); a saved preference never overrides the real role and
/// never grants access to the wrong side - each side's own splash still
/// enforces its role check exactly as it did as a standalone app.
class RolePreference {
  RolePreference._();

  static const _key = 'hudhud_unified_role';
  static const customer = 'customer';
  static const captain = 'captain';

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, role);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
