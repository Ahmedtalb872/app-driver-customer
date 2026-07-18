import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/demo_mode_config.dart';
import '../../core/constants/colors.dart';
import '../../core/services/captain_session.dart';
import '../../core/services/ride_alert_service.dart';
import '../../core/services/ride_notification_service.dart';
import '../../core/services/ride_repository.dart';
import '../../core/services/ride_settings_service.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../trips/my_trips_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import 'captain_active_trip_screen.dart';
import 'demo_trip_generator.dart';
import 'trip_request_screen.dart';
import '../authentication/captain_login_screen.dart';
import '../../dummy_data/dummy_data.dart';

class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Tracks which trip we've already pushed the active-trip screen for, so a
  // provider notification while that screen is on top (e.g. status changing
  // from arrived to started) doesn't push a second, duplicate instance.
  String? _pushedActiveTripId;

  // Real incoming-request pipeline: replaces the AppStateProvider timer
  // simulation with a live Supabase realtime subscription (see
  // RideRepository.watchIncomingRequests) once the captain is online.
  StreamSubscription<Trip?>? _incomingSub;
  bool _subscribedToIncoming = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RideSettingsService.instance.load();
    RideNotificationService.instance.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CaptainSession>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingSub?.cancel();
    RideAlertService.instance.stop();
    super.dispose();
  }

  // Backgrounding/closing the app means the captain can no longer receive
  // the realtime ride broadcast or show the accept dialog, so `is_online`
  // must not stay true - otherwise admin dispatch and other captains'
  // client-side filtering both keep treating this captain as reachable
  // (see 20260717000036_captain_online_dispatch_guard.sql for the
  // server-side half of this fix). Best effort: `CaptainSession.setOnline`
  // already no-ops for the always-online demo captain and swallows nothing
  // here beyond what a dying/suspended app process would swallow anyway.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    final session = context.read<CaptainSession>();
    if (session.isOnline) {
      session.setOnline(false).catchError((_) {});
    }
  }

  void _syncIncomingSubscription(CaptainSession session) {
    final shouldSubscribe = session.isOnline && session.captainId != null;
    if (shouldSubscribe == _subscribedToIncoming) return;
    _subscribedToIncoming = shouldSubscribe;

    _incomingSub?.cancel();
    _incomingSub = null;

    if (shouldSubscribe) {
      _incomingSub = RideRepository.instance
          .watchIncomingRequests(session.captainId!)
          .listen(_handleIncomingTrip);
    } else {
      RideAlertService.instance.stop();
      if (_dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }
  }

  void _handleIncomingTrip(Trip? trip) {
    if (!mounted) return;
    if (trip == null) {
      // The request this captain was looking at disappeared (accepted by
      // someone else, expired, or ignored) - clear our own alert/dialog.
      if (_dialogOpen) {
        RideAlertService.instance.stop();
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      return;
    }
    // Only one incoming-ride dialog is ever shown at a time.
    if (_dialogOpen) return;

    _dialogOpen = true;

    RideAlertService.instance.start(
      soundEnabled: RideSettingsService.instance.soundEnabled,
      vibrationEnabled: RideSettingsService.instance.vibrationEnabled,
      volume: RideSettingsService.instance.volume,
    );
    RideNotificationService.instance.showIncomingRide(
      tripId: trip.id,
      passengerName: trip.customerName,
      pickupAddress: trip.pickupLocation,
      destinationLabel: trip.isOpenTrip
          ? 'مشوار مفتوح'
          : trip.destinationLocation,
      estimatedFare: trip.isOpenTrip ? null : trip.price,
    );

    Navigator.of(context, rootNavigator: true)
        .push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (routeContext) => TripRequestScreen(
              trip: trip,
              onAccept: () => _handleAccept(trip),
              onIgnore: () => _handleIgnore(trip),
              onExpired: () => _handleDismiss(trip),
            ),
          ),
        )
        .then((_) {
          _dialogOpen = false;
          RideAlertService.instance.stop();
          RideNotificationService.instance.cancelIncomingRide(trip.id);
        });
  }

  Future<void> _handleAccept(Trip trip) async {
    // Demo/trial requests (see DemoTripGenerator) have no backing `trips`
    // row - accepting one only ever updates local app state, never the real
    // captain_accept_trip RPC.
    if (trip.isDemoTrip) {
      await RideAlertService.instance.stop();
      if (!mounted) return;
      context.read<AppStateProvider>().setActiveTripFromBackend(
        trip.copyWith(status: TripStatus.accepted),
      );
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    try {
      final accepted = await RideRepository.instance.acceptTrip(trip.id);
      await RideAlertService.instance.stop();
      if (!mounted) return;
      context.read<AppStateProvider>().setActiveTripFromBackend(accepted);
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      await RideAlertService.instance.stop();
      rethrow; // The dialog itself shows the canned error message.
    }
  }

  Future<void> _handleIgnore(Trip trip) async {
    await RideAlertService.instance.stop();
    if (!trip.isDemoTrip) {
      try {
        await RideRepository.instance.ignoreTrip(trip.id);
      } catch (_) {
        // Best effort - the dialog closes regardless.
      }
    }
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<void> _handleDismiss(Trip trip) async {
    await RideAlertService.instance.stop();
    if (!trip.isDemoTrip) {
      unawaited(RideRepository.instance.expireTrip(trip.id));
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('انتهت مهلة قبول المشوار')));
  }

  /// Feeds a locally-generated trial request into the exact same
  /// incoming-request pipeline a real Supabase broadcast uses (ringtone,
  /// vibration, countdown, accept/reject) - see [_handleIncomingTrip]. That
  /// method already refuses to show a second request while one is active, so
  /// this can never create more than one active request at a time.
  void _generateDemoTrip(Trip trip) => _handleIncomingTrip(trip);

  /// Temporary developer-only menu (see [DemoModeConfig.isEnabled]) to spawn
  /// a trial ride request without waiting for a real passenger.
  void _showDemoTripMenu() {
    if (_dialogOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يوجد طلب نشط بالفعل، عالجه أولاً')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'توليد مشوار تجريبي',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.payments_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'مشوار بسعر ثابت',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _generateDemoTrip(DemoTripGenerator.fixedPriceTrip());
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.speed_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'مشوار بالعداد',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _generateDemoTrip(DemoTripGenerator.meterTrip());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Turns a captain_set_online failure into the real, specific reason
  /// instead of a generic "try again" - the exact cause (no valid session,
  /// account not approved yet, suspended, a genuine network/server error,
  /// ...) is always available from the thrown exception, so there's no
  /// reason to hide it from the captain.
  String _describeOnlineError(Object error) {
    if (error is PostgrestException) {
      final message = error.message;
      if (message.contains('No captain profile found')) {
        return 'لا توجد جلسة كابتن صالحة على الخادم. سجّل الخروج وأعد تسجيل الدخول.';
      }
      // captain_set_online raises its approval/suspension messages already
      // in Arabic (see the captain_set_online migration) - show as-is.
      return message;
    }
    if (error is AuthException) {
      return error.message;
    }
    return 'تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final captainSession = Provider.of<CaptainSession>(context);
    _syncIncomingSubscription(captainSession);

    // List of screens for bottom navigation
    final List<Widget> screens = [
      _buildDashboardView(captainSession),
      const MyTripsScreen(showAppBar: false),
      const WalletScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    // Auto navigate to active trip screen if captain has accepted a trip
    final activeTrip = provider.activeTrip;
    final tripInProgress =
        activeTrip != null &&
        (activeTrip.status == TripStatus.accepted ||
            activeTrip.status == TripStatus.enRoute ||
            activeTrip.status == TripStatus.arrived ||
            activeTrip.status == TripStatus.started);

    if (tripInProgress && _pushedActiveTripId != activeTrip.id) {
      _pushedActiveTripId = activeTrip.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CaptainActiveTripScreen(),
          ),
        );
      });
    } else if (!tripInProgress) {
      _pushedActiveTripId = null;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(provider),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: screens[_currentIndex],
    );
  }

  Widget _buildDashboardView(CaptainSession captainSession) {
    final isOnline = captainSession.isOnline;
    return Stack(
      children: [
        // The map is the main element of this screen - full-bleed, no
        // route/pickup/destination markers while there's no real request
        // (those only ever appear on TripRequestScreen/CaptainActiveTripScreen
        // once a real trip exists).
        Positioned.fill(
          child: RealMapWidget(showRoute: false, interactive: isOnline),
        ),

        if (!isOnline)
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),

        // Header row: menu (top-right), connection capsule (top-center),
        // full logo badge (top-left) - order below reads right-to-left
        // under the app's RTL Directionality.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: Icons.menu_rounded,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  _ConnectionCapsule(
                    isOnline: isOnline,
                    isToggling: captainSession.isTogglingOnline,
                    onTap: () async {
                      try {
                        await captainSession.toggleOnline();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_describeOnlineError(e))),
                          );
                        }
                      }
                    },
                  ),
                  const _LogoBadge(),
                ],
              ),
            ),
          ),
        ),

        // Offline guidance card - only shown while offline, so the online
        // state stays as clean as possible (the map is the focus).
        if (!isOnline)
          Positioned(
            top: 78,
            left: 20,
            right: 20,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'قم بتفعيل زر الاتصال بالأعلى لبدء استقبال المشاوير.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawer(AppStateProvider provider) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            currentAccountPicture: CircleAvatar(
              backgroundImage: NetworkImage(DummyData.dummyCaptain.user.avatar),
              backgroundColor: Colors.white,
            ),
            accountName: Text(
              provider.captainName,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            accountEmail: Text(
              provider.captainPhone,
              style: const TextStyle(fontSize: 13),
            ),
            otherAccountsPictures: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/al-houdhoud-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),

          ListTile(
            leading: const Icon(
              Icons.dashboard_rounded,
              color: AppColors.primary,
            ),
            title: const Text(
              'لوحة التحكم',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 0;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.wallet_rounded, color: AppColors.primary),
            title: const Text(
              'الأرباح والمحفظة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 2; // Wallet tab
              });
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
            ),
            title: const Text(
              'سجل رحلات كابتن',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 1; // Trips tab
              });
            },
          ),
          if (DemoModeConfig.isEnabled) ...[
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.science_rounded,
                color: AppColors.accent,
              ),
              title: const Text(
                'توليد مشوار تجريبي (للمطور)',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showDemoTripMenu();
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.error),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              // Stop any active alert and take the captain offline
              // server-side before signing out (spec section 8/24).
              await RideAlertService.instance.stop();
              await context.read<CaptainSession>().clear();
              provider.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const CaptainLoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  static const List<_NavItemData> _navItems = [
    _NavItemData(Icons.dashboard_rounded, 'الرئيسية'),
    _NavItemData(Icons.history_rounded, 'الرحلات'),
    _NavItemData(Icons.wallet_rounded, 'المحفظة'),
    _NavItemData(Icons.person_rounded, 'الحساب'),
  ];

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
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

/// White circular icon button (menu trigger, top-right under RTL).
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.darkText, size: 22),
        ),
      ),
    );
  }
}

/// Full Al Hodhod logo badge (top-left under RTL). Deliberately no
/// ClipOval/cover - the badge only pads the full, uncropped image
/// (BoxFit.contain) small enough that its square bounds sit inside the
/// visual circle on their own, so nothing needs clipping.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(9),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Image.asset(
        'assets/images/al-houdhoud-logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Top-center connection-status capsule: red + X while offline, green +
/// check while online, with a spinner replacing the icon (and taps
/// ignored) while the toggle request is in flight.
class _ConnectionCapsule extends StatelessWidget {
  final bool isOnline;
  final bool isToggling;
  final Future<void> Function() onTap;

  const _ConnectionCapsule({
    required this.isOnline,
    required this.isToggling,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.primary : AppColors.error;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(30),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: isToggling ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isToggling)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                Icon(
                  isOnline ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'متصل' : 'غير متصل',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
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

  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.secondaryText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: color, size: 24),
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
