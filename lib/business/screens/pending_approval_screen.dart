import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/business_colors.dart';
import '../core/business_theme.dart';
import '../services/business_session.dart';

/// Shown instead of the dashboard for any status other than 'approved' -
/// a business account can sign in right after registering, but can't place
/// a single ride request until an admin reviews it (see
/// 20261103000119_business_accounts.sql / admin_business_accounts_screen).
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BusinessSession>();
    final (icon, color, title, message) = switch (session.status) {
      BusinessSessionStatus.rejected => (
        Icons.cancel_outlined,
        BusinessColors.error,
        'تم رفض طلب التسجيل',
        session.account?.rejectionReason?.isNotEmpty == true
            ? session.account!.rejectionReason!
            : 'تواصل معنا عبر الدعم لمزيد من التفاصيل.',
      ),
      BusinessSessionStatus.suspended => (
        Icons.block_rounded,
        BusinessColors.error,
        'الحساب موقوف مؤقتاً',
        'تواصل معنا عبر الدعم لمعرفة السبب وكيفية إعادة التفعيل.',
      ),
      _ => (
        Icons.hourglass_top_rounded,
        BusinessColors.warning,
        'طلبك قيد المراجعة',
        'سيقوم فريقنا بمراجعة بيانات حسابك والموافقة عليه قريباً. '
            'ستتمكن من إرسال طلبات المشاوير فور الاعتماد.',
      ),
    };

    return Theme(data: BusinessTheme.theme, child: Scaffold(
      backgroundColor: BusinessColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: BusinessColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Cairo',
                      color: BusinessColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => context.read<BusinessSession>().refresh(),
                    child: const Text('تحديث الحالة'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await context.read<BusinessSession>().signOut();
                      if (context.mounted) context.go('/business/login');
                    },
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
