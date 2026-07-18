import 'package:flutter/material.dart';

import '../../widgets/coming_soon_screen.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'الإشعارات',
      icon: Icons.notifications_rounded,
      description:
          'لا يوجد جدول notifications في قاعدة البيانات حالياً لتخزين '
          'الإشعارات المرسلة وسجلّها. هذا القسم مرتبط بمرحلة لاحقة تضيف '
          'الجدول والصلاحيات اللازمة.',
    );
  }
}
