import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/call_service.dart';
import '../../core/services/call_signaling_service.dart';

enum _CallPhase { ringingOutgoing, ringingIncoming, connecting, inCall, ended }

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

class _CallScreenState extends State<CallScreen> {
  late final CallService _call;
  late _CallPhase _phase;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speakerOn = false;

  StreamSubscription<CallConnectionStatus>? _statusSub;
  StreamSubscription<void>? _remoteHangupSub;

  @override
  void initState() {
    super.initState();
    _call = CallService(widget.signaling);
    _phase = widget.incomingOfferSdp != null
        ? _CallPhase.ringingIncoming
        : _CallPhase.ringingOutgoing;
    _statusSub = _call.onStatusChange.listen(_onStatusChange);
    _remoteHangupSub = _call.onRemoteHangup.listen((_) => _endCall(notifyPeer: false));

    if (widget.incomingOfferSdp == null) {
      _startOutgoingCall();
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
        setState(() => _phase = _CallPhase.inCall);
        _startTimer();
      case CallConnectionStatus.failed:
      case CallConnectionStatus.ended:
        _endCall(notifyPeer: false);
      case CallConnectionStatus.connecting:
        break;
    }
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
    if (_phase == _CallPhase.ended) return;
    _durationTimer?.cancel();
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
    _statusSub?.cancel();
    _remoteHangupSub?.cancel();
    if (_phase != _CallPhase.ended) {
      _call.dispose();
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
      case _CallPhase.ended:
        return 'انتهت المكالمة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithPop: (didPop, result) {
        if (didPop) return;
        _endCall(notifyPeer: true);
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
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
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.peerAvatarUrl;
    return Container(
      width: 100,
      height: 100,
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
                  fontSize: 34,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  Widget _buildControls() {
    if (_phase == _CallPhase.ringingIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            color: AppColors.error,
            onPressed: _declineIncomingCall,
          ),
          const SizedBox(width: 40),
          _CallButton(
            icon: Icons.call_rounded,
            color: AppColors.success,
            onPressed: _acceptIncomingCall,
          ),
        ],
      );
    }

    if (_phase == _CallPhase.inCall) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CallButton(
                icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 56,
                iconSize: 24,
                onPressed: () {
                  _call.toggleMute();
                  setState(() => _muted = _call.isMuted);
                },
              ),
              const SizedBox(width: 24),
              _CallButton(
                icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 56,
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
            color: AppColors.error,
            onPressed: () => _endCall(notifyPeer: true),
          ),
        ],
      );
    }

    // Outgoing/connecting/ended: a single hang-up button.
    return _CallButton(
      icon: Icons.call_end_rounded,
      color: AppColors.error,
      onPressed: () => _endCall(notifyPeer: true),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 64,
    this.iconSize = 28,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}
