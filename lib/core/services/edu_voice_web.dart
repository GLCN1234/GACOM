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
        final c = event.candidate;
        if (c != null) {
          _channel?.sendBroadcastMessage(event: 'ice', payload: {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          });
        }
      }.toJS;

      _channel!
        .onBroadcast(event: 'offer', callback: (payload) async {
          if (isInitiator) return;
          final remoteDesc = web.RTCSessionDescriptionInit(type: 'offer', sdp: payload['sdp'] as String);
          await _pc!.setRemoteDescription(remoteDesc).toDart;

          final answer = await _pc!.createAnswer().toDart;
          if (answer == null) return;
          final localDesc = web.RTCLocalSessionDescriptionInit(type: answer.type, sdp: answer.sdp ?? '');
          await _pc!.setLocalDescription(localDesc).toDart;
          _channel!.sendBroadcastMessage(event: 'answer', payload: {'sdp': answer.sdp ?? ''});
        })
        .onBroadcast(event: 'answer', callback: (payload) async {
          if (!isInitiator) return;
          final remoteDesc = web.RTCSessionDescriptionInit(type: 'answer', sdp: payload['sdp'] as String);
          await _pc!.setRemoteDescription(remoteDesc).toDart;
        })
        .onBroadcast(event: 'ice', callback: (payload) async {
          final candidateInit = web.RTCIceCandidateInit(
            candidate: payload['candidate'] as String,
            sdpMid: payload['sdpMid'] as String?,
            sdpMLineIndex: (payload['sdpMLineIndex'] as num?)?.toInt(),
          );
          await _pc!.addIceCandidate(candidateInit).toDart;
        })
        .subscribe();

      if (isInitiator) {
        final offer = await _pc!.createOffer().toDart;
        if (offer == null) return;
        final localDesc = web.RTCLocalSessionDescriptionInit(type: offer.type, sdp: offer.sdp ?? '');
        await _pc!.setLocalDescription(localDesc).toDart;
        _channel!.sendBroadcastMessage(event: 'offer', payload: {'sdp': offer.sdp ?? ''});
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
