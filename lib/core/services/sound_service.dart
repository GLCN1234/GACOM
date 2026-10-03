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

  // A small pool of pre-built, reusable players instead of
  // constructing a brand new native AudioPlayer on every single sound
  // trigger. That per-call construction was the real cause behind
  // reports of sound lagging noticeably behind the game event it was
  // meant to punctuate, especially in fast games like Signal Run where
  // several sounds can fire in quick succession — each new player
  // involves real platform-channel setup overhead, and under rapid
  // firing that overhead was audible as delay. Cycling through a
  // fixed pool round-robin still lets sounds overlap (each pool slot
  // is independent), just without rebuilding the player every time.
  static const _poolSize = 6;
  final List<AudioPlayer> _sfxPool = List.generate(_poolSize, (_) => AudioPlayer());
  int _poolIndex = 0;

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
    // Low-latency mode plays assets from memory instead of re-reading
    // from disk on every call — the other half of fixing the lag,
    // alongside not rebuilding the player itself each time.
    for (final p in _sfxPool) {
      try { await p.setPlayerMode(PlayerMode.lowLatency); } catch (_) {}
    }
  }

  Future<void> _playSfx(String assetName, {Duration? maxDuration}) async {
    if (!_sfxEnabled) return;
    try {
      final player = _sfxPool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize;
      // stop() before replaying this pool slot — necessary since it's
      // reused, but unlike the old shared-single-player approach this
      // only ever interrupts this one slot's own previous sound, never
      // a sound still in use elsewhere, so it doesn't reintroduce the
      // original overlapping-sounds crackle.
      await player.stop();
      await player.play(AssetSource('sounds/$assetName'));
      // For sounds whose source file runs noticeably longer than the
      // in-game moment it's meant to punctuate (the chess capture
      // sound specifically was reported as long and "relaying" into
      // the next move) — cap playback at a fixed, short duration.
      if (maxDuration != null) {
        Future.delayed(maxDuration, () async {
          try { await player.stop(); } catch (_) {}
        });
      }
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
  Future<void> playPieceCapture() => _playSfx('piece_capture.mp3', maxDuration: const Duration(milliseconds: 400));
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
