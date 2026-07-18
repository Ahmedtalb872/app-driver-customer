import 'package:flutter/material.dart';

import '../core/admin_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.success(String label) =>
      StatusBadge(label: label, color: AdminColors.success);
  factory StatusBadge.warning(String label) =>
      StatusBadge(label: label, color: AdminColors.warning);
  factory StatusBadge.error(String label) =>
      StatusBadge(label: label, color: AdminColors.error);
  factory StatusBadge.neutral(String label) =>
      StatusBadge(label: label, color: AdminColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
