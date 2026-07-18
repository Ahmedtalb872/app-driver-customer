import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import '../constants/colors.dart';
import '../services/map_tile_provider.dart';
import 'dart:async';

class RealMapWidget extends StatefulWidget {
  final TripStatus? status;
  final bool showRoute;
  final bool animateCar;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? carLat;
  final double? carLng;
  final List<LatLng>? routePolyline;

  /// Thick trail representing the driver's actual traveled path during an
  /// open trip (real GPS breadcrumbs, never a fabricated route).
  final List<LatLng>? tracePolyline;
  final Function(LatLng)? onMapTap;
  final bool interactive;

  /// Tile source for this map instance. Defaults to free OpenStreetMap
  /// tiles - see [MapTileProvider] for how to swap providers later without
  /// touching call sites.
  final MapTileProvider tileProvider;

  /// Whether the pickup marker can be dragged to fine-tune its position
  /// after an initial tap. Off by default so existing read-only map views
  /// (trip tracking, live operations, ...) are unaffected.
  final bool pickupDraggable;

  /// Whether the destination marker can be dragged. Off by default.
  final bool destDraggable;

  /// Called with the new coordinates while the pickup marker is being
  /// dragged. Only used when [pickupDraggable] is true.
  final ValueChanged<LatLng>? onPickupDragged;

  /// Called with the new coordinates while the destination marker is being
  /// dragged. Only used when [destDraggable] is true.
  final ValueChanged<LatLng>? onDestDragged;

  const RealMapWidget({
    super.key,
    this.status,
    this.showRoute = false,
    this.animateCar = false,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.carLat,
    this.carLng,
    this.routePolyline,
    this.tracePolyline,
    this.onMapTap,
    this.interactive = true,
    this.tileProvider = const OpenStreetMapTileProvider(),
    this.pickupDraggable = false,
    this.destDraggable = false,
    this.onPickupDragged,
    this.onDestDragged,
  });

  @override
  State<RealMapWidget> createState() => _RealMapWidgetState();
}

