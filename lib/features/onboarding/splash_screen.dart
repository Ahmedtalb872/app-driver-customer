import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../authentication/auth_welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentFade;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // A single, short fade+scale entrance - no rotation, no bounce/overshoot
    // curve, and it never repeats.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoFade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _logoScale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 2600), () {
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
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
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
          // fold - the SingleChildScrollView further down is only a safety
          // net for anything still tighter than that.
          final logoWidth = math
              .min(width * 0.55, height * 0.3)
              .clamp(140.0, 300.0);
          final taglineFontSize = (width * 0.038).clamp(13.0, 17.0);
          final curveHeight = (height * 0.2).clamp(110.0, 200.0);

          return Stack(
            children: [
              // Decorative bottom curves in the logo's brand colors - a
              // full-bleed background layer, intentionally outside the
              // SafeArea below so it can still touch the screen edges.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: width,
                  height: curveHeight,
                  child: CustomPaint(painter: _SplashCurvesPainter()),
                ),
              ),

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
                                              'assets/images/al-houdhoud-logo-mark.png',
                                              width: logoWidth,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: logoWidth * 0.12),
                                      FadeTransition(
                                        opacity: _contentFade,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Text(
                                            'نقل سريع، آمن وأسهل',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: taglineFontSize,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
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
                        padding: EdgeInsets.only(bottom: curveHeight + 20),
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
                                fontFamily: 'Cairo',
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

class _SplashCurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final greenPaint = Paint()..color = AppColors.primary;
    final greenPath = Path()
      ..moveTo(0, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.28,
        size.width * 0.52,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.62,
        size.width,
        size.height * 0.32,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    final orangePaint = Paint()..color = AppColors.accent;
    final orangePath = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height,
        size.width * 0.58,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.64,
        size.width,
        size.height * 0.86,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(orangePath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant _SplashCurvesPainter oldDelegate) => false;
}
