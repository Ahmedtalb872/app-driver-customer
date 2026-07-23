import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/features/authentication/phone_code_login_screen.dart';
import 'package:alhudhud/features/home/customer_home_screen.dart';
import 'package:alhudhud/providers/app_state_provider.dart';

import '../../test_helpers.dart';

Widget _buildLoginScreen() {
  return PhoneCodeLoginScreen(
    title: 'تسجيل الدخول',
    subtitle: 'أدخل رقم هاتفك لإرسال رمز التحقق إليه.',
    onSignedIn: () {},
  );
}

void main() {
  testWidgets('إرسال رمز التحقق لرقم الزبون التجريبي (40000001) ينتقل لخطوة الرمز', (
    tester,
  ) async {
    final appState = AppStateProvider();
    await pumpApp(tester, _buildLoginScreen(), appState: appState);

    await tester.enterText(find.byType(TextFormField).first, '40000001');
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pumpAndSettle();

    // The demo phone never hits the real backend to send a code (see
    // DemoModeConfig.isDemoPhone), so the UI moves straight to the
    // code-entry step.
    expect(find.text('رمز التحقق'), findsOneWidget);
    expect(appState.isLoggedIn, isFalse);
  });

  testWidgets('رمز تحقق خاطئ لرقم تجريبي يُرفض مع رسالة واضحة وبدون دخول', (
    tester,
  ) async {
    final appState = AppStateProvider();
    await pumpApp(tester, _buildLoginScreen(), appState: appState);

    await tester.enterText(find.byType(TextFormField).first, '40000001');
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, '000000');
    await tester.tap(find.text('تأكيد وتسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(CustomerHomeScreen), findsNothing);
    expect(appState.isLoggedIn, isFalse);
  });
}
