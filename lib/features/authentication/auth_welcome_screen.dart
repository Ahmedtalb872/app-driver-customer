import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../home/customer_home_screen.dart';
import 'phone_code_login_screen.dart';

/// First screen after the splash animation (and where a sign-out or a
/// forced "signed in elsewhere" kick lands too - see SettingsScreen and
/// SessionGuardService): a plain choice between creating a new account and
/// signing into an existing one, before the phone-number step.
///
/// Both buttons open the exact same [PhoneCodeLoginScreen] - it already
/// figures out on its own, from the phone number entered, whether this is
/// a new sign-up (real OTP, then choose a password) or an existing account
/// (password only, see [PhoneCodeLoginScreen]'s own doc comment). This
/// screen exists purely so a first-time visitor sees "إنشاء حساب/لدي حساب"
/// up front instead of being dropped straight into a bare phone field.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  void _goToPhoneLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhoneCodeLoginScreen(
          title: 'تسجيل الدخول',
          subtitle:
              'أدخل رقم هاتفك لإرسال رمز التحقق إليه، لتتمكن من طلب مشاويرك.',
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
                  // Soft radial teal glow behind the logo.
                  Container(
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
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/al-houdhoud-logo.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
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
                    onPressed: () => _goToPhoneLogin(context),
                    child: const Text('إنشاء حساب جديد'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _goToPhoneLogin(context),
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
