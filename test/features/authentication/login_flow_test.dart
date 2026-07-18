import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/features/authentication/captain_login_screen.dart';
import 'package:alhudhud/features/captain/captain_home_screen.dart';
import 'package:alhudhud/providers/app_state_provider.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets(
    'تسجيل دخول الكابتن التجريبي (40000002 / 123456) ينجح وينتقل للوحة الكابتن',
    (tester) async {
      final appState = AppStateProvider();
      await pumpApp(tester, const CaptainLoginScreen(), appState: appState);

      await tester.enterText(find.byType(TextFormField).first, '40000002');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('تسجيل الدخول ككابتن'));
      await tester.pumpAndSettle();

      expect(find.byType(CaptainHomeScreen), findsOneWidget);
      expect(appState.isLoggedIn, isTrue);
    },
  );

  testWidgets('رفض بيانات دخول خاطئة (غير تجريبية) مع رسالة واضحة وبدون دخول', (
    tester,
  ) async {
    final appState = AppStateProvider();
    await pumpApp(tester, const CaptainLoginScreen(), appState: appState);

    await tester.enterText(find.byType(TextFormField).first, '99999999');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
    await tester.tap(find.text('تسجيل الدخول ككابتن'));
    await tester.pumpAndSettle();

    // Non-demo credentials fall through to the real backend sign-in,
    // which fails in this offline test environment - caught and shown
    // as a clear Arabic error, exactly like a real rejected login would
    // be. No navigation happens and no session is created.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(CaptainHomeScreen), findsNothing);
    expect(appState.isLoggedIn, isFalse);
  });
}
