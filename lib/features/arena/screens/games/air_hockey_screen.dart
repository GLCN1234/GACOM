import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import '../../../../core/services/duel_session.dart';

/// Air hockey physics. Table is 100 wide by 160 tall, y points down.
/// The player defends the bottom goal, the AI defends the top goal.
class AirHockeyEngine {
  static const double w = 100.0;
  static const double h = 160.0;
  static const double puckR = 4.0;
  static const double malletR = 7.5;
  static const double goalHalf = 18.0;
  static const double maxPuck = 170.0;
  static const double friction = 0.3;
  static const double wallE = 0.94;
  static const double malletE = 0.9;
  static const double playerMax = 300.0;
  static const List<double> aiSpeeds = [55.0, 90.0, 130.0];
  static const List<double> aiErrors = [22.0, 12.0, 5.0];
  static const double timeLimit = 180.0;
  static const int target = 7;

  final Random rng;
  final double aiMax;
  final double aiErr;
  double px = w / 2, py = h / 2;
  double vx = 0.0, vy = 0.0;
  double mx = w / 2, my = h - 20.0; // player mallet
  double mvx = 0.0, mvy = 0.0;
  double tx = w / 2, ty = h - 20.0; // player target
  double ax = w / 2, ay = 20.0; // ai mallet
  double avx = 0.0, avy = 0.0;
  int playerScore = 0;
  int aiScore = 0;
  bool over = false;
  double pause = 0.0; // after a goal
  double clock = 0.0;
  double stallTime = 0.0;
  bool lastHitMallet = false;
  bool lastGoalByPlayer = false;
  int events = 0; // bumps when something audible happens
  double aimX = w / 2;
  double defOff = 0.0;
  double readErr = 0.0;
  double pinT = 0.0;
  double pinX = 0.0;
  double pinY = 0.0;
  double retreatT = 0.0;
  bool hitEvent = false;
  bool wallEvent = false;
  bool goalEvent = false;

  AirHockeyEngine(this.rng, {required this.aiMax, this.aiErr = 5.0}) {
    _serve(rng.nextBool());
  }

  void _serve(bool towardAi) {
    px = w / 2;
    py = h / 2;
    vx = 0.0;
    vy = 0.0;
    stallTime = 0.0;
    mx = w / 2; my = h - 20.0; mvx = 0.0; mvy = 0.0;
    tx = mx; ty = my;
    ax = w / 2; ay = 20.0; avx = 0.0; avy = 0.0;
    // the puck starts on the side of whoever just conceded
    py = towardAi ? h / 2 - 22.0 : h / 2 + 22.0;
  }

  void setTarget(double x, double y) {
    tx = clampD(x, malletR, w - malletR);
    ty = clampD(y, h / 2 + malletR, h - malletR);
  }

  void update(double dt) {
    if (over) return;
    clock += dt;
    if (clock >= timeLimit) {
      over = true;
      return;
    }
    hitEvent = false;
    wallEvent = false;
    goalEvent = false;
    if (pause > 0.0) {
      pause -= dt;
      if (pause <= 0.0) {
        pause = 0.0;
        _serve(lastGoalByPlayer);
      }
      return;
    }
    final int n = max(1, (dt * 120.0).ceil());
    final double s = dt / n;
    for (int i = 0; i < n; i++) {
      _step(s);
      if (pause > 0.0 || over) break;
    }
  }

  void _moveMallet(bool isPlayer, double goalX, double goalY, double maxSpeed, double s) {
    double dx = goalX - (isPlayer ? mx : ax);
    double dy = goalY - (isPlayer ? my : ay);
    final double dist = sqrt(dx * dx + dy * dy);
    final double maxStep = maxSpeed * s;
    if (dist > maxStep && dist > 0.0) {
      dx = dx / dist * maxStep;
      dy = dy / dist * maxStep;
    }
    if (isPlayer) {
      mx += dx; my += dy; mvx = dx / s; mvy = dy / s;
    } else {
      ax += dx; ay += dy; avx = dx / s; avy = dy / s;
    }
  }

