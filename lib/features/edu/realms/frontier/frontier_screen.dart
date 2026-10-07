import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'frontier_logic.dart';
import 'frontier_painter.dart';

/// Frontier: grow a living settlement. Knowledge unlocks growth.
class FrontierScreen extends StatelessWidget {
  const FrontierScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Frontier',
      title: 'Frontier',
      story: 'The capital has granted you a charter for a new town, far beyond its walls. '
          'The settlers will only follow a leader whose council is wise. '
          'Raise farms, houses and schools, listen to the elders at dusk, and hold the frontier for 30 days.',
      howTo: 'Tap a tile to see what can be built there, then tap a building in the bar below to build it '
          '(w = wood, s = stone, c = coins). Tap a built tile to upgrade it. '
          'Each dusk the council asks a question: answer it to earn a blessing, or skip it. '
          'Spend knowledge in Research, but prove each theory with a correct answer. '
          'Raiders come every 5th day, so raise towers and walls. Survive to day 30.',
      icon: Icons.cabin_rounded,
      accent: const Color(0xFF8BC34A),
      config: config,
      joystick: false,
      duelSeconds: 300,
      background: const Color(0xFF15241A),
      create: (RealmContent c) => FrontierLogic(c),
      painter: (RealmLogic l, Listenable r) => FrontierPainter(l as FrontierLogic, repaint: r),
      hud: _fHud,
    );
  }
}

const List<IconData> _fIcons = <IconData>[
  Icons.agriculture_rounded,
  Icons.forest_rounded,
  Icons.landscape_rounded,
  Icons.home_rounded,
  Icons.school_rounded,
  Icons.water_drop_rounded,
  Icons.cell_tower_rounded,
  Icons.fence_rounded,
];

const Color _fPanelBg = Color(0xEE0B0B0F);
const Color _fAccent = Color(0xFF8BC34A);
const Color _fWarm = Color(0xFFFF6A00);

Widget _fHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final FrontierLogic lg = logic as FrontierLogic;
  return Positioned.fill(
    child: Stack(children: <Widget>[
      if (!lg.over) Positioned(left: 8, right: 8, bottom: 8, child: _fBottom(lg, refresh)),
      if (!lg.over && lg.panel != 0) _fPanel(lg, refresh),
    ]),
  );
}

// ---- bottom HUD -------------------------------------------------------------

Widget _fBottom(FrontierLogic lg, VoidCallback refresh) {
  final int rd = lg.nextRaidDay;
  return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    SizedBox(
      height: 44,
      child: Row(children: <Widget>[
        Expanded(
          flex: 5,
          child: _fToolBtn(Icons.science_rounded, 'Research (${lg.knowledge})', const Color(0xFF4FC3F7), () {
            lg.openResearch();
            refresh();
          }),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: _fToolBtn(lg.speed == 1 ? Icons.play_arrow_rounded : Icons.fast_forward_rounded, lg.speed == 1 ? 'Speed x1' : 'Speed x2', const Color(0xFFFFD54F), () {
            lg.toggleSpeed();
            refresh();
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            'Raid on day $rd: strength ${lg.raidStrength(rd).round()}, your defence ${lg.defence.round()}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: lg.defence >= lg.raidStrength(rd) ? const Color(0xFFB9F6CA) : const Color(0xFFFF8A80), fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2, decoration: TextDecoration.none),
          ),
        ),
      ]),
    ),
    const SizedBox(height: 6),
    _fInfoCard(lg, refresh),
    const SizedBox(height: 6),
    SizedBox(
      height: 70,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: <Widget>[
          for (int t = 0; t < 8; t++) Padding(padding: const EdgeInsets.only(right: 6), child: _fBuildBtn(lg, t, refresh)),
        ]),
      ),
    ),
  ]);
}

Widget _fToolBtn(IconData icon, String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: const Color(0xCC101820), borderRadius: BorderRadius.circular(22), border: Border.all(color: color, width: 1.2)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, decoration: TextDecoration.none)),
        ),
      ]),
    ),
  );
}

