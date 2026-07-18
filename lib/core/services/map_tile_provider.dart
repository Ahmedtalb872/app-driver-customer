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

/// Default tile provider for this app: free OpenStreetMap raster tiles, no
/// API key, no paid usage tier. Used everywhere unless a screen explicitly
/// opts into a different [MapTileProvider].
class OpenStreetMapTileProvider extends MapTileProvider {
  const OpenStreetMapTileProvider();

  @override
  String get urlTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String get attribution => 'OpenStreetMap contributors';

  @override
  String get userAgentPackageName => 'com.alhudhud.app';
}
