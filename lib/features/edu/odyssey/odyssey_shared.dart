import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel, RealtimeChannelConfig, RealtimeSubscribeStatus;
import '../../../core/services/supabase_service.dart';
import '../realms/realm_kit.dart';

/// Another explorer in the same Odyssey world.
class OdyRemote {
  final String id;
  String name;
  Color shirt;
  Color pants;
  Color skin;
  Color hair;
  Color nameColor;
  double x = 0;
  double y = 0;
  double tx = 0;
  double ty = 0;
  double facing = 1;
  double phase = 0;
  bool moving = false;
  bool placed = false;
  int lastSeenMs = 0;
  int score = 0;

  OdyRemote(this.id, this.name, this.shirt, this.pants, this.skin, this.hair, this.nameColor);

  /// Fades out when no message has arrived for a while.
  double alpha(int nowMs) {
    final int age = nowMs - lastSeenMs;
    if (age <= 4500) return 1;
    if (age >= 6000) return 0;
    return 1 - (age - 4500) / 1500;
  }
}

/// One shared Odyssey world.
///
/// Everyone who explores with the same set of subjects gets the same world
/// layout (the same seed), so regions line up and players can meet. This link
/// carries only where each explorer is and a few cosmetic details. Questions,
/// orbs, enemies and scores are still each player's own, so nothing here can
/// change anyone's result.
///
/// Presence carries the look and name (sent once); broadcast 'pos' carries
/// movement about three times a second. Everything that arrives is checked,
/// blocked players are ignored, and at most [maxDrawn] explorers are drawn.
class OdysseyShared {
  static const int maxDrawn = 12;
  static const int roomSize = 24;
  static const int maxShards = 6;

  /// Same room and same world for the same subjects.
  static String roomFor(List<String> subjectIds) {
    final List<String> ids = List<String>.from(subjectIds)..sort();
    return ids.join('_');
  }

