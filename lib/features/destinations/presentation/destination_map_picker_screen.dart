import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/colors.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/widgets/real_map_widget.dart';
import '../data/models/destination_suggestion.dart';

/// Full-screen map for picking a point by tapping directly - used for both
/// a pickup point and a destination (see [title]). Pops with a synthetic
/// [DestinationSuggestion] built from the tapped point and its
/// reverse-geocoded address, same shape as picking a real search result so
/// every caller downstream is unaffected. Deliberately just a full-screen
/// map plus one small confirm card, not sharing a screen with any other
/// floating content - see [TripPlannerScreen] for why that separation
/// matters here.
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
  LatLng? _picked;
  String? _address;
  bool _isGeocoding = false;

  Future<void> _handleTap(LatLng point) async {
    setState(() {
      _picked = point;
      _isGeocoding = true;
      _address = null;
    });
    final address = await GeocodingService.instance.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _address = address ?? 'الموقع المحدد على الخريطة';
      _isGeocoding = false;
    });
  }

  void _confirm() {
    final point = _picked;
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
            child: RealMapWidget(
              interactive: true,
              destLat: _picked?.latitude,
              destLng: _picked?.longitude,
              onMapTap: _handleTap,
              destDraggable: true,
              onDestDragged: _handleTap,
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
                          _picked == null
                              ? 'اضغط على أي نقطة فى الخريطة لتحديدها.'
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
                          onPressed: _picked == null || _isGeocoding
                              ? null
                              : _confirm,
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
