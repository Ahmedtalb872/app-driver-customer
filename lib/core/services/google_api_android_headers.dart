import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// The `X-Android-Package`/`X-Android-Cert` headers Google's REST APIs check
/// an Android-app-restricted key against for a direct (non-SDK) HTTP call -
/// see https://developers.google.com/maps/api-security-best-practices.
/// Shared by every service that reuses the app's Android-restricted Maps
/// SDK key for a plain REST call instead of a separate key (Directions API,
/// Places API, ...), so the package name/cert fingerprint only need to be
/// kept in sync with android/app/build.gradle.kts and android/debug.keystore
/// in one place.
const _androidPackageName = 'com.alhudhud.customerapp';

// SHA-1 of android/debug.keystore's androiddebugkey (hex, no colons) - see
// android/app/build.gradle.kts's signingConfig for the keystore itself.
const _androidCertFingerprint = '51506D306A370A799C20DBF26C78D17F291CB7BA';

/// Empty on every platform except Android, where these two headers are
/// required for Google to accept the Android-restricted key on a direct
/// REST call. Safe to spread into any request's headers map unconditionally
/// - checks [kIsWeb] before ever touching [Platform], since `Platform.*`
/// getters throw on web rather than just returning false.
Map<String, String> googleApiAndroidHeaders() {
  if (kIsWeb || !Platform.isAndroid) return const {};
  return const {
    'X-Android-Package': _androidPackageName,
    'X-Android-Cert': _androidCertFingerprint,
  };
}
