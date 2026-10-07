import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import '../../../../core/services/duel_session.dart';

class TdTowerSpec {
  final String name;
  final int cost;
  final double dmg;
  final double range;
  final double cd;
  final double splash;
  final double slow;
  final double projSpeed;
  final Color color;
  final String blurb;
  const TdTowerSpec(this.name, this.cost, this.dmg, this.range, this.cd, this.splash, this.slow, this.projSpeed, this.color, this.blurb);
}

class TdTower {
  final int col;
  final int row;
  final int kind;
  int level = 1;
  double cooldown = 0.0;
  int spent;
  TdTower(this.col, this.row, this.kind, this.spent);
  double get x => col + 0.5;
  double get y => row + 0.5;
}

class TdEnemy {
  final int type;
  final double maxHp;
  double hp;
  double dist = 0.0;
  double slowT = 0.0;
  double x = 0.0;
  double y = 0.0;
  bool dead = false;
  TdEnemy(this.type, this.maxHp) : hp = maxHp;
}

class TdShot {
  double x;
  double y;
  final TdEnemy target;
  double tx;
  double ty;
  final int kind;
  final double dmg;
  final double splash;
  final double slow;
  final double speed;
  bool done = false;
  TdShot(this.x, this.y, this.target, this.kind, this.dmg, this.splash, this.slow, this.speed)
      : tx = target.x,
        ty = target.y;
}

/// Tower defence on a 9 by 13 grid with one winding path.
class TdEngine {
  static const int cols = 9;
  static const int rows = 13;
  static const int totalWaves = 30;
  static const List<TdTowerSpec> specs = [
    TdTowerSpec('ARROW', 50, 10.0, 2.6, 0.55, 0.0, 0.0, 12.0, Color(0xFF66BB6A), 'Fast and cheap. Good all rounder.'),
    TdTowerSpec('CANNON', 110, 28.0, 2.4, 1.5, 1.0, 0.0, 7.0, Color(0xFFEF6C00), 'Slow shells that blast groups.'),
    TdTowerSpec('FROST', 80, 3.0, 2.3, 0.9, 0.0, 0.5, 12.0, Color(0xFF4FC3F7), 'Slows enemies by half.'),
    TdTowerSpec('SNIPER', 160, 70.0, 5.5, 2.2, 0.0, 0.0, 26.0, Color(0xFFAB47BC), 'Huge range and damage.'),
  ];
  // enemy types: 0 grunt, 1 runner, 2 tank, 3 boss
  static const List<double> enemySpeed = [0.9, 1.7, 0.6, 0.45];
  static const List<double> enemyHp = [40.0, 24.0, 160.0, 900.0];
  static const List<int> enemyBounty = [4, 5, 12, 80];
  static const List<String> diffNames = ['EASY', 'NORMAL', 'HARD'];
  static const List<double> diffBase = [1.09, 1.115, 1.14];
  static const List<int> diffMoney = [220, 160, 130];
  static const List<List<double>> waypoints = [
    [-0.5, 1.5], [7.5, 1.5], [7.5, 4.5], [1.5, 4.5], [1.5, 7.5], [7.5, 7.5], [7.5, 10.5], [3.5, 10.5], [3.5, 13.2],
  ];

  final Random rng;
  final int diff;
  final List<TdTower> towers = <TdTower>[];
  final List<TdEnemy> enemies = <TdEnemy>[];
  final List<TdShot> shots = <TdShot>[];
  final List<int> queue = <int>[];
  final List<double> _cum = <double>[];
  final Set<int> pathCells = <int>{};
  double pathLen = 0.0;
  int money;
  int lives = 20;
  int wave = 0;
  bool waveActive = false;
  bool over = false;
  bool won = false;
  int kills = 0;
  double spawnTimer = 0.0;
  int shotEvents = 0;
  int killEvents = 0;
  int leakEvents = 0;
  String message = 'Build towers, then start the first wave.';

