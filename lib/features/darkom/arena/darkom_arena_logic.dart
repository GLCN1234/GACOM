import 'dart:math';
import 'dart:ui';
import '../darkom_armory.dart';
import '../darkom_look.dart';
import '../darkom_story.dart';
import 'darkom_arena_args.dart';

part 'darkom_arena_model.dart';
part 'darkom_arena_combat.dart';

// ---------------------------------------------------------------------------
// Constants

const double kArW = 1400;
const double kArH = 1000;
const double kArR = 13;
const double kArHp = 100;
const int kArWinsNeeded = 2;
const int kArMaxRounds = 6;
const double kArCountdown = 3;
const double kArIntermission = 6.5;
const double kArStale = 8;
const double kArLobbyWait = 25;
const double kArOverloadAt = 60;
const double kArAllow = 24;
const double kArStunCap = 0.5;
const int kArMaxProj = 40;
const int kArMaxFx = 60;
const int kArMaxParts = 140;
const int kArMaxTexts = 24;

enum ArPhase { lobby, failed, countdown, fight, intermission, over }

double arAngDiff(double a, double b) {
  double d = a - b;
  while (d > pi) {
    d -= 2 * pi;
  }
  while (d < -pi) {
    d += 2 * pi;
  }
  return d < 0 ? -d : d;
}

double arNum(dynamic v, double lo, double hi, double d) {
  if (v is num) {
    final double x = v.toDouble();
    if (x.isNaN || x.isInfinite) return d;
    return x < lo ? lo : (x > hi ? hi : x);
  }
  return d;
}

int arInt(dynamic v, int lo, int hi, int d) {
  if (v is num) {
    final double x = v.toDouble();
    if (x.isNaN || x.isInfinite) return d;
    final int i = x.toInt();
    return i < lo ? lo : (i > hi ? hi : i);
  }
  return d;
}

double _r1(double v) => (v * 10).roundToDouble() / 10;

Color? _hexColor(String? s) {
  if (s == null) return null;
  String h = s.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length != 6) return null;
  final int? v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

/// The glow colour of a player's weapon skin, used for their effects.
Color arWeaponColor(DarkomLook look) {
  final Color? g = _hexColor(look.weaponAsset['glow']?.toString());
  if (g != null) return g;
  final Color m = _hexColor(look.weaponAsset['metal']?.toString()) ?? const Color(0xFF98A4B8);
  return Color.lerp(m, const Color(0xFFFFFFFF), 0.35) ?? m;
}

// ---------------------------------------------------------------------------
// Game

/// The whole match state. It has no networking of its own: it asks [sender]
/// to broadcast and is fed received events through [onEvent] and
/// [onPresence]. Every incoming number is clamped here.
class ArenaGame {
  final DarkomArenaArgs args;
  final String myId;
  final ArenaMap map;
  final bool friendly;
  final Random _rnd = Random();

  DarkomArmory armory = DarkomArmory.plain();
  late ArenaPlayer me;
  final Map<String, ArenaPlayer> players = <String, ArenaPlayer>{};

  void Function(String event, Map<String, dynamic> payload)? sender;
  void Function()? onLookChanged;
  void Function()? onMatchOver;

  ArPhase phase = ArPhase.lobby;
  double clock = 0;
  double lobbyT = 0;
  double phaseT = 0;
  double roundT = 0;
  int round = 0;
  int version = 0;
  bool over = false;
  bool matchReported = false;
  String chosen = 'sword';
  String banner = '';
  double bannerT = 0;
  String failText = '';
  String lastRoundLine = '';
  final List<String> roundWinners = <String>[];

  // me
  double inX = 0;
  double inY = 0;
  double face = 0;
  double atkCd = 0;
  double atkCdMax = 0.4;
  double specCd = 0;
  double specCdMax = 6;
  double dashCd = 0;
  double mana = 100;
  double manaPause = 0;
  double guard = 0;
  double guardAge = 0;
  int flurry = 0;
  double flurryT = 0;
  double slamT = 0;
  double aimLock = 0;
  double kvx = 0;
  double kvy = 0;
  double dashT = 0;
  double dashVx = 0;
  double dashVy = 0;
  double chargeT = 0;
  double chargeVx = 0;
  double chargeVy = 0;
  double stunT = 0;
  double invuln = 0;
  double hitFlash = 0;
  double noManaT = 0;
  double shake = 0;
  String lastHitBy = '';
  double stSend = 0;
  double roundResend = 0;
  int resendLeft = 0;
  bool overloadWarned = false;
  int _seq = 0;
  int _elimCount = 0;
  final List<String> _elimOrder = <String>[];
  final Set<String> _seenAtk = <String>{};
  double emoteCd = 0;
  int goResendLeft = 0;
  double goT = 0;
  List<String> goRoster = <String>[];

  double camX = kArW / 2;
  double camY = kArH / 2;

  final List<ArProj> projs = <ArProj>[];
  final List<ArAxe> axes = <ArAxe>[];
  final List<ArPending> pend = <ArPending>[];
  final List<ArCharge> charges = <ArCharge>[];
  final List<ArFx> fx = <ArFx>[];
  final List<ArPart> parts = <ArPart>[];
  final List<ArText> texts = <ArText>[];

