import 'package:flutter/material.dart';

import '../../widgets/coming_soon_screen.dart';

class AdminReviewsScreen extends StatelessWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'التقييمات',
      icon: Icons.star_rounded,
      description:
          'لا يوجد عمود أو جدول لتقييمات الرحلات في قاعدة البيانات حالياً '
          '(جدول trips لا يخزّن تقييم الزبون أو الكابتن بعد). هذا القسم '
          'مرتبط بمرحلة لاحقة تضيف الحقول اللازمة.',
    );
  }
}
