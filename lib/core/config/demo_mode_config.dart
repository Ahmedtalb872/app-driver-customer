import 'package:flutter/foundation.dart';

import '../auth/app_role.dart';

/// Single source of truth for Hudhud's fixed-code demo/QA accounts.
///
/// [isEnabled] is derived from `kReleaseMode`, itself a compile-time
/// constant (`const bool.fromEnvironment('dart.vm.product')`). Because of
/// that, [demoAccounts] below is a const conditional expression: in a
/// `flutter build ... --release` binary the compiler resolves [isEnabled]
/// to `false` at compile time and dead-code-eliminates the QA branch -
/// including every QA phone number/code literal - out of the build
/// entirely.
///
/// **One deliberate exception: [reviewerPhone].** App Store and Play Store
/// reviewers have to be able to sign in, and this app's only sign-in path
/// is an SMS OTP to a Mauritanian number - which a reviewer sitting in
/// another country cannot receive. Apple rejects submissions it cannot log
/// into (guideline 2.1), so that single account keeps its fixed code in
/// release builds too. It is a plain customer account with no elevated
/// role, no wallet balance and no admin surface, so the worst case if the
/// number and code leak is that someone browses the app as an empty demo
/// customer.
///
/// This is the only file that needs to change to add/remove an account or
/// to flip demo mode off entirely.
class DemoModeConfig {
  DemoModeConfig._();

  static const bool isEnabled = !kReleaseMode;

  /// Store-reviewer account. Ships in every build - see the class doc.
  static const String reviewerPhone = '+22222441037';

  static const DemoAccount _reviewerAccount = DemoAccount(
    code: '451037',
    fullName: 'حساب المراجعة',
    role: AppRole.customer,
    internalPassword: 'hudhud_reviewer_22441037_a7f3c91e4b2d',
  );

  /// Debug/profile builds get the full QA set; release builds get only the
  /// store-reviewer account.
  static const Map<String, DemoAccount> demoAccounts = isEnabled
      ? _qaAccounts
      : _reviewerOnly;

  static const Map<String, DemoAccount> _reviewerOnly = {
    reviewerPhone: _reviewerAccount,
  };

  static const Map<String, DemoAccount> _qaAccounts = {
    reviewerPhone: _reviewerAccount,
    '+22240000001': DemoAccount(
      code: '111111',
      fullName: 'زبون تجريبي',
      role: AppRole.customer,
      internalPassword: 'hudhud_demo_22240000001_111111_2026',
    ),
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

  /// Deliberately not gated on [isEnabled] - [demoAccounts] is already the
  /// right set for this build, and in a release build it still holds the
  /// store-reviewer account, which must keep working.
  static bool isDemoPhone(String phone) => demoAccounts.containsKey(phone);

  static bool verifyCode(String phone, String code) =>
      demoAccounts[phone]?.code == code;
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