  ArenaGame(this.args, this.myId, DarkomLook myLook, {this.friendly = false}) : map = ArenaMap.generate(args.code) {
    me = ArenaPlayer(myId, myLook);
    me.present = true;
    players[myId] = me;
    for (final String id in args.playerIds) {
      if (id == myId || id.isEmpty) continue;
      players[id] = ArenaPlayer(id, DarkomLook.fromJson(<String, dynamic>{'u': id, 'n': 'Player'}));
    }
    chosen = darkomWeaponKinds.contains(myLook.weaponKind) ? myLook.weaponKind : 'sword';
    me.pick = chosen;
    me.weapon = chosen;
    face = 0;
  }

  // ---- queries ------------------------------------------------------------

  bool get isDuel => args.mode == 'duel';
  int get maxPlayers => isDuel ? 2 : 4;

  List<ArenaPlayer> _roster = <ArenaPlayer>[];

  /// The players of the running match, sorted by id. Fixed once the match starts.
  List<ArenaPlayer> get roster => _roster;

  List<ArenaPlayer> get lobbyPlayers {
    final List<ArenaPlayer> l = players.values.where((ArenaPlayer p) => p.present).toList();
    l.sort((ArenaPlayer a, ArenaPlayer b) => a.id.compareTo(b.id));
    return l;
  }

  bool get playing => phase == ArPhase.countdown || phase == ArPhase.fight;
  bool get canAct => phase == ArPhase.fight && me.alive && stunT <= 0;
  bool get canPick => phase == ArPhase.lobby || phase == ArPhase.intermission || phase == ArPhase.failed;

  List<ArenaPlayer> opponents() => roster.where((ArenaPlayer p) => !identical(p, me)).toList();

  String get objective {
    if (isDuel) {
      final List<ArenaPlayer> o = opponents();
      return o.isEmpty ? 'Defeat your opponent' : 'Defeat ${o.first.name}';
    }
    return 'Last one standing';
  }

  /// 0 good, 1 fair, 2 poor, 3 lost. Based on the longest silence from a peer.
  int linkQuality() {
    if (!playing && phase != ArPhase.intermission) return 0;
    double worst = 0;
    for (final ArenaPlayer p in roster) {
      if (identical(p, me)) continue;
      final double s = clock - p.lastSeen;
      if (s > worst) worst = s;
    }
    if (worst < 0.6) return 0;
    if (worst < 1.8) return 1;
    if (worst < kArStale) return 2;
    return 3;
  }

  double cdFrac(int which) {
    if (which == 0) return atkCdMax <= 0 ? 0 : (atkCd / atkCdMax).clamp(0.0, 1.0).toDouble();
    if (which == 1) {
      if (me.weapon == 'staff' && mana < 30) return 1;
      return specCdMax <= 0 ? 0 : (specCd / specCdMax).clamp(0.0, 1.0).toDouble();
    }
    return (dashCd / 1.6).clamp(0.0, 1.0).toDouble();
  }

  // ---- lobby --------------------------------------------------------------

  DarkomLook _lookWith(DarkomLook l, String kind) {
    return DarkomLook(
      userId: l.userId,
      name: l.name,
      shirt: l.shirt,
      pants: l.pants,
      skin: l.skin,
      hair: l.hair,
      hairStyle: l.hairStyle,
      trail: l.trail,
      trailColor: l.trailColor,
      title: l.title,
      frameColors: l.frameColors,
      frameStyle: l.frameStyle,
      weaponKind: kind,
      weaponAsset: Map<String, dynamic>.from(armory.assetFor(kind)),
    );
  }

  void setArmory(DarkomArmory a) {
    armory = a;
    me.look = _lookWith(me.look, chosen);
    version++;
    onLookChanged?.call();
  }

  void chooseWeapon(String kind) {
    if (!canPick || !darkomWeaponKinds.contains(kind) || kind == chosen) return;
    chosen = kind;
    me.pick = kind;
    me.look = _lookWith(me.look, kind);
    version++;
    _send('ready', <String, dynamic>{'u': myId, 'rd': me.ready, 'w': kind});
    onLookChanged?.call();
  }

  Map<String, dynamic> presencePayload() => <String, dynamic>{'v': 1, 'look': me.look.toJson(), 'rd': me.ready, 'w': chosen};

  void toggleReady() {
    if (phase != ArPhase.lobby) return;
    me.ready = !me.ready;
    version++;
    _send('ready', <String, dynamic>{'u': myId, 'rd': me.ready, 'w': chosen});
    onLookChanged?.call();
  }

  bool _allowed(String u) {
    if (u.isEmpty) return false;
    if (players.containsKey(u)) return true;
    if (args.playerIds.length >= 2) return false;
    return players.length < maxPlayers;
  }

  ArenaPlayer? _known(dynamic u) {
    if (u == null) return null;
    final String id = u.toString();
    if (id == myId) return null;
    return players[id];
  }

  void onPresence(List<Map<String, dynamic>> list) {
    final Set<String> seen = <String>{};
    for (final Map<String, dynamic> pl in list) {
      final dynamic lk = pl['look'];
      if (lk is! Map) continue;
      final String u = (lk['u'] ?? '').toString();
      if (u == myId || !_allowed(u)) continue;
      seen.add(u);
      ArenaPlayer? p = players[u];
      final DarkomLook look = DarkomLook.fromJson(lk);
      if (look.userId != u) continue;
      if (p == null) {
        p = ArenaPlayer(u, look);
        players[u] = p;
      }
      p.look = look;
      p.present = true;
      p.absentT = 0;
      p.ready = pl['rd'] == true;
      final String w = (pl['w'] ?? '').toString();
      if (darkomWeaponKinds.contains(w)) p.pick = w;
      if (!p.inMatch) p.lastSeen = clock;
    }
    for (final ArenaPlayer p in players.values) {
      if (identical(p, me)) continue;
      if (!seen.contains(p.id)) p.present = false;
    }
    version++;
  }

