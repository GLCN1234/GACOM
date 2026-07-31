// Mobile/desktop stub — voice chat is web-only for now since it uses
// browser-native WebRTC via package:web.

class EduVoiceService {
  void Function(bool connected)? onConnectionChange;
  void Function(String error)? onError;

  Future<void> start({required String roomId, required bool isInitiator}) async {
    onError?.call('Voice chat is currently web-only');
  }

  void toggleMute() {}
  bool get isMuted => false;
  Future<void> stop() async {}
}
