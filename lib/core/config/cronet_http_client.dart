import 'package:http/http.dart';

import 'cronet_http_client_stub.dart'
    if (dart.library.io) 'cronet_http_client_io.dart' as impl;

/// See cronet_http_client_io.dart for why this exists. The conditional
/// import above resolves to the stub (no `cronet_http`/`jni` import at
/// all) on web, and the real Cronet-backed implementation everywhere
/// `dart:io` exists - keeping the web-incompatible `jni` package
/// completely out of any web compilation, not just unused at runtime.
Client? buildAndroidCronetHttpClient() => impl.buildAndroidCronetHttpClient();
