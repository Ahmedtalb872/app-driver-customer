import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/admin/screens/dispatch/operator_dispatch_screen.dart';

/// Exercises the actual widget tree of the Operator Dispatch screen - tap to
/// place a marker, switch mode, tap again, drag to fine-tune - the same way
/// an operator would, instead of just asserting the code compiles. Doesn't
/// touch Supabase: the pricing/customer-lookup calls in this screen fail
/// silently (caught, falls back to "not loaded" UI state) with no network
/// available in the test environment, which is fine since none of that
/// gates the map/marker behavior under test here.
void main() {
  setUp(() {
    // Wide "desktop" surface so the screen picks its side-by-side layout
    // (map + form both fully laid out, nothing scrolled out of reach).
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OperatorDispatchScreen())),
    );
    // Let initState's pricing fetch fail against the network-less test
    // environment and settle instead of hanging on a pending Future.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets(
    'tap places pickup then destination, drawing a labeled straight-line estimate',
    (tester) async {
      await pumpScreen(tester);

      // No markers yet.
      expect(find.byIcon(Icons.location_pin), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);

      // Tap mode defaults to pickup - tap the map to place it. flutter_map
      // defers onTap behind an internal ~250ms timer (double-tap
      // disambiguation) that isn't tied to a scheduled frame, so
      // pumpAndSettle() alone won't advance past it - pump a fixed
      // duration first to fire it, matching what real wall-clock time does
      // for an actual user.
      final mapCenter = tester.getCenter(find.byType(FlutterMap));
      await tester.tapAt(mapCenter);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.textContaining('الإحداثيات:'), findsOneWidget);

      // Switch to destination mode and tap elsewhere on the map.
      await tester.tap(find.text('نقرة = الوجهة'));
      await tester.pumpAndSettle();
      await tester.tapAt(mapCenter.translate(60, 40));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Both markers now placed, a straight line drawn between them, and
      // the estimate clearly labeled as not the real road distance.
      expect(find.byIcon(Icons.location_pin), findsNWidgets(2));
      expect(find.textContaining('الإحداثيات:'), findsNWidgets(2));
      expect(find.byType(PolylineLayer), findsWidgets);
      expect(
        find.textContaining('تقدير بخط مستقيم (وليست مسافة الطريق الفعلية)'),
        findsOneWidget,
      );

      // OpenStreetMap attribution is present per tile usage policy.
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    },
  );

  testWidgets('dragging the pickup marker moves it to a new position', (
    tester,
  ) async {
    await pumpScreen(tester);

    final mapCenter = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(mapCenter);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final before = tester.getCenter(find.byIcon(Icons.location_pin));

    await tester.drag(find.byIcon(Icons.location_pin), const Offset(80, 0));
    await tester.pumpAndSettle();

    final after = tester.getCenter(find.byIcon(Icons.location_pin));
    expect(after.dx, greaterThan(before.dx));
  });

  // Regression coverage for the reported bug: "Send request to captains"
  // stayed disabled with zero explanation. These tests pin down (1) the
  // button is never silently disabled - a reason is always visible, and
  // (2) the phone field can no longer collect a number in a shape that
  // silently never matches `profiles.phone` (missing the `+222` prefix
  // every other phone field in the app already applies for the caller).
  bool sendButtonEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('إرسال المشوار للكباتن'),
        matching: find.byType(FilledButton),
      ),
    );
    return button.onPressed != null;
  }

  testWidgets(
    'send button starts disabled with a visible Arabic explanation, never silently',
    (tester) async {
      await pumpScreen(tester);

      expect(sendButtonEnabled(tester), isFalse);
      // The "why" must be on screen, not just an inert disabled button.
      expect(find.text('لإرسال المشوار، أكمل ما يلي:'), findsOneWidget);
      expect(find.textContaining('أدخل رقم هاتف الزبون'), findsOneWidget);
      expect(
        find.textContaining('حدد نقطة الانطلاق على الخريطة'),
        findsOneWidget,
      );
    },
  );

  testWidgets('phone field enforces +222-prefixed 8-digit numbers', (
    tester,
  ) async {
    await pumpScreen(tester);

    final phoneField = find.widgetWithText(TextField, 'XXXXXXXX');
    expect(phoneField, findsOneWidget);
    expect(find.text('+222 '), findsOneWidget);

    // Non-digit characters are rejected outright.
    await tester.enterText(phoneField, 'ab12cd34ef');
    await tester.pump();
    expect(tester.widget<TextField>(phoneField).controller?.text, '1234');

    // More than 8 digits is truncated, matching every other phone field.
    await tester.enterText(phoneField, '123456789012');
    await tester.pump();
    expect(tester.widget<TextField>(phoneField).controller?.text, '12345678');
  });

  testWidgets(
    'a phone number with no matching customer shows the reason next to the button, button stays disabled',
    (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'XXXXXXXX'),
        '40000009',
      );
      await tester.tap(find.text('بحث'));
      // No network in the test sandbox, so the lookup throws and is
      // treated the same as "not found" - the UI must say so, not just
      // leave the button dead.
      await tester.pumpAndSettle();

      expect(sendButtonEnabled(tester), isFalse);
      expect(
        find.textContaining('لم يتم العثور على حساب زبون بهذا الرقم'),
        findsWidgets,
      );
    },
  );

  testWidgets('open trip does not require a destination to be valid', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('مشوار مفتوح'));
    await tester.pumpAndSettle();

    final mapCenter = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(mapCenter);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Pickup is set, trip type is 'open' - the destination requirement
    // must never appear, even though no destination was ever picked.
    expect(find.textContaining('حدد الوجهة على الخريطة'), findsNothing);
  });
}
