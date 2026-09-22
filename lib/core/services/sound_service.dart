import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single, reusable sound service any game can call into. Every play
/// call is wrapped so a missing or invalid asset (expected until real
/// audio files are added under assets/sounds/) fails silently — a sound
/// effect must never be able to crash a game.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

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
    // A fresh, short-lived player per sound effect — not the old shared
    // stop-then-restart approach, which caused an audible crack/skip
    // whenever two sounds fired close together (e.g. a chess capture
    // triggering move + capture almost simultaneously): stopping a
    // still-playing sound truncates its waveform abruptly, which is
    // exactly what that glitch was. Independent players let sounds
    // overlap and finish naturally instead of cutting each other off.
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) => player.dispose());
      await player.play(AssetSource('sounds/$assetName'));
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
  Future<void> playPieceMove() => _playSfx('piece_move.mp3');
  Future<void> playPieceCapture() => _playSfx('piece_capture.mp3');
  Future<void> playCardFlip() => _playSfx('card_flip.mp3');
  Future<void> playCardShuffle() => _playSfx('card_shuffle.mp3');
  Future<void> playTileSlide() => _playSfx('tile_slide.mp3');
  Future<void> playDrop() => _playSfx('drop.mp3');
  Future<void> playExplosion() => _playSfx('explosion.mp3');
  Future<void> playShoot() => _playSfx('shoot.mp3');
  Future<void> playLetterType() => _playSfx('letter_type.mp3');

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