  TdEngine(this.rng, {required this.diff}) : money = diffMoney[diff] {
    _cum.add(0.0);
    for (int i = 1; i < waypoints.length; i++) {
      final double dx = waypoints[i][0] - waypoints[i - 1][0];
      final double dy = waypoints[i][1] - waypoints[i - 1][1];
      pathLen += sqrt(dx * dx + dy * dy);
      _cum.add(pathLen);
    }
    for (int i = 1; i < waypoints.length; i++) {
      final int c0 = waypoints[i - 1][0].floor();
      final int r0 = waypoints[i - 1][1].floor();
      final int c1 = waypoints[i][0].floor();
      final int r1 = waypoints[i][1].floor();
      for (int c = min(c0, c1); c <= max(c0, c1); c++) {
        for (int r = min(r0, r1); r <= max(r0, r1); r++) {
          if (c >= 0 && c < cols && r >= 0 && r < rows) pathCells.add(r * cols + c);
        }
      }
    }
  }

  bool isPath(int c, int r) => pathCells.contains(r * cols + c);

  TdTower? towerAt(int c, int r) {
    for (final t in towers) {
      if (t.col == c && t.row == r) return t;
    }
    return null;
  }

  bool canBuild(int c, int r) => c >= 0 && c < cols && r >= 0 && r < rows && !isPath(c, r) && towerAt(c, r) == null;

  double dmgOf(TdTower t) => specs[t.kind].dmg * (1.0 + 0.5 * (t.level - 1));
  double rangeOf(TdTower t) => specs[t.kind].range * (1.0 + 0.08 * (t.level - 1));
  double cdOf(TdTower t) => specs[t.kind].cd / (1.0 + 0.12 * (t.level - 1));
  int upgradeCost(TdTower t) => t.level >= 3 ? 0 : (specs[t.kind].cost * 0.7 * t.level).round();
  int sellValue(TdTower t) => (t.spent * 0.7).round();

  bool build(int c, int r, int kind) {
    if (!canBuild(c, r)) return false;
    final int cost = specs[kind].cost;
    if (money < cost) return false;
    money -= cost;
    towers.add(TdTower(c, r, kind, cost));
    return true;
  }

  bool upgrade(TdTower t) {
    final int cost = upgradeCost(t);
    if (t.level >= 3 || money < cost) return false;
    money -= cost;
    t.spent += cost;
    t.level++;
    return true;
  }

  void sell(TdTower t) {
    money += sellValue(t);
    towers.remove(t);
  }

  double hpScale(int n) => pow(diffBase[diff], n - 1).toDouble();

  List<int> waveTypes(int n) {
    final List<int> out = <int>[];
    for (int i = 0; i < 5 + n; i++) { out.add(0); }
    if (n >= 3) { for (int i = 0; i < (n - 1) ~/ 2; i++) { out.add(1); } }
    if (n >= 5) { for (int i = 0; i < (n - 3) ~/ 3; i++) { out.add(2); } }
    out.shuffle(rng);
    if (n % 10 == 0) {
      for (int i = 0; i < n ~/ 10; i++) { out.add(3); }
    }
    return out;
  }

  bool startWave() {
    if (waveActive || over) return false;
    wave++;
    queue
      ..clear()
      ..addAll(waveTypes(wave));
    spawnTimer = 0.0;
    waveActive = true;
    message = 'Wave $wave';
    return true;
  }

  void _pos(TdEnemy e) {
    final double d = min(e.dist, pathLen);
    int i = 1;
    while (i < _cum.length - 1 && _cum[i] < d) { i++; }
    final double seg = _cum[i] - _cum[i - 1];
    final double t = seg == 0.0 ? 0.0 : (d - _cum[i - 1]) / seg;
    e.x = waypoints[i - 1][0] + (waypoints[i][0] - waypoints[i - 1][0]) * t;
    e.y = waypoints[i - 1][1] + (waypoints[i][1] - waypoints[i - 1][1]) * t;
  }

  void step(double dt) {
    if (over) return;
    final int n = max(1, (dt * 60.0).ceil());
    final double s = dt / n;
    for (int i = 0; i < n; i++) { _sub(s); if (over) break; }
  }

