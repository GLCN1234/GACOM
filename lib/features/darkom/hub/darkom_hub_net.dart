import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel, RealtimeChannelConfig, RealtimeSubscribeStatus;
import '../../../core/services/supabase_service.dart';
import '../darkom_look.dart';
import 'darkom_hub_service.dart';
import 'darkom_hub_world.dart';

/// Another player in the plaza, smoothed for drawing.
class HubRemote {
  final String id;
  DarkomLook look;
  double x = 0;
  double y = 0;
  double tx = 0;
  double ty = 0;
  double facing = 1;
  double phase = 0;
  bool moving = false;
  bool drawMoving = false;
  bool placed = false;
  int lastSeenMs = 0;
  HubRemote(this.id, this.look);

  double alpha(int nowMs) {
    final int age = nowMs - lastSeenMs;
    if (age <= 4500) return 1;
    if (age >= 6000) return 0;
    return 1 - (age - 4500) / 1500;
  }
}

/// Realtime presence and movement for one hub instance.
///
/// Presence carries the look of each player (re-tracked only when it changes).
/// Broadcast 'pos' carries movement and 'emote' carries emotes. Everything
/// that arrives is checked, and blocked players are ignored completely.
class DarkomHubNet {
  static const int maxDrawn = 20;
  static const int maxKnown = 60;

  final String instance;
  final String myId;
  DarkomHubNet(this.instance, this.myId);

  final Map<String, HubRemote> remotes = <String, HubRemote>{};
  final Map<String, DarkomLook> looks = <String, DarkomLook>{};
  final ValueNotifier<int> online = ValueNotifier<int>(1);
  final ValueNotifier<String> status = ValueNotifier<String>('connecting');
  void Function(String userId, int index)? onEmote;

  Set<String> _blocked = <String>{};
  RealtimeChannel? _ch;
  Timer? _hb;
  bool _disposed = false;
  String _lastLookJson = '';
  DarkomLook? _look;
  int _lastSendMs = 0;
  double _sx = -1;
  double _sy = -1;
  double _sf = 1;
  bool _sm = false;
  final Map<String, int> _lastRecvMs = <String, int>{};
  final Map<String, int> _lastTs = <String, int>{};
  final Map<String, int> _lastEmoteMs = <String, int>{};

