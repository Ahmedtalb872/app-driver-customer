import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_signaling_service.dart';

enum CallConnectionStatus { connecting, connected, failed, ended }

/// Wraps a single audio-only [RTCPeerConnection] for one call and drives it
/// from a [CallSignalingService]'s offer/answer/ICE messages. STUN-only
/// (Google's public servers) - no TURN relay, so a call between two
/// networks that both do strict/symmetric NAT (some corporate or carrier
/// networks) may fail to connect; there's no free, reliable TURN option to
/// fall back to. Good enough for the common case of two phones on normal
/// mobile data or home/office wifi.
class CallService {
  CallService(this._signaling);

  final CallSignalingService _signaling;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _pendingRemoteCandidates = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;

  StreamSubscription<CallSignal>? _answerSub;
  StreamSubscription<CallSignal>? _iceSub;
  StreamSubscription<CallSignal>? _hangupSub;

  final _statusController = StreamController<CallConnectionStatus>.broadcast();
  Stream<CallConnectionStatus> get onStatusChange => _statusController.stream;

  final _hangupController = StreamController<void>.broadcast();
  Stream<void> get onRemoteHangup => _hangupController.stream;

  static const _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> _setUp() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    // Applies a mute toggled while the call was still connecting (before
    // this stream existed) - toggleMute() below only flips tracks that
    // already exist, so a mute tapped early would otherwise be silently
    // lost the moment the real mic stream comes up.
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_muted;
    }

    final pc = await createPeerConnection(_config);
    _pc = pc;

    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _signaling.sendIceCandidate(
        candidate: candidate.candidate!,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      );
    };

    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _statusController.add(CallConnectionStatus.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _statusController.add(CallConnectionStatus.failed);
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _statusController.add(CallConnectionStatus.ended);
        default:
          break;
      }
    };

    _iceSub = _signaling.onIceCandidate.listen((signal) {
      if (signal.candidate == null) return;
      final candidate = RTCIceCandidate(
        signal.candidate,
        signal.sdpMid,
        signal.sdpMLineIndex,
      );
      if (_remoteDescriptionSet) {
        pc.addCandidate(candidate);
      } else {
        _pendingRemoteCandidates.add(candidate);
      }
    });

    _hangupSub = _signaling.onHangup.listen((_) => _hangupController.add(null));
  }

  /// Creates the offer as the calling party and sends it over [_signaling].
  Future<void> startAsCaller() async {
    await _setUp();
    final pc = _pc!;

    _answerSub = _signaling.onAnswer.listen((signal) async {
      if (signal.sdp == null || _remoteDescriptionSet) return;
      await pc.setRemoteDescription(RTCSessionDescription(signal.sdp, 'answer'));
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();
    });

    // No offerToReceiveAudio constraint needed - the audio track already
    // added via addTrack above is enough to get an audio m-line under
    // Unified Plan (this and every other current WebRTC stack's default).
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signaling.sendOffer(offer.sdp ?? '');
  }

  /// Accepts an already-received [offerSdp] as the called party and sends
  /// the answer over [_signaling].
  Future<void> startAsCallee(String offerSdp) async {
    await _setUp();
    final pc = _pc!;

    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _signaling.sendAnswer(answer.sdp ?? '');
  }

  Future<void> _flushPendingCandidates() async {
    final pc = _pc;
    if (pc == null) return;
    for (final candidate in _pendingRemoteCandidates) {
      await pc.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  bool _muted = false;
  bool get isMuted => _muted;

  void toggleMute() {
    _muted = !_muted;
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = !_muted;
    }
  }

  bool _speakerOn = false;
  bool get isSpeakerOn => _speakerOn;

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await Helper.setSpeakerphoneOn(_speakerOn);
  }

  /// Tears down the local peer connection/stream without notifying the
  /// other side - use [hangUp] for a user-initiated end so the other party
  /// finds out immediately instead of just seeing the connection drop.
  Future<void> dispose() async {
    await _answerSub?.cancel();
    await _iceSub?.cancel();
    await _hangupSub?.cancel();
    for (final track in _localStream?.getTracks() ?? const []) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    await _statusController.close();
    await _hangupController.close();
  }

  Future<void> hangUp() async {
    await _signaling.sendHangup();
    await dispose();
  }
}