class _RealMapWidgetState extends State<RealMapWidget>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final GlobalKey _mapAreaKey = GlobalKey();
  LatLng _currentCenter = const LatLng(18.0858, -15.9785); // Nouakchott center
  bool _isLoadingLocation = false;

  late AnimationController _carController;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    _determinePosition();

    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _carAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _carController, curve: Curves.easeInOut));

    if (widget.animateCar) {
      _carController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RealMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateCar != oldWidget.animateCar) {
      if (widget.animateCar) {
        _carController.repeat();
      } else {
        _carController.stop();
      }
    }

    // Auto-center map if new locations are provided
    if (widget.pickupLat != null && widget.pickupLng != null) {
      LatLng newLoc = LatLng(widget.pickupLat!, widget.pickupLng!);
      if (oldWidget.pickupLat != widget.pickupLat ||
          oldWidget.pickupLng != widget.pickupLng) {
        _mapController.move(newLoc, 14.0);
      }
    }

    // Same auto-center for the destination marker - e.g. selecting a
    // destination from the dispatch screen's autocomplete/registry picker
    // must pan the map, not just move the marker, exactly like pickup
    // already does above.
    if (widget.destLat != null && widget.destLng != null) {
      LatLng newDest = LatLng(widget.destLat!, widget.destLng!);
      if (oldWidget.destLat != widget.destLat ||
          oldWidget.destLng != widget.destLng) {
        _mapController.move(newDest, 14.0);
      }
    }
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentCenter, 14.0);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  /// Converts a global pointer position (as reported by a marker's drag
  /// gesture) into map coordinates, using the same conversion flutter_map's
  /// own tap handling uses internally (`MapCamera.offsetToCrs` on an offset
  /// relative to the map viewport's top-left corner).
  LatLng? _globalToLatLng(Offset globalPosition) {
    final box = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    return _mapController.camera.offsetToCrs(local);
  }

  @override
  Widget build(BuildContext context) {
    // If no route provided but we have pickup/destination and want to show route
    List<LatLng> polylinePoints = widget.routePolyline ?? [];
    if (polylinePoints.isEmpty &&
        widget.showRoute &&
        widget.pickupLat != null &&
        widget.destLat != null) {
      polylinePoints = [
        LatLng(widget.pickupLat!, widget.pickupLng!),
        LatLng(widget.destLat!, widget.destLng!),
      ];
    }

    return Stack(
      children: [
        FlutterMap(
          key: _mapAreaKey,
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: 13.0,
            onTap: widget.interactive && widget.onMapTap != null
                ? (tapPosition, latLng) => widget.onMapTap!(latLng)
                : null,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: widget.tileProvider.urlTemplate,
              userAgentPackageName: widget.tileProvider.userAgentPackageName,
            ),

            if (polylinePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 4.0,
                    color: AppColors.primary,
                  ),
                ],
              ),

            if (widget.tracePolyline != null &&
                widget.tracePolyline!.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.tracePolyline!,
                    strokeWidth: 6.0,
                    color: AppColors.accent,
                  ),
                ],
              ),

            MarkerLayer(markers: _buildMarkers()),

            SimpleAttributionWidget(
              source: Text(widget.tileProvider.attribution),
            ),
          ],
        ),

        // Map controls (Compass, location)
        Positioned(
          left: 16,
          bottom: 150, // Keep above bottom sheets
          child: Column(
            children: [
              _buildMapButton(Icons.add, () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
              }),
              const SizedBox(height: 8),
              _buildMapButton(Icons.remove, () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                );
              }),
              const SizedBox(height: 8),
              _buildMapButton(
                _isLoadingLocation ? Icons.hourglass_empty : Icons.my_location,
                _determinePosition,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A location pin, optionally draggable. When [draggable], dragging the
  /// pin re-converts the pointer's position into map coordinates on every
  /// frame and reports it via [onDragged] - the parent screen owns the
  /// actual pickup/destination state and re-renders the marker at the new
  /// point, same as it does after a map tap.
  Widget _buildPinMarker({
    required Color color,
    required bool draggable,
    ValueChanged<LatLng>? onDragged,
  }) {
    final pin = Icon(Icons.location_pin, color: color, size: 36);
    if (!draggable || onDragged == null) return pin;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        final latLng = _globalToLatLng(details.globalPosition);
        if (latLng != null) onDragged(latLng);
      },
      child: pin,
    );
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    if (widget.pickupLat != null && widget.pickupLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.pickupLat!, widget.pickupLng!),
          width: 40,
          height: 40,
          child: _buildPinMarker(
            color: AppColors.success,
            draggable: widget.pickupDraggable,
            onDragged: widget.onPickupDragged,
          ),
        ),
      );
    }

    if (widget.destLat != null && widget.destLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.destLat!, widget.destLng!),
          width: 40,
          height: 40,
          child: _buildPinMarker(
            color: AppColors.error,
            draggable: widget.destDraggable,
            onDragged: widget.onDestDragged,
          ),
        ),
      );
    }

    if (widget.carLat != null && widget.carLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.carLat!, widget.carLng!),
          width: 40,
          height: 40,
          child: _buildCarIcon(),
        ),
      );
    } else if (widget.showRoute &&
        widget.pickupLat != null &&
        widget.destLat != null) {
      // Animate a simulated car between pickup and destination
      markers.add(
        Marker(
          point: _getSimulatedCarLocation(),
          width: 40,
          height: 40,
          child: _buildCarIcon(),
        ),
      );
    }

    return markers;
  }

  LatLng _getSimulatedCarLocation() {
    if (widget.pickupLat == null || widget.destLat == null) {
      return _currentCenter;
    }

    double t = _carAnimation.value;

    if (widget.status == TripStatus.started) {
      // Move from pickup to destination
      double lat =
          widget.pickupLat! + (widget.destLat! - widget.pickupLat!) * t;
      double lng =
          widget.pickupLng! + (widget.destLng! - widget.pickupLng!) * t;
      return LatLng(lat, lng);
    } else if (widget.status == TripStatus.accepted ||
        widget.status == TripStatus.enRoute) {
      // Simulate coming to pickup
      double fakeStartLat = widget.pickupLat! - 0.01;
      double fakeStartLng = widget.pickupLng! - 0.01;
      double lat = fakeStartLat + (widget.pickupLat! - fakeStartLat) * t;
      double lng = fakeStartLng + (widget.pickupLng! - fakeStartLng) * t;
      return LatLng(lat, lng);
    }

    return LatLng(widget.pickupLat!, widget.pickupLng!);
  }

  Widget _buildCarIcon() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(
        Icons.local_taxi_rounded,
        color: AppColors.darkText,
        size: 16,
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.darkText, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
