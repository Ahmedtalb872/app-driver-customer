import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../home/customer_home_screen.dart';
import 'phone_code_login_screen.dart';

/// First screen after the splash animation (and where a sign-out or a
/// forced "signed in elsewhere" kick lands too - see SettingsScreen and
/// SessionGuardService): a plain choice between creating a new account and
/// signing into an existing one, before the phone-number step.
///
/// "إنشاء حساب جديد" opens [PhoneCodeLoginScreen] at its normal phone-first
/// step (OTP, then choose a password, for a number that isn't registered
/// yet). "لدي حساب بالفعل" skips straight to its combined phone+password
/// form (see [PhoneCodeLoginScreen.startAsReturningUser]) - the customer
/// already told us they have an account, so there's no reason to ask for
/// the phone number on its own first.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  void _goToPhoneLogin(BuildContext context, {required bool returningUser}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhoneCodeLoginScreen(
          title: 'تسجيل الدخول',
          subtitle:
              'أدخل رقم هاتفك لإرسال رمز التحقق إليه، لتتمكن من طلب مشاويرك.',
          startAsReturningUser: returningUser,
          onSignedIn: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // A single soft brand-teal curve along the bottom edge - just
          // enough presence to echo the splash screen without competing
          // with it (that one uses the full two-tone curve).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: _WelcomeCurvePainter()),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),
                  // Soft radial teal glow behind the logo. The logo artwork
                  // itself is a wide composition (fanned feathers, the car,
                  // the wordmark below it) rather than a centered circular
                  // mark, so it must never be forced into a circle - a
                  // ClipOval + BoxFit.cover here previously cropped off most
                  // of the feathers and the car, leaving barely more than a
                  // sliver of the artwork visible. BoxFit.contain in a plain
                  // (unclipped) box always shows it in full.
                  Container(
                    width: 150,
                    height: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Image.asset(
                      'assets/images/al-houdhoud-logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'مرحباً بك في الهدهد',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نقل سريع، آمن وأسهل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () =>
                        _goToPhoneLogin(context, returningUser: false),
                    child: const Text('إنشاء حساب جديد'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        _goToPhoneLogin(context, returningUser: true),
                    child: const Text('لدي حساب بالفعل'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single, low-opacity teal wave hugging the bottom edge - deliberately
/// simpler than the splash screen's two-tone curves (this screen already
/// has two colored buttons doing the heavy branding lifting).
class _WelcomeCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary.withOpacity(0.08);
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width,
        size.height * 0.45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeCurvePainter oldDelegate) => false;
}
