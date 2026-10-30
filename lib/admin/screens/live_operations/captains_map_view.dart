import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/map_tile_provider.dart';
import '../../core/admin_colors.dart';
import '../../models/captain_admin_view.dart';
import '../../repositories/admin_captains_repository.dart';

/// Shows every currently-online captain as a marker on a live map, reading
/// [AdminCaptainsRepository.watchCaptainLocations] (the same `captain_locations`
/// table the captain app's own foreground location service keeps fresh -
/// see that repository method's doc comment). A captain who just went
/// online and has no GPS fix yet simply has no marker until one arrives;
/// this view never shows a stale/guessed position.
class CaptainsMapView extends StatelessWidget {
  final List<CaptainAdminView> captains;
  final Map<String, CaptainLocation> locations;

  const CaptainsMapView({
    super.key,
    required this.captains,
    required this.locations,
  });

  // Nouakchott - same default center used throughout the app
  // (app_settings.default_map_lat/lng).
  static const _defaultCenter = LatLng(18.0858, -15.9785);

  @override
  Widget build(BuildContext context) {
    final captainsById = {for (final c in captains) c.id: c};
    final markers = <Marker>[
      for (final entry in locations.entries)
        if (captainsById[entry.key] != null)
          Marker(
            point: LatLng(entry.value.lat, entry.value.lng),
            width: 160,
            height: 60,
            alignment: Alignment.topCenter,
            child: _CaptainMarker(
              captain: captainsById[entry.key]!,
              location: entry.value,
            ),
          ),
    ];

    final tileProvider = defaultMapTileProvider();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 480,
        child: Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 12.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: tileProvider.urlTemplate,
                  userAgentPackageName: tileProvider.userAgentPackageName,
                ),
                MarkerLayer(markers: markers),
                SimpleAttributionWidget(source: Text(tileProvider.attribution)),
              ],
            ),
            if (markers.isEmpty)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'لا يوجد كباتن متصلون لديهم موقع محدّث بعد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptainMarker extends StatelessWidget {
  final CaptainAdminView captain;
  final CaptainLocation location;

  const _CaptainMarker({required this.captain, required this.location});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCaptainInfo(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AdminColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: const Icon(
              Icons.local_taxi_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showCaptainInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          captain.fullName,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              captain.phone ?? '-',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 4),
            Text(
              captain.vehicleType ?? '-',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            if (location.updatedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'آخر تحديث للموقع: '
                '${location.updatedAt!.hour.toString().padLeft(2, '0')}:'
                '${location.updatedAt!.minute.toString().padLeft(2, '0')}:'
                '${location.updatedAt!.second.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
