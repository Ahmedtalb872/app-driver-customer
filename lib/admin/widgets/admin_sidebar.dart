import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/admin_colors.dart';

class AdminSidebarItem {
  final String label;
  final IconData icon;
  final String route;

  const AdminSidebarItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

const List<AdminSidebarItem> adminSidebarItems = [
  AdminSidebarItem(
    label: 'الرئيسية',
    icon: Icons.dashboard_rounded,
    route: '/admin/dashboard',
  ),
  AdminSidebarItem(
    label: 'الكباتن',
    icon: Icons.local_taxi_rounded,
    route: '/admin/captains',
  ),
  AdminSidebarItem(
    label: 'الرحلات',
    icon: Icons.route_rounded,
    route: '/admin/trips',
  ),
  AdminSidebarItem(
    label: 'العمليات المباشرة',
    icon: Icons.wifi_tethering_rounded,
    route: '/admin/live-operations',
  ),
  AdminSidebarItem(
    label: 'إرسال مشوار يدوي',
    icon: Icons.add_location_alt_rounded,
    route: '/admin/dispatch',
  ),
  AdminSidebarItem(
    label: 'المحافظ والمالية',
    icon: Icons.account_balance_wallet_rounded,
    route: '/admin/finance/wallets',
  ),
  AdminSidebarItem(
    label: 'طلبات الشحن',
    icon: Icons.add_card_rounded,
    route: '/admin/finance/recharge',
  ),
  AdminSidebarItem(
    label: 'طلبات السحب',
    icon: Icons.outbond_rounded,
    route: '/admin/finance/withdrawal',
  ),
  AdminSidebarItem(
    label: 'وسائل الدفع',
    icon: Icons.payments_rounded,
    route: '/admin/payments',
  ),
  AdminSidebarItem(
    label: 'التسعير والعمولة',
    icon: Icons.price_change_rounded,
    route: '/admin/pricing',
  ),
  AdminSidebarItem(
    label: 'المقاطعات والأحياء',
    icon: Icons.map_rounded,
    route: '/admin/locations/districts',
  ),
  AdminSidebarItem(
    label: 'الأماكن والتصنيفات',
    icon: Icons.place_rounded,
    route: '/admin/locations/places',
  ),
  AdminSidebarItem(
    label: 'أكواد الخصم',
    icon: Icons.local_offer_rounded,
    route: '/admin/promo-codes',
  ),
  AdminSidebarItem(
    label: 'الإشعارات',
    icon: Icons.notifications_rounded,
    route: '/admin/notifications',
  ),
  AdminSidebarItem(
    label: 'الدعم والشكاوى',
    icon: Icons.support_agent_rounded,
    route: '/admin/support',
  ),
  AdminSidebarItem(
    label: 'التقييمات',
    icon: Icons.star_rounded,
    route: '/admin/reviews',
  ),
  AdminSidebarItem(
    label: 'المستخدمون الإداريون',
    icon: Icons.admin_panel_settings_rounded,
    route: '/admin/admins',
  ),
  AdminSidebarItem(
    label: 'سجل العمليات',
    icon: Icons.history_rounded,
    route: '/admin/audit-logs',
  ),
  AdminSidebarItem(
    label: 'إعدادات التطبيق',
    icon: Icons.settings_rounded,
    route: '/admin/settings',
  ),
];

class AdminSidebar extends StatelessWidget {
  final String currentRoute;
  final bool collapsed;
  final ValueChanged<String>? onNavigate;

  const AdminSidebar({
    super.key,
    required this.currentRoute,
    this.collapsed = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.sidebarBackground,
      width: collapsed ? 76 : 260,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/al-houdhoud-logo-mark.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الهدهد',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: adminSidebarItems.length,
              itemBuilder: (context, index) {
                final item = adminSidebarItems[index];
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
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final AdminSidebarItem item;
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
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AdminColors.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: selected ? AdminColors.accentLight : Colors.white70,
          size: 20,
        ),
        title: collapsed
            ? null
            : Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
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
