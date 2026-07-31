import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real peer-to-peer voice chat for Edu Compete matches.
/// Signaling (offer/answer/ICE candidates) goes through a Supabase
/// Realtime broadcast channel scoped to the match room — no separate
/// signaling server needed. Uses public Google STUN servers for NAT
/// traversal, which works for the large majority of home/mobile networks
/// but can fail behind restrictive corporate/school firewalls — in that
/// case voice simply won't connect and the game still works via text.
class EduWebRTCService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RealtimeChannel? _channel;
  bool _muted = false;
  Function(bool connected)? onConnectionChange;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> start({
    required String roomId,
    required bool isInitiator,
  }) async {
    _pc = await createPeerConnection(_iceServers);

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    for (final track in _localStream!.getTracks()) {
      _pc!.addTrack(track, _localStream!);
    }

    _pc!.onConnectionState = (state) {
      final connected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      onConnectionChange?.call(connected);
    };

    _channel = Supabase.instance.client.channel('edu_voice_$roomId');

    _pc!.onIceCandidate = (candidate) {
      _channel?.sendBroadcastMessage(event: 'ice', payload: {
        'candidate': candidate.toMap(),
      });
    };

    _channel!
      .onBroadcast(event: 'offer', callback: (payload) async {
        if (isInitiator) return;
        final offer = RTCSessionDescription(payload['sdp'], payload['type']);
        await _pc!.setRemoteDescription(offer);
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _channel!.sendBroadcastMessage(event: 'answer', payload: {
          'sdp': answer.sdp, 'type': answer.type,
        });
      })
      .onBroadcast(event: 'answer', callback: (payload) async {
        if (!isInitiator) return;
        final answer = RTCSessionDescription(payload['sdp'], payload['type']);
        await _pc!.setRemoteDescription(answer);
      })
      .onBroadcast(event: 'ice', callback: (payload) async {
        final c = payload['candidate'];
        await _pc!.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      })
      .subscribe();

    if (isInitiator) {
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _channel!.sendBroadcastMessage(event: 'offer', payload: {
        'sdp': offer.sdp, 'type': offer.type,
      });
    }
  }

  void toggleMute() {
    _muted = !_muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_muted);
  }

  bool get isMuted => _muted;

  Future<void> stop() async {
    await _channel?.unsubscribe();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _pc?.close();
    _pc = null;
    _localStream = null;
  }
}
