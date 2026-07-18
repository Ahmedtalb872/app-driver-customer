import 'package:flutter/material.dart';

import '../core/admin_colors.dart';
import '../models/admin_profile.dart';

class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final AdminProfile? profile;
  final VoidCallback onToggleSidebar;
  final VoidCallback onLogout;
  final bool showMenuButton;

  const AdminTopBar({
    super.key,
    required this.title,
    required this.profile,
    required this.onToggleSidebar,
    required this.onLogout,
    this.showMenuButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onToggleSidebar,
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AdminColors.textPrimary,
                fontFamily: 'Cairo',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'الإشعارات',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  profile?.fullName.isNotEmpty == true
                      ? profile!.fullName
                      : 'المسؤول',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  profile?.roleDisplayName ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AdminColors.error,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
              child: Text(
                (profile?.fullName.isNotEmpty == true
                    ? profile!.fullName[0]
                    : 'أ'),
                style: const TextStyle(
                  color: AdminColors.primary,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
