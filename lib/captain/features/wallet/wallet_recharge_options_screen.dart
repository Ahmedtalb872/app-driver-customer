import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import 'bpay_recharge_screen.dart';

/// Wallet-recharge landing page: the captain picks which mobile-payment
/// service to top up from. Only Bankily is live today; Masrivi and Sedad
/// are shown as coming-soon tiles so captains know they're planned but
/// can't be picked yet.
class WalletRechargeOptionsScreen extends StatelessWidget {
  const WalletRechargeOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('شحن المحفظة'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'اختر طريقة الشحن',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'أضف رصيدًا إلى محفظتك عبر إحدى خدمات الدفع التالية.',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Cairo',
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),

            _RechargeOptionTile(
              title: 'Bankily',
              subtitle: 'ادفع فورًا عبر رمز Bpay التابع لبنكيلي',
              logo: Image.asset(
                'assets/images/bankily_logo_transparent.png',
                height: 44,
                fit: BoxFit.contain,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BpayRechargeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _RechargeOptionTile(
              title: 'Masrvi',
              subtitle: 'قريبًا',
              logo: _LetterLogo(
                letter: 'S',
                background: const Color(0xFF1FCFA6),
                foreground: const Color(0xFF1F2A5B),
              ),
              disabled: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),

            _RechargeOptionTile(
              title: 'Sedad',
              subtitle: 'قريبًا',
              logo: _LetterLogo(
                letter: 'س',
                background: const Color(0xFFC8A44A),
                foreground: Colors.white,
              ),
              disabled: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _RechargeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget logo;
  final bool disabled;
  final VoidCallback onTap;

  const _RechargeOptionTile({
    required this.title,
    required this.subtitle,
    required this.logo,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Center(child: logo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: disabled
                          ? AppColors.warning
                          : AppColors.secondaryText,
                      fontWeight:
                          disabled ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              disabled
                  ? Icons.hourglass_bottom_rounded
                  : Icons.chevron_left_rounded,
              color: disabled ? AppColors.warning : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );

    if (disabled) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: content,
    );
  }
}

class _LetterLogo extends StatelessWidget {
  final String letter;
  final Color background;
  final Color foreground;

  const _LetterLogo({
    required this.letter,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          fontFamily: 'Cairo',
          height: 1,
        ),
      ),
    );
  }
}