  void _sub(double s) {
    if (queue.isNotEmpty) {
      spawnTimer -= s;
      if (spawnTimer <= 0.0) {
        final int type = queue.removeAt(0);
        final e = TdEnemy(type, enemyHp[type] * hpScale(wave));
        _pos(e);
        enemies.add(e);
        spawnTimer = type == 1 ? 0.55 : (type == 3 ? 2.0 : 0.85);
      }
    }
    for (final e in enemies) {
      if (e.dead) continue;
      final double sp = enemySpeed[e.type] * (e.slowT > 0.0 ? 0.5 : 1.0);
      if (e.slowT > 0.0) e.slowT -= s;
      e.dist += sp * s;
      if (e.dist >= pathLen) {
        e.dead = true;
        lives -= e.type == 3 ? 5 : 1;
        leakEvents++;
        if (lives <= 0) {
          lives = 0;
          over = true;
          won = false;
          message = 'The base has fallen.';
        }
      } else {
        _pos(e);
      }
    }
    for (final t in towers) {
      t.cooldown -= s;
      if (t.cooldown > 0.0) continue;
      final double range = rangeOf(t);
      TdEnemy? best;
      for (final e in enemies) {
        if (e.dead) continue;
        final double dx = e.x - t.x;
        final double dy = e.y - t.y;
        if (dx * dx + dy * dy > range * range) continue;
        if (best == null || e.dist > best.dist) best = e;
      }
      if (best != null) {
        final sp = specs[t.kind];
        shots.add(TdShot(t.x, t.y, best, t.kind, dmgOf(t), sp.splash, sp.slow, sp.projSpeed));
        t.cooldown = cdOf(t);
        shotEvents++;
      }
    }
    for (final sh in shots) {
      if (sh.done) continue;
      if (!sh.target.dead) { sh.tx = sh.target.x; sh.ty = sh.target.y; }
      final double dx = sh.tx - sh.x;
      final double dy = sh.ty - sh.y;
      final double d = sqrt(dx * dx + dy * dy);
      final double mv = sh.speed * s;
      if (d <= mv + 0.1) {
        sh.done = true;
        _impact(sh);
      } else {
        sh.x += dx / d * mv;
        sh.y += dy / d * mv;
      }
    }
    shots.removeWhere((sh) => sh.done);
    enemies.removeWhere((e) => e.dead);
    if (waveActive && queue.isEmpty && enemies.isEmpty && !over) {
      waveActive = false;
      money += 20 + wave * 2;
      if (wave >= totalWaves) {
        over = true;
        won = true;
        message = 'All $totalWaves waves defeated!';
      } else {
        message = 'Wave $wave cleared.';
      }
    }
  }

  void _hurt(TdEnemy e, double dmg, double slow) {
    if (e.dead) return;
    e.hp -= dmg;
    if (slow > 0.0) e.slowT = 1.6;
    if (e.hp <= 0.0) {
      e.dead = true;
      kills++;
      killEvents++;
      money += enemyBounty[e.type];
    }
  }

  void _impact(TdShot sh) {
    if (sh.splash > 0.0) {
      for (final e in enemies) {
        if (e.dead) continue;
        final double dx = e.x - sh.tx;
        final double dy = e.y - sh.ty;
        if (dx * dx + dy * dy <= sh.splash * sh.splash) { _hurt(e, sh.dmg, sh.slow); }
      }
    } else if (!sh.target.dead) {
      _hurt(sh.target, sh.dmg, sh.slow);
    }
  }

  int get score {
    final int base = (wave - (waveActive ? 1 : 0)) * 100 + kills * 5;
    return base + (won ? 1000 + lives * 20 : 0);
  }
}

class TowerDefenseScreen extends StatefulWidget {
  const TowerDefenseScreen({super.key});
  @override
  State<TowerDefenseScreen> createState() => _TowerDefenseScreenState();
}

class _TowerDefenseScreenState extends State<TowerDefenseScreen> with SingleTickerProviderStateMixin {
  final Random _rng = duelRandom();
  TdEngine? _e;
  int _diff = 1;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  int _speed = 1;
  int _pick = 0; // tower type chosen for building
  TdTower? _sel;
  double _cell = 30.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    _ticker.stop();
    setState(() {
      _e = TdEngine(_rng, diff: _diff);
      _saved = false;
      _speed = 1;
      _sel = null;
      _pick = 0;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _toSetup() {
    _ticker.stop();
    setState(() => _e = null);
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) { dt = 0.05; }
    final int k0 = e.killEvents;
    final int s0 = e.shotEvents;
    final int l0 = e.leakEvents;
    for (int i = 0; i < _speed; i++) { e.step(dt); }
    if (e.killEvents > k0) { SoundService.instance.playCorrect(); }
    else if (e.shotEvents > s0 && e.shotEvents % 3 == 0) { SoundService.instance.playShoot(); }
    if (e.leakEvents > l0) { SoundService.instance.playWrong(); }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Tower Defense', score: e.score, won: e.won);
      if (e.won) { SoundService.instance.playWin(); } else { SoundService.instance.playLose(); }
    }
    setState(() {});
  }

