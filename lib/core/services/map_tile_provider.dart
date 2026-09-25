import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Abstraction over the map's tile source.
///
/// Every screen that renders a map (customer, captain, admin/operator
/// dispatch) goes through [RealMapWidget], which reads its tiles from a
/// [MapTileProvider] instead of hardcoding a URL. That means switching the
/// whole app - or just the admin dashboard - from free OpenStreetMap tiles
/// to a paid provider (e.g. Google Maps tiles) later is a one-place change:
/// implement a new [MapTileProvider] and pass it in, no screen rewrites.
abstract class MapTileProvider {
  const MapTileProvider();

  /// XYZ tile URL template, e.g. `https://.../{z}/{x}/{y}.png`.
  String get urlTemplate;

  /// Attribution text required by the tile source's usage policy.
  String get attribution;

  /// Required by some tile servers (including OpenStreetMap's) to identify
  /// the requesting app.
  String get userAgentPackageName;

  /// Whether this provider needs a secret API key to function. The default,
  /// free OpenStreetMap provider never does - see [OpenStreetMapTileProvider].
  bool get requiresApiKey => false;
}

/// Free OpenStreetMap raster tiles, no API key, no paid usage tier. This is
/// the fallback [MapTileProvider] whenever [MapTilerTileProvider] isn't
/// configured (see [defaultMapTileProvider]) - never removed, since it's
/// what keeps the app's map working with zero setup.
class OpenStreetMapTileProvider extends MapTileProvider {
  const OpenStreetMapTileProvider();

  @override
  String get urlTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String get attribution => 'OpenStreetMap contributors';

  @override
  String get userAgentPackageName => 'com.alhudhud.app';
}

/// MapTiler's raster "streets" style - closer to the familiar Google-Maps
/// look (per the Hudhud Map Spec) than OpenStreetMap's default raster
/// tiles. Requires an API key from a MapTiler account (free tier covers
/// moderate usage); see [defaultMapTileProvider] for how that key is read
/// and what happens when it isn't set yet.
class MapTilerTileProvider extends MapTileProvider {
  const MapTilerTileProvider(this.apiKey);

  final String apiKey;

  @override
  String get urlTemplate =>
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$apiKey';

  @override
  String get attribution => 'MapTiler © OpenStreetMap contributors';

  @override
  String get userAgentPackageName => 'com.alhudhud.app';

  @override
  bool get requiresApiKey => true;
}

/// The tile provider every [RealMapWidget] uses unless a call site passes
/// its own - reads `MAPTILER_API_KEY` from the already-loaded `.env` (same
/// file/mechanism as `SUPABASE_URL`, see `SupabaseConfig.initialize`) and
/// switches to [MapTilerTileProvider] when it's set. Falls back to
/// [OpenStreetMapTileProvider] when the key is missing/empty, so a build
/// that hasn't configured MapTiler yet (e.g. CI before the secret is added)
/// still renders a working map instead of broken/blank tiles.
MapTileProvider defaultMapTileProvider() {
  final key = dotenv.env['MAPTILER_API_KEY'];
  if (key != null && key.trim().isNotEmpty) {
    return MapTilerTileProvider(key.trim());
  }
  return const OpenStreetMapTileProvider();
}
