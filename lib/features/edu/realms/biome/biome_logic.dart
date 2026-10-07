import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';

double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
int _ci(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

const List<String> _biPre = <String>['Zor', 'Pim', 'Kyr', 'Bru', 'Fen', 'Gli', 'Mox', 'Tarn', 'Nib', 'Vel', 'Sko', 'Dru', 'Wex', 'Ola', 'Hob', 'Quin'];
const List<String> _biMid = <String>['a', 'o', 'i', 'u', 'e', 'ar', 'en', 'il', 'or'];
const List<String> _biSuf = <String>['bit', 'ling', 'ox', 'le', 'ra', 'zap', 'ium', 'kit', 'ent', 'ba', 'nus'];

const Map<String, String> _biStarters = <String, String>{
  'math': 'Sumkit',
  'physics': 'Sparkit',
  'chemistry': 'Fizzle',
  'biology': 'Sproutle',
  'english': 'Quillo',
  'geography': 'Terrox',
  'history': 'Relicub',
  'economics': 'Coinkit',
  'civics': 'Civvy',
  'coding': 'Bitling',
  'logic': 'Puzzlin',
  'bst': 'Atomu',
};

const List<String> _biStory = <String>[
  'The echo fades into a quiet breeze.',
  'A forgotten lesson finds its way home.',
  'The biome grows a little brighter.',
  'Another echo is at peace.',
  'Keeper, the wild is listening to you.',
];

/// One creature, wild or tamed. Shapes: 0 blob, 1 horned, 2 winged, 3 spiked.
class BiomeCreature {
  final String name;
  final String subjectId;
  final int shape;
  final int seed;
  final Color color;
  final bool elder;
  final double hpMul;
  int level;
  int xp = 0;
  int hp;
  int maxHp;
  double x;
  double y;
  int behavior; // 0 calm, 1 flee, 2 chase
  double wanderT = 0;
  double heading = 0;
  double wspeed = 0;
  double phase = 0;
  double facing = 1;
  bool moving = false;
  bool inBattle = false;

  BiomeCreature({
    required this.name,
    required this.subjectId,
    required this.shape,
    required this.seed,
    required this.color,
    required this.level,
    required this.hp,
    required this.maxHp,
    this.elder = false,
    this.hpMul = 1.0,
    this.x = 0,
    this.y = 0,
    this.behavior = 0,
  });

  static int maxHpFor(int level, double mul) => ((22 + level * 6) * mul).round();

  int get power => 6 + level * 2;
  int get xpToNext => 18 + level * 12;
  double get hpFrac => maxHp <= 0 ? 0.0 : hp / maxHp;
  bool get fainted => hp <= 0;
}

class BiomePickup {
  final int type; // 0 orb, 1 coin, 2 campfire
  final double x;
  final double y;
  final double phase;
  BiomePickup(this.type, this.x, this.y, this.phase);
}

/// State of one battle. Phases: 0 menu, 1 question, 2 answered, 3 info.
class BiomeBattle {
  final BiomeCreature wild;
  int phase = 0;
  int mode = 0; // 0 fight, 1 tame
  OdyQuestion? question;
  int? chosen;
  String log = '';
  String resultLine = '';
  int outcome = 0; // 0 ongoing, 1 won, 2 tamed, 3 ran, 4 blackout
  double questionAt = 0;
  double wildFlash = 0;
  double myFlash = 0;
  double lunge = 0;
  int lungeWho = 0; // 1 player creature, 2 wild
  double popT = 0;
  String popText = '';
  int popWho = 0;
  double tameT = 0;
  bool tameOk = false;
  BiomeBattle(this.wild);
}

class BiomeLogic extends RealmLogic {
  static const double speed = 170;
  static const double touchDist = 38;
  static const double startX = 800;
  static const double startY = 800;
  static const int maxTeam = 3;

  double px = startX;
  double py = startY;
  double facing = 1;
  double walkPhase = 0;
  bool moving = false;
  double fx = startX - 30;
  double fy = startY + 6;

  final List<BiomeCreature> team = <BiomeCreature>[];
  int activeIdx = 0;
  final List<BiomeCreature> wilds = <BiomeCreature>[];
  final List<BiomePickup> pickups = <BiomePickup>[];
  BiomeBattle? battle;

  int orbs = 2;
  int coins = 0;
  int tamed = 0;
  int battlesWon = 0;
  int eldersCalmed = 0;
  int eldersMet = 0;
  double maxDist = 0;

  String toast = '';
  double toastT = 0;

  double _spawnT = 0;
  double _pickT = 0;
  double _campT = 0;
  double _touchCd = 1.0;
  double _regenT = 0;
  int _curRegion = -1;
  int _storyN = 0;

  BiomeLogic(RealmContent content) : super(content) {
    final String sid = content.subjectIds.isEmpty ? 'math' : content.subjectIds[0];
    team.add(_makeCreature(sid, _biStarters[sid] ?? _genName(), 2, 0, 0, false));
    _toast('Wild echoes roam these lands. Find one and answer to fight.');
    _addWild(startX + 260, startY - 90, false);
    _addWild(startX - 190, startY + 280, false);
  }

  // ---- queries ----------------------------------------------------------------

  BiomeCreature get active => team[activeIdx];

  int get teamLevelSum {
    int s = 0;
    for (final BiomeCreature c in team) {
      s += c.level;
    }
    return s;
  }

  int get teamHp {
    int s = 0;
    for (final BiomeCreature c in team) {
      s += c.hp;
    }
    return s;
  }

  int get teamMaxHp {
    int s = 0;
    for (final BiomeCreature c in team) {
      s += c.maxHp;
    }
    return s;
  }

  bool get _teamHurt {
    for (final BiomeCreature c in team) {
      if (c.hp < c.maxHp) return true;
    }
    return false;
  }

  int regionIndexAt(double x, double y) {
    final int n = content.subjectIds.length;
    if (n <= 1) return 0;
    final double wx = x + sin(y * 0.0035) * 220;
    final double wy = y + sin(x * 0.0031 + 1.7) * 220;
    final int cx = (wx / 1500).floor();
    final int cy = (wy / 1500).floor();
    if (cx == 0 && cy == 0) return 0;
    return realmHash(cx, cy, content.seed) % n;
  }

  String subjectAt(double x, double y) {
    if (content.subjectIds.isEmpty) return 'math';
    return content.subjectIds[regionIndexAt(x, y)];
  }

  double distFromStart(double x, double y) {
    final double dx = x - startX;
    final double dy = y - startY;
    return sqrt(dx * dx + dy * dy);
  }

  // ---- RealmLogic -------------------------------------------------------------

  @override
  bool get modal => battle != null;

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('HP $teamHp/$teamMaxHp', Icons.favorite_rounded, const Color(0xFFFF5252)),
        RealmChip('$orbs', Icons.catching_pokemon, const Color(0xFFB388FF)),
        RealmChip('$tamed', Icons.pets_rounded, const Color(0xFF69F0AE)),
        RealmChip('$coins', Icons.monetization_on_rounded, const Color(0xFFFFD54F)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Tamed': '$tamed',
        'Battles won': '$battlesWon',
        'Team level': '$teamLevelSum',
      };

  @override
  int get finalScore {
    final int acc = stats.asked >= 6 ? (stats.accuracy * 60).round() : 0;
    return tamed * 200 + battlesWon * 60 + teamLevelSum * 25 + coins + acc + stats.bestStreak * 4;
  }

  @override
  int get xp => stats.baseXp + tamed * 5;

  void _toast(String s) {
    toast = s;
    toastT = 3.4;
  }

  // ---- creatures --------------------------------------------------------------

  String _genName() {
    return _biPre[rng.nextInt(_biPre.length)] + _biMid[rng.nextInt(_biMid.length)] + _biSuf[rng.nextInt(_biSuf.length)];
  }

  BiomeCreature _makeCreature(String sid, String name, int level, int shapeIn, double x, bool elder) {
    final int seed = rng.nextInt(1 << 20);
    final int shape = shapeIn >= 0 ? shapeIn : rng.nextInt(4);
    final Color base = content.subject(sid).color;
    final double tweak = (seed % 5) * 0.025;
    final Color col = realmLighten(base, 0.14 + tweak);
    final double mul = elder ? 1.4 : 1.0;
    final int mhp = BiomeCreature.maxHpFor(level, mul);
    return BiomeCreature(
      name: name,
      subjectId: sid,
      shape: shape,
      seed: seed,
      color: col,
      level: level,
      hp: mhp,
      maxHp: mhp,
      elder: elder,
      hpMul: mul,
    );
  }

  int _wildLevel(double dist, bool elder) {
    final int avg = team.isEmpty ? 1 : teamLevelSum ~/ team.length;
    int lvl = 1 + (dist / 700).floor() + (avg - 1) ~/ 2 + rng.nextInt(3) - 1;
    if (elder) lvl += 4;
    return _ci(lvl, 1, 60);
  }

  void _addWild(double x, double y, bool elder) {
    final String sid = subjectAt(x, y);
    final int lvl = _wildLevel(distFromStart(x, y), elder);
    final String base = _genName();
    final BiomeCreature w = _makeCreature(sid, elder ? 'Elder $base' : base, lvl, -1, x, elder);
    w.x = x;
    w.y = y;
    if (elder) {
      w.behavior = 2;
    } else {
      final double r = rng.nextDouble();
      w.behavior = r < 0.5 ? 0 : (r < 0.75 ? 1 : 2);
    }
    w.heading = rng.nextDouble() * pi * 2;
    wilds.add(w);
  }

  void _spawnWildRing(bool elder) {
    final double ang = rng.nextDouble() * pi * 2;
    final double d = 520 + rng.nextDouble() * 260;
    _addWild(px + cos(ang) * d, py + sin(ang) * d, elder);
  }

  void _spawnPickup(int type, double minD, double maxD) {
    final double ang = rng.nextDouble() * pi * 2;
    final double d = minD + rng.nextDouble() * (maxD - minD);
    pickups.add(BiomePickup(type, px + cos(ang) * d, py + sin(ang) * d, rng.nextDouble() * 6));
  }

  bool _giveXp(BiomeCreature c, int amt) {
    bool up = false;
    c.xp += amt;
    while (c.level < 50 && c.xp >= c.xpToNext) {
      c.xp -= c.xpToNext;
      c.level++;
      final int old = c.maxHp;
      c.maxHp = BiomeCreature.maxHpFor(c.level, c.hpMul);
      if (c.hp > 0) {
        c.hp = _ci(c.hp + (c.maxHp - old) + 4, 0, c.maxHp);
      }
      up = true;
    }
    return up;
  }

  // ---- world step -------------------------------------------------------------

  @override
  void step(double dt) {
    if (over) return;
    if (toastT > 0) toastT -= dt;
    final BiomeBattle? b = battle;
    if (b != null) {
      _stepBattleAnim(b, dt);
      return;
    }
    if (_touchCd > 0) _touchCd -= dt;

    // player
    final double mag = sqrt(inputX * inputX + inputY * inputY);
    moving = mag > 0.05;
    if (moving) {
      px += inputX * speed * dt;
      py += inputY * speed * dt;
      walkPhase += dt * 10;
      if (inputX.abs() > 0.1) facing = inputX > 0 ? 1.0 : -1.0;
    }
    final double fk = _cl(dt * 4.5, 0, 1);
    fx += (px - facing * 34 - fx) * fk;
    fy += (py + 8 - fy) * fk;
    final double dd = distFromStart(px, py);
    if (dd > maxDist) maxDist = dd;

    final int reg = regionIndexAt(px, py);
    if (reg != _curRegion) {
      if (_curRegion >= 0 && content.subjectIds.length > 1) {
        _toast('You enter the ${content.subject(content.subjectIds[reg]).label} biome.');
      }
      _curRegion = reg;
    }

    // slow recovery while exploring
    _regenT += dt;
    if (_regenT >= 3) {
      _regenT -= 3;
      for (final BiomeCreature c in team) {
        if (c.hp > 0 && c.hp < c.maxHp) c.hp++;
      }
    }

    _stepWilds(dt);
    _stepPickups(dt);
    if (over || battle != null) return;

    // touching a wild creature opens a battle
    if (_touchCd <= 0) {
      for (final BiomeCreature w in wilds) {
        if (w.inBattle) continue;
        final double dx = w.x - px;
        final double dy = w.y - py;
        if (dx * dx + dy * dy < touchDist * touchDist) {
          _startBattle(w);
          break;
        }
      }
    }
  }

  void _stepWilds(double dt) {
    // spawn
    _spawnT -= dt;
    bool hasElder = false;
    for (final BiomeCreature w in wilds) {
      if (w.elder) hasElder = true;
    }
    if (_spawnT <= 0) {
      _spawnT = 1.8;
      if (!hasElder && maxDist >= 1400 + 1800.0 * eldersMet) {
        _spawnWildRing(true);
      } else if (wilds.length < 6) {
        _spawnWildRing(false);
      }
    }
    // despawn far away and move
    for (int i = wilds.length - 1; i >= 0; i--) {
      final BiomeCreature w = wilds[i];
      if (w.inBattle) continue;
      final double dx = px - w.x;
      final double dy = py - w.y;
      final double d = sqrt(dx * dx + dy * dy);
      if (d > (w.elder ? 1600 : 1100)) {
        wilds.removeAt(i);
        continue;
      }
      w.wanderT -= dt;
      if (w.wanderT <= 0) {
        w.wanderT = 1.5 + rng.nextDouble() * 2.5;
        w.heading = rng.nextDouble() * pi * 2;
        w.wspeed = rng.nextDouble() < 0.35 ? 0.0 : 20 + rng.nextDouble() * 30;
      }
      double vx = 0;
      double vy = 0;
      if (w.behavior == 1 && d < 240 && d > 0.01) {
        vx = -dx / d * 120;
        vy = -dy / d * 120;
      } else if (w.behavior == 2 && d < 320 && d > 0.01) {
        final double sp = w.elder ? 95.0 : 72.0;
        vx = dx / d * sp;
        vy = dy / d * sp;
      } else {
        vx = cos(w.heading) * w.wspeed;
        vy = sin(w.heading) * w.wspeed;
      }
      w.x += vx * dt;
      w.y += vy * dt;
      final double sp2 = sqrt(vx * vx + vy * vy);
      w.moving = sp2 > 1;
      if (vx.abs() > 3) w.facing = vx > 0 ? 1.0 : -1.0;
      w.phase += dt * (2.5 + sp2 / 18);
    }
  }

  void _stepPickups(double dt) {
    bool hasCamp = false;
    int orbCount = 0;
    int others = 0;
    for (final BiomePickup p in pickups) {
      if (p.type == 2) hasCamp = true;
      if (p.type == 0) orbCount++;
      if (p.type != 2) others++;
    }
    _pickT -= dt;
    if (_pickT <= 0) {
      _pickT = 0.9;
      if (others < 5) {
        final bool wantOrb = orbCount < 2 && rng.nextDouble() < 0.25;
        _spawnPickup(wantOrb ? 0 : 1, 280, 650);
      }
    }
    if (!hasCamp) {
      _campT -= dt;
      if (_campT <= 0) {
        _spawnPickup(2, 350, 700);
        _campT = 45;
      }
    }
    for (int i = pickups.length - 1; i >= 0; i--) {
      final BiomePickup p = pickups[i];
      final double dx = p.x - px;
      final double dy = p.y - py;
      final double d2 = dx * dx + dy * dy;
      if (d2 > 1300 * 1300) {
        pickups.removeAt(i);
        continue;
      }
      if (d2 > 36 * 36) continue;
      if (p.type == 0) {
        orbs = _ci(orbs + 1, 0, 9);
        cues.add('tap');
        _toast('You found a taming orb.');
        pickups.removeAt(i);
      } else if (p.type == 1) {
        coins += 2;
        cues.add('tap');
        pickups.removeAt(i);
      } else {
        if (_teamHurt) {
          for (final BiomeCreature c in team) {
            c.hp = c.maxHp;
          }
          if (active.fainted) activeIdx = 0;
          cues.add('good');
          _toast('The campfire warms your whole team. Everyone is fully healed.');
          pickups.removeAt(i);
          _campT = 45;
        } else if (toastT <= 0) {
          _toast('Your team is already rested. Save the fire for later.');
        }
      }
    }
  }

  // ---- battle -----------------------------------------------------------------

  void _startBattle(BiomeCreature w) {
    inputX = 0;
    inputY = 0;
    moving = false;
    w.inBattle = true;
    final BiomeBattle b = BiomeBattle(w);
    b.log = 'A wild ${w.name} (level ${w.level}) blocks your path. What will ${active.name} do?';
    if (w.elder) {
      eldersMet++;
      final String lab = content.subject(w.subjectId).label;
      b.log = 'The Elder of the $lab biome rises. Its echo is old and strong. What will ${active.name} do?';
      _toast('An Elder echo has found you.');
    }
    battle = b;
  }

  void _stepBattleAnim(BiomeBattle b, double dt) {
    if (b.wildFlash > 0) b.wildFlash -= dt;
    if (b.myFlash > 0) b.myFlash -= dt;
    if (b.lunge > 0) b.lunge -= dt;
    if (b.popT > 0) b.popT -= dt;
    if (b.tameT > 0) b.tameT -= dt;
  }

  void _askQuestion(BiomeBattle b) {
    b.question = content.ask(b.wild.subjectId);
    b.chosen = null;
    b.resultLine = '';
    b.phase = 1;
    b.questionAt = time;
  }

  void battleFight() {
    final BiomeBattle? b = battle;
    if (b == null || over || b.phase != 0) return;
    b.mode = 0;
    _askQuestion(b);
  }

  void battleTame() {
    final BiomeBattle? b = battle;
    if (b == null || over || b.phase != 0) return;
    if (orbs <= 0) {
      b.log = 'You have no taming orbs. Look for glowing orbs in the wild.';
      return;
    }
    orbs--;
    b.mode = 1;
    _askQuestion(b);
  }

  void battleRun() {
    final BiomeBattle? b = battle;
    if (b == null || over || b.phase != 0) return;
    b.phase = 3;
    if (rng.nextDouble() < 0.6) {
      b.outcome = 3;
      b.log = 'You slip away from ${b.wild.name}.';
      wilds.remove(b.wild);
    } else {
      b.log = 'You could not get away. ${_wildStrike(b)}';
    }
  }

  void battleAnswer(int i) {
    final BiomeBattle? b = battle;
    final OdyQuestion? q = b == null ? null : b.question;
    if (b == null || q == null || over || b.phase != 1) return;
    if (i < 0 || i >= q.options.length) return;
    final bool ok = i == q.answerIndex;
    stats.record(q, ok, chosen: q.options[i]);
    b.chosen = i;
    b.phase = 2;
    cues.add(ok ? 'good' : 'bad');
    final BiomeCreature me = active;
    final BiomeCreature w = b.wild;
    if (b.mode == 0) {
      if (ok) {
        final bool fast = time - b.questionAt <= 5.0;
        final int streakBonus = stats.streak > 1 ? (stats.streak - 1 > 5 ? 5 : stats.streak - 1) * 2 : 0;
        int dmg = me.power + streakBonus;
        if (fast) dmg = (dmg * 1.5).round();
        if (dmg < 1) dmg = 1;
        w.hp = _ci(w.hp - dmg, 0, w.maxHp);
        b.wildFlash = 0.45;
        b.lunge = 0.5;
        b.lungeWho = 1;
        b.popT = 0.9;
        b.popWho = 2;
        b.popText = '-$dmg';
        if (w.hp <= 0) {
          _winBattle(b, 'Correct! ${me.name} lands the final blow${fast ? ' with a quick strike' : ''}.');
        } else {
          b.resultLine = 'Correct! ${me.name} hits for $dmg.${fast ? ' Quick strike!' : ''}';
        }
      } else {
        b.resultLine = 'Wrong. The right answer is ${q.answer}. ${_wildStrike(b)}';
      }
    } else {
      b.tameT = 1.6;
      if (ok && w.hpFrac <= 0.5) {
        b.tameOk = true;
        _tameSuccess(b);
      } else if (ok) {
        b.tameOk = false;
        b.resultLine = 'Correct, but ${w.name} is still too strong to tame. The orb is lost. Weaken it first.';
      } else {
        b.tameOk = false;
        b.resultLine = 'Wrong. The orb is lost. ${_wildStrike(b)}';
      }
    }
  }

  void battleContinue() {
    final BiomeBattle? b = battle;
    if (b == null) return;
    if (b.phase != 2 && b.phase != 3) return;
    if (b.outcome != 0) {
      b.wild.inBattle = false;
      battle = null;
      _touchCd = 1.2;
      return;
    }
    b.phase = 0;
    b.question = null;
    b.chosen = null;
    b.resultLine = '';
    b.log = 'What will ${active.name} do?';
  }

  /// The wild creature hits the active one. Returns a sentence about it.
  String _wildStrike(BiomeBattle b) {
    final BiomeCreature w = b.wild;
    final BiomeCreature me = active;
    int d = 3 + w.level * 2 + rng.nextInt(3);
    if (w.elder) d = (d * 1.25).round();
    me.hp = _ci(me.hp - d, 0, me.maxHp);
    b.myFlash = 0.45;
    b.lunge = 0.5;
    b.lungeWho = 2;
    b.popT = 0.9;
    b.popWho = 1;
    b.popText = '-$d';
    String msg = '${w.name} hits ${me.name} for $d.';
    if (me.hp <= 0) {
      msg += ' ${me.name} faints.';
      int next = -1;
      for (int i = 0; i < team.length; i++) {
        if (team[i].hp > 0) {
          next = i;
          break;
        }
      }
      if (next >= 0) {
        activeIdx = next;
        msg += ' ${team[next].name} steps in.';
      } else {
        b.outcome = 4;
        over = true;
        cues.add('lose');
        msg += ' Your whole team is out. The wild fades the world to black.';
      }
    }
    return msg;
  }

  void _winBattle(BiomeBattle b, String lead) {
    final BiomeCreature w = b.wild;
    battlesWon++;
    b.outcome = 1;
    int gain = 10 + w.level * 6;
    if (w.elder) gain *= 2;
    final BiomeCreature me = active;
    String ups = '';
    for (final BiomeCreature c in team) {
      if (c.hp <= 0) continue;
      final int amt = identical(c, me) ? gain : gain ~/ 2;
      if (_giveXp(c, amt)) ups += ' ${c.name} reached level ${c.level}!';
    }
    final int coinGain = w.elder ? 15 : 3;
    coins += coinGain;
    String drop = '';
    if (orbs < 9 && rng.nextDouble() < 0.3) {
      orbs++;
      drop = ' It dropped a taming orb.';
    }
    wilds.remove(w);
    String story = _biStory[_storyN % _biStory.length];
    _storyN++;
    if (w.elder) {
      eldersCalmed++;
      story = 'The Elder is calm. The ${content.subject(w.subjectId).label} biome is restored.';
      _toast(story);
    } else if (battlesWon == 1) {
      _toast('Your first echo is calmed. The Keeper path begins.');
    }
    cues.add('win');
    b.resultLine = '$lead +$gain XP, +$coinGain coins.$drop$ups $story';
  }

  void _tameSuccess(BiomeBattle b) {
    final BiomeCreature w = b.wild;
    tamed++;
    b.outcome = 2;
    wilds.remove(w);
    final BiomeCreature c = BiomeCreature(
      name: w.name,
      subjectId: w.subjectId,
      shape: w.shape,
      seed: w.seed,
      color: w.color,
      level: w.level,
      hp: w.maxHp,
      maxHp: w.maxHp,
      elder: w.elder,
      hpMul: w.hpMul,
    );
    String msg;
    if (team.length < maxTeam) {
      team.add(c);
      msg = 'The orb closes. ${w.name} joins your team at level ${w.level}!';
    } else {
      int wi = 0;
      for (int i = 1; i < team.length; i++) {
        if (team[i].level < team[wi].level) wi = i;
      }
      if (w.level > team[wi].level) {
        final String old = team[wi].name;
        team[wi] = c;
        if (team[activeIdx].fainted) activeIdx = wi;
        msg = 'The orb closes. ${w.name} takes the place of $old on your team!';
      } else {
        msg = 'The orb closes. ${w.name} is tamed, but your team is full, so it returns to the wild as a friend.';
      }
    }
    if (w.elder) {
      eldersCalmed++;
      msg += ' The Elder bonds with you. The ${content.subject(w.subjectId).label} biome is restored.';
    } else if (tamed == 1) {
      msg += ' A forgotten lesson has found a home.';
    }
    cues.add('win');
    b.resultLine = msg;
  }
}
