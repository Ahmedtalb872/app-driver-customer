import 'package:flutter/material.dart';

import '../core/admin_colors.dart';

/// Used for sidebar sections that are wired into routing/navigation (so
/// the sidebar always matches the full spec and nothing 404s) but whose
/// backend and screen work is intentionally out of scope for this pass -
/// see the delivery report for exactly which sections this covers and why.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.description = 'هذا القسم قيد التطوير وسيتم تفعيله في مرحلة لاحقة.',
    this.icon = Icons.construction_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AdminColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
