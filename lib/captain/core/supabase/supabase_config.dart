import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for the captain side of the unified app.
///
/// Originally the standalone captain app read its credentials from
/// --dart-define and tracked its own `_initialized` flag, calling
/// `Supabase.initialize` in its own `main()`. In the unified app the global
/// Supabase client is initialized exactly once by the customer-side entry
/// (from the bundled `.env`), and calling `Supabase.initialize` a second
/// time would throw. So [isReady] and [client] here simply reflect that one
/// shared global client - the captain repositories keep working against the
/// same project and the same signed-in session, unchanged, without a second
/// initialization.
class SupabaseConfig {
  // Kept for source compatibility; the unified app does not rely on these
  // being provided via --dart-define anymore.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => isReady;

  /// True once the shared global Supabase client exists. `Supabase.instance`
  /// throws until `Supabase.initialize` has run (done once by the unified
  /// `main()`), so this catches that to report readiness.
  static bool get isReady {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// No-op when the shared client is already up (the unified app's normal
  /// case). Retained only so any lingering direct caller stays harmless; it
  /// will not double-initialize.
  static Future<void> initialize() async {
    if (isReady) return;
    if (url.isEmpty || anonKey.isEmpty) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
