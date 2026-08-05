import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode_config.dart';
import '../config/supabase_config.dart';
import 'app_role.dart';

/// Authentication foundation shared by the customer, captain and admin
/// flows. Two identity kinds coexist here, both keyed by phone number from
/// every caller's point of view:
///  - Real customer accounts sign up through Supabase's own phone/SMS OTP
///    provider ([requestPhoneCode]/[verifyPhoneCode]), so they're
///    phone-identified in Supabase - [signInWithPhonePassword] matches that.
///  - Admin accounts (and the debug/profile-only [DemoModeConfig] demo
///    accounts) never go through OTP, so [signIn]/[signUp] map the phone
///    number to a deterministic synthetic email instead and use Supabase's
///    standard email/password APIs.
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
    return _withRetry(
      () => _auth.signInWithPassword(
        email: _phoneToEmail(phone),
        password: password,
      ),
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Whether [phone] already has an account - lets the login screen decide
  /// between the password step (existing account) and the OTP sign-up flow
  /// (new number), before any auth session exists.
  Future<bool> isPhoneRegistered(String phone) {
    return _withRetry(() async {
      final result = await SupabaseConfig.client.rpc(
        'check_phone_registered',
        params: {'p_phone': phone},
      );
      return result as bool;
    });
  }

  /// Signs in an existing account with its phone number and password -
  /// the normal path once a customer has set a password (see
  /// [setPasswordForCurrentUser]), no OTP needed. A real customer account
  /// is always created via the phone-OTP path (Supabase's own phone/SMS
  /// auth provider - see [requestPhoneCode]/[verifyPhoneCode]), so it's
  /// phone-identified in Supabase, not the synthetic-email identity
  /// [signIn]/[signUp] use for admin/demo accounts - this must match that
  /// and sign in by phone directly.
  Future<AuthResponse> signInWithPhonePassword({
    required String phone,
    required String password,
  }) {
    return _withRetry(
      () => _auth.signInWithPassword(phone: phone, password: password),
    );
  }

  /// Sets a password credential on the already phone-OTP-verified current
  /// user, right after a brand-new sign-up, so every later sign-in can use
  /// [signInWithPhonePassword] instead of requesting a fresh OTP.
  Future<void> setPasswordForCurrentUser(String password) async {
    await _auth.updateUser(UserAttributes(password: password));
  }

  /// Overwrites this account's single allowed active session. Every other
  /// device already signed in is watching this same value (see
  /// `SessionGuardService`) and signs itself out the moment it sees one
  /// that isn't its own.
  Future<void> setActiveSession(String sessionId) async {
    await SupabaseConfig.client.rpc(
      'set_active_session',
      params: {'p_session_id': sessionId},
    );
  }

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
    await _withRetry(() => _auth.signInWithOtp(phone: phone));
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

    return _withRetry(
      () => _auth.verifyOTP(type: OtpType.sms, phone: phone, token: code),
    );
  }

  /// Retries [action] on a transient network failure (DNS lookup/socket
  /// errors) - this app has repeatedly seen brief "Failed host lookup"
  /// blips on flaky mobile data that succeed a moment later, so a couple
  /// of quick retries avoid surfacing a scary error for what's often a
  /// one-off timeout. Never retries a real [AuthException] (wrong
  /// password, invalid code, ...) since trying again can't change that.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on SocketException {
        if (attempt == maxAttempts) rethrow;
      } on ClientException {
        if (attempt == maxAttempts) rethrow;
      }
      await Future.delayed(Duration(milliseconds: 600 * attempt));
    }
    throw StateError('unreachable');
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
