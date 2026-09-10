import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  late final AdminSession _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _session = AdminSession();
    // go_router re-evaluates its redirect callback every time this
    // ChangeNotifier fires, so login/logout/session-expiry all route
    // correctly without any screen manually calling context.go().
    _router = buildAdminRouter(_session);
    _session.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminSession>.value(
      value: _session,
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
