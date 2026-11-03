import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/business_colors.dart';

class BusinessSidebarItem {
  final String label;
  final IconData icon;
  final String route;

  const BusinessSidebarItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

const List<BusinessSidebarItem> businessSidebarItems = [
  BusinessSidebarItem(
    label: 'لوحة التحكم',
    icon: Icons.dashboard_rounded,
    route: '/business/dashboard',
  ),
  BusinessSidebarItem(
    label: 'طلب مشوار جديد',
    icon: Icons.add_location_alt_rounded,
    route: '/business/new-request',
  ),
  BusinessSidebarItem(
    label: 'طلباتي',
    icon: Icons.route_rounded,
    route: '/business/requests',
  ),
  BusinessSidebarItem(
    label: 'الدعم',
    icon: Icons.support_agent_rounded,
    route: '/business/support',
  ),
  BusinessSidebarItem(
    label: 'الإعدادات',
    icon: Icons.settings_rounded,
    route: '/business/settings',
  ),
];

class BusinessSidebar extends StatelessWidget {
  final String currentRoute;
  final bool collapsed;
  final ValueChanged<String>? onNavigate;

  const BusinessSidebar({
    super.key,
    required this.currentRoute,
    this.collapsed = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? 76 : 260,
      color: BusinessColors.sidebarBackground,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'بوابة الأعمال',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: businessSidebarItems.length,
              itemBuilder: (context, index) {
                final item = businessSidebarItems[index];
                final selected = currentRoute.startsWith(item.route);
                return _SidebarTile(
                  item: item,
                  selected: selected,
                  collapsed: collapsed,
                  onTap: () {
                    if (onNavigate != null) {
                      onNavigate!(item.route);
                    } else {
                      context.go(item.route);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final BusinessSidebarItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected ? BusinessColors.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          item.icon,
          color: selected
              ? BusinessColors.sidebarSelectedText
              : BusinessColors.sidebarText,
          size: 20,
        ),
        title: collapsed
            ? null
            : Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? BusinessColors.sidebarSelectedText
                      : BusinessColors.sidebarText,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
        onTap: onTap,
      ),
    );

    if (!collapsed) return content;
    return Tooltip(message: item.label, child: content);
  }
}