  /// The world seed every player of [room] shares.
  static int seedFor(String room) {
    int h = 17;
    for (final int c in room.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h == 0 ? 1 : h;
  }

  final String room;
  final String myId;
  final String myName;
  OdysseyShared(this.room, this.myId, this.myName);

  final Map<String, OdyRemote> remotes = <String, OdyRemote>{};
  final Map<String, Map<String, dynamic>> _known = <String, Map<String, dynamic>>{};
  final ValueNotifier<int> online = ValueNotifier<int>(1);
  final ValueNotifier<String> status = ValueNotifier<String>('connecting');

  Set<String> _blocked = <String>{};
  RealtimeChannel? _ch;
  bool _disposed = false;
  bool _hidden = false;
  int _shard = 0;
  int _hops = 0;
  int _lastSendMs = 0;
  double _sx = -1;
  double _sy = -1;
  bool _sm = false;
  final Map<String, int> _lastRecvMs = <String, int>{};
  final Map<String, int> _lastTs = <String, int>{};

  /// When true nobody is drawn and nothing is sent.
  bool get hidden => _hidden;
  set hidden(bool v) {
    _hidden = v;
    if (v) {
      remotes.clear();
    }
  }

  void setBlocked(Set<String> blocked) {
    _blocked = Set<String>.from(blocked);
    remotes.removeWhere((String id, OdyRemote r) => _blocked.contains(id));
    _known.removeWhere((String id, Map<String, dynamic> v) => _blocked.contains(id));
  }

  static String _hex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0');

  static Color _col(dynamic v, Color fallback) {
    if (v is! String || v.length != 8) return fallback;
    final int? n = int.tryParse(v, radix: 16);
    return n == null ? fallback : Color(n);
  }

  Map<String, dynamic> _myLook() {
    final HeroLook l = HeroLook.current;
    return <String, dynamic>{
      'u': myId,
      'n': myName,
      'sh': _hex(l.shirt),
      'pa': _hex(l.pants),
      'sk': _hex(l.skin),
      'ha': _hex(l.hair),
    };
  }

  Future<void> start() async {
    if (_disposed) return;
    await _join();
  }

  Future<void> _join() async {
    if (_disposed) return;
    status.value = 'connecting';
    try {
      final RealtimeChannel ch = SupabaseService.client.channel(
        'odyssey:world:$room:$_shard',
        opts: RealtimeChannelConfig(self: false, key: myId),
      );
      _ch = ch;
      ch
          .onPresenceSync((_) => _syncPresence())
          .onPresenceJoin((_) => _syncPresence())
          .onPresenceLeave((_) => _syncPresence())
          .onBroadcast(event: 'pos', callback: (Map<String, dynamic> p) => _onPos(p))
          .subscribe((RealtimeSubscribeStatus s, Object? error) async {
        if (_disposed) return;
        if (s == RealtimeSubscribeStatus.subscribed) {
          status.value = 'live';
          try {
            await ch.track(_myLook());
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
  }

  void _syncPresence() {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null) return;
    final Map<String, Map<String, dynamic>> next = <String, Map<String, dynamic>>{};
    try {
      outer:
      for (final s in ch.presenceState()) {
        for (final p in s.presences) {
          if (next.length >= roomSize * 2) break outer;
          final dynamic raw = p.payload;
          if (raw is! Map) continue;
          final String u = (raw['u'] ?? '').toString();
          if (u.isEmpty || u == myId || _blocked.contains(u)) continue;
          next[u] = Map<String, dynamic>.from(raw);
        }
      }
    } catch (_) {
      return;
    }
    _known
      ..clear()
      ..addAll(next);
    remotes.removeWhere((String id, OdyRemote r) => !next.containsKey(id));
    _lastRecvMs.removeWhere((String id, int v) => !next.containsKey(id));
    _lastTs.removeWhere((String id, int v) => !next.containsKey(id));
    remotes.forEach((String id, OdyRemote r) {
      final Map<String, dynamic>? k = next[id];
      if (k != null) _applyLook(r, k);
    });
    online.value = next.length + 1;
    // A full room sends this player to the next one with space, once or twice.
    if (next.length + 1 > roomSize && _hops < 2 && _shard + 1 < maxShards) {
      _hops++;
      _hop();
    }
  }

  Future<void> _hop() async {
    final RealtimeChannel? old = _ch;
    _ch = null;
    remotes.clear();
    _known.clear();
    _shard++;
    if (old != null) {
      try {
        await old.untrack();
      } catch (_) {}
      try {
        await old.unsubscribe();
      } catch (_) {}
      try {
        await SupabaseService.client.removeChannel(old);
      } catch (_) {}
    }
    await _join();
  }

  static String _clean(dynamic v) {
    final String s = (v ?? '').toString().trim();
    if (s.isEmpty) return 'Explorer';
    return s.length > 14 ? s.substring(0, 14) : s;
  }

  void _applyLook(OdyRemote r, Map<String, dynamic> k) {
    r.name = _clean(k['n']);
    r.shirt = _col(k['sh'], r.shirt);
    r.pants = _col(k['pa'], r.pants);
    r.skin = _col(k['sk'], r.skin);
    r.hair = _col(k['ha'], r.hair);
  }

  void _onPos(Map<String, dynamic> raw) {
    if (_hidden) return;
    try {
      Map<String, dynamic> p = raw;
      final dynamic inner = raw['payload'];
      if (raw['u'] == null && inner is Map) p = Map<String, dynamic>.from(inner);
      final dynamic u = p['u'];
      if (u is! String || u.isEmpty || u == myId || _blocked.contains(u)) return;
      final Map<String, dynamic>? k = _known[u];
      if (k == null) return;
      final dynamic xv = p['x'];
      final dynamic yv = p['y'];
      if (xv is! num || yv is! num) return;
      final double x = xv.toDouble();
      final double y = yv.toDouble();
      if (!x.isFinite || !y.isFinite || x.abs() > 1e7 || y.abs() > 1e7) return;
      final dynamic tsv = p['ts'];
      if (tsv is num) {
        final int ts = tsv.toInt();
        final int prev = _lastTs[u] ?? 0;
        if (ts <= prev && prev - ts < 60000) return;
        _lastTs[u] = ts;
      }
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - (_lastRecvMs[u] ?? 0) < 60) return;
      _lastRecvMs[u] = now;
      OdyRemote? r = remotes[u];
      if (r == null) {
        if (remotes.length >= roomSize * 2) return;
        r = OdyRemote(u, 'Explorer', const Color(0xFFFF6A00), const Color(0xFF2A3A63), const Color(0xFFF2B785), const Color(0xFF2B1B12), const Color(0xFFFFFFFF));
        _applyLook(r, k);
        remotes[u] = r;
      }
      r.tx = x;
      r.ty = y;
      if (!r.placed) {
        r.x = x;
        r.y = y;
        r.placed = true;
      }
      final dynamic f = p['f'];
      r.facing = (f is num && f < 0) ? -1 : 1;
      r.moving = p['m'] == true;
      final dynamic sc = p['s'];
      if (sc is num) r.score = sc.toInt().clamp(0, 99999999).toInt();
      r.lastSeenMs = now;
    } catch (_) {}
  }

  /// Smooths remote movement. Call once per frame.
  void step(double dt) {
    final double k = 1 - exp(-dt * 9);
    for (final OdyRemote r in remotes.values) {
      final double dx = r.tx - r.x;
      final double dy = r.ty - r.y;
      final double d2 = dx * dx + dy * dy;
      if (d2 > 640000) {
        r.x = r.tx;
        r.y = r.ty;
      } else {
        r.x += dx * k;
        r.y += dy * k;
      }
      if (r.moving || d2 > 16) r.phase += dt * 9;
    }
  }

  /// Sends my position when it changed, or every 700 ms when standing still.
  void maybeSend(double x, double y, double facing, bool moving, int score) {
    final RealtimeChannel? ch = _ch;
    if (_disposed || _hidden || ch == null || status.value != 'live') return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int gap = now - _lastSendMs;
    if (gap < 300) return;
    final bool changed = moving != _sm || (x - _sx).abs() + (y - _sy).abs() > 4;
    if (!changed && gap < 700) return;
    _lastSendMs = now;
    _sx = x;
    _sy = y;
    _sm = moving;
    try {
      final Future<dynamic> f = ch.sendBroadcastMessage(event: 'pos', payload: <String, dynamic>{
        'u': myId,
        'x': (x * 10).round() / 10,
        'y': (y * 10).round() / 10,
        'f': facing >= 0 ? 1 : -1,
        'm': moving,
        's': score,
        'ts': now,
      });
      f.then((dynamic _) {}, onError: (Object _) {});
    } catch (_) {}
  }

  /// The closest explorers that are fresh enough to draw.
  List<OdyRemote> visible(double meX, double meY, int nowMs) {
    if (_hidden) return const <OdyRemote>[];
    final List<OdyRemote> out = <OdyRemote>[];
    for (final OdyRemote r in remotes.values) {
      if (!r.placed || _blocked.contains(r.id)) continue;
      if (r.alpha(nowMs) <= 0.02) continue;
      out.add(r);
    }
    if (out.length > maxDrawn) {
      double d(OdyRemote r) => (r.x - meX) * (r.x - meX) + (r.y - meY) * (r.y - meY);
      out.sort((OdyRemote a, OdyRemote b) => d(a).compareTo(d(b)));
      return out.sublist(0, maxDrawn);
    }
    return out;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final RealtimeChannel? ch = _ch;
    _ch = null;
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
