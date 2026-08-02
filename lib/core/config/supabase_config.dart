import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cronet_http_client.dart';

/// Central place that owns Supabase initialization and exposes the
/// singleton client used across the app.
class SupabaseConfig {
  SupabaseConfig._();

  static bool _initialized = false;

  /// Loads credentials from the bundled `.env` file and initializes the
  /// Supabase client. Must be called once, before any [client] access,
  /// typically at app startup in `main()`.
  static Future<void> initialize() async {
    if (_initialized) return;

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Copy .env.example to .env and fill in your Supabase project values.',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      httpClient: buildAndroidCronetHttpClient(),
    );
    _initialized = true;
  }

  /// The shared Supabase client. Only valid after [initialize] has run.
  static SupabaseClient get client => Supabase.instance.client;
}
