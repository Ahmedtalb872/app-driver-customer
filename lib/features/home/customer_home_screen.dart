import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/services/ride_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_search_screen.dart';
import '../profile/profile_screen.dart';
import '../subscription/captains_browse_screen.dart';
import '../trips/delivery_request_screen.dart';
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
  String _pickupAddress = 'موقعي الحالي';
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determinePickup();
    _resumeActiveTripIfAny();
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
              content: Text('تعذر التحقق من مشوار جارٍ: $e'),
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
          initialPickupAddress: _pickupAddress,
        ),
      ),
    );
  }

  /// Parcel delivery entry point, separate from [TripPlannerScreen] (a
  /// delivery isn't a "trip type" - it always has a destination and
  /// collects a recipient/package instead of a passenger count, see
  /// [DeliveryRequestScreen]). Reuses the same destination search screen.
  Future<void> _startDeliveryRequest() async {
    if (_pickupLat == null || _pickupLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء تفعيل خدمة الموقع الجغرافي لتتمكن من طلب توصيل.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    final destination = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(builder: (context) => const DestinationSearchScreen()),
    );
    if (destination == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeliveryRequestScreen(
          pickupLat: _pickupLat!,
          pickupLng: _pickupLng!,
          pickupAddress: _pickupAddress,
          destination: destination,
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
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _buildLocationBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _buildServiceCards(),
          ),
        ],
        ),
      ),
    );
  }

  /// The location "خانة تحديث الموقع" the home screen shows the detected
  /// pickup address in, with a refresh action - separate from the compact
  /// icon-only button in the logo row above (kept for a quick refresh
  /// without needing to read the address), this is the only place on the
  /// home screen that actually shows *where* the app currently thinks the
  /// customer is before they ever open the trip planner.
  Widget _buildLocationBar() {
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
                    const Text(
                      'موقعك الحالي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLocating ? 'جارٍ تحديد الموقع...' : _pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
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

  /// Each service is its own elevated card with a gap between them
  /// (previously one card with hairline dividers between rows) - easier to
  /// scan and matches the spaced-card style used elsewhere in the app
  /// (e.g. WalletScreen's Selefli/subscription banners).
  Widget _buildServiceCards() {
    return Column(
      children: [
        _ServiceCard(
          onTap: _openTripPlanner,
          leadingColor: AppColors.accent,
          leadingIcon: Icons.search_rounded,
          title: 'إلى أين تريد الذهاب؟',
          subtitle: 'مشوار عادي أو مفتوح',
        ),
        const SizedBox(height: 12),
        _ServiceCard(
          onTap: _startDeliveryRequest,
          leadingColor: AppColors.accent,
          leadingIcon: Icons.local_shipping_rounded,
          title: 'توصيل طرد',
          subtitle: 'أريد توصيل طرد بدل ركوب مشوار',
        ),
        const SizedBox(height: 12),
        _ServiceCard(
          onTap: _openCaptainsBrowse,
          leadingColor: AppColors.accent,
          leadingIcon: Icons.handshake_rounded,
          title: 'اشتراك شهري مع كابتن',
          subtitle: 'مشاوير بلا مقابل إضافي',
        ),
        const SizedBox(height: 12),
        _ServiceCard(
          onTap: _openSelefli,
          leadingColor: AppColors.accent,
          leadingIcon: Icons.payments_rounded,
          title: 'سلفلي',
          subtitle: 'اطلب مشوارك الآن وادفع لاحقاً',
        ),
      ],
    );
  }

  static const List<_NavItemData> _navItems = [
    _NavItemData(Icons.home_rounded, 'الرئيسية'),
    _NavItemData(Icons.history_rounded, 'رحلاتي'),
    _NavItemData(Icons.wallet_rounded, 'المحفظة'),
    _NavItemData(Icons.person_rounded, 'حسابي'),
  ];

  Widget _buildBottomNavigationBar() {
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
              for (var i = 0; i < _navItems.length; i++)
                _NavItem(
                  data: _navItems[i],
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

/// One of the home dashboard's service entry points - its own elevated,
/// rounded card (see [_CustomerHomeScreenState._buildServiceCards]).
class _ServiceCard extends StatelessWidget {
  final VoidCallback onTap;
  final Color leadingColor;
  final IconData leadingIcon;
  final String title;
  final String subtitle;

  const _ServiceCard({
    required this.onTap,
    required this.leadingColor,
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      shadowColor: AppColors.primaryDark.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconBadge(icon: leadingIcon, color: leadingColor, size: 42, iconSize: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.secondaryText,
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
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
