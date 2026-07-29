import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'admin/admin_app.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'features/onboarding/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();

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
