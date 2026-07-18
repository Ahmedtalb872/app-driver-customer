import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alhudhud/core/services/captain_session.dart';
import 'package:alhudhud/core/theme/app_theme.dart';
import 'package:alhudhud/providers/app_state_provider.dart';

/// Wraps [child] the same way `main.dart`'s `MyApp` does for the captain
/// mobile flow - Arabic RTL `MaterialApp` plus the app-wide providers -
/// without booting the real `main()` entrypoint (which calls
/// `SupabaseConfig.initialize()`). These tests deliberately stay hermetic
/// and offline: they exercise the local/dummy-data code paths, not the
/// real Supabase-backed ones, matching this task's front-end-only scope.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  AppStateProvider? appState,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => appState ?? AppStateProvider(),
        ),
        ChangeNotifierProvider(create: (_) => CaptainSession()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar', '')],
        locale: const Locale('ar', ''),
        home: child,
      ),
    ),
  );
}