Widget _fInfoCard(FrontierLogic lg, VoidCallback refresh) {
  final bool up = lg.canUpgradeSel();
  final List<int> uc = up ? lg.costOf(lg.bType[lg.sel], lg.bLevel[lg.sel]) : <int>[0, 0, 0];
  final bool afford = up && lg.canAfford(uc);
  return Container(
    height: 78,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xDD101820), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
    child: Row(children: <Widget>[
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Flexible(child: Text(lg.infoTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, decoration: TextDecoration.none))),
            if (lg.discount) const Text('  half price ready', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
          ]),
          const SizedBox(height: 2),
          Text(lg.infoBody, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ]),
      ),
      if (up) ...<Widget>[
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            lg.upgrade();
            refresh();
          },
          child: Container(
            width: 112,
            height: 54,
            decoration: BoxDecoration(color: afford ? _fWarm : Colors.white12, borderRadius: BorderRadius.circular(14)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              const Text('UPGRADE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, decoration: TextDecoration.none)),
              Text(_fCost(uc), style: TextStyle(color: afford ? Colors.white : const Color(0xFFFF8A80), fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            ]),
          ),
        ),
      ],
    ]),
  );
}

String _fCost(List<int> c) {
  final StringBuffer b = StringBuffer();
  if (c[0] > 0) b.write('${c[0]}w ');
  if (c[1] > 0) b.write('${c[1]}s ');
  if (c[2] > 0) b.write('${c[2]}c');
  return b.toString().trim();
}

Widget _fBuildBtn(FrontierLogic lg, int t, VoidCallback refresh) {
  final List<int> c = lg.costOf(t, 0);
  final bool afford = lg.canAfford(c);
  final bool fits = lg.sel >= 0 ? lg.canBuildHere(t) : true;
  return Opacity(
    opacity: fits ? 1.0 : 0.35,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        lg.build(t);
        refresh();
      },
      child: Container(
        width: 76,
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xDD101820),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fits && lg.sel >= 0 ? _fAccent : Colors.white24, width: fits && lg.sel >= 0 ? 1.6 : 1.0),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Icon(_fIcons[t], color: Colors.white, size: 22),
          Text(FrontierData.shortNames[t], maxLines: 1, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, decoration: TextDecoration.none)),
          Text(_fCost(c), maxLines: 1, style: TextStyle(color: afford ? Colors.white60 : const Color(0xFFFF8A80), fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
        ]),
      ),
    ),
  );
}

// ---- modal panels -----------------------------------------------------------

Widget _fPanel(FrontierLogic lg, VoidCallback refresh) {
  Widget body;
  switch (lg.panel) {
    case 1:
      body = _fOffer(lg, refresh);
      break;
    case 2:
      body = _fQuestion(lg, refresh, true);
      break;
    case 3:
      body = _fBlessing(lg, refresh);
      break;
    case 5:
      body = _fResearch(lg, refresh);
      break;
    case 6:
      body = _fQuestion(lg, refresh, false);
      break;
    default:
      body = const SizedBox.shrink();
      break;
  }
  return Positioned.fill(
    child: Container(
      color: const Color(0xAA000000),
      padding: const EdgeInsets.fromLTRB(14, 90, 14, 14),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: body),
        ),
      ),
    ),
  );
}

Widget _fCard(Color accent, List<Widget> children) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _fPanelBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: accent, width: 1.4)),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

Widget _fTitle(String s, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(s.toUpperCase(), style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1, decoration: TextDecoration.none)),
    );

Widget _fText(String s, {Color color = Colors.white70, double size = 13.5, bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(s, style: TextStyle(color: color, fontSize: size, height: 1.35, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, decoration: TextDecoration.none)),
    );

Widget _fButton(String label, VoidCallback onTap, {bool primary = true}) {
  return SizedBox(
    height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? _fWarm : Colors.white12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1, fontSize: 15)),
    ),
  );
}

