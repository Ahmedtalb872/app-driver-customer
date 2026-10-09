import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/call_log_service.dart';
import '../../core/services/call_signaling_service.dart';
import '../../features/calls/call_screen.dart';
import '../core/admin_colors.dart';
import '../repositories/admin_trips_repository.dart';
import '../screens/trips/trip_detail_panel.dart';
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

  // Incoming-call banner state. A new offer shows as a slim bar at the top
  // of whichever admin page is open - not a full-screen CallScreen - so
  // answering a support call doesn't interrupt dispatch, live ops, or
  // whatever else the admin is doing. Navigator.push only happens once the
  // admin actually taps "رد" on the bar.
  AdminIncomingOffer? _pendingOffer;
  CallSignalingService? _pendingSignaling;
  StreamSubscription<CallSignal>? _pendingHangupSub;
  Future<List<Object?>>? _pendingDetailsFuture;
  String _pendingLabel = 'زبون';
  Map<String, dynamic>? _pendingTrip;
  int? _pendingLogId;
  final _logService = CallLogService();
  final _ringPlayer = AudioPlayer();

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
    _pendingHangupSub?.cancel();
    _pendingSignaling?.dispose();
    unawaited(_ringPlayer.dispose());
    super.dispose();
  }

  /// Same ringtone asset [CallScreen] itself uses while ringing - needed
  /// here too since the banner, not the call screen, is now what's on
  /// screen for as long as the admin hasn't answered yet.
  Future<void> _playRingtone() async {
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('audio/hudhud_ride_request.wav'));
    } catch (_) {
      // Best effort - see CallScreen._playRingtone's own doc.
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {
      // Best effort.
    }
  }

  /// Shows the incoming-call banner and starts logging/signaling for it -
  /// [_callScreenOpen]/[_pendingOffer] guard against a second offer (a
  /// stray retransmit, or a different customer calling in at the same
  /// moment) replacing one already being shown or handled.
  Future<void> _onIncomingOffer(AdminIncomingOffer offer) async {
    if (!mounted || _pendingOffer != null || _callScreenOpen) return;
    setState(() {
      _pendingOffer = offer;
      _pendingLabel = 'زبون';
      _pendingTrip = null;
    });
    // Noticeable even if the admin is looking at a different browser tab -
    // stopped the moment the admin acts on the banner (answers or
    // declines), not only once the call itself ends.
    startTabTitleAlert('📞 مكالمة واردة...');
    unawaited(_playRingtone());

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
    _pendingSignaling = signaling;
    _pendingHangupSub = signaling.onHangup.listen((_) => _onPendingOfferHangup(offer));

    unawaited(
      _logService
          .logStarted(tripId: offer.tripId, callerRole: 'customer', calleeRole: 'admin')
          .then((id) => _pendingLogId = id),
    );

    _pendingDetailsFuture = Future.wait([
      _tripsRepository.loadCallerLabel(offer.tripId),
      _tripsRepository.loadTripById(offer.tripId),
    ]);
    final results = await _pendingDetailsFuture!;
    if (!mounted || _pendingOffer != offer) return;
    setState(() {
      _pendingLabel = results[0] as String;
      _pendingTrip = results[1] as Map<String, dynamic>?;
    });
  }

  /// The customer hung up (or gave up) before the admin acted on the
  /// banner at all - the same "missed" outcome a ring-timeout logs on
  /// [CallScreen], just from the other side.
  void _onPendingOfferHangup(AdminIncomingOffer offer) {
    if (_pendingOffer != offer) return;
    unawaited(_logService.logEnded(_pendingLogId, outcome: 'missed'));
    _clearPendingOffer();
  }

  Future<void> _declinePendingOffer() async {
    if (_pendingOffer == null) return;
    unawaited(_pendingSignaling?.sendHangup());
    unawaited(_logService.logEnded(_pendingLogId, outcome: 'declined'));
    _clearPendingOffer();
  }

  void _clearPendingOffer() {
    unawaited(_stopRingtone());
    stopTabTitleAlert();
    _pendingHangupSub?.cancel();
    _pendingSignaling?.dispose();
    if (!mounted) return;
    setState(() {
      _pendingOffer = null;
      _pendingSignaling = null;
      _pendingTrip = null;
      _pendingLogId = null;
    });
  }

  /// Hands the already-ringing call off to the full [CallScreen] - answered
  /// immediately ([CallScreen.autoAccept]) rather than asking again, since
  /// tapping "رد" on the banner already was that decision. Mirrors the
  /// previous direct-push behavior otherwise: the trip's details panel
  /// still appears stacked on top of the call screen itself.
  Future<void> _openPendingOffer() async {
    final offer = _pendingOffer;
    final signaling = _pendingSignaling;
    if (offer == null || signaling == null) return;
    unawaited(_stopRingtone());
    stopTabTitleAlert();
    await _pendingHangupSub?.cancel();

    final label = _pendingLabel;
    var trip = _pendingTrip;
    if (trip == null && _pendingDetailsFuture != null) {
      final results = await _pendingDetailsFuture!;
      trip = results[1] as Map<String, dynamic>?;
    }
    final logId = _pendingLogId;

    if (!mounted) return;
    setState(() {
      _pendingOffer = null;
      _pendingSignaling = null;
      _pendingTrip = null;
      _pendingLogId = null;
    });

    _callScreenOpen = true;
    try {
      // Pushed without awaiting it yet - requested explicitly: the trip's
      // own details (pickup/destination editor, same tools a phone-in
      // dispatch already uses) should appear right over the call itself,
      // not after hanging up, since that's exactly when the admin is
      // hearing the destination from the customer and needs somewhere to
      // put it. Both routes stack on the same Navigator: the call screen
      // underneath, this sheet on top of it, draggable out of the way
      // without ending the call.
      final callScreenFuture = Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            signaling: signaling,
            peerName: label,
            peerRole: 'customer',
            incomingOfferSdp: offer.offerSdp,
            autoAccept: true,
            initialLogId: logId,
          ),
        ),
      );
      if (trip != null && mounted) {
        unawaited(
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => TripDetailPanel(trip: trip!, onChanged: () {}),
          ),
        );
      }
      await callScreenFuture;
    } finally {
      signaling.dispose();
      _callScreenOpen = false;
    }
  }

  Widget _buildIncomingCallBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 6,
        color: AdminColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'مكالمة واردة من $_pendingLabel',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _declinePendingOffer,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('رفض', style: TextStyle(fontFamily: 'Cairo')),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _openPendingOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.success,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('رد', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        body: Stack(
          children: [
            // Positioned.fill, not a bare child - Stack gives non-positioned
            // children loose constraints, and this page was always built
            // assuming it fills the body exactly like it did before this
            // banner overlay existed.
            Positioned.fill(child: widget.child),
            if (_pendingOffer != null) _buildIncomingCallBanner(),
          ],
        ),
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: AdminColors.background,
                          child: widget.child,
                        ),
                      ),
                      if (_pendingOffer != null) _buildIncomingCallBanner(),
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
