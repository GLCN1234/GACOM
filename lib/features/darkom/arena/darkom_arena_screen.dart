import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../darkom_armory.dart';
import '../darkom_look.dart';
import '../hub/darkom_hub_service.dart';
import 'darkom_arena_args.dart';
import 'darkom_arena_logic.dart';
import 'darkom_arena_net.dart';
import 'darkom_arena_painter.dart';
import 'darkom_arena_panels.dart';

/// The realtime Darkom Arena. Route: '/darkom/arena', with a
/// [DarkomArenaArgs] passed as the GoRouter `extra`.
///
/// This screen has its own lobby and networking, so it does not use
/// RealmShell. A Ticker drives the game and a ValueNotifier repaints the
/// canvas, so nothing rebuilds per frame.
class DarkomArenaScreen extends StatefulWidget {
  final DarkomArenaArgs args;
  const DarkomArenaScreen({super.key, required this.args});

  @override
  State<DarkomArenaScreen> createState() => _DarkomArenaScreenState();
}

class _DarkomArenaScreenState extends State<DarkomArenaScreen> with SingleTickerProviderStateMixin {
  late DarkomArenaArgs _args;
  ArenaGame? _g;
  ArenaNet? _net;
  ArenaPainter? _painter;
  ArenaStickPainter? _stick;
  DarkomLook? _look;
  late final Ticker _ticker;
  Duration? _last;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final ValueNotifier<int> _hud = ValueNotifier<int>(0);
  final FocusNode _focus = FocusNode();
  final Set<LogicalKeyboardKey> _keys = <LogicalKeyboardKey>{};
  double _hudAcc = 0;
  int _seenVersion = -1;
  ArPhase? _seenPhase;
  Offset? _stickOrigin;
  Offset _stickKnob = Offset.zero;
  bool _loading = true;
  String? _error;
  bool _reporting = false;
  String _reportText = '';
  int _rematches = 0;
  bool _exiting = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _args = widget.args;
    _ticker = createTicker(_onTick);
    _boot();
  }

  @override
  void dispose() {
    final ArenaGame? g = _g;
    if (g != null && g.leaveCountsAsForfeit && !g.over) _forfeitReport(g);
    _ticker.dispose();
    _frame.dispose();
    _hud.dispose();
    _focus.dispose();
    final ArenaNet? n = _net;
    _net = null;
    n?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    DarkomLook look;
    try {
      look = await DarkomLook.mine();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your look. Please try again.');
      return;
    }
    if (!mounted) return;
    final String uid = look.userId.isNotEmpty ? look.userId : (SupabaseService.currentUserId ?? '');
    if (uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to enter the arena.';
      });
      return;
    }
    _look = look;
    _startGame(uid);
  }

  void _startGame(String uid) {
    final DarkomLook look = _look!;
    final ArenaGame g = ArenaGame(_args, uid, look, friendly: _rematches > 0);
    g.onMatchOver = _onMatchOver;
    final ArenaNet net = ArenaNet(_args.code, g);
    _g = g;
    _net = net;
    _painter = ArenaPainter(g, repaint: _frame);
    _stick = ArenaStickPainter(origin: () => _stickOrigin, knob: () => _stickKnob, repaint: _frame);
    _reporting = false;
    _reportText = '';
    _last = null;
    _seenVersion = -1;
    _stickOrigin = null;
    _stickKnob = Offset.zero;
    _keys.clear();
    net.start();
    if (!_ticker.isActive) _ticker.start();
    setState(() => _loading = false);
    DarkomArmory.load().then((DarkomArmory a) {
      if (!mounted || !identical(_g, g)) return;
      g.setArmory(a);
    }).catchError((Object _) {});
  }

  // ---- tick ---------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final ArenaGame? g = _g;
    if (g == null) return;
    final Duration? prev = _last;
    _last = elapsed;
    if (prev == null) return;
    final double dt = (elapsed - prev).inMicroseconds / 1e6;
    _applyKeys(g);
    g.update(dt);
    _frame.value++;
    _hudAcc += dt;
    if (_hudAcc >= 0.12) {
      _hudAcc = 0;
      _hud.value++;
    }
    if (g.version != _seenVersion || g.phase != _seenPhase) {
      _seenVersion = g.version;
      _seenPhase = g.phase;
      if (mounted) setState(() {});
    }
  }

  void _applyKeys(ArenaGame g) {
    if (_keys.isEmpty || _stickOrigin != null) return;
    double x = 0;
    double y = 0;
    if (_keys.contains(LogicalKeyboardKey.arrowLeft) || _keys.contains(LogicalKeyboardKey.keyA)) x -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowRight) || _keys.contains(LogicalKeyboardKey.keyD)) x += 1;
    if (_keys.contains(LogicalKeyboardKey.arrowUp) || _keys.contains(LogicalKeyboardKey.keyW)) y -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowDown) || _keys.contains(LogicalKeyboardKey.keyS)) y += 1;
    if (x != 0 && y != 0) {
      x *= 0.7071;
      y *= 0.7071;
    }
    g.setInput(x, y);
  }

  // ---- input --------------------------------------------------------------

  void _panStart(DragStartDetails d) {
    _stickOrigin = d.localPosition;
    _stickKnob = Offset.zero;
  }

  void _panUpdate(DragUpdateDetails d) {
    final Offset? o = _stickOrigin;
    final ArenaGame? g = _g;
    if (o == null || g == null) return;
    Offset v = d.localPosition - o;
    const double r = 58;
    if (v.distance > r) v = v / v.distance * r;
    _stickKnob = v;
    g.setInput(v.dx / r, v.dy / r);
  }

  void _panEnd() {
    _stickOrigin = null;
    _stickKnob = Offset.zero;
    _g?.setInput(0, 0);
  }

  static final Set<LogicalKeyboardKey> _usedKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.escape,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final ArenaGame? g = _g;
    if (g == null || !_usedKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = event.logicalKey;
    if (event is KeyDownEvent) {
      _keys.add(k);
      if (k == LogicalKeyboardKey.space) {
        g.pressAttack();
      } else if (k == LogicalKeyboardKey.keyE) {
        g.pressSpecial();
      } else if (k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight) {
        g.pressDash();
      } else if (k == LogicalKeyboardKey.escape) {
        _requestLeave();
      }
    } else if (event is KeyUpEvent) {
      _keys.remove(k);
      if (_keys.isEmpty && _stickOrigin == null) g.setInput(0, 0);
    }
    return KeyEventResult.handled;
  }

  // ---- results ------------------------------------------------------------

  void _onMatchOver() {
    final ArenaGame? g = _g;
    if (g == null || g.matchReported) return;
    g.matchReported = true;
    _report(g);
  }

  Future<void> _report(ArenaGame g) async {
    if (g.friendly) {
      _reportText = 'Friendly rematch. It does not count for rewards.';
      return;
    }
    DarkomDuelResult? r;
    bool noTarget = false;
    if (mounted) setState(() => _reporting = true);
    try {
      if (g.isDuel) {
        final String? id = g.args.challengeId;
        if (id == null || id.isEmpty) {
          noTarget = true;
        } else {
          r = await DarkomHubService.reportDuel(challengeId: id, iWon: g.iWon);
        }
      } else {
        final String? sid = g.args.squadId;
        if (sid == null || sid.isEmpty) {
          noTarget = true;
        } else {
          r = await DarkomHubService.reportSquadMatch(squadId: sid, placement: g.myPlacement, players: g.roster.length);
        }
      }
    } catch (_) {
      r = null;
    }
    if (!mounted || !identical(_g, g)) return;
    String text;
    if (noTarget) {
      text = 'Match complete';
    } else if (r == null) {
      text = 'Could not send your result';
    } else if (r.accepted) {
      text = r.xp > 0 ? 'Result recorded. +${r.xp} XP' : 'Result recorded';
    } else if (r.error != null && r.error!.isNotEmpty) {
      text = r.error!;
    } else {
      text = 'Result recorded';
    }
    setState(() {
      _reporting = false;
      _reportText = text;
    });
  }

  /// Quietly sends a loss when someone leaves a running match.
  void _forfeitReport(ArenaGame g) {
    if (g.matchReported || g.friendly) return;
    g.matchReported = true;
    try {
      if (g.isDuel) {
        final String? id = g.args.challengeId;
        if (id != null && id.isNotEmpty) {
          DarkomHubService.reportDuel(challengeId: id, iWon: false).then((DarkomDuelResult _) {}, onError: (Object _) {});
        }
      } else {
        final String? sid = g.args.squadId;
        if (sid != null && sid.isNotEmpty) {
          final int n = g.roster.length < 2 ? 2 : g.roster.length;
          DarkomHubService.reportSquadMatch(squadId: sid, placement: n, players: n).then((DarkomDuelResult _) {}, onError: (Object _) {});
        }
      }
    } catch (_) {}
  }

  Future<void> _requestLeave() async {
    final ArenaGame? g = _g;
    if (g == null) {
      _exit();
      return;
    }
    if (_exiting || _asking) return;
    if (g.leaveCountsAsForfeit) {
      _asking = true;
      final bool? leave = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          backgroundColor: GacomColors.cardDark,
          title: const Text('Leave the match?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
          content: const Text('The arena cannot be paused. Leaving counts as a forfeit and you lose this match.', style: TextStyle(color: GacomColors.textSecondary)),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep fighting')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: GacomColors.error))),
          ],
        ),
      );
      _asking = false;
      if (leave != true || !mounted) return;
      if (!g.over) _forfeitReport(g);
    }
    _exit();
  }

  void _exit() {
    if (_exiting || !mounted) return;
    _exiting = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/darkom');
    }
  }

  void _rematch() {
    final ArenaGame? old = _g;
    final DarkomLook? look = _look;
    if (old == null || look == null || !old.isDuel) return;
    final String uid = old.myId;
    _args = DarkomArenaArgs(code: '${_args.code}_r', mode: _args.mode, playerIds: _args.playerIds, challengeId: _args.challengeId, squadId: _args.squadId);
    _rematches++;
    final ArenaNet? n = _net;
    _net = null;
    n?.dispose();
    _startGame(uid);
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ArenaGame? g = _g;
    if (_loading || g == null) {
      return Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    arenaButton('LEAVE', _exit, secondary: true, width: 140),
                  ]),
                )
              : Column(mainAxisSize: MainAxisSize.min, children: const <Widget>[
                  CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  SizedBox(height: 16),
                  Text('Entering the arena...', style: TextStyle(color: GacomColors.textSecondary)),
                ]),
        ),
      );
    }
    final bool inter = g.phase == ArPhase.intermission;
    return WillPopScope(
      onWillPop: () async {
        await _requestLeave();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05060A),
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: (_) => _panEnd(),
                onPanCancel: _panEnd,
                child: RepaintBoundary(
                  child: CustomPaint(painter: _painter, foregroundPainter: _stick, size: Size.infinite),
                ),
              ),
            ),
            if (g.playing || inter)
              Positioned.fill(
                child: SafeArea(
                  child: ArenaHud(
                    game: g,
                    tick: _hud,
                    frame: _frame,
                    onLeave: _requestLeave,
                    onEmote: g.sendEmote,
                    onAttack: g.pressAttack,
                    onSpecial: g.pressSpecial,
                    onDash: g.pressDash,
                    buttons: !inter,
                  ),
                ),
              ),
            if (inter) Positioned.fill(child: SafeArea(child: ArenaIntermissionPanel(game: g, tick: _hud, onPick: g.chooseWeapon))),
            if (g.phase == ArPhase.lobby)
              Positioned.fill(
                child: ArenaLobbyPanel(game: g, tick: _hud, onReady: g.toggleReady, onLeave: _requestLeave, onPick: g.chooseWeapon),
              ),
            if (g.phase == ArPhase.failed) Positioned.fill(child: ArenaFailedCard(game: g, onLeave: _requestLeave)),
            if (g.phase == ArPhase.over)
              Positioned.fill(
                child: ArenaResultCard(game: g, reporting: _reporting, reportText: _reportText, onRematch: _rematch, onLeave: _requestLeave),
              ),
          ]),
        ),
      ),
    );
  }
}
