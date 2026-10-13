import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// What the other player of a duel is doing right now.
class RivalLive {
  final String userId;
  final int score;
  final int relics;
  final int goal;
  final DateTime at;

  /// True once the rival has finished and sent their final number.
  final bool done;

  /// True when the rival's game sends running scores (not just a final one).
  final bool progressive;
  const RivalLive({required this.userId, required this.score, required this.relics, required this.goal, required this.at, this.done = false, this.progressive = false});
}

/// A light live link between the two players of one duel, so each can see the
/// other's progress while they play. It only carries numbers for display: the
/// result of the duel is still decided by the server from the submitted scores,
/// so a missing or late message can never change who wins.
class DuelLive {
  /// The link for the duel on screen, or null outside a duel.
  static DuelLive? current;

  final String duelId;
  final String myId;

  /// The rival's latest numbers, or null until the first message arrives.
  final ValueNotifier<RivalLive?> rival = ValueNotifier<RivalLive?>(null);
  final ValueNotifier<int> mineScore = ValueNotifier<int>(0);
  final ValueNotifier<int> mineRelics = ValueNotifier<int>(0);
  int goal = 0;
  /// True once the game has reported at least once. Games that never report
  /// show no live bar.
  bool reported = false;

  /// True once the game on screen sends running scores through [progress].
  bool progressive = false;

  /// True after [finish] has been called.
  bool finished = false;
  int _lastAt = 0;

  RealtimeChannel? _ch;
  bool _subscribed = false;
  bool _disposed = false;
  int _lastSent = -1;

  DuelLive(this.duelId, this.myId);

  Future<void> start() async {
    if (_disposed) return;
    current = this;
    try {
      final RealtimeChannel ch = SupabaseService.client.channel('duel:live:$duelId', opts: const RealtimeChannelConfig(self: false));
      _ch = ch;
      ch.onBroadcast(event: 'p', callback: (Map<String, dynamic> payload) {
        if (_disposed) return;
        Map<String, dynamic> p = payload;
        final dynamic inner = payload['payload'];
        if (!payload.containsKey('u') && inner is Map) p = Map<String, dynamic>.from(inner);
        final String u = (p['u'] ?? '').toString();
        if (u.isEmpty || u == myId) return;
        rival.value = RivalLive(
          userId: u,
          score: _int(p['s']),
          relics: _int(p['r']),
          goal: _int(p['g']),
          at: DateTime.now(),
          done: _int(p['f']) == 1,
          progressive: _int(p['m']) == 1,
        );
      });
      ch.subscribe((RealtimeSubscribeStatus status, Object? error) {
        if (_disposed) return;
        _subscribed = status == RealtimeSubscribeStatus.subscribed;
        if (_subscribed && reported) {
          report(score: mineScore.value, relics: mineRelics.value, goalRelics: goal, force: true);
        }
      });
    } catch (_) {
      // a duel plays fine without the live link
    }
  }

  static int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

  /// Called by the game about once a second.
  void report({required int score, int relics = 0, int goalRelics = 0, bool force = false}) {
    if (_disposed) return;
    reported = true;
    mineScore.value = score;
    mineRelics.value = relics;
    if (goalRelics > 0) goal = goalRelics;
    final RealtimeChannel? ch = _ch;
    if (ch == null || !_subscribed) return;
    final int stamp = score * 31 + relics + (finished ? 1 : 0);
    if (!force && stamp == _lastSent) return;
    _lastSent = stamp;
    try {
      final Future<dynamic> f = ch.sendBroadcastMessage(
        event: 'p',
        payload: <String, dynamic>{'u': myId, 's': score, 'r': relics, 'g': goal, 'f': finished ? 1 : 0, 'm': progressive ? 1 : 0},
      );
      f.then((dynamic _) {}, onError: (Object _) {});
    } catch (_) {}
  }

  /// Any game can call this whenever its score changes. It is rate limited,
  /// so calling it on every point is fine. Safe to call outside a duel via
  /// `DuelLive.current?.progress(score)`.
  void progress(int score) {
    if (_disposed || finished) return;
    progressive = true;
    mineScore.value = score;
    reported = true;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastAt < 700) return;
    _lastAt = now;
    report(score: score, relics: mineRelics.value, goalRelics: goal);
  }

  /// Tells the rival this player has finished, with the number being submitted.
  void finish(int score) {
    if (_disposed) return;
    finished = true;
    report(score: score, relics: mineRelics.value, goalRelics: goal, force: true);
    // one repeat, in case the first message was dropped
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!_disposed) report(score: score, relics: mineRelics.value, goalRelics: goal, force: true);
    });
  }

  /// Marks the duel as live so the rival bar shows even for games that only
  /// have a final result. Sends a first "playing" message.
  void markPlaying() {
    if (_disposed) return;
    reported = true;
    report(score: mineScore.value, relics: mineRelics.value, goalRelics: goal, force: true);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!_disposed && !finished) report(score: mineScore.value, relics: mineRelics.value, goalRelics: goal, force: true);
    });
  }

  Future<void> stop() async {
    if (_disposed) return;
    _disposed = true;
    if (identical(current, this)) current = null;
    final RealtimeChannel? ch = _ch;
    _ch = null;
    if (ch == null) return;
    try {
      await ch.unsubscribe();
    } catch (_) {}
    try {
      await SupabaseService.client.removeChannel(ch);
    } catch (_) {}
  }
}
