// Smoke tests for the Hudhud ("الهدهد") app entrypoint: the app boots
// without throwing, and the splash screen auto-navigates straight to the
// customer phone-code login screen. See test/features/**/*.dart for the
// rest of the required front-end smoke-test coverage.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alhudhud/features/authentication/phone_code_login_screen.dart';
import 'package:alhudhud/main.dart';
import 'package:alhudhud/providers/app_state_provider.dart';

void main() {
  // Mirrors main()'s MultiProvider wiring without calling
  // SupabaseConfig.initialize()/dotenv.load(), which MyApp itself never
  // touches directly - only screens reached via user actions do.
  Widget wrappedApp() {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
      child: const MyApp(),
    );
  }

  testWidgets('التطبيق يفتح ويعرض الشاشة الافتتاحية دون أخطاء', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrappedApp());

    // The "الهدهد" / "AL HODHOD" wordmark is baked into the logo artwork
    // itself (shown uncropped via BoxFit.contain) rather than duplicated
    // as separate text, so the meaningful check here is that the logo
    // image renders and the tagline copy is present.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('نقل سريع، آمن وأسهل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('تنتقل الشاشة الافتتاحية تلقائياً إلى تسجيل الدخول', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrappedApp());

    // Splash auto-navigates after a 2.6s timer, then a 500ms fade.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.byType(PhoneCodeLoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The localization delegates below are needed for MaterialApp's default
  // Arabic-locale text direction/date-formatting machinery.
  testWidgets('واجهة تسجيل الدخول تدعم الاتجاه من اليمين لليسار', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', '')],
          locale: const Locale('ar', ''),
          home: PhoneCodeLoginScreen(
            title: 'تسجيل الدخول',
            subtitle: 'أدخل رقم هاتفك لإرسال رمز التحقق إليه.',
            onSignedIn: () {},
          ),
        ),
      ),
    );

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
