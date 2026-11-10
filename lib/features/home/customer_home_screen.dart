import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/services/ride_repository.dart';
import '../../core/services/saved_places_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../profile/profile_screen.dart';
import '../subscription/captains_browse_screen.dart';
import '../trips/delivery_locations_screen.dart';
import '../trips/my_trips_screen.dart';
import '../trips/trip_planner_screen.dart';
import '../trips/trip_tracking_screen.dart';
import '../wallet/wallet_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _pushedActiveTripId;

  double? _pickupLat;
  double? _pickupLng;
  String? _pickupAddress;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determinePickup();
    _resumeActiveTripIfAny();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pickupAddress ??= AppLocalizations.of(context)!.myCurrentLocation;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Nothing else in this app ever reacts to app-lifecycle transitions -
  /// this screen is the sole exception, specifically so a still-active trip
  /// isn't missed on the far more common case of the app being backgrounded
  /// and later resumed *without* the process actually restarting (a full
  /// restart already re-triggers [_resumeActiveTripIfAny] via [initState],
  /// but that alone left a gap: the OS can resume this exact same
  /// long-lived screen instance - initState never runs again - after the
  /// customer switched away mid-request and the trip only became active
  /// while they were gone).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeActiveTripIfAny();
    }
  }

  /// Best-effort: [AppStateProvider.activeTrip] only ever lives in memory -
  /// this app has no local persistence of it at all - so if this customer
  /// already has a trip running server-side that this screen doesn't know
  /// about yet (the app was restarted after losing connectivity mid-trip,
  /// simply relaunched, or just resumed from the background - see
  /// [didChangeAppLifecycleState]), there would otherwise be no way back
  /// into [TripTrackingScreen] even though the trip is still very much
  /// active. build() below already pushes it whenever provider.activeTrip
  /// holds a non-terminal trip; this just makes sure that field actually
  /// gets populated here too, not only by [TripTrackingScreen] itself once
  /// already open.
  Future<void> _resumeActiveTripIfAny() async {
    if (!mounted) return;
    final provider = context.read<AppStateProvider>();
    if (provider.activeTrip != null) return;
    try {
      final trip = await RideRepository.instance.fetchActiveTrip();
      if (trip != null && mounted) {
        provider.setActiveTripFromBackend(trip);
      }
    } catch (e) {
      // Best effort - a fetch failure just leaves the customer on the home
      // screen, same as if they truly had no active trip. debugPrint alone
      // is invisible on a real installed APK (only shows with a debugger
      // attached), and a reported case of this exact failure mode (a still-
      // open trip not being resumed after a full app close/reopen) had no
      // way to be diagnosed without it - a visible SnackBar at least lets
      // whoever hits this screenshot the real error.
      debugPrint('CustomerHomeScreen: fetchActiveTrip failed: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.checkActiveTripError('$e'),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        });
      }
    }
  }

  Future<void> _determinePickup() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _pickupLat = position.latitude;
        _pickupLng = position.longitude;
      });

      final address = await GeocodingService.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (mounted && address != null) {
        setState(() => _pickupAddress = address);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Opens [TripPlannerScreen], which owns the pickup/destination pickers
  /// and the normal-vs-open choice for both - pre-filled with the
  /// GPS-detected pickup point above, freely changeable there.
  void _openTripPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TripPlannerScreen(
          initialPickupLat: _pickupLat,
          initialPickupLng: _pickupLng,
          initialPickupAddress:
              _pickupAddress ?? AppLocalizations.of(context)!.myCurrentLocation,
        ),
      ),
    );
  }

  /// Parcel delivery entry point, separate from [TripPlannerScreen] (a
  /// delivery isn't a "trip type" - it always has a destination and
  /// collects a recipient/package instead of a passenger count, see
  /// DeliveryRequestScreen). Opens [DeliveryLocationsScreen], which asks
  /// for BOTH the pickup (where the package is collected from) and the
  /// destination inline on one screen - the same LocationSearchField
  /// type-to-search-or-pick-from-map pattern the normal ride's
  /// pickup/destination fields use - rather than silently locking pickup to
  /// the customer's detected GPS location with no way to change it, which is
  /// wrong whenever the parcel isn't actually being picked up from wherever
  /// the customer is standing.
  void _startDeliveryRequest() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeliveryLocationsScreen(
          initialPickupLat: _pickupLat,
          initialPickupLng: _pickupLng,
          initialPickupAddress: _pickupAddress,
        ),
      ),
    );
  }

  /// "سلفلي" (pay-later credit) isn't its own request flow - it's a
  /// payment method picked at request time (see
  /// [RequestRideScreen._buildSelefliOption]), only ever offered once an
  /// estimated price is known for a normal ride. WalletScreen already shows
  /// a customer's real Selefli status (eligible/outstanding debt/how many
  /// more rides until eligible - see its `_buildSelefliCard`), so that's
  /// the most useful thing this home-screen entry point can open directly.
  void _openSelefli() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WalletScreen(showAppBar: true),
      ),
    );
  }

  void _openCaptainsBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CaptainsBrowseScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final screens = [
      _buildDashboardView(),
      const MyTripsScreen(showAppBar: false),
      const WalletScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    final activeTrip = provider.activeTrip;
    final tripInProgress =
        activeTrip != null &&
        (activeTrip.status == TripStatus.searching ||
            activeTrip.status == TripStatus.accepted ||
            activeTrip.status == TripStatus.enRoute ||
            activeTrip.status == TripStatus.arrived ||
            activeTrip.status == TripStatus.started);

    if (tripInProgress && _pushedActiveTripId != activeTrip.id) {
      _pushedActiveTripId = activeTrip.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TripTrackingScreen(tripId: activeTrip.id),
          ),
        );
      });
    } else if (!tripInProgress) {
      _pushedActiveTripId = null;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: screens[_currentIndex],
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _LogoBadge(),
                  _CircleIconButton(
                    icon: _isLocating
                        ? Icons.hourglass_empty
                        : Icons.my_location_rounded,
                    onTap: _isLocating ? null : _determinePickup,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildLocationBar(),
              const SizedBox(height: 20),
              _buildHeroBanner(),
              const SizedBox(height: 20),
              _buildServiceTilesGrid(),
              const SizedBox(height: 24),
              _buildSavedPlacesSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Promo-style banner above the service grid - the "تنقّل بسهولة / اطلب
  /// الآن" hook that opens [TripPlannerScreen] directly, same screen the
  /// "where to" tile below also opens. Purely a second, more prominent
  /// entry point to the single most common action on this screen.
  Widget _buildHeroBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            left: -18,
            bottom: -22,
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: 130,
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تنقّل بكل سهولة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'رحلات آمنة وسريعة في أي وقت',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _openTripPlanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'اطلب الآن',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The four real entry points this screen offers, as a 2x2 grid of big
  /// icon tiles (replaces the previous single-column list of rows) - same
  /// visual language as the reference design's Courses/Livraison/Voyage
  /// tiles, sized to this app's actual feature set instead of inventing
  /// ones it doesn't have (there's no restaurant ordering here).
  Widget _buildServiceTilesGrid() {
    final tiles = [
      _TileData(
        icon: Icons.local_taxi_rounded,
        color: AppColors.primary,
        label: 'رحلة',
        onTap: _openTripPlanner,
      ),
      _TileData(
        icon: Icons.local_shipping_rounded,
        color: AppColors.accent,
        label: 'توصيل',
        onTap: _startDeliveryRequest,
      ),
      _TileData(
        icon: Icons.handshake_rounded,
        color: AppColors.success,
        label: 'اشتراك كابتن',
        onTap: _openCaptainsBrowse,
      ),
      _TileData(
        icon: Icons.payments_rounded,
        color: AppColors.primaryDark,
        label: 'سلفلي',
        onTap: _openSelefli,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.3,
      children: [for (final t in tiles) _ServiceTile(data: t)],
    );
  }

  /// Horizontal shortcut row for this customer's saved places (home/work/
  /// other - see [SavedPlacesRepository]) - hidden entirely while none are
  /// saved yet rather than showing an empty section. Each chip just opens
  /// the trip planner today; it doesn't yet pre-fill that place as the
  /// destination (TripPlannerScreen takes no initial-destination param).
  Widget _buildSavedPlacesSection() {
    return FutureBuilder<List<SavedPlace>>(
      future: SavedPlacesRepository.instance.fetchMine(),
      builder: (context, snapshot) {
        final places = snapshot.data ?? const [];
        if (places.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الأماكن المحفوظة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: places.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _SavedPlaceChip(place: places[index], onTap: _openTripPlanner),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The location "خانة تحديث الموقع" the home screen shows the detected
  /// pickup address in, with a refresh action - separate from the compact
  /// icon-only button in the logo row above (kept for a quick refresh
  /// without needing to read the address), this is the only place on the
  /// home screen that actually shows *where* the app currently thinks the
  /// customer is before they ever open the trip planner.
  Widget _buildLocationBar() {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: AppColors.primaryDark.withOpacity(0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isLocating ? null : _determinePickup,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const _IconBadge(
                icon: Icons.location_on_rounded,
                color: AppColors.success,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentLocationLabel,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLocating
                          ? l10n.locatingInProgress
                          : (_pickupAddress ?? l10n.myCurrentLocation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  List<_NavItemData> _navItems(AppLocalizations l10n) => [
    _NavItemData(Icons.home_rounded, l10n.navHome),
    _NavItemData(Icons.history_rounded, l10n.navTrips),
    _NavItemData(Icons.wallet_rounded, l10n.navWallet),
    _NavItemData(Icons.person_rounded, l10n.navProfile),
  ];

  Widget _buildBottomNavigationBar() {
    final navItems = _navItems(AppLocalizations.of(context)!);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < navItems.length; i++)
                _NavItem(
                  data: navItems[i],
                  selected: _currentIndex == i,
                  onTap: () => setState(() => _currentIndex = i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset('assets/images/al-houdhoud-logo-mark.png', fit: BoxFit.contain),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
        ),
      ),
    );
  }
}

/// Small circular tinted icon badge used across the redesigned home
/// dashboard (where-to bar, trip-type chips, delivery row) so every entry
/// point reads as part of the same visual system instead of a bare Icon.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const _IconBadge({
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _TileData {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _TileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

/// One of the home dashboard's four big service tiles (see
/// [_CustomerHomeScreenState._buildServiceTilesGrid]) - a colored icon
/// chip over a short label, the same "illustration tile" language as the
/// reference design's service grid.
class _ServiceTile extends StatelessWidget {
  final _TileData data;
  const _ServiceTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: AppColors.primaryDark.withOpacity(0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: data.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconBadge(icon: data.icon, color: data.color, size: 52, iconSize: 26),
            const SizedBox(height: 10),
            Text(
              data.label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved-place shortcut card (see
/// [_CustomerHomeScreenState._buildSavedPlacesSection]).
class _SavedPlaceChip extends StatelessWidget {
  final SavedPlace place;
  final VoidCallback onTap;
  const _SavedPlaceChip({required this.place, required this.onTap});

  IconData get _icon => switch (place.label) {
    'home' => Icons.home_rounded,
    'work' => Icons.work_rounded,
    _ => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: AppColors.primaryDark.withOpacity(0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: _icon, color: AppColors.primary, size: 30, iconSize: 15),
              const Spacer(),
              Text(
                place.displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData(this.icon, this.label);
}

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Gold instead of the usual teal on the selected tab - a deliberate,
    // easy-to-spot-in-a-screenshot marker to confirm a build actually
    // reached the device/browser being tested, independent of whatever's
    // going on with the home dashboard's where-to card.
    final color = selected ? AppColors.accent : AppColors.secondaryText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withOpacity(0.15)
                    : Colors.transparent,
                border: selected
                    ? Border.all(color: AppColors.accent, width: 1.5)
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(data.icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
