import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads connection details from --dart-define (or --dart-define-from-file=env.json).
/// See env.json.example for the expected keys.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static bool get isReady => _initialized;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
