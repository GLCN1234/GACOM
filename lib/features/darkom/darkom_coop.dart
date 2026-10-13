import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

/// City Patrol: the co-op mode of Darkom City.
///
/// One phone in the squad (the host) runs every enemy. The others send their
/// hits to the host and draw what the host sends back. There is no game
/// server: the host's phone is the referee, so if the host leaves the patrol
/// ends for everyone. Nothing from a patrol is saved to any ranking, season
/// pass or wallet.

/// Who is in the patrol and who runs it.
class DarkomCoopArgs {
  final String squadId;

  /// Whoever runs the enemies right now. Changes if the host leaves.
  String hostId;
  final String myId;
  final List<String> playerIds;
  final List<String> names;

  /// '' for a free patrol, else clear | hold | bounty | data (a Squad Contract).
  final String contract;

  DarkomCoopArgs({
    required this.squadId,
    required this.hostId,
    required this.myId,
    required this.playerIds,
    required this.names,
    this.contract = '',
  });

  bool get isHost => myId == hostId;

  /// Everyone builds the same city from the squad id.
  int get seed {
    int h = 7;
    for (final int c in squadId.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  String nameOf(String id) {
    final int i = playerIds.indexOf(id);
    if (i >= 0 && i < names.length && names[i].trim().isNotEmpty) {
      final String n = names[i].trim();
      return n.length > 12 ? n.substring(0, 12) : n;
    }
    return 'Ally';
  }

  int slotOf(String id) {
    final int i = playerIds.indexOf(id);
    return i < 0 ? 0 : i;
  }
}

/// Another player in the patrol, as this phone sees them.
class DAlly {
  final String id;
  final String name;
  final int slot;
  double x = 0;
  double y = 0;
  double tx = 0;
  double ty = 0;
  double face = 1;
  double hp = 100;
  double maxHp = 100;
  bool dead = false;
  bool seen = false;
  bool gone = false;
  double swing = 0;
  double lastSeen = 0;
  double phase = 0;
  bool moving = false;

  /// Host only: short protection after this ally was hit.
  double invuln = 0;
  int kills = 0;

  DAlly(this.id, this.name, this.slot);

  bool get alive => seen && !gone && !dead;
}

const List<Color> darkomAllyColors = <Color>[Color(0xFF00E5FF), Color(0xFFFFD54F), Color(0xFF69F0AE), Color(0xFFE040FB)];

class DarkomCoop {
  final DarkomCoopArgs args;
  final Map<String, DAlly> allies = <String, DAlly>{};
  final Stopwatch _sw = Stopwatch()..start();

  RealtimeChannel? _ch;
  bool subscribed = false;
  bool _disposed = false;

  /// Seconds since the last snapshot from the host (guests).
  double lastSnapAt = 0;
  bool snapSeen = false;
  bool hostLostFired = false;

  void Function(Map<String, dynamic> p)? onSnap;
  void Function(String from, Map<String, dynamic> p)? onHit;
  void Function(Map<String, dynamic> p)? onHurt;
  void Function(Map<String, dynamic> p)? onKill;
  void Function()? onHostLost;
  void Function(String from, Map<String, dynamic> p)? onFx;
  void Function(bool nowHost)? onHostChanged;

  /// Former hosts that went silent. Never elected again.
  final Set<String> lostHosts = <String>{};

  DarkomCoop(this.args) {
    for (int i = 0; i < args.playerIds.length; i++) {
      final String id = args.playerIds[i];
      if (id == args.myId) continue;
      allies[id] = DAlly(id, args.nameOf(id), i);
    }
  }

  double get now => _sw.elapsedMilliseconds / 1000.0;

  static const List<String> _events = <String>['pos', 'snap', 'hit', 'hurt', 'kill', 'fx', 'host'];

  Future<void> start() async {
    if (_disposed || _ch != null) return;
    try {
      final RealtimeChannel ch = SupabaseService.client.channel('darkom:coop:${args.squadId}', opts: const RealtimeChannelConfig(self: false));
      _ch = ch;
      for (final String ev in _events) {
        ch.onBroadcast(
            event: ev,
            callback: (Map<String, dynamic> payload) {
              if (_disposed) return;
              Map<String, dynamic> p = payload;
              final dynamic inner = payload['payload'];
              if (!payload.containsKey('u') && inner is Map) p = Map<String, dynamic>.from(inner);
              _handle(ev, p);
            });
      }
      ch.subscribe((RealtimeSubscribeStatus status, Object? error) {
        if (_disposed) return;
        if (status == RealtimeSubscribeStatus.subscribed) {
          subscribed = true;
          lastSnapAt = now;
        } else {
          subscribed = false;
        }
      });
    } catch (_) {}
  }

  static String _s(dynamic v) => v == null ? '' : v.toString();

  static double num0(dynamic v, double lo, double hi, [double d = 0]) {
    double x = d;
    if (v is num) x = v.toDouble();
    if (x.isNaN || x.isInfinite) x = d;
    return x < lo ? lo : (x > hi ? hi : x);
  }

  void _handle(String ev, Map<String, dynamic> p) {
    final String u = _s(p['u']);
    if (u.isEmpty || u == args.myId || !args.playerIds.contains(u)) return;
    switch (ev) {
      case 'pos':
        final DAlly? a = allies[u];
        if (a == null) return;
        final double nx = num0(p['x'], -20000, 20000);
        final double ny = num0(p['y'], -20000, 20000);
        a.tx = nx;
        a.ty = ny;
        if (!a.seen) {
          a.x = nx;
          a.y = ny;
          a.seen = true;
        }
        a.gone = false;
        a.face = num0(p['f'], -7, 7, 1);
        a.hp = num0(p['h'], 0, 400, 100);
        a.maxHp = num0(p['m'], 1, 400, 100);
        a.dead = p['d'] == 1;
        a.swing = num0(p['s'], 0, 1);
        a.lastSeen = now;
        break;
      case 'snap':
        if (u != args.hostId) return;
        snapSeen = true;
        lastSnapAt = now;
        onSnap?.call(p);
        break;
      case 'hit':
        if (!args.isHost) return;
        onHit?.call(u, p);
        break;
      case 'hurt':
        if (u != args.hostId || _s(p['to']) != args.myId) return;
        onHurt?.call(p);
        break;
      case 'kill':
        if (u != args.hostId) return;
        onKill?.call(p);
        break;
      case 'fx':
        onFx?.call(u, p);
        break;
      case 'host':
        // Someone took over after the host went quiet.
        if (lostHosts.contains(u) || u == args.hostId) return;
        final bool wasHost = args.isHost;
        args.hostId = u;
        hostLostFired = false;
        snapSeen = false;
        lastSnapAt = now;
        if (wasHost) onHostChanged?.call(false);
        break;
    }
  }

  void send(String event, Map<String, dynamic> payload) {
    final RealtimeChannel? ch = _ch;
    if (_disposed || ch == null || !subscribed) return;
    payload['u'] = args.myId;
    try {
      final Future<dynamic> f = ch.sendBroadcastMessage(event: event, payload: payload);
      f.then((dynamic _) {}, onError: (Object _) {});
    } catch (_) {}
  }

  double _posT = 0;
  double _lastX = 0;
  double _lastY = 0;
  int _lastH = -1;
  double _quiet = 0;

  /// The player who should take over, or null if nobody else is around.
  String? electNext() {
    for (final String id in args.playerIds) {
      if (lostHosts.contains(id)) continue;
      if (id == args.myId) return id;
      final DAlly? a = allies[id];
      if (a != null && a.seen && !a.gone && now - a.lastSeen < 4) return id;
    }
    return null;
  }

  /// The host went quiet. Returns true if this player is the new host.
  bool handleHostLoss() {
    lostHosts.add(args.hostId);
    final String? next = electNext();
    hostLostFired = false;
    snapSeen = false;
    lastSnapAt = now;
    if (next == null) return false;
    args.hostId = next;
    if (next == args.myId) {
      send('host', <String, dynamic>{});
      onHostChanged?.call(true);
      return true;
    }
    return false;
  }

  /// Call every frame. Sends this player's position about 8 times a second
  /// and glides the other players toward their last known spot.
  void tick(double dt, double x, double y, double face, double hp, double maxHp, bool dead, double swing, bool moving) {
    _posT -= dt;
    _quiet += dt;
    if (_posT <= 0) {
      // Slower in bigger squads and silent while standing still, to stay
      // inside the realtime message budget.
      _posT = 0.14 + 0.03 * allies.length;
      final bool still = (x - _lastX).abs() < 3 && (y - _lastY).abs() < 3 && hp.round() == _lastH && swing == 0;
      if (still && _quiet < 1.2) {
        // skip this one
      } else {
        _quiet = 0;
        _lastX = x;
        _lastY = y;
        _lastH = hp.round();
      send('pos', <String, dynamic>{
        'x': x.round(),
        'y': y.round(),
        'f': (face * 100).round() / 100,
        'h': hp.round(),
        'm': maxHp.round(),
        'd': dead ? 1 : 0,
        's': (swing * 100).round() / 100,
      });
      }
    }
    final double t = now;
    final double k = min(1.0, dt * 12);
    for (final DAlly a in allies.values) {
      if (a.invuln > 0) a.invuln -= dt;
      if (!a.seen) continue;
      if (t - a.lastSeen > 8) a.gone = true;
      final double dx = a.tx - a.x;
      final double dy = a.ty - a.y;
      if (dx * dx + dy * dy > 640000) {
        a.x = a.tx;
        a.y = a.ty;
      } else {
        a.x += dx * k;
        a.y += dy * k;
      }
      a.moving = dx * dx + dy * dy > 16;
      if (a.moving) a.phase += dt * 11;
    }
    if (!args.isHost && !hostLostFired) {
      final double wait = snapSeen ? 5 : 14;
      if (t - lastSnapAt > wait) {
        hostLostFired = true;
        onHostLost?.call();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
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
