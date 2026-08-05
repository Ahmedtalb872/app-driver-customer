import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'admin/admin_app.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/app_navigator.dart';
import 'core/network/doh_fallback_http_overrides.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'features/onboarding/splash_screen.dart';

/// Release builds normally swallow a widget build exception into a small,
/// easy-to-miss blank/gray box instead of the loud red debug screen - which
/// has made a handful of "part of the screen just doesn't show up" reports
/// impossible to diagnose from a photo alone. Overriding this makes any
/// such exception render as plainly visible text everywhere, debug or
/// release, until the underlying reports stop and this can come back out.
void installVisibleErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFFEBEE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Widget build error:\n${details.exception}',
            style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 11),
          ),
        ),
      ),
    );
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installVisibleErrorWidget();
  // dart:io's DNS resolution has been observed to fail unconditionally on
  // at least one real device/network combination that the same device's
  // browser has no trouble with at all - see DohFallbackHttpOverrides for
  // the full reasoning. Web has no dart:io HttpClient to override.
  if (!kIsWeb) {
    HttpOverrides.global = DohFallbackHttpOverrides();
  }
  try {
    await dotenv.load(fileName: '.env');
    await SupabaseConfig.initialize();
  } catch (e, stackTrace) {
    // Never let a startup failure leave the native splash screen frozen
    // forever with zero feedback - runApp() below must still happen so
    // Flutter draws a first frame. Anything that actually needs Supabase
    // will now fail loudly and visibly (installVisibleErrorWidget above)
    // instead of hanging silently before the app ever appears.
    debugPrint('Startup initialization failed: $e\n$stackTrace');
  }

  // Web only ever serves the AL HODHOD admin dashboard - the customer
  // mobile flow below is completely untouched on every other platform.
  // usePathUrlStrategy() is a documented no-op off web, so it's safe to
  // call unconditionally.
  usePathUrlStrategy();
  if (kIsWeb) {
    runApp(const AdminApp());
    return;
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الهدهد',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key,
      theme: AppTheme.lightTheme,

      // Arabic RTL Localization configuration
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''), // Arabic
      ],
      locale: const Locale('ar', ''), // Set Arabic as default language

      home: const SplashScreen(),
    );
  }
}
