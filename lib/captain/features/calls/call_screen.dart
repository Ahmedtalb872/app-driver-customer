import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../../core/constants/colors.dart';
import '../../core/services/call_service.dart';
import '../../core/services/call_signaling_service.dart';

enum _CallPhase { ringingOutgoing, ringingIncoming, connecting, inCall, noAnswer, ended }

/// How long an outgoing call rings before giving up - matches a normal
/// phone call's rough patience window rather than ringing forever if the
/// other party never opens their call screen.
const _ringTimeout = Duration(seconds: 30);

/// Full-screen in-app call UI, audio-only. Two ways in:
/// - Outgoing: [incomingOfferSdp] is null - creates and sends the WebRTC
///   offer as soon as this screen mounts.
/// - Incoming: [incomingOfferSdp] is the offer already received by the
///   caller (see `TripTrackingScreen`'s `_callSignaling.onOffer` listener,
///   which pushes this screen instead of creating one) - shows an
///   accept/decline prompt instead of dialing immediately.
///
/// Owns a [CallService] for the call's duration, but not the
/// [CallSignalingService] itself - that's owned by the trip-tracking screen
/// so it keeps listening for the *next* incoming call after this one ends.
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.signaling,
    required this.peerName,
    this.peerAvatarUrl,
    this.incomingOfferSdp,
  });

  final CallSignalingService signaling;
  final String peerName;
  final String? peerAvatarUrl;
  final String? incomingOfferSdp;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late final CallService _call;
  late _CallPhase _phase;
  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speakerOn = false;

  // Local ringtone for an *incoming* call on this device - the signaling
  // channel only carries WebRTC offer/answer/ICE, it never made a sound on
  // its own, so an incoming call used to sit there completely silent with
  // only the on-screen text giving it away.
  final AudioPlayer _ringPlayer = AudioPlayer();
  late final AnimationController _pulseController;

  StreamSubscription<CallConnectionStatus>? _statusSub;
  StreamSubscription<void>? _remoteHangupSub;

  @override
  void initState() {
    super.initState();
    _call = CallService(widget.signaling);
    _phase = widget.incomingOfferSdp != null
        ? _CallPhase.ringingIncoming
        : _CallPhase.ringingOutgoing;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _statusSub = _call.onStatusChange.listen(_onStatusChange);
    _remoteHangupSub = _call.onRemoteHangup.listen((_) => _endCall(notifyPeer: false));

    if (widget.incomingOfferSdp == null) {
      _startOutgoingCall();
      _ringTimeoutTimer = Timer(_ringTimeout, _onRingTimeout);
    } else {
      _startRinging();
    }
  }

  Future<void> _startRinging() async {
    unawaited(_vibrateRingLoop());
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('sounds/new_trip_chime.wav'));
    } catch (_) {
      // No audio output available in this environment; ignore.
    }
  }

  Future<void> _vibrateRingLoop() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 500, 300, 500, 300], repeat: 0);
      }
    } catch (_) {
      // No vibration hardware/permission on this platform; ignore.
    }
  }

  Future<void> _stopRinging() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _startOutgoingCall() async {
    setState(() => _phase = _CallPhase.connecting);
    try {
      await _call.startAsCaller();
    } catch (_) {
      if (mounted) _endCall(notifyPeer: true);
    }
  }

  Future<void> _acceptIncomingCall() async {
    _stopRinging();
    setState(() => _phase = _CallPhase.connecting);
    try {
      await _call.startAsCallee(widget.incomingOfferSdp!);
    } catch (_) {
      if (mounted) _endCall(notifyPeer: true);
    }
  }

  void _declineIncomingCall() => _endCall(notifyPeer: true);

  void _onStatusChange(CallConnectionStatus status) {
    if (!mounted) return;
    switch (status) {
      case CallConnectionStatus.connected:
        _stopRinging();
        _ringTimeoutTimer?.cancel();
        setState(() => _phase = _CallPhase.inCall);
        _startTimer();
      case CallConnectionStatus.failed:
      case CallConnectionStatus.ended:
        _endCall(notifyPeer: false);
      case CallConnectionStatus.connecting:
        break;
    }
  }

  /// The other side never answered within [_ringTimeout] - ends the call
  /// (still tells them, in case they open their call screen a moment
  /// later) and shows "لم يتم الرد" briefly instead of popping instantly,
  /// so the customer/captain actually sees why the call stopped.
  void _onRingTimeout() {
    if (_phase != _CallPhase.ringingOutgoing && _phase != _CallPhase.connecting) return;
    _call.hangUp();
    setState(() => _phase = _CallPhase.noAnswer);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  /// [notifyPeer] tells the other side over signaling before tearing down
  /// locally - true for every user-initiated end on this side (hang up,
  /// decline, back button, a failed dial); false when we're reacting to a
  /// message/status that already means the other side is gone.
  void _endCall({required bool notifyPeer}) {
    if (_phase == _CallPhase.ended || _phase == _CallPhase.noAnswer) return;
    _stopRinging();
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    if (notifyPeer) {
      _call.hangUp();
    } else {
      _call.dispose();
    }
    setState(() => _phase = _CallPhase.ended);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _statusSub?.cancel();
    _remoteHangupSub?.cancel();
    _pulseController.dispose();
    _ringPlayer.dispose();
    unawaited(Vibration.cancel());
    // Covers every way off this screen that isn't already-handled by
    // _endCall (back button, swipe-back, a parent navigator popping this
    // route) - hangUp (not just dispose) so the other party is told the
    // call ended instead of just seeing the connection silently drop.
    if (_phase != _CallPhase.ended && _phase != _CallPhase.noAnswer) {
      _call.hangUp();
    }
    super.dispose();
  }

  String _formatElapsed() {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _statusText {
    switch (_phase) {
      case _CallPhase.ringingOutgoing:
      case _CallPhase.connecting:
        return 'جارٍ الاتصال...';
      case _CallPhase.ringingIncoming:
        return 'مكالمة واردة';
      case _CallPhase.inCall:
        return _formatElapsed();
      case _CallPhase.noAnswer:
        return 'لم يتم الرد';
      case _CallPhase.ended:
        return 'انتهت المكالمة';
    }
  }

  bool get _isRinging =>
      _phase == _CallPhase.ringingIncoming || _phase == _CallPhase.ringingOutgoing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildTypeBadge(),
              const Spacer(flex: 3),
              _buildAvatar(),
              const SizedBox(height: 24),
              Text(
                widget.peerName,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _buildStatusPill(),
              const Spacer(flex: 4),
              _buildControlsPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_calling_3_rounded, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            'مكالمة داخل التطبيق',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    IconData icon;
    switch (_phase) {
      case _CallPhase.ringingOutgoing:
      case _CallPhase.connecting:
        icon = Icons.call_made_rounded;
      case _CallPhase.ringingIncoming:
        icon = Icons.call_received_rounded;
      case _CallPhase.inCall:
        icon = Icons.graphic_eq_rounded;
      case _CallPhase.noAnswer:
        icon = Icons.call_missed_rounded;
      case _CallPhase.ended:
        icon = Icons.call_end_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
          const SizedBox(width: 6),
          Text(
            _statusText,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.peerAvatarUrl;
    final core = Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: (url != null && url.isNotEmpty)
          ? ClipOval(child: Image.network(url, fit: BoxFit.cover))
          : Center(
              child: Text(
                widget.peerName.isNotEmpty ? widget.peerName.substring(0, 1) : '؟',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 38,
                  color: Colors.white,
                ),
              ),
            ),
    );

    if (!_isRinging) return core;

    // A soft breathing ring around the avatar while it's ringing (either
    // direction) - the only visual cue that used to exist was the static
    // status text, easy to miss at a glance.
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.16);
        final opacity = 0.35 * (1 - _pulseController.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(opacity),
                    width: 3,
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: core,
    );
  }

  /// Groups the call controls into a distinct rounded panel at the bottom
  /// instead of leaving them floating loosely on the gradient - the biggest
  /// contributor to the screen reading as unorganized.
  Widget _buildControlsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: _buildControls(),
    );
  }

  Widget _buildControls() {
    if (_phase == _CallPhase.ringingIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'رفض',
            color: AppColors.error,
            onPressed: _declineIncomingCall,
          ),
          _CallButton(
            icon: Icons.call_rounded,
            label: 'رد',
            color: AppColors.success,
            onPressed: _acceptIncomingCall,
          ),
        ],
      );
    }

    if (_phase == _CallPhase.noAnswer || _phase == _CallPhase.ended) {
      return Center(
        child: _CallButton(
          icon: Icons.call_end_rounded,
          label: 'إنهاء',
          color: AppColors.error,
          onPressed: () => _endCall(notifyPeer: true),
        ),
      );
    }

    // Outgoing/connecting/in-call: mute + speaker are available from the
    // moment the call starts dialing (not only once it connects), matching
    // a normal phone dialer - lets someone mute or switch to speaker while
    // still waiting for the other side to answer.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallButton(
              icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _muted ? 'إلغاء الكتم' : 'كتم الصوت',
              color: _muted ? AppColors.accent : Colors.white.withOpacity(0.2),
              size: 58,
              iconSize: 24,
              onPressed: () {
                _call.toggleMute();
                setState(() => _muted = _call.isMuted);
              },
            ),
            _CallButton(
              icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: 'مكبر الصوت',
              color: _speakerOn ? AppColors.accent : Colors.white.withOpacity(0.2),
              size: 58,
              iconSize: 24,
              onPressed: () async {
                await _call.toggleSpeaker();
                if (mounted) setState(() => _speakerOn = _call.isSpeakerOn);
              },
            ),
          ],
        ),
        const SizedBox(height: 28),
        _CallButton(
          icon: Icons.call_end_rounded,
          label: _phase == _CallPhase.inCall ? 'إنهاء المكالمة' : 'إنهاء',
          color: AppColors.error,
          onPressed: () => _endCall(notifyPeer: true),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.size = 64,
    this.iconSize = 28,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
