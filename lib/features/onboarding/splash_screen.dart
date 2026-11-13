import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/app_role.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/colors.dart';
import '../../core/services/push_notifications.dart';
import '../../core/services/session_guard_service.dart';
import '../../core/services/version_gate_service.dart';
import '../../providers/app_state_provider.dart';
import '../authentication/auth_welcome_screen.dart';
import '../home/customer_home_screen.dart';

// Store links for the "force update" dialog below - the iOS App Store one
// needs this app's actual numeric Apple ID filled in once it's known (visible
// on App Information in App Store Connect); until then the iOS button just
// opens the App Store app to a name search instead of the exact listing.
const String _androidStoreUrl =
    'https://play.google.com/store/apps/details?id=com.alhudhud.lizeboun';
const String _iosStoreUrl = 'https://apps.apple.com/search?term=TRENDE';

// The TRENDE logo's own green (sampled from assets/images/trende-logo.png,
// same value as pubspec.yaml's flutter_launcher_icons theme_color and
// web/manifest.json) - AppColors itself still carries the old Al Hodhod
// teal/gold palette, so the animated brand text below needs its own.
const Color _brandGreen = Color(0xFF006D36);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _brandText = 'TRENDE';

  // Drives the loading indicator's fade-in, independent of the logo/brand
  // animations below.
  late final AnimationController _controller;
  late final Animation<double> _contentFade;

  late final AnimationController _logoController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Separate controller so "TRENDE" types itself out letter by letter
  // instead of just fading in with the logo - started a beat after the
  // logo so the two don't compete for attention at once.
  late final AnimationController _brandController;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoScale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    _brandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _brandController.forward();
    });

    _navigationTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      unawaited(_navigateNextWithDeadline());
    });
  }

  /// Absolute backstop on top of _navigateNext's own per-call timeouts
  /// (VersionGateService, AuthService.fetchCurrentRole/fetchCurrentFullName/
  /// setActiveSession already each cap at 6s and fall through gracefully on
  /// their own) - still reported stuck on this screen despite those, so
  /// this guarantees forward progress no matter what turns out to be
  /// hanging, known or not: if _navigateNext hasn't finished by this
  /// deadline, stop waiting on it and go to the welcome screen directly,
  /// the same safe destination every other failure path above already
  /// falls back to.
  Future<void> _navigateNextWithDeadline() async {
    try {
      await _navigateNext().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthWelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    _logoController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  /// Supabase already restores a previously-signed-in session from local
  /// storage before this ever runs (the default `supabase_flutter`
  /// behaviour) - so reopening the app is not the same event as choosing to
  /// sign out, and shouldn't be treated as one. Only an explicit tap on
  /// "تسجيل الخروج" (SettingsScreen) or a SessionGuardService kick from
  /// another device signing in should ever land the user back on
  /// [AuthWelcomeScreen]; a restored session skips straight to the home
  /// screen instead of forcing a fresh login every time the app is closed
  /// and reopened.
  Future<void> _navigateNext() async {
    final requiredVersion = await VersionGateService.requiredMinVersionOrNull();
    if (!mounted) return;
    if (requiredVersion != null) {
      await _showForceUpdateDialog(requiredVersion);
      return;
    }

    if (AuthService.instance.isAuthenticated) {
      try {
        final role = await AuthService.instance.fetchCurrentRole();
        if (!mounted) return;

        if (role == AppRole.customer) {
          final fullName = await AuthService.instance.fetchCurrentFullName();
          if (!mounted) return;

          // Best effort, same as the normal login path (see
          // PhoneCodeLoginScreen) - this device just won't be forcibly
          // kicked by a later login elsewhere until the next successful
          // call.
          try {
            final sessionId = SessionGuardService.generateSessionId();
            await AuthService.instance.setActiveSession(sessionId);
            SessionGuardService.instance.start(sessionId);
          } catch (_) {}

          if (!mounted) return;
          Provider.of<AppStateProvider>(context, listen: false).login(
            AuthService.instance.currentUser?.phone ?? '',
            fullName: fullName,
          );
          // Fire-and-forget, same as SessionGuardService above - a
          // failure here just means this device misses admin broadcast
          // notifications until the next successful sync.
          unawaited(PushNotifications.syncToken());
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const CustomerHomeScreen(),
            ),
          );
          return;
        }

        // Any other role (captain, admin, or a profile that failed to
        // load) isn't supported on this mobile app - mirrors the same
        // fallback PhoneCodeLoginScreen uses after a fresh login.
        await AuthService.instance.signOut();
      } catch (_) {
        // Couldn't confirm the restored session is still good (e.g. no
        // network yet) - fall through to the welcome screen rather than
        // show a home screen that can't load anything. The session itself
        // is untouched, so the next successful launch tries again.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Blocks the splash screen indefinitely behind a non-dismissible dialog -
  /// no path back into the app - once the admin dashboard's "تحديث إجباري"
  /// toggle (AdminSettingsScreen) is on and this install is below the
  /// configured minimum version. Only a tap on "تحديث الآن" (which leaves the
  /// app for the store) ends this; there is deliberately no "later" option.
  Future<void> _showForceUpdateDialog(String requiredVersion) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'يتوفر تحديث جديد',
            style: TextStyle(fontFamily: 'El Messiri', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'يجب تحديث التطبيق إلى الإصدار $requiredVersion أو أحدث للمتابعة.',
            style: const TextStyle(fontFamily: 'El Messiri'),
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Platform.isIOS ? _iosStoreUrl : _androidStoreUrl;
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text(
                  'تحديث الآن',
                  style: TextStyle(fontFamily: 'El Messiri', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // The logo gets a generous, responsive slice of the available
          // space - never a fixed height box, so BoxFit.contain always has
          // room to lay out the full image without cropping it. Bounded by
          // height as well as width so short/wide viewports (tablets in
          // landscape, split-screen, ...) never push the content below the
          // fold.
          final logoWidthCandidate = width * 0.55 < height * 0.3
              ? width * 0.55
              : height * 0.3;
          final logoWidth = logoWidthCandidate.clamp(140.0, 300.0);
          final taglineFontSize = (width * 0.038).clamp(13.0, 17.0);

          return Stack(
            children: [
              // All real content (logo, tagline, loading indicator) stays
              // clear of the status bar and the bottom system/gesture bar.
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, innerConstraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: innerConstraints.maxHeight,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FadeTransition(
                                        opacity: _logoFade,
                                        child: ScaleTransition(
                                          scale: _logoScale,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: logoWidth,
                                            ),
                                            child: Image.asset(
                                              // Icon-only crop of the full
                                              // lockup (no baked-in "TRENDE"
                                              // text) - the brand name below
                                              // is its own animated widget.
                                              'assets/images/trende-logo-icon.png',
                                              width: logoWidth,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: logoWidth * 0.1),
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: AnimatedBuilder(
                                          animation: _brandController,
                                          builder: (context, child) {
                                            final visibleCount =
                                                (_brandText.length *
                                                        _brandController.value)
                                                    .ceil()
                                                    .clamp(0, _brandText.length);
                                            return Text(
                                              _brandText.substring(
                                                0,
                                                visibleCount,
                                              ),
                                              style: TextStyle(
                                                fontSize: taglineFontSize + 2,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                                color: _brandGreen,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    FadeTransition(
                      opacity: _contentFade,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'جاري التحميل...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryText,
                                fontFamily: 'El Messiri',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

