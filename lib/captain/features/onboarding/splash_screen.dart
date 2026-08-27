import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import 'auth_choice_screen.dart';
import 'pending_review_screen.dart';
import 'widgets/splash_route_map.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    Timer(const Duration(milliseconds: 2800), _resumeSessionOrLogin);
  }

  Future<void> _resumeSessionOrLogin() async {
    Widget destination = const AuthChoiceScreen();

    final currentUser = AuthRepository().currentUser;
    if (currentUser != null) {
      try {
        final profile = await AuthRepository().getProfile(currentUser.id);
        if (profile['role'] == 'captain' && mounted) {
          Map<String, dynamic>? captain;
          bool approved = false;
          try {
            captain = await AuthRepository().getCaptain(currentUser.id);
            approved = captain['status'] == 'approved';
          } catch (_) {
            // Fall back to "not approved".
          }
          if (mounted) {
            final appState = Provider.of<AppStateProvider>(
              context,
              listen: false,
            );
            appState.loginFromProfile(
              profile,
              currentUser.phone ?? '',
              captain: captain,
            );
            // Restores an in-progress trip if the app process was killed
            // mid-trip (e.g. the phone locked/closed) - otherwise the
            // captain would land on the dashboard with no sign it still
            // exists, even though nothing changed on the server.
            if (approved) {
              await appState.restoreActiveTripIfAny();
            }
          }
          destination = approved
              ? const CaptainHomeScreen()
              : const PendingReviewScreen();
        }
      } catch (_) {
        // No usable session/profile; fall back to the login screen.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    // Scales the logo puck to the screen instead of a fixed 180px, so it
    // stays proportionate on small phones and large tablets alike.
    final logoSize = (screenSize.shortestSide * 0.42).clamp(120.0, 200.0);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Animated map of Nouakchott with the الهدهد car driving along a
          // route, tinted with the brand gold so it reads as a backdrop
          // rather than competing with the logo on top of it.
          const Positioned.fill(child: SplashRouteMap()),

          // Main content - kept inside SafeArea so nothing sits under a
          // notch/Dynamic Island (iOS) or a status/navigation bar (Android).
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/images/logo_splash.png'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'الهدهد',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkText,
                            fontFamily: 'Cairo',
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkText.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'نقل سريع، آمن وأسهل',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom loading indicator + status text, inset by SafeArea so it
          // never sits under a home indicator/gesture bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 40,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.darkText,
                      ),
                      strokeWidth: 3,
                      backgroundColor: AppColors.darkText.withOpacity(0.15),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'جاري التحميل...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText.withOpacity(0.85),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
