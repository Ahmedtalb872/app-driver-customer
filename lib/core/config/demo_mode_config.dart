import 'package:flutter/foundation.dart';

import '../auth/app_role.dart';

/// Single source of truth for Hudhud's fixed-code demo/QA accounts.
///
/// [isEnabled] is derived from `kReleaseMode`, itself a compile-time
/// constant (`const bool.fromEnvironment('dart.vm.product')`). Because of
/// that, [demoAccounts] below is a const conditional expression: in a
/// `flutter build ... --release` binary the compiler resolves [isEnabled]
/// to `false` at compile time and dead-code-eliminates the `true` branch -
/// including every demo phone number/code literal - out of the build
/// entirely. They never ship in a production artifact. In debug/profile
/// builds (`flutter run`, `flutter run --profile`) the real map is present
/// and the fixed codes work.
///
/// This is the only file that needs to change to add/remove a demo
/// account or to flip demo mode off entirely.
class DemoModeConfig {
  DemoModeConfig._();

  static const bool isEnabled = !kReleaseMode;

  static const Map<String, DemoAccount> demoAccounts = isEnabled
      ? _demoAccounts
      : <String, DemoAccount>{};

  static const Map<String, DemoAccount> _demoAccounts = {
    '+22240000002': DemoAccount(
      code: '222222',
      fullName: 'كابتن تجريبي',
      role: AppRole.captain,
      internalPassword: 'hudhud_demo_22240000002_222222_2026',
    ),
    '+22240000003': DemoAccount(
      code: '333333',
      fullName: 'مدير تجريبي',
      role: AppRole.admin,
      internalPassword: 'hudhud_demo_22240000003_333333_2026',
    ),
  };

  static bool isDemoPhone(String phone) =>
      isEnabled && demoAccounts.containsKey(phone);

  static bool verifyCode(String phone, String code) =>
      isEnabled && demoAccounts[phone]?.code == code;

  /// Phone number of the demo captain account that should always report
  /// (and stay) online during development - see [CaptainSession] - so
  /// testers don't have to remember to flip it on after every sign-in.
  /// Null outside debug/profile builds since [demoAccounts] is empty there.
  static String? get alwaysOnlineCaptainPhone {
    if (!isEnabled) return null;
    for (final entry in demoAccounts.entries) {
      if (entry.value.role == AppRole.captain) return entry.key;
    }
    return null;
  }
}

class DemoAccount {
  const DemoAccount({
    required this.code,
    required this.fullName,
    required this.role,
    required this.internalPassword,
  });

  /// The fixed 6-digit code the tester types in place of a real SMS OTP.
  final String code;

  final String fullName;

  final AppRole role;

  /// Never shown in any UI and never sent over the wire as a "password".
  /// Supabase Auth has no API to mint a session from a client-known fixed
  /// code without a real OTP challenge behind it, so [AuthService] uses
  /// this only as an internal credential to reuse the app's existing
  /// phone -> synthetic-email sign-in for this one demo identity, strictly
  /// after the fixed [code] above has already been checked. Compiled out
  /// of release builds along with everything else in this class.
  final String internalPassword;
}
