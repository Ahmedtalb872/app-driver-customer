import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../business/routes/business_router.dart';
import '../business/services/business_session.dart';
import 'core/admin_theme.dart';
import 'routes/admin_router.dart';
import 'services/admin_session.dart';

/// The AL HODHOD admin dashboard - reached directly on web (the `kIsWeb`
/// branch in `lib/main.dart`), and pushed on top of the mobile customer
/// app's navigation stack once `PhoneCodeLoginScreen` sees an `admin`
/// account sign in. Both entry points share the same `AdminSession`/
/// `AdminAuthService`, which themselves reuse the app's one Supabase
/// session - an admin who already verified their phone-OTP on mobile never
/// sees this dashboard's own login screen. Arabic RTL by default,
/// admin-only palette/theme.
class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminSession _adminSession;
  late final BusinessSession _businessSession;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _adminSession = AdminSession();
    _businessSession = BusinessSession();
    // go_router re-evaluates its redirect callback every time either
    // ChangeNotifier fires, so login/logout/session-expiry on both the
    // admin and business sides route correctly without any screen
    // manually calling context.go(). One combined router (rather than two
    // separate GoRouters/MaterialApps) keeps a single `/` origin, which
    // this web build is served from either way.
    _router = GoRouter(
      initialLocation: '/admin/dashboard',
      refreshListenable: Listenable.merge([_adminSession, _businessSession]),
      redirect: (context, state) {
        final path = state.matchedLocation;
        if (path.startsWith('/business')) {
          return businessRedirect(_businessSession, path);
        }
        return adminRedirect(_adminSession, path);
      },
      routes: [
        ...adminRoutes(_adminSession),
        ...businessRoutes(_businessSession),
      ],
      errorBuilder: (context, state) => const Scaffold(
        body: Center(
          child: Text('الصفحة غير موجودة', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ),
    );
    _adminSession.refresh();
    _businessSession.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminSession>.value(value: _adminSession),
        ChangeNotifierProvider<BusinessSession>.value(value: _businessSession),
      ],
      child: MaterialApp.router(
        title: 'الهدهد | لوحة التحكم',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.theme,
        routerConfig: _router,
        locale: const Locale('ar', ''),
        supportedLocales: const [Locale('ar', '')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
