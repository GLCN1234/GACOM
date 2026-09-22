import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single, reusable sound service any game can call into. Every play
/// call is wrapped so a missing or invalid asset (expected until real
/// audio files are added under assets/sounds/) fails silently — a sound
/// effect must never be able to crash a game.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _initialized = false;

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicEnabled = prefs.getBool('sound_music_enabled') ?? true;
      _sfxEnabled = prefs.getBool('sound_sfx_enabled') ?? true;
    } catch (_) {}
  }

  Future<void> _playSfx(String assetName) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/$assetName'));
    } catch (_) {
      // Expected until real files exist — never let a sound effect
      // take down a game.
    }
  }

  Future<void> playTap() => _playSfx('tap.mp3');
  Future<void> playCorrect() => _playSfx('correct.mp3');
  Future<void> playWrong() => _playSfx('wrong.mp3');
  Future<void> playWin() => _playSfx('win.mp3');
  Future<void> playLose() => _playSfx('lose.mp3');

  Future<void> startBackgroundMusic() async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(AssetSource('sounds/bgm.mp3'), volume: 0.35);
    } catch (_) {}
  }

  Future<void> stopBackgroundMusic() async {
    try { await _musicPlayer.stop(); } catch (_) {}
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_music_enabled', enabled);
    } catch (_) {}
    if (!enabled) await stopBackgroundMusic();
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_sfx_enabled', enabled);
    } catch (_) {}
  }
}
