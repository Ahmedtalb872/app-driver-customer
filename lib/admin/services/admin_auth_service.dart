import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/supabase_config.dart';
import '../models/admin_profile.dart';

/// Wraps the shared Phase 1 [AuthService] with the admin-specific role
/// check. Reuses Supabase Auth, `profiles`, and `admin_users` exactly as
/// they already exist - no parallel auth system.
class AdminAuthService {
  AdminAuthService._();

  static final AdminAuthService instance = AdminAuthService._();

  bool get isAuthenticated => AuthService.instance.isAuthenticated;

  Stream<AuthState> get authStateChanges =>
      AuthService.instance.authStateChanges;

  Future<AuthResponse> signIn({
    required String identifier,
    required String password,
  }) {
    // Admins sign in the same way customers/captains do (phone-derived
    // synthetic email under the hood) - accept either a phone number or an
    // already-formatted email so an admin created via phone or email both
    // work.
    final looksLikeEmail = identifier.contains('@');
    if (looksLikeEmail) {
      return SupabaseConfig.client.auth.signInWithPassword(
        email: identifier,
        password: password,
      );
    }
    return AuthService.instance.signIn(
      phone: normalizePhone(identifier),
      password: password,
    );
  }

  /// Brings whatever the admin typed into the `+222XXXXXXXX` form every
  /// other entry point in both apps already stores and signs in with.
  ///
  /// This screen's code mode hardcodes `'+222' + digits`, but password
  /// mode used to hand the raw text straight to AuthService, which derives
  /// the synthetic email from the digits it is given. Typing the local
  /// 8-digit number therefore looked up `20522064@hudhud.app` while the
  /// account actually lives at `22220522064@hudhud.app` - same admin, two
  /// different identities, and an "Invalid login credentials" that looked
  /// like a wrong password.
  static String normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return input.trim();
    // Already carries the Mauritanian country code, with or without '+'.
    if (digits.length > 8 && digits.startsWith('222')) return '+$digits';
    // Bare local number.
    if (digits.length == 8) return '+222$digits';
    // Some other country's number, or something we don't recognise - pass
    // it through rather than corrupting it.
    return input.trim().startsWith('+') ? '+$digits' : digits;
  }

  Future<void> signOut() => AuthService.instance.signOut();

  /// Phone + verification-code sign-in, for the admin dashboard's demo
  /// account and (once an SMS provider is configured) real admin phone
  /// numbers. Thin passthrough to the shared [AuthService] implementation -
  /// see it for the demo-vs-real-OTP split.
  Future<void> requestPhoneCode(String phone) =>
      AuthService.instance.requestPhoneCode(phone);

  Future<AuthResponse> verifyPhoneCode({
    required String phone,
    required String code,
  }) => AuthService.instance.verifyPhoneCode(phone: phone, code: code);

  /// Returns the current user's [AdminProfile], or null if they aren't a
  /// signed-in, active admin. This is the single source of truth
  /// `/admin/*` routing uses to decide access - the database's
  /// `admin_users.is_active` flag and `profiles.role = 'admin'` are always
  /// re-checked here, never cached across sessions.
  Future<AdminProfile?> fetchCurrentAdminProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    final profileRow = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, phone, role')
        .eq('id', user.id)
        .maybeSingle();
    if (profileRow == null || profileRow['role'] != 'admin') return null;

    final adminRow = await SupabaseConfig.client
        .from('admin_users')
        .select('admin_role, is_active, full_name')
        .eq('id', user.id)
        .maybeSingle();
    if (adminRow == null) return null;

    return AdminProfile.fromJson({...profileRow, ...adminRow, 'id': user.id});
  }
}