  // ---- match flow ---------------------------------------------------------

  void _startMatch(List<String> ids) {
    final List<String> sorted = List<String>.from(ids)..sort();
    for (final ArenaPlayer p in players.values) {
      p.inMatch = sorted.contains(p.id);
      p.wins = 0;
      p.elimPts = 0;
      p.lastSeen = clock;
    }
    _roster = players.values.where((ArenaPlayer p) => p.inMatch).toList()..sort((ArenaPlayer a, ArenaPlayer b) => a.id.compareTo(b.id));
    round = 0;
    roundWinners.clear();
    over = false;
    _beginRound();
  }

  void _beginRound() {
    round++;
    phase = ArPhase.countdown;
    phaseT = kArCountdown;
    roundT = 0;
    projs.clear();
    axes.clear();
    pend.clear();
    charges.clear();
    fx.clear();
    parts.clear();
    texts.clear();
    _seenAtk.clear();
    _elimOrder.clear();
    _elimCount = 0;
    overloadWarned = false;
    final List<ArenaPlayer> r = roster;
    for (int i = 0; i < r.length; i++) {
      final ArenaPlayer p = r[i];
      final Offset sp = ArenaMap.spawnFor(i, args.mode, r.length);
      p.x = sp.dx;
      p.y = sp.dy;
      p.tx = sp.dx;
      p.ty = sp.dy;
      p.tvx = 0;
      p.tvy = 0;
      p.vx = 0;
      p.vy = 0;
      p.gotState = false;
      p.stAge = 0;
      p.stClock = clock;
      p.hp = kArHp;
      p.flags = 0;
      p.swingT = -1;
      p.aim = ArenaMap.spawnFace(sp);
      p.face = cos(p.aim) >= 0 ? 1 : -1;
      p.moving = false;
      p.weapon = identical(p, me) ? chosen : p.pick;
      p.lastAtk.clear();
      p.tokens = 7;
      p.tokClock = clock;
      p.mana = 100;
      p.manaClock = clock;
      p.alive = !(clock - p.lastSeen > kArStale) || identical(p, me);
      if (!p.alive) _elimOrder.add(p.id);
    }
    _elimCount = _elimOrder.length;
    final ArenaPlayer m = me;
    face = m.aim;
    mana = 100;
    manaPause = 0;
    atkCd = 0;
    specCd = 0;
    dashCd = 0;
    guard = 0;
    flurry = 0;
    slamT = 0;
    aimLock = 0;
    kvx = 0;
    kvy = 0;
    dashT = 0;
    chargeT = 0;
    stunT = 0;
    invuln = 0;
    hitFlash = 0;
    lastHitBy = '';
    resendLeft = 0;
    final DarkomWeaponDef d = darkomWeapon(m.weapon);
    atkCdMax = d.cd;
    specCdMax = d.scd;
    camX = m.x;
    camY = m.y;
    banner = 'ROUND $round';
    bannerT = 2;
    version++;
  }

  void _beginFight() {
    phase = ArPhase.fight;
    roundT = 0;
    banner = 'FIGHT';
    bannerT = 1;
    for (final ArenaPlayer p in roster) {
      p.lastSeen = clock;
    }
    version++;
  }

  void _eliminate(ArenaPlayer p, String by) {
    if (!p.alive) return;
    p.alive = false;
    p.hp = 0;
    _elimOrder.add(p.id);
    _elimCount = _elimOrder.length;
    this._burst(p.x, p.y, arWeaponColor(p.look));
    this._text(p.x, p.y - 40, 'KO', const Color(0xFFFF5252), size: 20);
    version++;
  }

  void _checkRoundEnd() {
    if (phase != ArPhase.fight) return;
    final List<ArenaPlayer> alive = roster.where((ArenaPlayer p) => p.alive).toList();
    if (alive.length > 1) return;
    _concludeRound(alive.isEmpty ? null : alive.first, announce: true);
  }

  void _concludeRound(ArenaPlayer? w, {required bool announce}) {
    if (phase != ArPhase.fight) return;
    final List<ArenaPlayer> r = roster;
    // Survival points: the later you fall, the more you earn for tie breaks.
    for (int i = 0; i < _elimOrder.length; i++) {
      final ArenaPlayer? p = players[_elimOrder[i]];
      if (p != null) p.elimPts += i;
    }
    if (w != null) {
      w.wins++;
      w.elimPts += r.length - 1;
      roundWinners.add(w.id);
      lastRoundLine = identical(w, me) ? 'You won round $round' : '${w.name} won round $round';
    } else {
      roundWinners.add('');
      lastRoundLine = 'Round $round was a draw';
    }
    banner = lastRoundLine;
    bannerT = 3;
    if (announce) {
      _send('round', <String, dynamic>{'u': myId, 'r': round, 'win': w?.id ?? '', 'ts': _now()});
    }
    version++;
    if (_matchDecided()) {
      _finish();
    } else {
      phase = ArPhase.intermission;
      phaseT = kArIntermission;
    }
  }

  bool _matchDecided() {
    for (final ArenaPlayer p in roster) {
      if (p.wins >= kArWinsNeeded) return true;
    }
    if (round >= kArMaxRounds) return true;
    return false;
  }