  void _tapCell(Offset p) {
    final e = _e;
    if (e == null || e.over) return;
    final int c = (p.dx / _cell).floor();
    final int r = (p.dy / _cell).floor();
    final t = e.towerAt(c, r);
    if (t != null) {
      setState(() => _sel = t);
      return;
    }
    if (e.canBuild(c, r)) {
      if (e.build(c, r, _pick)) {
        SoundService.instance.playPieceMove();
        setState(() => _sel = e.towerAt(c, r));
      } else {
        e.message = 'Not enough money for a ${TdEngine.specs[_pick].name.toLowerCase()} tower.';
        SoundService.instance.playWrong();
        setState(() {});
      }
    } else {
      setState(() => _sel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'tower_defense',
      title: 'HOW TO PLAY TOWER DEFENSE',
      steps: const [
        HowToPlayStep(icon: Icons.add_box_rounded, title: 'Build towers', description: 'Pick a tower type at the bottom, then tap any empty green square beside the path to build it. Towers cost money.'),
        HowToPlayStep(icon: Icons.play_arrow_rounded, title: 'Start the waves', description: 'Press NEXT WAVE when you are ready. Enemies walk the path to your base. Every enemy that reaches the end costs you a life, and bosses cost 5.'),
        HowToPlayStep(icon: Icons.upgrade_rounded, title: 'Upgrade and sell', description: 'Tap a tower to upgrade it (up to level 3) or sell it for most of its money back. Kills and cleared waves earn more cash.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Survive 30 waves', description: 'Mix tower types: Frost slows, Cannon hits groups, Sniper shoots far, Arrow is cheap and fast. Survive all 30 waves to win.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('TOWER DEFENSE')),
        body: e == null
            ? ArcadeStartView(
                icon: Icons.castle_rounded,
                title: 'TOWER DEFENSE',
                subtitle: 'Hold the line for 30 waves.',
                buttonLabel: 'START',
                onStart: _start,
                extra: [ArcadeChoiceRow(label: 'DIFFICULTY', options: TdEngine.diffNames, selected: _diff, onSelect: (i) => setState(() => _diff = i))],
              )
            : Stack(children: [_game(e), if (e.over) _result(e)]),
      ),
    );
  }

  Widget _game(TdEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      double cell = (cons.maxWidth - 8.0) / TdEngine.cols;
      final double maxCellH = (cons.maxHeight - 150.0) / TdEngine.rows;
      if (cell > maxCellH) cell = maxCellH;
      _cell = cell;
      final double gw = cell * TdEngine.cols;
      final double gh = cell * TdEngine.rows;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
          const SizedBox(width: 3),
          Text('${e.lives}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
          const SizedBox(width: 14),
          const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 16),
          const SizedBox(width: 3),
          Text('${e.money}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
          const SizedBox(width: 14),
          Text('WAVE ${e.wave}/${TdEngine.totalWaves}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textMuted)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _speed = _speed == 1 ? 2 : 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: GacomColors.border), borderRadius: BorderRadius.circular(8)),
              child: Text('x$_speed', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.accentCyan)),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          width: gw,
          height: gh,
          child: GestureDetector(
            onTapDown: (d) => _tapCell(d.localPosition),
            child: CustomPaint(painter: _TdPainter(e, _sel, cell)),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(height: 18, child: Text(e.message, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12))),
        _panel(e),
      ]);
    });
  }

  Widget _panel(TdEngine e) {
    final t = _sel;
    if (t != null && e.towers.contains(t)) {
      final sp = TdEngine.specs[t.kind];
      final int up = e.upgradeCost(t);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${sp.name} L${t.level}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: sp.color, fontSize: 15)),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            onPressed: t.level >= 3 ? null : () {
              if (e.upgrade(t)) { SoundService.instance.playCorrect(); }
              else { SoundService.instance.playWrong(); }
              setState(() {});
            },
            child: Text(t.level >= 3 ? 'MAX' : 'UPGRADE $up', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              e.sell(t);
              SoundService.instance.playTap();
              setState(() => _sel = null);
            },
            child: Text('SELL ${e.sellValue(t)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: () => setState(() => _sel = null), icon: const Icon(Icons.close_rounded, size: 18, color: GacomColors.textMuted)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < TdEngine.specs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _pick = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: _pick == i ? TdEngine.specs[i].color.withValues(alpha: 0.2) : GacomColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _pick == i ? TdEngine.specs[i].color : GacomColors.border, width: 1.5),
                ),
                child: Column(children: [
                  Text(TdEngine.specs[i].name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: TdEngine.specs[i].color)),
                  Text('${TdEngine.specs[i].cost}', style: TextStyle(fontSize: 11, color: e.money >= TdEngine.specs[i].cost ? GacomColors.textPrimary : Colors.redAccent)),
                ]),
              ),
            ),
          ),
        const SizedBox(width: 6),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: e.waveActive ? GacomColors.border : GacomColors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
          onPressed: e.waveActive ? null : () {
            e.startWave();
            SoundService.instance.playTap();
            setState(() => _sel = null);
          },
          child: const Text('NEXT WAVE', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _result(TdEngine e) {
    return ArcadeResultOverlay(
      good: e.won,
      title: e.won ? 'BASE DEFENDED!' : 'BASE LOST',
      detail: e.won ? 'All 30 waves cleared. Score ${e.score}' : 'You reached wave ${e.wave}. Score ${e.score}',
      onAgain: _toSetup,
      onExit: () => Navigator.pop(context),
    );
  }
}

