import 'dart:io' show Platform;

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';

/// Android specifically has been observed, on more than one physical
/// device/network, to fail dart:io's raw sockets outright -
/// `SocketException: Failed host lookup`, and even a hardcoded
/// DNS-over-HTTPS provider IP connection came back `Operation not
/// permitted` - while the exact same devices' browsers never have any
/// trouble reaching the exact same host. Cronet is Android's own native
/// network stack (the one Chrome itself is built on), so routing
/// Supabase's traffic through it inherits whatever lets the browser
/// succeed where Dart's raw sockets don't. Returns null on iOS/desktop,
/// which leaves supabase_flutter's own default client untouched there.
///
/// This file must never be imported directly - always go through
/// cronet_http_client.dart, whose conditional import keeps this (and the
/// `cronet_http`/`jni` packages it pulls in) out of web builds entirely,
/// since `package:jni`'s generated FFI bindings don't compile for web at
/// all, even when merely imported and never called.
Client? buildAndroidCronetHttpClient() {
  if (!Platform.isAndroid) return null;
  final engine = CronetEngine.build(
    cacheMode: CacheMode.memory,
    cacheMaxSize: 2 * 1024 * 1024,
  );
  return CronetClient.fromCronetEngine(engine, closeEngine: true);
}
