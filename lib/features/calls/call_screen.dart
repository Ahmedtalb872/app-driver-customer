import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
    required this.peerRole,
    this.peerAvatarUrl,
    this.incomingOfferSdp,
  });

  final CallSignalingService signaling;
  final String peerName;

  /// 'customer' or 'captain' - the *other* party.
  final String peerRole;

  final String? peerAvatarUrl;
  final String? incomingOfferSdp;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallService _call;
  late _CallPhase _phase;
  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speakerOn = false;

  final _ringPlayer = AudioPlayer();

  StreamSubscription<CallConnectionStatus>? _statusSub;
  StreamSubscription<void>? _remoteHangupSub;

  @override
  void initState() {
    super.initState();
    _call = CallService(widget.signaling);
    final isOutgoing = widget.incomingOfferSdp == null;
    _phase = isOutgoing ? _CallPhase.ringingOutgoing : _CallPhase.ringingIncoming;
    _subscribeCall();

    if (isOutgoing) {
      _startOutgoingCall();
      _ringTimeoutTimer = Timer(_ringTimeout, _onRingTimeout);
    } else {
      _playRingtone();
    }
  }

  void _subscribeCall() {
    _statusSub = _call.onStatusChange.listen(_onStatusChange);
    _remoteHangupSub = _call.onRemoteHangup.listen((_) => _endCall(notifyPeer: false));
  }

  /// Loops the same "new request" sound already bundled for the captain
  /// app (assets/audio/hudhud_ride_request.wav) while this screen is
  /// ringing for the person being called - a silent full-screen UI is easy
  /// to miss entirely if the phone/tab isn't being looked at right now.
  /// Browsers can block audio that doesn't follow a user gesture (Flutter
  /// Web's autoplay policy), so this is best-effort - a blocked ring is
  /// just silent, not a crash.
  Future<void> _playRingtone() async {
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('audio/hudhud_ride_request.wav'));
    } catch (_) {
      // Best effort - see doc comment above.
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {
      // Best effort.
    }
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
    unawaited(_stopRingtone());
    setState(() => _phase = _CallPhase.connecting);
    // The caller's own CallScreen gives up and tears down its CallService
    // after _ringTimeout too - if we answer any later than that (a slow
    // network, a backgrounded app) our answer reaches no one and the
    // connection can never complete. Without this timer nothing ever moved
    // this screen out of "connecting" in that case - see _onRingTimeout,
    // which already handles both directions.
    _ringTimeoutTimer = Timer(_ringTimeout, _onRingTimeout);
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

  /// Covers two different timeouts that share one phase/UI: the other side
  /// never answered our outgoing call within [_ringTimeout] ("missed"), or
  /// we accepted an incoming one but it never actually connected within
  /// that same window ("failed" - the caller almost certainly already gave
  /// up and tore down their own end). Unlike every other way a call ends,
  /// this deliberately does NOT auto-pop: see [_buildControls]'s
  /// `noAnswer` branch.
  void _onRingTimeout() {
    if (_phase != _CallPhase.ringingOutgoing && _phase != _CallPhase.connecting) return;
    _call.hangUp();
    setState(() => _phase = _CallPhase.noAnswer);
  }

  /// Re-dials from the "لم يتم الرد" screen - a fresh [CallService] (the
  /// previous one already tore down its peer connection), otherwise
  /// identical to the first attempt.
  Future<void> _retryCall() async {
    await _statusSub?.cancel();
    await _remoteHangupSub?.cancel();
    await _call.dispose();
    _call = CallService(widget.signaling);
    _subscribeCall();

    setState(() {
      _phase = _CallPhase.ringingOutgoing;
      _elapsed = Duration.zero;
    });
    _startOutgoingCall();
    _ringTimeoutTimer = Timer(_ringTimeout, _onRingTimeout);
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
    unawaited(_stopRingtone());
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
    unawaited(_ringPlayer.dispose());
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
        return widget.incomingOfferSdp != null ? 'تعذر إكمال الاتصال' : 'لم يتم الرد';
      case _CallPhase.ended:
        return 'انتهت المكالمة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Invisible on purpose - this call is audio-only and nothing
            // here should ever look like a video call. It still has to be
            // an actually-built (if 1x1) RTCVideoView, not left out
            // entirely: that's what makes the browser create the
            // underlying media element the remote party's voice is
            // actually audible through on Flutter Web - see
            // CallService.remoteRenderer's doc comment.
            SizedBox(
              width: 1,
              height: 1,
              child: RTCVideoView(_call.remoteRenderer),
            ),
            const SizedBox(height: 56),
            _buildAvatar(),
            const SizedBox(height: 20),
            Text(
              widget.peerName,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            const Spacer(),
            _buildControls(),
            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.peerAvatarUrl;
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
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

    if (_phase == _CallPhase.noAnswer) {
      // _retryCall only ever re-dials as the outgoing caller (startAsCaller)
      // - meaningless for a call we were accepting, where "retry" would
      // have to mean calling the customer back, which nothing here is set
      // up to do. Only the outgoing side gets that button; the accepting
      // side just closes.
      final isAccepting = widget.incomingOfferSdp != null;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'إنهاء',
            color: isAccepting ? AppColors.error : Colors.white.withOpacity(0.2),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (!isAccepting)
            _CallButton(
              icon: Icons.refresh_rounded,
              label: 'إعادة الاتصال',
              color: AppColors.success,
              onPressed: _retryCall,
            ),
        ],
      );
    }

    if (_phase == _CallPhase.ended) {
      return _CallButton(
        icon: Icons.call_end_rounded,
        label: 'إنهاء',
        color: AppColors.error,
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    // Outgoing/connecting/in-call: mute + speaker are available from the
    // moment the call starts dialing (not only once it connects), matching
    // a normal phone dialer - lets someone mute or switch to speaker while
    // still waiting for the other side to answer.
    return Column(
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
        const SizedBox(height: 32),
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