  Future<void> start(DarkomLook look) async {
    if (_disposed) return;
    _look = look;
    _lastLookJson = jsonEncode(look.toJson());
    try {
      final RealtimeChannel ch = SupabaseService.client.channel(
        'darkom:hub:$instance',
        opts: RealtimeChannelConfig(self: false, key: myId),
      );
      _ch = ch;
      ch
          .onPresenceSync((_) => _syncPresence())
          .onPresenceJoin((_) => _syncPresence())
          .onPresenceLeave((_) => _syncPresence())
          .onBroadcast(event: 'pos', callback: (Map<String, dynamic> p) => _onPos(p))
          .onBroadcast(event: 'emote', callback: (Map<String, dynamic> p) => _onEmote(p))
          .subscribe((RealtimeSubscribeStatus s, Object? error) async {
        if (_disposed) return;
        if (s == RealtimeSubscribeStatus.subscribed) {
          status.value = 'live';
          try {
            final DarkomLook? l = _look;
            if (l != null) await ch.track(l.toJson());
          } catch (_) {}
          _syncPresence();
        } else if (s == RealtimeSubscribeStatus.channelError || s == RealtimeSubscribeStatus.timedOut) {
          status.value = 'offline';
        } else if (s == RealtimeSubscribeStatus.closed) {
          if (!_disposed) status.value = 'offline';
        }
      });
    } catch (_) {
      if (!_disposed) status.value = 'offline';
    }
    _hb?.cancel();
    _hb = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_disposed) return;
      try {
        DarkomHubService.heartbeat(instance);
      } catch (_) {}
    });
  }

  /// Sends a new look only when something actually changed.
  Future<void> updateLook(DarkomLook look) async {
    if (_disposed) return;
    final String j = jsonEncode(look.toJson());
    if (j == _lastLookJson) return;
    _lastLookJson = j;
    _look = look;
    final RealtimeChannel? ch = _ch;
    if (ch == null || status.value != 'live') return;
    try {
      await ch.track(look.toJson());
    } catch (_) {}
  }

  void setBlocked(Set<String> blocked) {
    _blocked = Set<String>.from(blocked);
    remotes.removeWhere((String id, HubRemote r) => _blocked.contains(id));
    looks.removeWhere((String id, DarkomLook l) => _blocked.contains(id));
    _syncPresence();
  }

  void _syncPresence() {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null) return;
    final Map<String, DarkomLook> next = <String, DarkomLook>{};
    try {
      outer:
      for (final s in ch.presenceState()) {
        for (final p in s.presences) {
          if (next.length >= maxKnown) break outer;
          final dynamic raw = p.payload;
          if (raw is! Map) continue;
          final DarkomLook l = DarkomLook.fromJson(raw);
          if (l.userId.isEmpty || l.userId == myId) continue;
          if (_blocked.contains(l.userId)) continue;
          next[l.userId] = l;
        }
      }
    } catch (_) {
      return;
    }
    looks
      ..clear()
      ..addAll(next);
    remotes.removeWhere((String id, HubRemote r) => !next.containsKey(id));
    _lastRecvMs.removeWhere((String id, int v) => !next.containsKey(id));
    _lastTs.removeWhere((String id, int v) => !next.containsKey(id));
    _lastEmoteMs.removeWhere((String id, int v) => !next.containsKey(id));
    remotes.forEach((String id, HubRemote r) {
      final DarkomLook? l = next[id];
      if (l != null) r.look = l;
    });
    online.value = next.length + 1;
  }

  void _onPos(Map<String, dynamic> raw) {
    try {
      Map<String, dynamic> p = raw;
      final dynamic inner = raw['payload'];
      if (raw['u'] == null && inner is Map) p = Map<String, dynamic>.from(inner);
      final dynamic u = p['u'];
      if (u is! String || u.isEmpty || u == myId) return;
      if (_blocked.contains(u)) return;
      final DarkomLook? look = looks[u];
      if (look == null) return;
      final dynamic xv = p['x'];
      final dynamic yv = p['y'];
      if (xv is! num || yv is! num) return;
      final double x = xv.toDouble();
      final double y = yv.toDouble();
      if (!x.isFinite || !y.isFinite) return;
      final dynamic tsv = p['ts'];
      if (tsv is num) {
        final int ts = tsv.toInt();
        final int prev = _lastTs[u] ?? 0;
        if (ts <= prev && prev - ts < 60000) return;
        _lastTs[u] = ts;
      }
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int last = _lastRecvMs[u] ?? 0;
      if (now - last < 40) return;
      _lastRecvMs[u] = now;
      HubRemote? r = remotes[u];
      if (r == null) {
        if (remotes.length >= maxKnown) return;
        r = HubRemote(u, look);
        remotes[u] = r;
      }
      r.tx = x.clamp(0.0, HubWorld.width).toDouble();
      r.ty = y.clamp(0.0, HubWorld.height).toDouble();
      if (!r.placed) {
        r.x = r.tx;
        r.y = r.ty;
        r.placed = true;
      }
      final dynamic f = p['f'];
      r.facing = (f is num && f < 0) ? -1 : 1;
      r.moving = p['m'] == true;
      r.lastSeenMs = now;
    } catch (_) {}
  }

  void _onEmote(Map<String, dynamic> raw) {
    try {
      Map<String, dynamic> p = raw;
      final dynamic inner = raw['payload'];
      if (raw['u'] == null && inner is Map) p = Map<String, dynamic>.from(inner);
      final dynamic u = p['u'];
      final dynamic e = p['e'];
      if (u is! String || u.isEmpty || u == myId || e is! num) return;
      if (_blocked.contains(u) || !looks.containsKey(u)) return;
      final int idx = e.toInt();
      if (idx < 0 || idx >= kHubEmotes.length) return;
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - (_lastEmoteMs[u] ?? 0) < 1000) return;
      _lastEmoteMs[u] = now;
      onEmote?.call(u, idx);
    } catch (_) {}
  }

  /// Smooths remote movement. Call once per frame.
  void step(double dt) {
    final double k = 1 - exp(-dt * 11);
    for (final HubRemote r in remotes.values) {
      final double dx = r.tx - r.x;
      final double dy = r.ty - r.y;
      final double d2 = dx * dx + dy * dy;
      if (d2 > 360000) {
        r.x = r.tx;
        r.y = r.ty;
      } else {
        r.x += dx * k;
        r.y += dy * k;
      }
      r.drawMoving = r.moving || d2 > 9;
      if (r.drawMoving) r.phase += dt * 9;
    }
  }

  /// Sends my position when it changed, or every 400 ms when idle.
  void maybeSendPos(double x, double y, double facing, bool moving) {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null || status.value != 'live') return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int gap = now - _lastSendMs;
    if (gap < 120) return;
    final bool changed = moving != _sm || facing != _sf || (x - _sx).abs() + (y - _sy).abs() > 1.5;
    if (!changed && gap < 400) return;
    _lastSendMs = now;
    _sx = x;
    _sy = y;
    _sf = facing;
    _sm = moving;
    _send(ch, 'pos', <String, dynamic>{
      'u': myId,
      'x': (x * 10).round() / 10,
      'y': (y * 10).round() / 10,
      'f': facing >= 0 ? 1 : -1,
      'm': moving,
      'ts': now,
    });
  }

  void sendEmote(int index) {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null || status.value != 'live') return;
    _send(ch, 'emote', <String, dynamic>{'u': myId, 'e': index});
  }

  Future<void> _send(RealtimeChannel ch, String event, Map<String, dynamic> payload) async {
    try {
      await ch.sendBroadcastMessage(event: event, payload: payload);
    } catch (_) {}
  }

  /// The closest players that are fresh enough to draw, at most [maxDrawn].
  List<HubRemote> visible(double meX, double meY, int nowMs) {
    final List<HubRemote> out = <HubRemote>[];
    for (final HubRemote r in remotes.values) {
      if (!r.placed || _blocked.contains(r.id)) continue;
      if (r.alpha(nowMs) <= 0.02) continue;
      out.add(r);
    }
    if (out.length > maxDrawn) {
      double d(HubRemote r) => (r.x - meX) * (r.x - meX) + (r.y - meY) * (r.y - meY);
      out.sort((HubRemote a, HubRemote b) => d(a).compareTo(d(b)));
      return out.sublist(0, maxDrawn);
    }
    return out;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _hb?.cancel();
    final RealtimeChannel? ch = _ch;
    _ch = null;
    onEmote = null;
    online.dispose();
    status.dispose();
    if (ch != null) {
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
}
