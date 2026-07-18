import 'package:flutter/material.dart';

import '../../widgets/coming_soon_screen.dart';

class AdminSupportScreen extends StatelessWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'الدعم والشكاوى',
      icon: Icons.support_agent_rounded,
      description:
          'لا يوجد جدول تذاكر دعم/شكاوى في قاعدة البيانات حالياً. هذا '
          'القسم مرتبط بمرحلة لاحقة تضيف الجدول والصلاحيات اللازمة.',
    );
  }
}
