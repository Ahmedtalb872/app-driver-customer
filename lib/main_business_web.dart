import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'business/business_app.dart';
import 'core/config/supabase_config.dart';
import 'main.dart' show installVisibleErrorWidget;

/// Alternate web entrypoint that serves only the business portal
/// (restaurants/institutions) - built and deployed separately from both
/// the admin dashboard (`main.dart`'s `kIsWeb` branch) and the customer app
/// preview (`main_customer_web.dart`), to its own Vercel project/URL. See
/// .github/workflows/deploy-business-vercel.yml. This is the actual public
/// entry point businesses are given - nothing admin-related exists in this
/// build at all.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installVisibleErrorWidget();
  // Not ".env" - see pubspec.yaml's assets list (Android APK packaging
  // reason; kept the same name here too for one consistent filename
  // across every build target).
  await dotenv.load(fileName: 'app.env');
  await SupabaseConfig.initialize();
  usePathUrlStrategy();

  runApp(const BusinessApp());
}