  void _finish() {
    if (over) return;
    over = true;
    phase = ArPhase.over;
    version++;
    onMatchOver?.call();
  }

  List<ArenaPlayer> standings() {
    final List<ArenaPlayer> l = List<ArenaPlayer>.from(roster);
    l.sort((ArenaPlayer a, ArenaPlayer b) {
      if (a.wins != b.wins) return b.wins.compareTo(a.wins);
      if (a.elimPts != b.elimPts) return b.elimPts.compareTo(a.elimPts);
      return a.id.compareTo(b.id);
    });
    return l;
  }

  int get myPlacement {
    final List<ArenaPlayer> s = standings();
    for (int i = 0; i < s.length; i++) {
      if (identical(s[i], me)) return i + 1;
    }
    return s.length < 1 ? 1 : s.length;
  }

  bool get iWon {
    final List<ArenaPlayer> s = standings();
    if (s.isEmpty || !identical(s.first, me)) return false;
    if (s.length > 1 && s[1].wins == me.wins) return false;
    return true;
  }

  /// Leaving a running match: counts as forfeiting. Returns true when a
  /// result should be reported.
  bool get leaveCountsAsForfeit => !over && (playing || phase == ArPhase.intermission) && round > 0;

  // ---- sending ------------------------------------------------------------

  int _now() => DateTime.now().millisecondsSinceEpoch;

  void _send(String ev, Map<String, dynamic> p) {
    try {
      sender?.call(ev, p);
    } catch (_) {}
  }

  void sendState() {
    final ArenaPlayer m = me;
    int f = 0;
    if (guard > 0) f |= 1;
    if (dashT > 0) f |= 2;
    if (chargeT > 0) f |= 4;
    if (slamT > 0) f |= 8;
    if (stunT > 0) f |= 16;
    _send('st', <String, dynamic>{
      'u': myId,
      'x': _r1(m.x),
      'y': _r1(m.y),
      'vx': m.vx.roundToDouble(),
      'vy': m.vy.roundToDouble(),
      'an': (face * 100).roundToDouble() / 100,
      'hp': m.hp.round(),
      'w': m.weapon,
      'f': f,
      'rd': round,
      'ts': _now(),
    });
  }

  void sendEmote(int e) {
    if (emoteCd > 0 || e < 0 || e > 1) return;
    emoteCd = 2.5;
    _setEmote(me, e);
    _send('em', <String, dynamic>{'u': myId, 'e': e});
  }

  void _setEmote(ArenaPlayer p, int e) {
    p.emote = e == 0 ? 'Wave' : 'GG';
    p.emoteT = 2.2;
  }

  // ---- incoming events ----------------------------------------------------

  void onEvent(String ev, Map<String, dynamic> p) {
    try {
      switch (ev) {
        case 'st':
          _onState(p);
          break;
        case 'atk':
          _onAtk(p);
          break;
        case 'hit':
          _onHit(p);
          break;
        case 'round':
          _onRound(p);
          break;
        case 'ready':
          _onReady(p);
          break;
        case 'em': {
          final ArenaPlayer? pl = _known(p['u']);
          if (pl != null) {
            pl.lastSeen = clock;
            _setEmote(pl, arInt(p['e'], 0, 1, 0));
          }
          break;
        }
        default:
          break;
      }
    } catch (_) {}
  }

  void _onReady(Map<String, dynamic> p) {
    final ArenaPlayer? pl = _known(p['u']);
    if (pl == null) return;
    pl.lastSeen = clock;
    pl.present = true;
    if (canPick) {
      if (p.containsKey('rd')) pl.ready = p['rd'] == true;
      final String w = (p['w'] ?? '').toString();
      if (darkomWeaponKinds.contains(w)) pl.pick = w;
    }
    if (p['go'] == true && (phase == ArPhase.lobby || phase == ArPhase.failed)) {
      final dynamic r = p['roster'];
      if (r is List) {
        final List<String> ids = <String>[];
        for (final dynamic e in r) {
          final String s = e.toString();
          if (players.containsKey(s) && !ids.contains(s)) ids.add(s);
        }
        ids.sort();
        if (ids.length >= 2 && ids.contains(myId) && ids.first == pl.id) {
          me.ready = true;
          _startMatch(ids);
        }
      }
    }
    version++;
  }

  void _onState(Map<String, dynamic> p) {
    final ArenaPlayer? pl = _known(p['u']);
    if (pl == null) return;
    pl.lastSeen = clock;
    if (!pl.inMatch || !(playing || phase == ArPhase.intermission)) return;
    final int rd = arInt(p['rd'], 0, 99, 0);
    if (rd != round) {
      if (rd > round && phase == ArPhase.fight) _forceConclude();
      return;
    }
    final double nx = arNum(p['x'], 0, kArW, pl.tx);
    final double ny = arNum(p['y'], 0, kArH, pl.ty);
    if (!pl.gotState) {
      pl.gotState = true;
      pl.stClock = clock;
      if (!map.circleHits(nx, ny, 10)) {
        pl.tx = nx;
        pl.ty = ny;
        pl.x = nx;
        pl.y = ny;
      }
    } else {
      final double dt = clock - pl.stClock;
      pl.stClock = clock;
      final double maxStep = 760 * (dt < 0.05 ? 0.05 : dt) + 50;
      double dx = nx - pl.tx;
      double dy = ny - pl.ty;
      final double dist = sqrt(dx * dx + dy * dy);
      if (dist > maxStep) {
        dx = dx / dist * maxStep;
        dy = dy / dist * maxStep;
      }
      final double px = pl.tx + dx;
      final double py = pl.ty + dy;
      if (!map.circleHits(px, py, 10)) {
        pl.tx = px;
        pl.ty = py;
      }
    }
    pl.stAge = 0;
    pl.tvx = arNum(p['vx'], -700, 700, 0);
    pl.tvy = arNum(p['vy'], -700, 700, 0);
    pl.aim = arNum(p['an'], -7, 7, pl.aim);
    pl.flags = arInt(p['f'], 0, 31, 0);
    final double hpIn = arNum(p['hp'], 0, kArHp, pl.hp);
    if (hpIn < pl.hp) pl.hp = hpIn;
    if (phase == ArPhase.countdown) {
      final String w = (p['w'] ?? '').toString();
      if (darkomWeaponKinds.contains(w)) pl.weapon = w;
    }
    if (pl.hp <= 0 && pl.alive && phase == ArPhase.fight) {
      _eliminate(pl, '');
      _checkRoundEnd();
    }
  }

