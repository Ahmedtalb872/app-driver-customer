import 'package:flutter/material.dart';

import '../core/business_colors.dart';
import '../models/business_account.dart';

class BusinessTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final BusinessAccount? account;
  final VoidCallback onToggleSidebar;
  final VoidCallback onLogout;
  final bool showMenuButton;

  const BusinessTopBar({
    super.key,
    required this.title,
    required this.account,
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
        color: BusinessColors.surface,
        border: Border(bottom: BorderSide(color: BusinessColors.border)),
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
                color: BusinessColors.textPrimary,
                fontFamily: 'Cairo',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  account?.businessName.isNotEmpty == true
                      ? account!.businessName
                      : 'حسابي',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  account?.typeLabel ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: BusinessColors.textSecondary,
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
                      color: BusinessColors.error,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: BusinessColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: BusinessColors.primary.withValues(alpha: 0.1),
              child: Text(
                (account?.businessName.isNotEmpty == true
                    ? account!.businessName[0]
                    : 'ع'),
                style: const TextStyle(
                  color: BusinessColors.primary,
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
