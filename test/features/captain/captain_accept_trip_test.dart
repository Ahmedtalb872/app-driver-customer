import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/models/models.dart';
import 'package:alhudhud/providers/app_state_provider.dart';

/// Exercises AppStateProvider's simulated captain incoming-request flow
/// directly, rather than pumping CaptainHomeScreen: that screen's online
/// toggle also reaches into the real Supabase-backed CaptainSession/
/// RideRepository (captain_session.dart), which requires
/// SupabaseConfig.initialize() and isn't available in this offline test
/// environment. The local/dummy simulation below is a real, independent
/// code path in AppStateProvider (toggleCaptainOnline ->
/// _startSimulatedIncomingRequest -> acceptIncomingRequest) and is what
/// this test verifies.
void main() {
  testWidgets('الكابتن يستقبل طلباً تجريبياً عند الاتصال ويقبله بنجاح', (
    tester,
  ) async {
    // A trivial pumped tree is enough to give the test binding an active
    // fake clock for the Timer-based simulation below.
    await tester.pumpWidget(const SizedBox.shrink());

    final provider = AppStateProvider()
      ..login('+22240000002', UserType.captain);

    expect(provider.isCaptainOnline, isFalse);
    expect(provider.incomingRequest, isNull);

    provider.toggleCaptainOnline();
    expect(provider.isCaptainOnline, isTrue);

    // The simulated incoming request arrives after a 4s timer.
    await tester.pump(const Duration(seconds: 5));
    expect(provider.incomingRequest, isNotNull);
    expect(provider.activeTrip, isNull);

    provider.acceptIncomingRequest();

    expect(provider.incomingRequest, isNull);
    expect(provider.activeTrip, isNotNull);
    expect(provider.activeTrip!.status, TripStatus.accepted);
  });
}
