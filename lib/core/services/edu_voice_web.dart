// Real WebRTC voice chat using the browser's native APIs directly via
// package:web — Flutter's officially supported JS interop layer.
// This deliberately avoids flutter_webrtc/dart_webrtc, which has an
// unresolved compatibility bug with the current Dart web compiler.
//
// Web-only file — loaded via conditional import, so it never gets
// compiled into mobile/desktop builds.

import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:supabase_flutter/supabase_flutter.dart';

class EduVoiceService {
  web.RTCPeerConnection? _pc;
  web.MediaStream? _localStream;
  RealtimeChannel? _channel;
  bool _muted = false;
  void Function(bool connected)? onConnectionChange;
  void Function(String error)? onError;

  static final _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  }.jsify() as web.RTCConfiguration;

  Future<void> start({required String roomId, required bool isInitiator}) async {
    try {
      _pc = web.RTCPeerConnection(_iceServers);

      final constraints = {'audio': true, 'video': false}.jsify() as web.MediaStreamConstraints;
      _localStream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;

      for (final track in _localStream!.getTracks().toDart) {
        _pc!.addTrack(track, _localStream!);
      }

      _pc!.onconnectionstatechange = (JSAny _) {
        final connected = _pc!.connectionState == 'connected';
        onConnectionChange?.call(connected);
      }.toJS;

      _channel = Supabase.instance.client.channel('edu_voice_$roomId');

      _pc!.onicecandidate = (web.RTCPeerConnectionIceEvent event) {
        if (event.candidate != null) {
          _channel?.sendBroadcastMessage(event: 'ice', payload: {
            'candidate': event.candidate!.candidate,
            'sdpMid': event.candidate!.sdpMid,
            'sdpMLineIndex': event.candidate!.sdpMLineIndex,
          });
        }
      }.toJS;

      _channel!
        .onBroadcast(event: 'offer', callback: (payload) async {
          if (isInitiator) return;
          final desc = web.RTCSessionDescriptionInit(type: 'offer', sdp: payload['sdp'] as String);
          await _pc!.setRemoteDescription(desc).toDart;
          final answer = await _pc!.createAnswer().toDart;
          await _pc!.setLocalDescription(answer).toDart;
          _channel!.sendBroadcastMessage(event: 'answer', payload: {'sdp': answer.sdp});
        })
        .onBroadcast(event: 'answer', callback: (payload) async {
          if (!isInitiator) return;
          final desc = web.RTCSessionDescriptionInit(type: 'answer', sdp: payload['sdp'] as String);
          await _pc!.setRemoteDescription(desc).toDart;
        })
        .onBroadcast(event: 'ice', callback: (payload) async {
          final candidate = web.RTCIceCandidateInit(
            candidate: payload['candidate'] as String,
            sdpMid: payload['sdpMid'] as String?,
            sdpMLineIndex: (payload['sdpMLineIndex'] as num?)?.toInt(),
          );
          await _pc!.addIceCandidate(web.RTCIceCandidate(candidate)).toDart;
        })
        .subscribe();

      if (isInitiator) {
        final offer = await _pc!.createOffer().toDart;
        await _pc!.setLocalDescription(offer).toDart;
        _channel!.sendBroadcastMessage(event: 'offer', payload: {'sdp': offer.sdp});
      }
    } catch (e) {
      onError?.call(e.toString());
      rethrow;
    }
  }

  void toggleMute() {
    _muted = !_muted;
    _localStream?.getAudioTracks().toDart.forEach((t) => t.enabled = !_muted);
  }

  bool get isMuted => _muted;

  Future<void> stop() async {
    await _channel?.unsubscribe();
    _localStream?.getTracks().toDart.forEach((t) => t.stop());
    _pc?.close();
    _pc = null;
    _localStream = null;
  }
}
