import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/admins/admin_users_screen.dart';
import '../screens/audit_logs/admin_audit_logs_screen.dart';
import '../screens/auth/admin_login_screen.dart';
import '../screens/auth/unauthorized_screen.dart';
import '../screens/captains/admin_captains_screen.dart';
import '../screens/dashboard/admin_dashboard_screen.dart';
import '../screens/dispatch/operator_dispatch_screen.dart';
import '../screens/finance/finance_reports_screen.dart';
import '../screens/finance/finance_wallets_screen.dart';
import '../screens/finance/recharge_requests_screen.dart';
import '../screens/finance/subscription_disputes_screen.dart';
import '../screens/finance/withdrawal_requests_screen.dart';
import '../screens/live_operations/live_operations_screen.dart';
import '../screens/locations/districts_neighborhoods_screen.dart';
import '../screens/locations/places_categories_screen.dart';
import '../screens/notifications/admin_notifications_screen.dart';
import '../screens/payments/payment_methods_screen.dart';
import '../screens/pricing/admin_pricing_screen.dart';
import '../screens/promo_codes/promo_codes_screen.dart';
import '../screens/reviews/admin_reviews_screen.dart';
import '../screens/settings/admin_settings_screen.dart';
import '../screens/support/admin_support_screen.dart';
import '../screens/trips/admin_trips_screen.dart';
import '../services/admin_session.dart';
import '../widgets/admin_shell.dart';

const Map<String, String> _routeTitles = {
  '/admin/dashboard': 'الرئيسية',
  '/admin/captains': 'الكباتن',
  '/admin/trips': 'الرحلات',
  '/admin/live-operations': 'العمليات المباشرة',
  '/admin/dispatch': 'إرسال طلب يدوي',
  '/admin/finance/reports': 'التقارير المالية',
  '/admin/finance/wallets': 'المحافظ',
  '/admin/finance/recharge': 'طلبات الشحن',
  '/admin/finance/withdrawal': 'طلبات السحب',
  '/admin/finance/subscription-disputes': 'مراجعة الاشتراكات الشهرية',
  '/admin/payments': 'وسائل الدفع',
  '/admin/pricing': 'التسعير والعمولة',
  '/admin/locations/districts': 'المقاطعات والأحياء',
  '/admin/locations/places': 'الأماكن والتصنيفات',
  '/admin/promo-codes': 'أكواد الخصم',
  '/admin/notifications': 'الإشعارات',
  '/admin/support': 'الدعم والشكاوى',
  '/admin/reviews': 'التقييمات',
  '/admin/admins': 'المستخدمون الإداريون',
  '/admin/audit-logs': 'سجل العمليات',
  '/admin/settings': 'إعدادات التطبيق',
};

GoRouter buildAdminRouter(AdminSession session) {
  return GoRouter(
    initialLocation: '/admin/dashboard',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final onLogin = path == '/admin/login';
      final onUnauthorized = path == '/admin/unauthorized';

      switch (session.status) {
        case AdminSessionStatus.unknown:
        case AdminSessionStatus.loading:
          return null; // wait for the first refresh() to resolve
        case AdminSessionStatus.signedOut:
          return onLogin ? null : '/admin/login';
        case AdminSessionStatus.unauthorized:
          return onUnauthorized ? null : '/admin/unauthorized';
        case AdminSessionStatus.authorized:
          if (onLogin || onUnauthorized) return '/admin/dashboard';
          if (path == '/admin') return '/admin/dashboard';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/admin', redirect: (context, state) => '/admin/dashboard'),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.matchedLocation;
          return AdminShell(
            currentRoute: path,
            title: _routeTitles[path] ?? 'لوحة التحكم',
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/captains',
            builder: (context, state) => const AdminCaptainsScreen(),
          ),
          GoRoute(
            path: '/admin/trips',
            builder: (context, state) => const AdminTripsScreen(),
          ),
          GoRoute(
            path: '/admin/live-operations',
            builder: (context, state) => const LiveOperationsScreen(),
          ),
          GoRoute(
            path: '/admin/dispatch',
            builder: (context, state) => const OperatorDispatchScreen(),
          ),
          GoRoute(
            path: '/admin/finance/reports',
            builder: (context, state) => const FinanceReportsScreen(),
          ),
          GoRoute(
            path: '/admin/finance/wallets',
            builder: (context, state) => const FinanceWalletsScreen(),
          ),
          GoRoute(
            path: '/admin/finance/recharge',
            builder: (context, state) => const RechargeRequestsScreen(),
          ),
          GoRoute(
            path: '/admin/finance/withdrawal',
            builder: (context, state) => const WithdrawalRequestsScreen(),
          ),
          GoRoute(
            path: '/admin/finance/subscription-disputes',
            builder: (context, state) => const SubscriptionDisputesScreen(),
          ),
          GoRoute(
            path: '/admin/payments',
            builder: (context, state) => const PaymentMethodsScreen(),
          ),
          GoRoute(
            path: '/admin/pricing',
            builder: (context, state) => const AdminPricingScreen(),
          ),
          GoRoute(
            path: '/admin/locations/districts',
            builder: (context, state) => const DistrictsNeighborhoodsScreen(),
          ),
          GoRoute(
            path: '/admin/locations/places',
            builder: (context, state) => const PlacesCategoriesScreen(),
          ),
          GoRoute(
            path: '/admin/promo-codes',
            builder: (context, state) => const PromoCodesScreen(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (context, state) => const AdminNotificationsScreen(),
          ),
          GoRoute(
            path: '/admin/support',
            builder: (context, state) => const AdminSupportScreen(),
          ),
          GoRoute(
            path: '/admin/reviews',
            builder: (context, state) => const AdminReviewsScreen(),
          ),
          GoRoute(
            path: '/admin/admins',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            builder: (context, state) => const AdminAuditLogsScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(
        child: Text('الصفحة غير موجودة', style: TextStyle(fontFamily: 'Cairo')),
      ),
    ),
  );
}
