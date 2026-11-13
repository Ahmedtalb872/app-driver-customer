import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhoneCodeLoginScreen(
          title: l10n.loginTitle,
          subtitle: l10n.loginSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
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
                      'assets/images/trende-logo-mark.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.welcomeTitle,
                    style: const TextStyle(
                      fontFamily: 'El Messiri',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'El Messiri',
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const Spacer(flex: 1),
                  ElevatedButton(
                    onPressed: () =>
                        _goToPhoneLogin(context, returningUser: false),
                    child: Text(l10n.createAccount),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        _goToPhoneLogin(context, returningUser: true),
                    child: Text(l10n.haveAccount),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
