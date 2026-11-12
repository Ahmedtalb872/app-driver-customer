import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/business_theme.dart';
import 'routes/business_router.dart';
import 'services/business_session.dart';

/// The business portal, standalone - built and deployed completely
/// separately from the staff admin dashboard (see
/// .github/workflows/deploy-business-vercel.yml / lib/main_business_web.dart),
/// its own Vercel project and its own URL. A restaurant/institution never
/// sees anything admin-related because nothing admin-related ships in this
/// build at all - not hidden behind a route guard, genuinely absent.
class BusinessApp extends StatefulWidget {
  const BusinessApp({super.key});

  @override
  State<BusinessApp> createState() => _BusinessAppState();
}

class _BusinessAppState extends State<BusinessApp> {
  late final BusinessSession _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _session = BusinessSession();
    _router = GoRouter(
      initialLocation: '/business/register',
      refreshListenable: _session,
      redirect: (context, state) => businessRedirect(_session, state.matchedLocation),
      routes: businessRoutes(_session),
      errorBuilder: (context, state) => const Scaffold(
        body: Center(
          child: Text('الصفحة غير موجودة', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ),
    );
    _session.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BusinessSession>.value(
      value: _session,
      child: MaterialApp.router(
        title: 'بوابة الأعمال - اترينـد',
        debugShowCheckedModeBanner: false,
        theme: BusinessTheme.theme,
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
