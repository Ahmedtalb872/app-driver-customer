import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:alhudhud/core/widgets/real_map_widget.dart';

void main() {
  testWidgets('RealMapWidget.onMapTap fires on a tap', (tester) async {
    LatLng? tapped;
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: RealMapWidget(onMapTap: (p) => tapped = p),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final center = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 500));

    expect(tapped, isNotNull);
  });
}
