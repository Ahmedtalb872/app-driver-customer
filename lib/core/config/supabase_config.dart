import 'dart:async';

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
  ///
  /// Retries a few times on failure before giving up: `main()` only calls
  /// this once at cold start, and [_initialized] never gets set on a
  /// throw, so without a retry here a single transient blip (this app has
  /// seen real devices intermittently fail every DNS lookup for a moment -
  /// see DohFallbackHttpOverrides) would leave [client] permanently
  /// throwing `LateInitializationError` for the rest of that app session,
  /// even once connectivity recovers a second later.
  ///
  /// The first attempt uses Cronet (Android's own network stack, routed
  /// through Google Play Services' Cronet module - see
  /// cronet_http_client_io.dart for why). That module is one more moving
  /// part that can itself fail to load independently of the actual
  /// network, and unlike a plain connectivity blip that isn't something a
  /// same-path retry can recover from - so every attempt after the first
  /// falls back to Supabase's own default client instead, which is still
  /// covered by [DohFallbackHttpOverrides] for the exact DNS failures
  /// Cronet was originally added to work around.
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

    const maxAttempts = 4;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
          httpClient: attempt == 1 ? buildAndroidCronetHttpClient() : null,
        ).timeout(const Duration(seconds: 8));
        _initialized = true;
        return;
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 700 * attempt));
      }
    }
  }

  /// The shared Supabase client. Only valid after [initialize] has run.
  static SupabaseClient get client => Supabase.instance.client;
}
