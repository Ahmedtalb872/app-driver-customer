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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              ClipOval(
                child: Image.asset(
                  'assets/images/al-houdhoud-logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
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
    );
  }
}
