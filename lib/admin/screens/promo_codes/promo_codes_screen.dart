import 'package:flutter/material.dart';

import '../../widgets/coming_soon_screen.dart';

class PromoCodesScreen extends StatelessWidget {
  const PromoCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'أكواد الخصم',
      icon: Icons.local_offer_rounded,
      description:
          'لا يوجد جدول promo_codes في قاعدة البيانات حالياً لتخزين الأكواد '
          'وحدود الاستخدام. هذا القسم مرتبط بمرحلة لاحقة تضيف الجدول '
          'والصلاحيات اللازمة.',
    );
  }
}
