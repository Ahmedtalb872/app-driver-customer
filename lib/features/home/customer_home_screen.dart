import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_search_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/delivery_request_screen.dart';
import '../trips/my_trips_screen.dart';
import '../trips/request_ride_screen.dart';
import '../trips/trip_tracking_screen.dart';
import '../wallet/wallet_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  String? _pushedActiveTripId;

  double? _pickupLat;
  double? _pickupLng;
  String _pickupAddress = 'موقعي الحالي';
  bool _isLocating = false;
  TripType _tripType = TripType.normal;

  @override
  void initState() {
    super.initState();
    _determinePickup();
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

  /// Lets the customer fine-tune (or fully override the GPS-detected)
  /// pickup point by tapping or dragging the pin on the home screen map -
  /// mirrors how the admin dispatch/route-editing maps already let an
  /// operator set a point (see `RealMapWidget.pickupDraggable`).
  Future<void> _handlePickupPointChanged(LatLng point) async {
    setState(() {
      _pickupLat = point.latitude;
      _pickupLng = point.longitude;
      _pickupAddress = 'جارٍ تحديد العنوان...';
    });
    final address = await GeocodingService.instance.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _pickupAddress = address ?? 'الموقع المحدد على الخريطة';
    });
  }

  Future<void> _startRequest() async {
    if (_pickupLat == null || _pickupLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء تفعيل خدمة الموقع الجغرافي لتتمكن من طلب مشوار.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    // An open trip has no destination to search for - its whole point is
    // that one is picked as the ride happens - so it skips straight to the
    // confirm screen with none.
    if (_tripType == TripType.open) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RequestRideScreen(
            pickupLat: _pickupLat!,
            pickupLng: _pickupLng!,
            pickupAddress: _pickupAddress,
            tripType: TripType.open,
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
        builder: (context) => RequestRideScreen(
          pickupLat: _pickupLat!,
          pickupLng: _pickupLng!,
          pickupAddress: _pickupAddress,
          destination: destination,
          tripType: TripType.normal,
        ),
      ),
    );
  }

  /// Parcel delivery entry point, separate from the ride trip-type selector
  /// above (a delivery isn't a third "trip type" - it always has a
  /// destination and collects a recipient/package instead of a passenger
  /// count, see [DeliveryRequestScreen]). Reuses the same destination search
  /// screen as a normal ride.
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
    // NOT a Stack with the where-to bar floating over the map anymore.
    // Two diagnostic builds nailed down why: with the map swapped for a
    // solid color the overlay rendered fine, but with the real map back
    // (flutter_map/web, tiles fetched cross-origin) it silently disappeared
    // again with no exception anywhere - consistent with flutter_map's web
    // tile images compositing as a browser-level layer that sits above
    // Flutter's own canvas regardless of widget stack order, which no
    // amount of Z-ordering inside Flutter can override. Laying the where-to
    // bar out below the map instead of on top of it sidesteps that
    // entirely, at the cost of the map no longer filling the full screen.
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                // Fixed height instead of Expanded - deliberately removing
                // flex layout from this section entirely as a variable
                // while tracking down why this exact area has repeatedly
                // rendered in an order/size that didn't match the code.
                height: 260,
                // The web preview build only: flutter_map's live tiles have
                // been the one remaining suspect across every layout
                // rewrite, so this swaps in a plain decorative placeholder
                // there instead, isolating it completely. Android/iOS keep
                // the real interactive map - this never touches the actual
                // app.
                child: kIsWeb ? const _MapPlaceholder() : RealMapWidget(
                  interactive: true,
                  pickupLat: _pickupLat,
                  pickupLng: _pickupLng,
                  onMapTap: _handlePickupPointChanged,
                  pickupDraggable: true,
                  onPickupDragged: _handlePickupPointChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildWhereToBar(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildWhereToBar() {
    final isOpen = _tripType == TripType.open;
    // Material + elevation instead of a Container/BoxDecoration with a
    // manual boxShadow - a diagnostic build proved this card's background,
    // border and shadow simply never painted (only its child content did)
    // while everything else on the same screen rendered fine; Material's
    // elevation system is the standard, better-tested way to get a white
    // elevated surface and doesn't have that failure mode.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 10,
      shadowColor: AppColors.primaryDark.withOpacity(0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            onTap: _startRequest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Row(
                children: [
                  _IconBadge(
                    icon: isOpen ? Icons.timelapse_rounded : Icons.search_rounded,
                    color: isOpen ? AppColors.accent : AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOpen ? 'اطلب مشوار مفتوح الآن' : 'إلى أين تريد الذهاب؟',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isOpen
                              ? 'بدون وجهة محددة - الانطلاق من: $_pickupAddress'
                              : 'الانطلاق من: $_pickupAddress',
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
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: _buildTripTypeSelector(),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            onTap: _startDeliveryRequest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  _IconBadge(
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.secondary,
                    size: 32,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'أريد توصيل طرد بدل ركوب مشوار',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTypeSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildTripTypeChip(
            type: TripType.normal,
            icon: Icons.route_rounded,
            label: 'عادي',
            description: 'تحدد وجهتك',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTripTypeChip(
            type: TripType.open,
            icon: Icons.timelapse_rounded,
            label: 'مفتوح',
            description: 'بدون وجهة، السائق تحت تصرفك',
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  // "عادي"/"مفتوح" alone don't tell a first-time user what actually differs
  // between the two (a fixed destination vs. none at all) - each chip now
  // carries a one-line description under the label so the distinction is
  // clear before tapping, not just after.
  Widget _buildTripTypeChip({
    required TripType type,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
  }) {
    final selected = _tripType == type;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.09) : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? color : Colors.transparent, width: 1.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _tripType = type),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBadge(icon: icon, color: color, size: 30, iconSize: 15),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: selected ? color : AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9.5,
                    color: selected
                        ? color.withOpacity(0.85)
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

/// Static stand-in for the live map, web preview only - see the call site
/// in [_CustomerHomeScreenState._buildDashboardView].
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.background, AppColors.primary.withOpacity(0.15)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_rounded,
              size: 40,
              color: AppColors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'الخريطة متاحة في التطبيق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
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
