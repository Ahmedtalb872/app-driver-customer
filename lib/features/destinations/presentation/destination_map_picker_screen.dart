import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/colors.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/widgets/real_map_widget.dart';
import '../data/models/destination_suggestion.dart';

/// Full-screen map for picking a point - used for both a pickup point and a
/// destination (see [title]). A pin stays fixed at the exact center of the
/// screen while the map pans underneath it (the standard ride-hailing-app
/// picker pattern), rather than requiring a tap to place a marker; whatever
/// ends up under the pin's tip when the map stops moving is what gets
/// reverse-geocoded and offered up. Pops with a synthetic
/// [DestinationSuggestion] built from that point, same shape as picking a
/// real search result so every caller downstream is unaffected.
class DestinationMapPickerScreen extends StatefulWidget {
  const DestinationMapPickerScreen({
    super.key,
    this.title = 'اختر الموقع من الخريطة',
  });

  final String title;

  @override
  State<DestinationMapPickerScreen> createState() =>
      _DestinationMapPickerScreenState();
}

class _DestinationMapPickerScreenState
    extends State<DestinationMapPickerScreen> {
  LatLng? _center;
  String? _address;
  bool _isGeocoding = false;
  Timer? _debounce;

  /// Fires on every frame of the map panning - only the point where the map
  /// actually stops (after [_settleDelay] of no further movement) gets
  /// reverse-geocoded, so a fast drag across the city doesn't fire a
  /// network call per frame.
  static const _settleDelay = Duration(milliseconds: 500);

  void _onCameraMove(LatLng point) {
    setState(() => _center = point);
    _debounce?.cancel();
    _debounce = Timer(_settleDelay, () => _geocode(point));
  }

  Future<void> _geocode(LatLng point) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    final address = await GeocodingService.instance.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    // The map may have moved again while this request was in flight - only
    // apply the result if it's still the point the pin is sitting on
    // (compared by coordinates, not object identity/== - not relying on
    // LatLng overriding equality).
    final current = _center;
    if (!mounted ||
        current == null ||
        current.latitude != point.latitude ||
        current.longitude != point.longitude) {
      return;
    }
    setState(() {
      _address = address ?? 'الموقع المحدد على الخريطة';
      _isGeocoding = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _confirm() {
    final point = _center;
    if (point == null) return;
    Navigator.of(context).pop(
      DestinationSuggestion(
        resultType: DestinationResultType.place,
        id: 'map_${point.latitude}_${point.longitude}',
        title: _address ?? 'الموقع المحدد على الخريطة',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Positioned.fill(
            child: RealMapWidget(interactive: true, onCameraMove: _onCameraMove),
          ),
          // The fixed pin - drawn as a plain overlay (not a map marker) so
          // it stays glued to the screen center while the map moves under
          // it. Offset so the icon's *tip*, not its visual middle, marks
          // the selected point.
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 38),
                child: Icon(
                  Icons.location_on,
                  size: 46,
                  color: AppColors.error,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 6,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _center == null
                              ? 'حرّك الخريطة لتحديد الموقع.'
                              : (_isGeocoding
                                    ? 'جارٍ تحديد العنوان...'
                                    : _address ?? ''),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _center == null ? null : _confirm,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('تأكيد هذا الموقع'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