  void _aiTarget(double s) {
    double gx = ax, gy = ay;
    // if the AI mallet is just pinning the puck against a wall or corner, back off and let it loose
    final double pdx = px - ax;
    final double pdy = py - ay;
    if (sqrt(pdx * pdx + pdy * pdy) < puckR + malletR + 1.0) {
      if ((px - pinX).abs() + (py - pinY).abs() < 2.0) {
        pinT += s;
      } else {
        pinT = 0.0;
        pinX = px;
        pinY = py;
      }
    } else {
      pinT = 0.0;
      pinX = px;
      pinY = py;
    }
    if (pinT > 0.35) {
      retreatT = 1.0;
      pinT = 0.0;
    }
    if (retreatT > 0.0) {
      retreatT -= s;
      _moveMallet(false, w / 2, 17.0, aiMax, s);
      return;
    }
    final bool puckOnAiSide = py < h / 2 + 4.0;
    if (!puckOnAiSide) {
      aimX = w / 2 + (rng.nextDouble() * 2.0 - 1.0) * (goalHalf - 4.0);
      defOff = (rng.nextDouble() * 2.0 - 1.0) * 5.0;
      readErr = (rng.nextDouble() * 2.0 - 1.0) * aiErr;
    }
    final double slow = sqrt(vx * vx + vy * vy);
    if (puckOnAiSide && (slow < 90.0 || vy > -10.0 || py < h / 2 - 20.0)) {
      // attack: get behind the puck, then drive it toward the player's goal
      final double ddx = aimX - px;
      final double ddy = h - py;
      final double dl = max(1.0, sqrt(ddx * ddx + ddy * ddy));
      final double ux = ddx / dl;
      final double uy = ddy / dl;
      if (ay < py - 3.0 && (ax - px).abs() < 14.0) {
        gx = px + ux * 4.0;
        gy = py + uy * 4.0;
      } else {
        gx = px - ux * 12.0;
        gy = py - uy * 12.0;
        if (gy < malletR) gy = malletR;
      }
    } else {
      // defend: sit in front of the goal and track the puck sideways
      double predX = px;
      if (vy < -5.0) {
        final double t = (py - 20.0) / -vy;
        predX = px + vx * t;
        // fold the prediction back inside the table walls
        final double span = w - 2.0 * puckR;
        double u = (predX - puckR) % (2.0 * span);
        if (u < 0.0) u += 2.0 * span;
        predX = (u > span ? 2.0 * span - u : u) + puckR;
      }
      gx = clampD(predX + defOff + readErr, 24.0, w - 24.0);
      gy = 17.0;
    }
    gx = clampD(gx, malletR, w - malletR);
    gy = clampD(gy, malletR, h / 2 - malletR);
    _moveMallet(false, gx, gy, aiMax, s);
  }

  void _collide(double cx, double cy, double cvx, double cvy) {
    final double dx = px - cx;
    final double dy = py - cy;
    final double dist = sqrt(dx * dx + dy * dy);
    final double minD = puckR + malletR;
    if (dist >= minD || dist == 0.0) return;
    final double nx = dx / dist;
    final double ny = dy / dist;
    px = cx + nx * minD;
    py = cy + ny * minD;
    final double rvx = vx - cvx;
    final double rvy = vy - cvy;
    final double vn = rvx * nx + rvy * ny;
    if (vn < 0.0) {
      vx -= (1.0 + malletE) * vn * nx;
      vy -= (1.0 + malletE) * vn * ny;
      hitEvent = true;
      lastHitMallet = true;
    }
  }

  void _walls() {
    if (px < puckR) { px = puckR; vx = vx.abs() * wallE; wallEvent = true; }
    if (px > w - puckR) { px = w - puckR; vx = -vx.abs() * wallE; wallEvent = true; }
    final bool inGap = px > w / 2 - goalHalf && px < w / 2 + goalHalf;
    if (py < puckR && !inGap) { py = puckR; vy = vy.abs() * wallE; wallEvent = true; }
    if (py > h - puckR && !inGap) { py = h - puckR; vy = -vy.abs() * wallE; wallEvent = true; }
  }