Widget _fOffer(FrontierLogic lg, VoidCallback refresh) {
  final OdySubject sub = lg.content.subject(lg.councilSubject);
  return _fCard(_fAccent, <Widget>[
    _fTitle('Council of day ${lg.day}', _fAccent),
    for (final String r in lg.report) _fText(r, size: 12.5),
    const SizedBox(height: 6),
    _fText('The elders have a question about ${sub.label}. Answer well and choose a blessing for the town. Skip, and the town goes without.', color: Colors.white, bold: true),
    const SizedBox(height: 10),
    Row(children: <Widget>[
      Expanded(
        child: _fButton('SKIP', () {
          lg.councilSkip();
          refresh();
        }, primary: false),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _fButton('ANSWER', () {
          lg.councilAnswer();
          refresh();
        }),
      ),
    ]),
  ]);
}

Widget _fQuestion(FrontierLogic lg, VoidCallback refresh, bool council) {
  final OdyQuestion? q = lg.q;
  if (q == null) return const SizedBox.shrink();
  final OdySubject sub = lg.content.subject(lg.councilSubject);
  final String header = council ? 'Council: ${sub.label}' : 'Prove the theory: ${lg.resTech >= 0 ? FrontierData.techNames[lg.resTech] : ''}';
  return RealmQuestionPanel(
    question: q,
    accent: sub.color,
    header: header,
    chosen: lg.chosen,
    resultLine: lg.resultLine,
    continueLabel: council ? (lg.lastOk ? 'CHOOSE BLESSING' : 'CONTINUE') : 'CONTINUE',
    onPick: (int i) {
      if (council) {
        lg.councilPick(i);
      } else {
        lg.researchPick(i);
      }
      refresh();
    },
    onContinue: () {
      if (council) {
        lg.councilContinue();
      } else {
        lg.researchContinue();
      }
      refresh();
    },
  );
}

Widget _fBlessing(FrontierLogic lg, VoidCallback refresh) {
  return _fCard(const Color(0xFFFFD54F), <Widget>[
    _fTitle('Choose a blessing', const Color(0xFFFFD54F)),
    for (int k = 0; k < 4; k++)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            lg.chooseBlessing(k);
            refresh();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(FrontierData.blessingNames[k], style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, decoration: TextDecoration.none)),
              Text(FrontierData.blessingBlurbs[k], style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            ]),
          ),
        ),
      ),
  ]);
}

Widget _fResearch(FrontierLogic lg, VoidCallback refresh) {
  return _fCard(const Color(0xFF4FC3F7), <Widget>[
    _fTitle('Research', const Color(0xFF4FC3F7)),
    _fText('Knowledge: ${lg.knowledge}. Each theory must be proven with a correct answer before it is learned.', size: 12.5),
    const SizedBox(height: 4),
    for (int i = 0; i < 5; i++) _fTechRow(lg, i, refresh),
    const SizedBox(height: 4),
    _fButton('CLOSE', () {
      lg.closeResearch();
      refresh();
    }, primary: false),
  ]);
}

Widget _fTechRow(FrontierLogic lg, int i, VoidCallback refresh) {
  final bool done = lg.tech[i];
  final int cost = FrontierData.techCosts[i];
  final bool can = !done && lg.knowledge >= cost;
  String status;
  if (done) {
    status = 'Learned';
  } else if (can) {
    status = 'PROVE';
  } else {
    status = 'Needs $cost';
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: can
          ? () {
              lg.startResearch(i);
              refresh();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: done ? const Color(0x331B5E20) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: can ? const Color(0xFF4FC3F7) : Colors.white24, width: can ? 1.6 : 1.0),
        ),
        child: Row(children: <Widget>[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(FrontierData.techNames[i], style: TextStyle(color: done ? const Color(0xFF69F0AE) : Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, decoration: TextDecoration.none)),
              Text(FrontierData.techBlurbs[i], style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500, height: 1.25, decoration: TextDecoration.none)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(color: can ? const Color(0xFF4FC3F7) : (done ? const Color(0xFF69F0AE) : Colors.white54), fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, decoration: TextDecoration.none)),
        ]),
      ),
    ),
  );
}