class _TdPainter extends CustomPainter {
  final TdEngine e;
  final TdTower? sel;
  final double cell;
  _TdPainter(this.e, this.sel, this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    for (int r = 0; r < TdEngine.rows; r++) {
      for (int c = 0; c < TdEngine.cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        canvas.drawRect(rect, Paint()..color = e.isPath(c, r) ? const Color(0xFF8D6E46) : ((r + c) % 2 == 0 ? const Color(0xFF1F4D2B) : const Color(0xFF1B4527)));
      }
    }
    final s = sel;
    if (s != null && e.towers.contains(s)) {
      canvas.drawCircle(Offset(s.x * cell, s.y * cell), e.rangeOf(s) * cell, Paint()..color = Colors.white.withValues(alpha: 0.12));
      canvas.drawCircle(Offset(s.x * cell, s.y * cell), e.rangeOf(s) * cell, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white54);
    }
    for (final t in e.towers) {
      final sp = TdEngine.specs[t.kind];
      final o = Offset(t.x * cell, t.y * cell);
      canvas.drawCircle(o, cell * 0.38, Paint()..color = Colors.black54);
      canvas.drawCircle(o, cell * 0.32, Paint()..color = sp.color);
      for (int i = 0; i < t.level; i++) {
        canvas.drawCircle(o + Offset((i - (t.level - 1) / 2.0) * cell * 0.2, cell * 0.05), cell * 0.06, Paint()..color = Colors.white);
      }
    }
    for (final en in e.enemies) {
      final o = Offset(en.x * cell, en.y * cell);
      final double rad = cell * (en.type == 3 ? 0.42 : (en.type == 2 ? 0.34 : (en.type == 1 ? 0.2 : 0.26)));
      final Color col = en.type == 0 ? const Color(0xFFE53935) : (en.type == 1 ? const Color(0xFFFFEB3B) : (en.type == 2 ? const Color(0xFF6D4C41) : const Color(0xFFD500F9)));
      canvas.drawCircle(o, rad, Paint()..color = en.slowT > 0.0 ? Color.lerp(col, const Color(0xFF4FC3F7), 0.6)! : col);
      final double f = en.hp / en.maxHp;
      canvas.drawRect(Rect.fromLTWH(o.dx - rad, o.dy - rad - 4, rad * 2, 2.5), Paint()..color = Colors.black54);
      canvas.drawRect(Rect.fromLTWH(o.dx - rad, o.dy - rad - 4, rad * 2 * clampD(f, 0.0, 1.0), 2.5), Paint()..color = Colors.greenAccent);
    }
    for (final sh in e.shots) {
      canvas.drawCircle(Offset(sh.x * cell, sh.y * cell), sh.kind == 1 ? cell * 0.12 : cell * 0.07, Paint()..color = TdEngine.specs[sh.kind].color);
    }
  }

  @override
  bool shouldRepaint(_TdPainter oldDelegate) => true;
}
