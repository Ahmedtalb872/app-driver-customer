import 'package:go_router/go_router.dart';

import '../screens/auth/business_login_screen.dart';
import '../screens/auth/business_register_screen.dart';
import '../screens/dashboard/business_dashboard_screen.dart';
import '../screens/pending_approval_screen.dart';
import '../screens/requests/business_new_request_screen.dart';
import '../screens/requests/business_requests_screen.dart';
import '../screens/settings/business_settings_screen.dart';
import '../screens/support/business_support_screen.dart';
import '../services/business_session.dart';
import '../widgets/business_shell.dart';

const Map<String, String> businessRouteTitles = {
  '/business/dashboard': 'لوحة التحكم',
  '/business/new-request': 'طلب مشوار جديد',
  '/business/requests': 'طلباتي',
  '/business/support': 'الدعم',
  '/business/settings': 'الإعدادات',
};

/// Redirect decision for any path under `/business` - called from the
/// combined app router's one `redirect` callback (see admin_app.dart),
/// parallel to [AdminSession]'s own branch for `/admin`.
String? businessRedirect(BusinessSession session, String path) {
  final onLogin = path == '/business/login';
  final onRegister = path == '/business/register';
  final onPending = path == '/business/pending';

  switch (session.status) {
    case BusinessSessionStatus.unknown:
    case BusinessSessionStatus.loading:
      return null; // wait for the first refresh() to resolve
    case BusinessSessionStatus.signedOut:
      // The public landing experience is the registration form only - a
      // signed-out visitor who lands anywhere else (including trying
      // /business/dashboard directly) is sent there, not to a visible
      // login form. /business/login still works for a returning business
      // that knows to go there (linked from the register screen itself),
      // it's just never the default.
      return (onLogin || onRegister) ? null : '/business/register';
    case BusinessSessionStatus.noAccount:
      // Signed in mid-registration (createMyAccount hasn't run/finished
      // yet) - only the register screen itself should be reachable here,
      // it's the one place that resolves this state.
      return onRegister ? null : '/business/register';
    case BusinessSessionStatus.pending:
    case BusinessSessionStatus.rejected:
    case BusinessSessionStatus.suspended:
      return onPending ? null : '/business/pending';
    case BusinessSessionStatus.approved:
      if (onLogin || onRegister || onPending) return '/business/dashboard';
      return null;
  }
}

List<RouteBase> businessRoutes(BusinessSession session) => [
  GoRoute(
    path: '/business',
    redirect: (context, state) => '/business/dashboard',
  ),
  GoRoute(
    path: '/business/login',
    builder: (context, state) => const BusinessLoginScreen(),
  ),
  GoRoute(
    path: '/business/register',
    builder: (context, state) => const BusinessRegisterScreen(),
  ),
  GoRoute(
    path: '/business/pending',
    builder: (context, state) => const PendingApprovalScreen(),
  ),
  ShellRoute(
    builder: (context, state, child) {
      final path = state.matchedLocation;
      return BusinessShell(
        currentRoute: path,
        title: businessRouteTitles[path] ?? 'بوابة الأعمال',
        child: child,
      );
    },
    routes: [
      GoRoute(
        path: '/business/dashboard',
        builder: (context, state) => const BusinessDashboardScreen(),
      ),
      GoRoute(
        path: '/business/new-request',
        builder: (context, state) => const BusinessNewRequestScreen(),
      ),
      GoRoute(
        path: '/business/requests',
        builder: (context, state) => const BusinessRequestsScreen(),
      ),
      GoRoute(
        path: '/business/support',
        builder: (context, state) => const BusinessSupportScreen(),
      ),
      GoRoute(
        path: '/business/settings',
        builder: (context, state) => const BusinessSettingsScreen(),
      ),
    ],
  ),
];