  void _yield(bool isPlayer) {
    final double cx = isPlayer ? mx : ax;
    final double cy = isPlayer ? my : ay;
    final double dx = px - cx;
    final double dy = py - cy;
    final double dist = sqrt(dx * dx + dy * dy);
    final double minD = puckR + malletR;
    if (dist >= minD || dist == 0.0) return;
    final double nx = dx / dist;
    final double ny = dy / dist;
    double nxp = px - nx * minD;
    double nyp = py - ny * minD;
    nxp = clampD(nxp, malletR, w - malletR);
    nyp = isPlayer ? clampD(nyp, h / 2 + malletR, h - malletR) : clampD(nyp, malletR, h / 2 - malletR);
    if (isPlayer) { mx = nxp; my = nyp; } else { ax = nxp; ay = nyp; }
  }

  void _step(double s) {
    _moveMallet(true, tx, ty, playerMax, s);
    my = clampD(my, h / 2 + malletR, h - malletR);
    mx = clampD(mx, malletR, w - malletR);
    _aiTarget(s);
    px += vx * s;
    py += vy * s;
    final double f = max(0.0, 1.0 - friction * s);
    vx *= f;
    vy *= f;
    _walls();
    _collide(mx, my, mvx, mvy);
    _collide(ax, ay, avx, avy);
    // a puck squeezed against a wall by a mallet: keep it in the table and let the mallet give way
    _walls();
    _yield(true);
    _yield(false);
    final double sp = sqrt(vx * vx + vy * vy);
    if (sp > maxPuck) { vx = vx / sp * maxPuck; vy = vy / sp * maxPuck; }
    // stall nudge: a puck stuck still in a corner gets a push
    if (sp < 2.0) {
      stallTime += s;
      if (stallTime > 5.0) {
        stallTime = 0.0;
        vy = py < h / 2 ? 30.0 : -30.0;
        vx = (rng.nextDouble() - 0.5) * 20.0;
      }
    } else {
      stallTime = 0.0;
    }
    // goals
    if (py < -puckR) { _goal(true); }
    else if (py > h + puckR) { _goal(false); }
  }

  void _goal(bool byPlayer) {
    goalEvent = true;
    lastGoalByPlayer = byPlayer;
    if (byPlayer) { playerScore++; } else { aiScore++; }
    vx = 0.0;
    vy = 0.0;
    if (playerScore >= target || aiScore >= target) {
      over = true;
    } else {
      pause = 1.0;
    }
    // park the puck out of play during the pause
    px = w / 2;
    py = byPlayer ? -20.0 : h + 20.0;
  }
}

class AirHockeyScreen extends StatefulWidget {
  const AirHockeyScreen({super.key});
  @override
  State<AirHockeyScreen> createState() => _AirHockeyScreenState();
}

