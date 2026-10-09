import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import 'darkom_arena_logic.dart';

/// Supabase Realtime plumbing for one arena room: presence for looks and the
/// ready state, broadcast for everything that happens in the match. Nothing
/// here decides game rules: received payloads go straight to [ArenaGame],
/// which clamps and validates them.
class ArenaNet {
  final String code;
  final ArenaGame game;
  RealtimeChannel? _ch;
  bool subscribed = false;
  bool failed = false;
  bool _disposed = false;

  ArenaNet(this.code, this.game);

  static const List<String> _events = <String>['st', 'atk', 'hit', 'round', 'ready', 'em'];

  Future<void> start() async {
    if (_disposed) return;
    try {
      final RealtimeChannel ch = SupabaseService.client.channel('darkom:arena:$code', opts: const RealtimeChannelConfig(self: false));
      _ch = ch;
      for (final String ev in _events) {
        ch.onBroadcast(event: ev, callback: (Map<String, dynamic> payload) {
          if (_disposed) return;
          Map<String, dynamic> p = payload;
          final dynamic inner = payload['payload'];
          if (!payload.containsKey('u') && inner is Map) p = Map<String, dynamic>.from(inner);
          game.onEvent(ev, p);
        });
      }
      ch.onPresenceSync((dynamic _) => _readPresence());
      ch.onPresenceJoin((dynamic _) => _readPresence());
      ch.onPresenceLeave((dynamic _) => _readPresence());
      game.sender = send;
      game.onLookChanged = trackNow;
      ch.subscribe((RealtimeSubscribeStatus status, Object? error) {
        if (_disposed) return;
        if (status == RealtimeSubscribeStatus.subscribed) {
          subscribed = true;
          failed = false;
          trackNow();
        } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
          subscribed = false;
          failed = true;
        } else if (status == RealtimeSubscribeStatus.closed) {
          subscribed = false;
        }
      });
    } catch (_) {
      failed = true;
    }
  }

  void trackNow() {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null || !subscribed) return;
    try {
      final Future<dynamic> f = ch.track(game.presencePayload());
      f.then((dynamic _) {}, onError: (Object _) {});
    } catch (_) {}
  }

  void send(String event, Map<String, dynamic> payload) {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null || !subscribed) return;
    try {
      final Future<dynamic> f = ch.sendBroadcastMessage(event: event, payload: payload);
      f.then((dynamic _) {}, onError: (Object _) {});
    } catch (_) {}
  }

  void _readPresence() {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null) return;
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    try {
      final dynamic states = ch.presenceState();
      for (final dynamic s in (states as Iterable<dynamic>)) {
        final dynamic ps = s.presences;
        for (final dynamic p in (ps as Iterable<dynamic>)) {
          final dynamic pl = p.payload;
          if (pl is Map) out.add(Map<String, dynamic>.from(pl));
        }
      }
    } catch (_) {}
    game.onPresence(out);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    game.sender = null;
    game.onLookChanged = null;
    final RealtimeChannel? ch = _ch;
    _ch = null;
    if (ch == null) return;
    try {
      await ch.untrack();
    } catch (_) {}
    try {
      await ch.unsubscribe();
    } catch (_) {}
    try {
      await SupabaseService.client.removeChannel(ch);
    } catch (_) {}
  }
}