  bool _rateOk(ArenaPlayer pl, String w, bool sp) {
    pl.tokens = min(7.0, pl.tokens + (clock - pl.tokClock) * 9);
    pl.tokClock = clock;
    if (pl.tokens < 1) return false;
    final DarkomWeaponDef d = darkomWeapon(w);
    double gap;
    if (sp) {
      gap = (w == 'dagger' ? min(d.scd, 2.5) : d.scd) * 0.8;
    } else if (w == 'dagger') {
      gap = 0.07;
    } else if (w == 'axe') {
      gap = 0.15;
    } else if (w == 'shield') {
      gap = 0.2;
    } else {
      gap = d.cd * 0.8;
    }
    final String key = sp ? '$w:s' : '$w:a';
    final double last = pl.lastAtk[key] ?? -99.0;
    if (clock - last < gap) return false;
    if (w == 'staff') {
      pl.mana = min(100.0, pl.mana + (clock - pl.manaClock) * 20);
      pl.manaClock = clock;
      final double cost = sp ? 30 : 13;
      if (pl.mana < cost - 10) return false;
      pl.mana -= cost;
    }
    pl.lastAtk[key] = clock;
    pl.tokens -= 1;
    return true;
  }

  void _onAtk(Map<String, dynamic> p) {
    final ArenaPlayer? pl = _known(p['u']);
    if (pl == null) return;
    pl.lastSeen = clock;
    if (phase != ArPhase.fight || !pl.inMatch || !pl.alive) return;
    if (arInt(p['rd'], 0, 99, -1) != round) return;
    final String w = (p['w'] ?? '').toString();
    if (w != pl.weapon || !darkomWeaponKinds.contains(w)) return;
    final bool sp = p['k'] == 's';
    String id = (p['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (id.length > 24) id = id.substring(0, 24);
    final String key = '${pl.id}|$id';
    if (_seenAtk.contains(key)) return;
    if (!_rateOk(pl, w, sp)) return;
    if (_seenAtk.length > 120) _seenAtk.clear();
    _seenAtk.add(key);
    double ox = arNum(p['x'], 0, kArW, pl.tx);
    double oy = arNum(p['y'], 0, kArH, pl.ty);
    if (!pl.gotState) {
      ox = pl.x;
      oy = pl.y;
    } else {
      final double ddx = ox - pl.tx;
      final double ddy = oy - pl.ty;
      if (ddx * ddx + ddy * ddy > 280 * 280) {
        ox = pl.tx;
        oy = pl.ty;
      }
    }
    final double an = arNum(p['an'], -7, 7, pl.aim);
    final double dist = arNum(p['d'], 0, 340, 0);
    pl.aim = an;
    this._applyAttack(pl, w, sp, id, ox, oy, an, dist);
  }

  void _onHit(Map<String, dynamic> p) {
    final ArenaPlayer? v = _known(p['u']);
    if (v == null) return;
    v.lastSeen = clock;
    if (!v.inMatch || phase != ArPhase.fight) return;
    final String by = (p['a'] ?? '').toString();
    final ArenaPlayer? a = players[by];
    double maxD = 60;
    if (a != null) {
      final DarkomWeaponDef d = darkomWeapon(a.weapon);
      maxD = max(d.dmg, d.sdmg) * 1.1 + 2;
    }
    final double dmg = arNum(p['d'], 0, maxD, 0);
    final double hpIn = arNum(p['hp'], 0, kArHp, v.hp);
    if (hpIn < v.hp) v.hp = hpIn;
    v.flash = 0.2;
    final bool blk = p['b'] == true;
    this._text(v.x, v.y - 34, blk ? 'BLOCK' : dmg.round().toString(), blk ? const Color(0xFF80D8FF) : const Color(0xFFFFFFFF), size: blk ? 13 : 15);
    this._spark(v.x, v.y, blk ? const Color(0xFF80D8FF) : const Color(0xFFFF5252), n: 5, spd: 150);
    if (a != null && identical(a, me)) {
      this._text(me.x, me.y - 52, blk ? 'blocked' : 'HIT', const Color(0xFFFFD54F), size: 12);
    }
    if (v.hp <= 0 && v.alive) {
      _eliminate(v, by);
      _checkRoundEnd();
    }
  }

  void _onRound(Map<String, dynamic> p) {
    final ArenaPlayer? s = _known(p['u']);
    if (s == null) return;
    s.lastSeen = clock;
    if (phase != ArPhase.fight || arInt(p['r'], 0, 99, -1) != round) return;
    final String loser = (p['loser'] ?? '').toString();
    if (loser.isNotEmpty) {
      final ArenaPlayer? lp = players[loser];
      if (lp != null && !identical(lp, me) && lp.inMatch && lp.alive) {
        // Confirm against what we saw: they must already be badly hurt, or silent.
        if (lp.hp <= 60 || clock - lp.lastSeen > 3) {
          _eliminate(lp, (p['by'] ?? '').toString());
          _checkRoundEnd();
        }
      }
    }
    final String win = (p['win'] ?? '').toString();
    if (win.isNotEmpty && phase == ArPhase.fight) {
      final ArenaPlayer? wp = players[win];
      if (wp == null || !wp.inMatch) return;
      bool all = true;
      for (final ArenaPlayer o in roster) {
        if (identical(o, wp)) continue;
        if (identical(o, me)) {
          if (o.alive) {
            all = false;
            break;
          }
          continue;
        }
        if (o.alive && o.hp > 60) {
          all = false;
          break;
        }
      }
      if (all) {
        for (final ArenaPlayer o in roster) {
          if (!identical(o, wp) && !identical(o, me) && o.alive) _eliminate(o, win);
        }
        _checkRoundEnd();
      }
    }
  }

  void _forceConclude() {
    ArenaPlayer? best;
    for (final ArenaPlayer p in roster) {
      if (!p.alive) continue;
      if (best == null || p.hp > best.hp) best = p;
    }
    for (final ArenaPlayer p in roster) {
      if (!identical(p, best) && p.alive) _eliminate(p, '');
    }
    _concludeRound(best, announce: false);
  }

  // ---- update -------------------------------------------------------------

  void update(double dt) {
    if (dt > 0.1) dt = 0.1;
    clock += dt;
    if (bannerT > 0) bannerT -= dt;
    if (emoteCd > 0) emoteCd -= dt;
    if (goResendLeft > 0) {
      // The start signal is sent a few more times in case the other side was slow to listen.
      goT -= dt;
      if (goT <= 0) {
        goT = 0.8;
        goResendLeft--;
        _send('ready', <String, dynamic>{'u': myId, 'rd': true, 'w': chosen, 'go': true, 'roster': goRoster});
      }
    }
    switch (phase) {
      case ArPhase.lobby:
        _lobbyTick(dt);
        break;
      case ArPhase.failed:
        _failedTick();
        break;
      case ArPhase.countdown:
        phaseT -= dt;
        if (phaseT <= 0) _beginFight();
        _sendStateTick(dt, 0.25);
        break;
      case ArPhase.fight:
        _fightTick(dt);
        break;
      case ArPhase.intermission:
        phaseT -= dt;
        _sendStateTick(dt, 0.25);
        _staleTick(dt);
        if (phaseT <= 0) _beginRound();
        break;
      case ArPhase.over:
        break;
    }
    _updateRemotes(dt);
    _updateFxLists(dt);
    if (phase == ArPhase.fight || phase == ArPhase.countdown || phase == ArPhase.intermission || phase == ArPhase.over) _updateCamera(dt);
  }

  void _lobbyTick(double dt) {
    lobbyT += dt;
    for (final ArenaPlayer p in players.values) {
      if (identical(p, me)) continue;
      if (!p.present) p.absentT += dt;
    }
    final List<ArenaPlayer> here = lobbyPlayers;
    if (here.length >= 2 && here.every((ArenaPlayer p) => p.ready)) {
      final bool expectedAll = args.playerIds.every((String id) => id == myId || (players[id]?.present ?? false));
      if (isDuel || expectedAll || lobbyT >= kArLobbyWait) {
        if (here.first.id == myId) {
          final List<String> ids = here.map((ArenaPlayer p) => p.id).toList();
          _send('ready', <String, dynamic>{'u': myId, 'rd': true, 'w': chosen, 'go': true, 'roster': ids});
          goRoster = ids;
          goResendLeft = 4;
          goT = 0.8;
          _startMatch(ids);
          return;
        }
      }
    }
    if (lobbyT >= kArLobbyWait && here.length < 2) {
      phase = ArPhase.failed;
      failText = isDuel ? 'Opponent did not arrive' : 'Nobody else arrived';
      version++;
    }
  }

  void _failedTick() {
    if (lobbyPlayers.length >= 2) {
      phase = ArPhase.lobby;
      lobbyT = 0;
      version++;
    }
  }

  void _sendStateTick(double dt, double every) {
    stSend += dt;
    if (stSend >= every) {
      stSend = 0;
      sendState();
    }
  }

  void _staleTick(double dt) {
    for (final ArenaPlayer p in roster) {
      if (identical(p, me)) continue;
      if (!p.present) {
        p.absentT += dt;
      } else {
        p.absentT = 0;
      }
      final bool gone = clock - p.lastSeen > kArStale;
      if (gone && p.alive && phase == ArPhase.fight) {
        this._text(p.x, p.y - 40, 'Left the match', const Color(0xFFFFD54F), size: 12);
        _eliminate(p, '');
        _checkRoundEnd();
      }
    }
    if (phase == ArPhase.intermission) {
      // Everyone else is gone while we wait: the match is over.
      bool allGone = true;
      for (final ArenaPlayer p in roster) {
        if (identical(p, me)) continue;
        if (clock - p.lastSeen <= kArStale) {
          allGone = false;
          break;
        }
      }
      if (allGone && roster.length > 1) {
        for (final ArenaPlayer p in roster) {
          if (!identical(p, me)) p.alive = false;
        }
        for (final ArenaPlayer p in roster) {
          if (identical(p, me)) p.wins = max(p.wins, kArWinsNeeded);
        }
        _finish();
      }
    }
  }

  void _fightTick(double dt) {
    roundT += dt;
    _sendStateTick(dt, 0.1);
    _updateMe(dt);
    _updateProjs(dt);
    _updatePend(dt);
    _staleTick(dt);
    if (resendLeft > 0 && !me.alive) {
      roundResend -= dt;
      if (roundResend <= 0) {
        roundResend = 1.0;
        resendLeft--;
        this._sendRound(lastHitBy);
      }
    }
    // The grid overloads when a round drags on, so nobody can stall.
    if (roundT > kArOverloadAt && me.alive) {
      if (!overloadWarned) {
        overloadWarned = true;
        banner = 'GRID OVERLOAD';
        bannerT = 2;
      }
      me.hp -= 4 * dt;
      if (me.hp <= 0) {
        me.hp = 0;
        this._killMe('');
      }
    }
    _checkRoundEnd();
  }

  void _updateMe(double dt) {
    final ArenaPlayer m = me;
    if (invuln > 0) invuln -= dt;
    if (hitFlash > 0) hitFlash -= dt;
    if (atkCd > 0) atkCd -= dt;
    if (specCd > 0) specCd -= dt;
    if (dashCd > 0) dashCd -= dt;
    if (aimLock > 0) aimLock -= dt;
    if (stunT > 0) stunT -= dt;
    if (noManaT > 0) noManaT -= dt;
    if (shake > 0) {
      shake -= dt * 30;
      if (shake < 0) shake = 0;
    }
    if (manaPause > 0) {
      manaPause -= dt;
    } else if (mana < 100) {
      mana += (m.weapon == 'staff' ? 20 : 8) * dt;
      if (mana > 100) mana = 100;
    }
    if (!m.alive) {
      m.vx = 0;
      m.vy = 0;
      m.moving = false;
      return;
    }
    final double imag = sqrt(inX * inX + inY * inY);
    m.moving = imag > 0.12 && stunT <= 0;
    double vx = 0;
    double vy = 0;
    double sp = 190;
    if (slamT > 0) sp *= 0.3;
    if (guard > 0) sp *= 0.6;
    if (flurry > 0) sp *= 0.7;
    if (dashT > 0) {
      vx = dashVx;
      vy = dashVy;
      dashT -= dt;
    } else if (chargeT > 0) {
      vx = chargeVx;
      vy = chargeVy;
      chargeT -= dt;
    } else if (m.moving) {
      vx = inX * sp;
      vy = inY * sp;
      if (aimLock <= 0) face = atan2(inY, inX);
    }
    final double c = cos(face);
    if (c > 0.25) {
      m.face = 1;
    } else if (c < -0.25) {
      m.face = -1;
    }
    vx += kvx;
    vy += kvy;
    final double dec = exp(-9 * dt);
    kvx *= dec;
    kvy *= dec;
    final Offset np = map.move(m.x, m.y, vx * dt, vy * dt, kArR);
    m.x = np.dx;
    m.y = np.dy;
    m.vx = vx;
    m.vy = vy;
    m.aim = face;
    m.phase += sqrt(vx * vx + vy * vy) * dt * 0.055;
    // guard window, dagger flurry and hammer wind up
    if (guard > 0) {
      guard -= dt;
      guardAge += dt;
      if (guard <= 0) {
        guard = 0;
        if (atkCd < 0.35) {
          atkCd = 0.35;
          atkCdMax = 0.35;
        }
      }
    }
    if (slamT > 0) slamT -= dt;
    if (flurry > 0) {
      flurryT -= dt;
      if (flurryT <= 0) {
        this._daggerStab();
        flurry -= 1;
        flurryT = 0.13;
        if (flurry <= 0) {
          flurry = 0;
          atkCd = 0.32;
          atkCdMax = 0.32;
        }
      }
    }
  }

  void _updateRemotes(double dt) {
    for (final ArenaPlayer p in players.values) {
      if (p.swingT >= 0) {
        p.swingT += dt;
        if (p.swingT > p.swingDur) p.swingT = -1;
      }
      if (p.flash > 0) p.flash -= dt;
      if (p.emoteT > 0) p.emoteT -= dt;
      if (identical(p, me) || !p.inMatch || !p.gotState) continue;
      p.stAge += dt;
      final double age = p.stAge > 0.25 ? 0.25 : p.stAge;
      final double gx = p.tx + p.tvx * age;
      final double gy = p.ty + p.tvy * age;
      final double k = dt * 14 > 1 ? 1.0 : dt * 14;
      final double nx = p.x + (gx - p.x) * k;
      final double ny = p.y + (gy - p.y) * k;
      p.moving = p.tvx * p.tvx + p.tvy * p.tvy > 400 && (p.flags & 16) == 0;
      p.phase += sqrt((nx - p.x) * (nx - p.x) + (ny - p.y) * (ny - p.y)) * 0.055;
      p.x = nx;
      p.y = ny;
      final double c = cos(p.aim);
      if (c > 0.25) {
        p.face = 1;
      } else if (c < -0.25) {
        p.face = -1;
      }
    }
  }

  void _updateProjs(double dt) {
    final ArenaPlayer m = me;
    for (final ArProj b in projs) {
      if (b.dead) continue;
      b.life -= dt;
      final int steps = 2;
      for (int s = 0; s < steps && !b.dead; s++) {
        b.x += b.vx * dt / steps;
        b.y += b.vy * dt / steps;
        if (map.wallAt(b.x, b.y, b.r * 0.5)) {
          b.dead = true;
          this._spark(b.x, b.y, const Color(0xFFB39DDB), n: 3, spd: 90, life: 0.25);
          break;
        }
        if (b.owner != myId && m.alive) {
          final double dx = m.x - b.x;
          final double dy = m.y - b.y;
          final double rr = kArR + b.r + 4;
          if (dx * dx + dy * dy < rr * rr) {
            if (this._hitMe(b.owner, 'b${b.hashCode}', b.dmg, b.x - b.vx * 0.05, b.y - b.vy * 0.05, 90, 0)) {
              b.dead = true;
              break;
            }
          }
        }
        for (final ArenaPlayer p in roster) {
          if (p.id == b.owner || identical(p, m) || !p.alive) continue;
          final double dx = p.x - b.x;
          final double dy = p.y - b.y;
          if (dx * dx + dy * dy < (kArR + b.r) * (kArR + b.r)) {
            b.dead = true;
            this._spark(b.x, b.y, const Color(0xFFFFFFFF), n: 3, spd: 100, life: 0.25);
            break;
          }
        }
      }
      if (b.life <= 0) b.dead = true;
    }
    projs.removeWhere((ArProj b) => b.dead);

    for (final ArAxe a in axes) {
      if (a.dead) continue;
      a.life -= dt;
      a.spin += dt * 20;
      final ArenaPlayer? o = players[a.owner];
      if (a.out) {
        final double stepD = 520 * dt;
        a.x += a.dx * stepD;
        a.y += a.dy * stepD;
        a.dist += stepD;
        if (a.dist >= a.maxDist || map.wallAt(a.x, a.y, 4)) a.out = false;
      } else {
        if (o == null) {
          a.dead = true;
          continue;
        }
        double tx = o.x - a.x;
        double ty = o.y - a.y;
        final double len = sqrt(tx * tx + ty * ty);
        if (len < 24) {
          a.dead = true;
          continue;
        }
        tx /= len;
        ty /= len;
        a.dx = tx;
        a.dy = ty;
        a.x += tx * 520 * dt;
        a.y += ty * 520 * dt;
        if (map.wallAt(a.x, a.y, 4)) {
          a.dead = true;
          continue;
        }
      }
      if (a.owner != myId && m.alive) {
        final double dx = m.x - a.x;
        final double dy = m.y - a.y;
        final double rr = kArR + 12 + 6;
        if (dx * dx + dy * dy < rr * rr) {
          final bool already = a.out ? a.hitOut : a.hitBack;
          if (!already) {
            if (this._hitMe(a.owner, '${a.id}${a.out ? 'o' : 'r'}', a.dmg, a.x, a.y, 120, 0)) {
              if (a.out) {
                a.hitOut = true;
              } else {
                a.hitBack = true;
              }
            }
          }
        }
      }
      if (a.life <= 0) a.dead = true;
    }
    axes.removeWhere((ArAxe a) => a.dead);

    for (final ArCharge c in charges) {
      c.t -= dt;
      final ArenaPlayer? o = players[c.owner];
      if (o == null || !o.alive) {
        c.t = -1;
        continue;
      }
      if (!c.hit && m.alive) {
        final double dx = m.x - o.x;
        final double dy = m.y - o.y;
        if (dx * dx + dy * dy < (kArR + 30) * (kArR + 30)) {
          final DarkomWeaponDef d = darkomWeapon('shield');
          if (this._hitMe(c.owner, c.id, d.sdmg, o.x - dx * 0.2, o.y - dy * 0.2, 400, 0.8)) {
            c.hit = true;
          }
        }
      }
    }
    charges.removeWhere((ArCharge c) => c.t <= 0);
  }

  void _updatePend(double dt) {
    for (int i = pend.length - 1; i >= 0; i--) {
      final ArPending p = pend[i];
      p.t -= dt;
      if (p.t > 0) continue;
      pend.removeAt(i);
      final ArenaPlayer? o = players[p.owner];
      if (o == null || !o.alive) continue;
      if (!this._inShape(p)) continue;
      this._hitMe(p.owner, p.id, p.dmg, p.ox, p.oy, p.kb, p.stun);
    }
  }

  void _updateFxLists(double dt) {
    for (int i = fx.length - 1; i >= 0; i--) {
      final ArFx f = fx[i];
      if (f.delay > 0) {
        f.delay -= dt;
        continue;
      }
      f.life -= dt;
      if (f.life <= 0) fx.removeAt(i);
    }
    for (int i = parts.length - 1; i >= 0; i--) {
      final ArPart p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final double dec = exp(-4 * dt);
      p.vx *= dec;
      p.vy *= dec;
    }
    for (int i = texts.length - 1; i >= 0; i--) {
      final ArText t = texts[i];
      t.life -= dt;
      t.y -= 30 * dt;
      if (t.life <= 0) texts.removeAt(i);
    }
  }

  void _updateCamera(double dt) {
    double tx = me.x;
    double ty = me.y;
    if (!me.alive) {
      for (final ArenaPlayer p in roster) {
        if (p.alive) {
          tx = p.x;
          ty = p.y;
          break;
        }
      }
    }
    final double k = dt * 9 > 1 ? 1.0 : dt * 9;
    camX += (tx - camX) * k;
    camY += (ty - camY) * k;
  }
}