class _AirHockeyScreenState extends State<AirHockeyScreen> with SingleTickerProviderStateMixin {
  static const List<String> _levels = ['EASY', 'MEDIUM', 'HARD'];
  final Random _rng = duelRandom();
  AirHockeyEngine? _e;
  int _level = 1;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  Size _tablePx = const Size(300, 480);

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
      _e = AirHockeyEngine(_rng, aiMax: AirHockeyEngine.aiSpeeds[_level], aiErr: AirHockeyEngine.aiErrors[_level]);
      _saved = false;
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
    e.update(dt);
    if (e.hitEvent) { SoundService.instance.playTap(); }
    if (e.goalEvent) {
      if (e.lastGoalByPlayer) { SoundService.instance.playCorrect(); } else { SoundService.instance.playWrong(); }
    }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      final bool? won = e.playerScore > e.aiScore ? true : (e.playerScore < e.aiScore ? false : null);
      GameScoreService.save(gameName: 'Air Hockey', score: e.playerScore * 100 + (won == true ? 200 : 0) - e.aiScore * 20 + 50, won: won);
      if (won == true) { SoundService.instance.playWin(); } else { SoundService.instance.playLose(); }
    }
    setState(() {});
  }

  void _drag(Offset p) {
    final e = _e;
    if (e == null || e.over) return;
    final double kx = AirHockeyEngine.w / _tablePx.width;
    final double ky = AirHockeyEngine.h / _tablePx.height;
    // the mallet sits a little above the finger so it stays visible
    e.setTarget(p.dx * kx, (p.dy - 28.0) * ky);
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'air_hockey',
      title: 'HOW TO PLAY AIR HOCKEY',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Drag your mallet', description: 'Slide your finger on your half of the table (the bottom). Your mallet follows, a little above your finger.'),
        HowToPlayStep(icon: Icons.sports_hockey_rounded, title: 'Hit the puck', description: 'Hit the puck into the AI goal at the top. A faster swing sends it faster. Walls bounce it back.'),
        HowToPlayStep(icon: Icons.shield_rounded, title: 'Defend your goal', description: 'The gap at the bottom is your goal. Keep your mallet between the puck and the gap.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'First to 7 wins', description: 'Every goal is one point. The first side to reach 7 wins, or whoever leads when the 3 minute clock runs out.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('AIR HOCKEY')),
        body: e == null
            ? ArcadeStartView(
                icon: Icons.sports_hockey_rounded,
                title: 'AIR HOCKEY',
                subtitle: 'First to 7 goals, or the lead at 3:00, beats the AI.',
                buttonLabel: 'START MATCH',
                onStart: _start,
                extra: [ArcadeChoiceRow(label: 'AI SKILL', options: _levels, selected: _level, onSelect: (i) => setState(() => _level = i))],
              )
            : Stack(children: [_game(e), if (e.over) _result(e)]),
      ),
    );
  }

  Widget _game(AirHockeyEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      final double availH = cons.maxHeight - 56.0;
      double tw = cons.maxWidth - 24.0;
      double th = tw * AirHockeyEngine.h / AirHockeyEngine.w;
      if (th > availH) {
        th = availH;
        tw = th * AirHockeyEngine.w / AirHockeyEngine.h;
      }
      _tablePx = Size(tw, th);
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('AI ${e.aiScore}   -   YOU ${e.playerScore}     ${max(0, (AirHockeyEngine.timeLimit - e.clock).ceil())}s', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        SizedBox(
          width: tw,
          height: th,
          child: Listener(
            onPointerDown: (d) => _drag(d.localPosition),
            onPointerMove: (d) => _drag(d.localPosition),
            child: CustomPaint(painter: _HockeyPainter(e)),
          ),
        ),
      ]);
    });
  }

  Widget _result(AirHockeyEngine e) {
    final bool won = e.playerScore > e.aiScore;
    final bool draw = e.playerScore == e.aiScore;
    return ArcadeResultOverlay(
      good: won,
      title: won ? 'YOU WIN!' : (draw ? 'DRAW' : 'AI WINS'),
      detail: 'Final score  ${e.playerScore} - ${e.aiScore}',
      onAgain: _toSetup,
      onExit: () => Navigator.pop(context),
      againLabel: 'REMATCH',
    );
  }
}

class _HockeyPainter extends CustomPainter {
  final AirHockeyEngine e;
  _HockeyPainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / AirHockeyEngine.w;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), Paint()..color = const Color(0xFF0D2A3A));
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white24;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14 * k, line);
    // goals
    final goalPaint = Paint()..color = GacomColors.deepOrange;
    final double gx0 = (AirHockeyEngine.w / 2 - AirHockeyEngine.goalHalf) * k;
    final double gx1 = (AirHockeyEngine.w / 2 + AirHockeyEngine.goalHalf) * k;
    canvas.drawRect(Rect.fromLTRB(gx0, 0, gx1, 4), goalPaint);
    canvas.drawRect(Rect.fromLTRB(gx0, size.height - 4, gx1, size.height), goalPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white54);
    void mallet(double x, double y, Color c) {
      final o = Offset(x * k, y * k);
      canvas.drawCircle(o, AirHockeyEngine.malletR * k, Paint()..color = c);
      canvas.drawCircle(o, AirHockeyEngine.malletR * k * 0.55, Paint()..color = Colors.black26);
    }
    mallet(e.ax, e.ay, const Color(0xFF42A5F5));
    mallet(e.mx, e.my, GacomColors.deepOrange);
    if (e.pause <= 0.0) {
      canvas.drawCircle(Offset(e.px * k, e.py * k), AirHockeyEngine.puckR * k, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_HockeyPainter oldDelegate) => true;
}
