import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode_config.dart';
import '../config/supabase_config.dart';
import 'app_role.dart';

/// Authentication foundation shared by the customer, captain and admin
/// flows. Supabase's default email/password provider is used underneath;
/// since Hudhud accounts are identified by phone number (no SMS provider is
/// configured yet), each phone number is mapped to a deterministic
/// synthetic email so the standard email/password APIs can be reused as-is.
/// This can be swapped for real phone/OTP auth later without touching
/// callers, since they only ever pass phone numbers in and out.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => SupabaseConfig.client.auth;

  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  bool get isAuthenticated => currentSession != null;

  /// Emits whenever the auth state changes (sign in, sign out, token refresh).
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Creates a new account for the given [role] and signs the user in.
  /// A `profiles` row (plus the matching `customers`/`captains`/`admin_users`
  /// row and a `wallets` row) is created automatically server-side via the
  /// `handle_new_user` trigger, using the metadata passed here.
  Future<AuthResponse> signUp({
    required String phone,
    required String password,
    required String fullName,
    required AppRole role,
  }) {
    return _auth.signUp(
      email: _phoneToEmail(phone),
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': role.value},
    );
  }

  Future<AuthResponse> signIn({
    required String phone,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: _phoneToEmail(phone),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Requests a verification code for [phone]. This is Hudhud's "normal
  /// Supabase OTP flow": it calls Supabase Auth's real phone-OTP endpoint,
  /// which requires an SMS provider to be configured on the project
  /// (Authentication > Providers > Phone in the Supabase dashboard).
  ///
  /// The one exception is [DemoModeConfig]'s fixed demo phone numbers,
  /// which only ever exist in debug/profile builds: since their code is
  /// already known, no real OTP is requested and this is a local no-op.
  Future<void> requestPhoneCode(String phone) async {
    if (DemoModeConfig.isDemoPhone(phone)) return;
    await _auth.signInWithOtp(phone: phone);
  }

  /// Verifies [code] for [phone] and signs the user in.
  ///
  /// For a [DemoModeConfig] demo phone number, [code] is checked locally
  /// against the fixed demo code; on a match the demo account is signed in
  /// via its internal phone -> synthetic-email credential (see
  /// [DemoAccount.internalPassword]) rather than a real OTP, since none was
  /// ever sent. This path does not exist in release builds.
  ///
  /// Every other phone number goes through Supabase Auth's real
  /// `verifyOTP`, exactly mirroring [requestPhoneCode] above.
  Future<AuthResponse> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    final demoAccount = DemoModeConfig.demoAccounts[phone];
    if (demoAccount != null) {
      if (demoAccount.code != code) {
        throw const AuthException('رمز التحقق غير صحيح.');
      }
      return _auth.signInWithPassword(
        email: _phoneToEmail(phone),
        password: demoAccount.internalPassword,
      );
    }

    return _auth.verifyOTP(type: OtpType.sms, phone: phone, token: code);
  }

  /// Reads the signed-in user's role from `public.profiles`. Returns null
  /// if there is no active session or the profile row isn't visible yet.
  Future<AppRole?> fetchCurrentRole() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final row = await SupabaseConfig.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();

    return AppRoleX.fromValue(row?['role'] as String?);
  }

  /// Reads the signed-in user's display name from `public.profiles`. Empty
  /// for a brand-new account created via phone-OTP sign-up, which never
  /// sends a `full_name` (see [requestPhoneCode]) - callers use that to
  /// detect a first-time sign-in and prompt for one.
  Future<String> fetchCurrentFullName() async {
    final uid = currentUser?.id;
    if (uid == null) return '';

    final row = await SupabaseConfig.client
        .from('profiles')
        .select('full_name')
        .eq('id', uid)
        .maybeSingle();

    return (row?['full_name'] as String?)?.trim() ?? '';
  }

  /// Persists a display name for the signed-in user, used the first time a
  /// phone-OTP customer signs in (see [fetchCurrentFullName]).
  Future<void> updateFullName(String fullName) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await SupabaseConfig.client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', uid);
  }

  /// Maps a phone number (e.g. `+22236000000`) to the deterministic
  /// synthetic email Supabase auth stores it under.
  String _phoneToEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@hudhud.app';
  }
}
