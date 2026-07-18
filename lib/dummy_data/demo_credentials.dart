import '../models/models.dart';

/// Local, fully offline demo credentials for reviewing the Hudhud
/// front-end without any backend connection - a phone/password match here
/// never calls Supabase. Unrelated to the real backend-connected demo
/// accounts (see core/config/demo_mode_config.dart), which stay untouched.
class DemoCredentials {
  DemoCredentials._();

  static const String captainPhone = '40000002';
  static const String password = '123456';

  /// Strips everything but digits, then keeps only the last 8 of them (a
  /// Mauritanian local number), so '40000001', '+22240000001' and
  /// '+222 40 00 00 01' all normalize to the same value before comparison.
  static String normalize(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 8) return digits;
    return digits.substring(digits.length - 8);
  }

  /// Returns the matching [UserType] for [rawPhone]/[rawPassword], or null
  /// if they don't match a local demo account. Never logs the password.
  static UserType? matchRole(String rawPhone, String rawPassword) {
    if (rawPassword != password) return null;
    final phone = normalize(rawPhone);
    if (phone == captainPhone) return UserType.captain;
    return null;
  }
}
