import 'package:flutter/material.dart';

import '../captain/captain_app.dart';
import '../core/constants/colors.dart';
import '../features/onboarding/splash_screen.dart';
import 'role_preference.dart';

/// First screen a brand-new (signed-out) user sees in the unified app:
/// a single, branded chooser between the rider ("زبون") and driver
/// ("كابتن") experiences. Picking one remembers the choice ([RolePreference])
/// and enters that side's own flow, which then handles its own login exactly
/// as each app did on its own. A user who is already signed in never reaches
/// this screen - [RoleGate] sends them straight to the side that matches
/// their real account role.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _choose(BuildContext context, String role) {
    RolePreference.save(role);
    final Widget destination =
        role == RolePreference.captain
        ? const CaptainApp()
        : const SplashScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/images/al-houdhoud-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'مرحباً بك في الهدهد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر نوع الاستخدام للمتابعة',
                  style: TextStyle(
                    color: Color(0xFFD6E2E4),
                    fontSize: 15,
                  ),
                ),
                const Spacer(flex: 2),
                _RoleCard(
                  emoji: '🚕',
                  title: 'زبون',
                  subtitle: 'اطلب سيارتك وتابع مشوارك على الخريطة',
                  accent: AppColors.secondary,
                  onTap: () => _choose(context, RolePreference.customer),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  emoji: '🚗',
                  title: 'كابتن',
                  subtitle: 'استقبل الطلبات وأدِر مشاويرك وأرباحك',
                  accent: AppColors.accent,
                  onTap: () => _choose(context, RolePreference.captain),
                ),
                const Spacer(flex: 3),
                const Text(
                  'يمكنك تغيير النوع لاحقاً عند تسجيل الخروج',
                  style: TextStyle(color: Color(0xFFAFC2C5), fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_new, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
