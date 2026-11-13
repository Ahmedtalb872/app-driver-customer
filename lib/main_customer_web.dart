import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/supabase_config.dart';
import 'providers/app_state_provider.dart';
import 'providers/locale_provider.dart';
import 'main.dart' show MyApp, installVisibleErrorWidget;

/// Alternate web entrypoint that always serves the customer app, instead of
/// `main.dart`'s `kIsWeb` branch (which is reserved for the TRENDE admin
/// dashboard). Built and deployed separately for previewing the customer
/// app in a browser - see .github/workflows/deploy-customer-web.yml. Not
/// used by the real mobile builds or the admin web deployment.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installVisibleErrorWidget();
  // Not ".env" - see pubspec.yaml's assets list (Android APK packaging
  // reason; kept the same name here too for one consistent filename
  // across every build target).
  await dotenv.load(fileName: 'app.env');
  await SupabaseConfig.initialize();
  usePathUrlStrategy();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
