import 'dart:io' show Platform;

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' show Client;
import 'package:supabase_flutter/supabase_flutter.dart';

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
      httpClient: _buildHttpClient(),
    );
    _initialized = true;
  }

  /// Android specifically has been observed, on more than one physical
  /// device/network, to fail dart:io's raw sockets outright -
  /// `SocketException: Failed host lookup`, and even a hardcoded
  /// DNS-over-HTTPS provider IP connection came back `Operation not
  /// permitted` - while the exact same devices' browsers never have any
  /// trouble reaching the exact same host. Cronet is Android's own native
  /// network stack (the one Chrome itself is built on), so routing
  /// Supabase's traffic through it inherits whatever lets the browser
  /// succeed where Dart's raw sockets don't. Returns null everywhere else
  /// (web, iOS, desktop), which leaves supabase_flutter's own default
  /// client untouched there.
  static Client? _buildHttpClient() {
    if (kIsWeb || !Platform.isAndroid) return null;
    final engine = CronetEngine.build(
      cacheMode: CacheMode.memory,
      cacheMaxSize: 2 * 1024 * 1024,
    );
    return CronetClient.fromCronetEngine(engine, closeEngine: true);
  }

  /// The shared Supabase client. Only valid after [initialize] has run.
  static SupabaseClient get client => Supabase.instance.client;
}
