import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../core/services/supabase_service.dart';

/// Wraps a real LiveKit room connection for live 2-player voice during a
/// match — not a mock, this actually captures the mic and streams audio.
/// One instance per match; call connect() when voice is toggled on,
/// disconnect() when toggled off or the match screen closes.
class VoiceService {
  lk.Room? _room;
  bool _connected = false;
  bool get connected => _connected;

  /// Called whenever the set of currently-speaking remote participants
  /// changes — the match screen uses this to drive the "opponent
  /// speaking" indicator.
  void Function(bool opponentSpeaking)? onOpponentSpeakingChanged;

  Future<bool> connect(String roomName) async {
    if (_connected) return true;
    try {
      final authHeader = 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken ?? ''}';
      final result = await SupabaseService.client.functions.invoke(
        'livekit-token',
        body: {'roomName': roomName},
        headers: {'Authorization': authHeader},
      );
      final token = result.data?['token'] as String?;
      if (token == null) return false;

      final url = const String.fromEnvironment('LIVEKIT_URL', defaultValue: '');
      if (url.isEmpty) return false;

      final room = lk.Room();
      await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);

      room.addListener(() {
        final speaking = room.activeSpeakers.any((p) => p != room.localParticipant);
        onOpponentSpeakingChanged?.call(speaking);
      });

      _room = room;
      _connected = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  Future<void> disconnect() async {
    try {
      await _room?.disconnect();
    } catch (_) {}
    _room = null;
    _connected = false;
  }
}
