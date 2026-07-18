import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/admin_colors.dart';
import '../../services/admin_session.dart';

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AdminColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 56,
                  color: AdminColors.error,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'لا تملك صلاحية الوصول',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'هذا الحساب غير مصرح له بالدخول إلى لوحة تحكم الهدهد.\nتواصل مع المدير العام إذا كنت تعتقد أن هذا خطأ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AdminColors.textSecondary,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await context.read<AdminSession>().signOut();
                  if (context.mounted) context.go('/admin/login');
                },
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
