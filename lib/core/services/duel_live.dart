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
  const RivalLive({required this.userId, required this.score, required this.relics, required this.goal, required this.at});
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
        );
      });
      ch.subscribe((RealtimeSubscribeStatus status, Object? error) {
        if (_disposed) return;
        _subscribed = status == RealtimeSubscribeStatus.subscribed;
      });
    } catch (_) {
      // a duel plays fine without the live link
    }
  }

  static int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

  /// Called by the game about once a second.
  void report({required int score, int relics = 0, int goalRelics = 0}) {
    if (_disposed) return;
    reported = true;
    mineScore.value = score;
    mineRelics.value = relics;
    if (goalRelics > 0) goal = goalRelics;
    final RealtimeChannel? ch = _ch;
    if (ch == null || !_subscribed) return;
    final int stamp = score * 31 + relics;
    if (stamp == _lastSent) return;
    _lastSent = stamp;
    try {
      final Future<dynamic> f = ch.sendBroadcastMessage(event: 'p', payload: <String, dynamic>{'u': myId, 's': score, 'r': relics, 'g': goal});
      f.then((dynamic _) {}, onError: (Object _) {});
    } catch (_) {}
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
