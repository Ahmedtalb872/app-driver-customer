import 'package:flutter/material.dart';

import '../captain/captain_app.dart';
import '../core/auth/app_role.dart';
import '../core/auth/auth_service.dart';
import '../core/constants/colors.dart';
import '../features/onboarding/splash_screen.dart';
import 'role_preference.dart';
import 'role_selection_screen.dart';

/// The unified app's entry gate. Decides, once per cold start, whether to
/// show the customer side, the captain side, or the role chooser - without
/// the user having to pick every time:
///
///  * Signed in  -> route by the account's REAL role (authoritative). A
///    customer account can never land on the captain UI or vice versa; this
///    is the same role check each side already enforced on its own.
///  * Signed out -> reuse the last chosen side if there is one, otherwise
///    show [RoleSelectionScreen].
///
/// Each side then runs its own unchanged splash/login flow from here.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final Widget destination = await _resolveDestination();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  Future<Widget> _resolveDestination() async {
    // Authoritative path: a live session's real role decides the side.
    if (AuthService.instance.isAuthenticated) {
      try {
        final role = await AuthService.instance.fetchCurrentRole();
        if (role == AppRole.captain) {
          await RolePreference.save(RolePreference.captain);
          return const CaptainApp();
        }
        if (role == AppRole.customer) {
          await RolePreference.save(RolePreference.customer);
          return const SplashScreen();
        }
        // Any other role (e.g. admin) has no mobile side here - fall
        // through to the chooser rather than guessing.
      } catch (_) {
        // Offline / lookup failed: fall back to the last chosen side below
        // instead of forcing a fresh choice on someone already signed in.
      }
    }

    final saved = await RolePreference.read();
    if (saved == RolePreference.captain) return const CaptainApp();
    if (saved == RolePreference.customer) return const SplashScreen();
    return const RoleSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Brief branded hold while the (usually instant) decision resolves.
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
