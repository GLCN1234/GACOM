import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../edu/realms/realm_kit.dart';
import '../edu/realms/realm_shell.dart';
import 'darkom_armory.dart';
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
  const DarkomScreen({super.key, this.config = const RealmConfig(useSchool: false), this.mission});
  final RealmConfig config;

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
    _load();
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
    setState(() => _boot = DarkomBoot(progress, armory, ghost, mission: widget.mission));
  }

  /// The next open mission after this one, in board order.
  DarkomMission? _nextMission(DarkomMission cur, int chapter) {
    final int i = darkomMissions.indexWhere((DarkomMission m) => m.id == cur.id);
    for (int k = i + 1; k < darkomMissions.length; k++) {
      if (darkomMissions[k].isOpen(chapter)) return darkomMissions[k];
    }
    return null;
  }

  List<RealmResultAction> _resultActions(RealmLogic l) {
    final DarkomMission? ms = widget.mission;
    final DarkomBoot? b = _boot;
    if (ms == null || b == null || l is! DarkomLogic || !l.missionDone) return const <RealmResultAction>[];
    final DarkomMission? nx = _nextMission(ms, b.progress.chapter);
    if (nx == null) return const <RealmResultAction>[];
    return <RealmResultAction>[
      RealmResultAction('NEXT MISSION', () {
        if (mounted) context.pushReplacement('/darkom/play', extra: nx);
      }),
    ];
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
    final DarkomMission? ms = widget.mission;
    final bool roam = ms == null && b.progress.chapter >= 6;
    final DarkomChapterDef ch = ms != null ? ms.asChapter() : darkomChapter(roam ? 5 : b.progress.chapter);
    return RealmShell(
      gameName: 'Darkom City',
      gameId: 'darkom',
      title: ms != null ? ms.title : (roam ? 'Darkom City: Free Roam' : 'Chapter ${ch.n}: ${ch.name}'),
      story: ms != null ? ms.brief : (roam ? darkomRoamIntro : '${ch.fixer}, ${ch.fixerRole}: "${ch.intro}"'),
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
      background: const Color(0xFF05060A),
      learning: false,
      resultActions: _resultActions,
      exitLabel: ms != null ? 'MISSION BOARD' : 'EXIT',
    );
  }
}
