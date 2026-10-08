import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/call_signaling_service.dart';
import '../../features/calls/call_screen.dart';
import '../core/admin_colors.dart';
import '../repositories/admin_trips_repository.dart';
import '../services/admin_incoming_call_listener.dart';
import '../services/admin_session.dart';
import '../utils/tab_title_alert.dart';
import 'admin_sidebar.dart';
import 'admin_topbar.dart';

/// Responsive dashboard shell (section 3 / 21 of the spec):
/// - >= 1100px: fixed/collapsible sidebar always visible.
/// - 700-1100px: collapsible (icon-only) sidebar.
/// - < 700px: sidebar becomes a Drawer, opened via the topbar's menu button.
class AdminShell extends StatefulWidget {
  final String currentRoute;
  final String title;
  final Widget child;

  const AdminShell({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.child,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _collapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _tripsRepository = AdminTripsRepository();
  late final AdminIncomingCallListener _incomingCalls;
  StreamSubscription<AdminIncomingOffer>? _incomingCallSub;
  bool _callScreenOpen = false;

  @override
  void initState() {
    super.initState();
    // Lives for as long as the admin dashboard itself (this shell wraps
    // every route and isn't rebuilt by navigating between them) rather than
    // being tied to any one screen - a customer's support call should ring
    // no matter which admin page happens to be open at the time.
    _incomingCalls = AdminIncomingCallListener()..start();
    _incomingCallSub = _incomingCalls.onOffer.listen(_onIncomingOffer);
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _incomingCalls.dispose();
    super.dispose();
  }

  /// Mirrors `TripTrackingScreen._onIncomingCallOffer` - pushes the same
  /// [CallScreen] used everywhere else in the app, so accept/decline, mute,
  /// speaker and the ring timeout all behave identically regardless of
  /// which side of a call the admin is on. [_callScreenOpen] guards against
  /// a second offer (a stray retransmit, or a different customer calling in
  /// at the same moment) popping a second call screen on top of one already
  /// being handled.
  Future<void> _onIncomingOffer(AdminIncomingOffer offer) async {
    if (!mounted || _callScreenOpen) return;
    _callScreenOpen = true;
    // Noticeable even if the admin is looking at a different browser tab -
    // the call screen's own ringtone only helps if this tab is the focused
    // one. Stopped in the `finally` below regardless of how the call ends.
    startTabTitleAlert('📞 مكالمة واردة...');
    final label = await _tripsRepository.loadCallerLabel(offer.tripId);
    if (!mounted) {
      _callScreenOpen = false;
      stopTabTitleAlert();
      return;
    }
    // Backdated just before the offer's own timestamp: the caller may
    // already have sent a few ICE candidates in the time it took this
    // listener's poll to notice the offer and fetch the caller's label -
    // without this they'd be dropped as "stale" the moment this
    // signaling service actually starts. See CallSignalingService's own
    // sinceOverride doc for the full reasoning.
    final signaling = CallSignalingService(
      tripId: offer.tripId,
      selfRole: 'admin',
      sinceOverride: offer.createdAt.subtract(const Duration(seconds: 2)),
    )..start();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            signaling: signaling,
            peerName: label,
            peerRole: 'customer',
            incomingOfferSdp: offer.offerSdp,
          ),
        ),
      );
    } finally {
      stopTabTitleAlert();
      signaling.dispose();
      _callScreenOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final isTablet = width >= 700 && width < 1100;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: AdminColors.sidebarBackground,
          child: SafeArea(
            child: AdminSidebar(
              currentRoute: widget.currentRoute,
              onNavigate: (route) {
                Navigator.of(context).pop();
                _goTo(context, route);
              },
            ),
          ),
        ),
        appBar: AdminTopBar(
          title: widget.title,
          profile: session.profile,
          onToggleSidebar: () => _scaffoldKey.currentState?.openDrawer(),
          onLogout: () => _logout(context),
        ),
        body: widget.child,
      );
    }

    final collapsed = _collapsed || isTablet;

    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(currentRoute: widget.currentRoute, collapsed: collapsed),
          Expanded(
            child: Column(
              children: [
                AdminTopBar(
                  title: widget.title,
                  profile: session.profile,
                  onToggleSidebar: () =>
                      setState(() => _collapsed = !_collapsed),
                  onLogout: () => _logout(context),
                ),
                Expanded(
                  child: Container(
                    color: AdminColors.background,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(BuildContext context, String route) {
    context.go(route);
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AdminSession>().signOut();
    if (context.mounted) {
      context.go('/admin/login');
    }
  }
}
