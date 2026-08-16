import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // Was a hardcoded "1.0.0+1" string that never reflected what was
  // actually installed - every build stamps a real, unique version+build
  // number since build-customer-apk.yml started bumping it per run, but
  // this screen kept showing the same placeholder regardless.
  String _versionLabel = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _versionLabel = '${info.version}+${info.buildNumber}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Image.asset(
                  'assets/images/al-houdhoud-logo-mark.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'الهدهد',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'تطبيق النقل الذكي',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _buildInfoRow('رقم الإصدار', _versionLabel),
                    const Divider(height: 1),
                    _buildInfoRow('المطور', 'Al Hodhod'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'الهدهد هو تطبيق نقل ذكي يربط الزبائن بالكباتن لتوفير رحلات آمنة وسريعة وسهلة داخل المدينة، مع دعم كامل لطرق الدفع المحلية وتتبع مباشر لسير الرحلة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                    height: 1.7,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2026 الهدهد. جميع الحقوق محفوظة.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
