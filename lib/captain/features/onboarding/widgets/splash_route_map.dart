import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/colors.dart';

/// Animated Google Map background for the splash screen: a muted map of
/// central Nouakchott with a glowing orange trail animating along
/// [_routePoints].
///
/// This is purely decorative - it does not use the device's real location,
/// so no location permission is requested for it. [_routePoints] is a
/// hand-picked path through the city rather than one fetched from the
/// Directions API, so the splash screen never has to wait on (or fail due
/// to) a network call before it can animate; swap it for a fetched
/// route later by replacing that list with the DirectionsService result.
class SplashRouteMap extends StatefulWidget {
  const SplashRouteMap({super.key});

  @override
  State<SplashRouteMap> createState() => _SplashRouteMapState();
}

class _SplashRouteMapState extends State<SplashRouteMap>
    with SingleTickerProviderStateMixin {
  // How long one full pass along the route takes - tweak freely, the
  // animation loops for as long as this widget stays on screen.
  static const Duration animationDuration = Duration(seconds: 9);

  // A winding path through central Nouakchott. Distinct waypoints (not just
  // a straight line) so the car's heading visibly changes as it drives,
  // matching the general shape of the city's street grid.
  static const List<LatLng> _routePoints = [
    LatLng(18.0735, -15.9820),
    LatLng(18.0752, -15.9803),
    LatLng(18.0778, -15.9788),
    LatLng(18.0801, -15.9764),
    LatLng(18.0824, -15.9749),
    LatLng(18.0849, -15.9769),
    LatLng(18.0869, -15.9791),
    LatLng(18.0889, -15.9809),
    LatLng(18.0909, -15.9799),
    LatLng(18.0929, -15.9779),
  ];

  // Muted/"calm" map style: light greys, no POI icons or transit clutter,
  // so the map reads as a soft backdrop instead of competing with the logo.
  static const String _calmMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f2ede4"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#b8ada0"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#f2ede4"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
    {"featureType": "poi", "stylers": [{"visibility": "off"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#e6ddcd"}]},
    {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#f0dfb8"}]},
    {"featureType": "transit", "stylers": [{"visibility": "off"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#d6e8ea"}]}
  ]
  ''';

  late final AnimationController _controller;
  late final List<double> _segmentLengths;
  late final double _totalLength;

  @override
  void initState() {
    super.initState();
    _segmentLengths = [
      for (var i = 0; i < _routePoints.length - 1; i++)
        Geolocator.distanceBetween(
          _routePoints[i].latitude,
          _routePoints[i].longitude,
          _routePoints[i + 1].latitude,
          _routePoints[i + 1].longitude,
        ),
    ];
    _totalLength = _segmentLengths.fold(0.0, (sum, d) => sum + d);

    // reverse: true so the trail animates forward along the route, then
    // back along it, instead of snapping from the last point back to the
    // first each lap.
    _controller = AnimationController(vsync: this, duration: animationDuration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Walks the multi-segment route to the point [t] (0..1) of the way along
  /// its total length, returning that interpolated position plus the
  /// heading (in degrees) of the segment it's currently on.
  ({LatLng position, double heading, List<LatLng> traveled}) _pointAt(
    double t,
  ) {
    final targetDistance = _totalLength * t;
    var covered = 0.0;
    final traveled = <LatLng>[_routePoints.first];

    for (var i = 0; i < _segmentLengths.length; i++) {
      final segmentLength = _segmentLengths[i];
      final start = _routePoints[i];
      final end = _routePoints[i + 1];
      final heading = Geolocator.bearingBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      if (covered + segmentLength >= targetDistance || i == _segmentLengths.length - 1) {
        final segmentT = segmentLength == 0
            ? 0.0
            : ((targetDistance - covered) / segmentLength).clamp(0.0, 1.0);
        final position = LatLng(
          start.latitude + (end.latitude - start.latitude) * segmentT,
          start.longitude + (end.longitude - start.longitude) * segmentT,
        );
        traveled.add(position);
        return (position: position, heading: heading, traveled: traveled);
      }

      covered += segmentLength;
      traveled.add(end);
    }

    return (position: _routePoints.last, heading: 0, traveled: traveled);
  }

  LatLngBounds _routeBounds() {
    var minLat = _routePoints.first.latitude;
    var maxLat = _routePoints.first.latitude;
    var minLng = _routePoints.first.longitude;
    var maxLng = _routePoints.first.longitude;
    for (final point in _routePoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final frame = _pointAt(_controller.value);
            return GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _routePoints[_routePoints.length ~/ 2],
                zoom: 13.6,
              ),
              onMapCreated: (controller) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    controller.animateCamera(
                      CameraUpdate.newLatLngBounds(_routeBounds(), 80),
                    );
                  } catch (_) {
                    // Ignored - the initial camera position is already a
                    // reasonable fallback if the bounds fit fails.
                  }
                });
              },
              style: _calmMapStyle,
              liteModeEnabled: false,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              polylines: {
                // Soft wide "glow" underneath the crisp trail line.
                Polyline(
                  polylineId: const PolylineId('trail_glow'),
                  points: frame.traveled,
                  width: 10,
                  color: AppColors.primary.withOpacity(0.25),
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
                Polyline(
                  polylineId: const PolylineId('trail'),
                  points: frame.traveled,
                  width: 4,
                  color: AppColors.primary,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              },
            );
          },
        ),
        // Translucent gold wash over the map - keeps الهدهد's brand color as
        // the dominant tone and the logo/text legible on top, while still
        // letting the streets of Nouakchott show through underneath.
        Positioned.fill(
          child: Container(color: AppColors.primary.withOpacity(0.62)),
        ),
      ],
    );
  }
}
