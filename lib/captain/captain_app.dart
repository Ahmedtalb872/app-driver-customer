import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/colors.dart';
import 'core/theme/app_theme.dart';
import 'core/services/new_trip_alert.dart';
import 'core/services/motivation_notifications.dart';
import 'core/services/push_notifications.dart' as captain_push;
import 'providers/app_state_provider.dart' as captain_state;
import 'features/onboarding/splash_screen.dart' as captain_splash;

/// Root of the captain experience inside the unified app.
///
/// Mirrors exactly what the standalone captain app's `main()` + `MyApp`
/// did: it owns the captain [AppStateProvider], starts the captain-only
/// notification channels (new-trip alert, motivation, push), applies the
/// gold status-bar style, and shows the captain splash. Supabase is already
/// initialized once by the unified `main()` (both apps share one Supabase
/// project and one global client), so it is intentionally NOT
/// re-initialized here - calling Supabase.initialize twice would throw.
///
/// This is pushed as a full screen by the role-selection flow, so its own
/// MaterialApp gives the captain side its own Navigator and theme, keeping
/// every captain screen and behaviour byte-for-byte what it was as a
/// standalone app.
class CaptainApp extends StatefulWidget {
  const CaptainApp({super.key});

  @override
  State<CaptainApp> createState() => _CaptainAppState();
}

class _CaptainAppState extends State<CaptainApp> {
  @override
  void initState() {
    super.initState();
    _initCaptainServices();
    // Gold status bar matching the brand, same as the standalone captain
    // app set globally in its main().
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  /// Captain-only notification channels. Each is best-effort: a failure to
  /// set one up must never block the captain from reaching the app, exactly
  /// as the customer side treats its own push init.
  Future<void> _initCaptainServices() async {
    try {
      await NewTripAlert.initialize();
    } catch (_) {}
    try {
      await MotivationNotifications.initialize();
    } catch (_) {}
    try {
      await captain_push.PushNotifications.initialize();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => captain_state.AppStateProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'الهدهد',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar', '')],
        locale: const Locale('ar', ''),
        home: const captain_splash.SplashScreen(),
      ),
    );
  }
}
