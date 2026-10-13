import '../../core/services/cosmetics_service.dart';
import 'package:flutter/material.dart';
import '../edu/realms/realm_kit.dart';
import '../edu/realms/realm_shell.dart';
import 'darkom_armory.dart';
import 'darkom_coop.dart';
import 'darkom_ghost.dart';
import 'darkom_hud.dart';
import 'darkom_logic.dart';
import 'darkom_missions.dart';
import 'darkom_painter.dart';
import 'darkom_service.dart';
import 'darkom_story.dart';

const Color _dkAccent = Color(0xFFFF2E93);

/// Darkom City: an open, top-down, cyber-noir action game.
/// Route: '/darkom'.
class DarkomScreen extends StatefulWidget {
  const DarkomScreen({super.key, this.config = const RealmConfig(useSchool: false), this.mission, this.coopArgs});
  final RealmConfig config;

  /// Set for City Patrol: the squad that plays together in one city.
  final DarkomCoopArgs? coopArgs;

  /// A mission picked on the board. Null plays the story (or free roam).
  final DarkomMission? mission;

  @override
  State<DarkomScreen> createState() => _DarkomScreenState();
}

class _DarkomScreenState extends State<DarkomScreen> {
  DarkomBoot? _boot;

  @override
  void initState() {
    super.initState();
    CosmeticsService.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    _boot?.coop?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    DarkomProgress progress = DarkomProgress.empty;
    DarkomArmory armory = DarkomArmory.plain();
    DarkomGhost? ghost;
    try {
      progress = await DarkomService.loadProgress().timeout(const Duration(seconds: 6), onTimeout: () => DarkomProgress.empty);
    } catch (_) {}
    try {
      armory = await DarkomArmory.load().timeout(const Duration(seconds: 6), onTimeout: () => DarkomArmory.plain());
    } catch (_) {}
    try {
      ghost = await DarkomGhost.load();
    } catch (_) {}
    if (!mounted) return;
    final DarkomBoot boot = DarkomBoot(progress, armory, ghost, mission: widget.mission);
    if (widget.coopArgs != null) boot.coop = DarkomCoop(widget.coopArgs!);
    if (widget.mission != null) {
      try {
        final DarkomMissionStats st = await DarkomService.loadMissionStats().timeout(const Duration(seconds: 5), onTimeout: () => DarkomMissionStats.empty);
        boot.cleared.addAll(st.done.keys);
      } catch (_) {}
      boot.onSwitch = _switchTo;
    }
    if (!mounted) return;
    setState(() {
      _mission = widget.mission;
      _boot = boot;
    });
  }

  DarkomMission? _mission;
  bool _fade = false;
  bool _skipIntro = false;
  int _gen = 0;
  String _toName = '';

  /// The next mission is in another district: fade out, rebuild the world, fade in.
  void _switchTo(DarkomMission m) {
    if (!mounted) return;
    setState(() {
      _fade = true;
      _toName = m.theme.name;
    });
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _mission = m;
        _skipIntro = true;
        _gen++;
      });
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _fade = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final DarkomBoot? b = _boot;
    if (b == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF05060A),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            CircularProgressIndicator(color: _dkAccent),
            SizedBox(height: 16),
            Text('Entering Darkom City...', style: TextStyle(color: Colors.white70)),
          ]),
        ),
      );
    }
    final DarkomMission? ms = _mission;
    final bool patrol = b.coop != null;
    final bool roam = ms == null && (patrol || b.progress.chapter >= 6);
    final DarkomChapterDef ch = ms != null ? ms.asChapter() : darkomChapter(roam ? 5 : b.progress.chapter);
    final Widget shell = RealmShell(
      key: ValueKey<int>(_gen),
      gameName: 'Darkom City',
      gameId: 'darkom',
      title: ms != null ? ms.title : (patrol ? 'Darkom City: City Patrol' : (roam ? 'Darkom City: Free Roam' : 'Chapter ${ch.n}: ${ch.name}')),
      story: ms != null ? ms.brief : (patrol ? 'Your squad patrols the open city together. The same enemies hunt all of you, so stay close and cover each other. Patrols are for fun: they never change rankings.' : roam ? darkomRoamIntro : '${ch.fixer}, ${ch.fixerRole}: "${ch.intro}"'),
      howTo: 'Drag anywhere to move. ATTACK fights with your weapon and aims at the nearest enemy. SPECIAL is a strong move that recharges, DASH is a short safe dodge, SWAP changes weapon. Follow the arrow and the minimap flag. On a computer: WASD to move, SPACE to attack, E for special, SHIFT to dash, Q to swap weapon.',
      icon: Icons.location_city_rounded,
      accent: _dkAccent,
      config: const RealmConfig(useSchool: false),
      create: (RealmContent c) => DarkomLogic(c, b),
      painter: (RealmLogic l, Listenable repaint) => DarkomPainter(l as DarkomLogic, repaint: repaint),
      hud: darkomHud,
      actions: const <RealmAction>[
        RealmAction(0, Icons.flash_on_rounded, 'ATTACK'),
        RealmAction(1, Icons.auto_awesome_rounded, 'SPECIAL'),
        RealmAction(2, Icons.bolt_rounded, 'DASH'),
        RealmAction(3, Icons.swap_horiz_rounded, 'SWAP'),
      ],
      joystick: true,
      actionScale: 1.22,
      saveScore: !patrol,
      background: const Color(0xFF05060A),
      learning: false,
      skipIntro: _skipIntro,
      pauseActions: (RealmLogic l) => ms != null && l is DarkomLogic
          ? <RealmResultAction>[RealmResultAction('RESTART MISSION', l.restartMission)]
          : const <RealmResultAction>[],
    );
    if (ms == null) return shell;
    return Stack(children: <Widget>[
      Positioned.fill(child: shell),
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _fade ? 1 : 0,
            duration: const Duration(milliseconds: 450),
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Text(_toName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, decoration: TextDecoration.none)),
            ),
          ),
        ),
      ),
    ]);
  }
}
