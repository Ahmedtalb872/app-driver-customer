import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../features/authentication/phone_code_login_screen.dart';
import '../../features/home/customer_home_screen.dart';
import '../auth/auth_service.dart';
import '../config/supabase_config.dart';
import '../constants/colors.dart';
import '../navigation/app_navigator.dart';

/// Enforces a single active session per customer account. Every login
/// (password or a fresh OTP sign-up) calls [AuthService.setActiveSession]
/// with a brand-new random id, overwriting whatever was stored before; every
/// other device that's currently signed in is watching that same
/// `profiles.active_session_id` column via [start] below, and the moment it
/// sees a value that isn't its own [_localSessionId], it's been "kicked" and
/// signs itself out.
class SessionGuardService {
  SessionGuardService._();

  static final SessionGuardService instance = SessionGuardService._();

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String? _localSessionId;

  /// A random, client-generated id in standard UUID text form (the
  /// `active_session_id` column is `uuid`) - doesn't need to be a *valid*
  /// v4 UUID, just unique enough per login to tell devices apart.
  static String generateSessionId() {
    final random = Random.secure();
    String hex(int length) =>
        List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
  }

  /// Starts watching for another device taking over this account. Call
  /// right after [AuthService.setActiveSession] succeeds with the same
  /// [sessionId].
  void start(String sessionId) {
    stop();
    _localSessionId = sessionId;
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return;

    _sub = SupabaseConfig.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .listen((rows) {
          if (rows.isEmpty) return;
          final activeSessionId = rows.first['active_session_id'] as String?;
          if (activeSessionId != null && activeSessionId != _localSessionId) {
            _handleKicked();
          }
        });
  }

  /// Stops watching - call on a normal, deliberate sign-out so it doesn't
  /// immediately (and incorrectly) treat the resulting auth-state change as
  /// having been kicked by another device.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _localSessionId = null;
  }

  Future<void> _handleKicked() async {
    stop();
    await AuthService.instance.signOut();

    final navigator = AppNavigator.key.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => PhoneCodeLoginScreen(
          title: 'تسجيل الدخول',
          subtitle:
              'أدخل رقم هاتفك لإرسال رمز التحقق إليه، لتتمكن من طلب مشاويرك.',
          onSignedIn: () {
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CustomerHomeScreen(),
              ),
              (route) => false,
            );
          },
        ),
      ),
      (route) => false,
    );

    final context = navigator.context;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم تسجيل الدخول إلى حسابك من جهاز آخر، لذلك تم تسجيل خروجك من هذا الجهاز.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
