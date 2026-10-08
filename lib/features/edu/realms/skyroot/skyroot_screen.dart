import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'skyroot_logic.dart';
import 'skyroot_painter.dart';

const Color _acc = Color(0xFF4BD37B);
const Color _ink = Color(0xFF0F1B14);
const Color _good = Color(0xFF69F0AE);
const Color _bad = Color(0xFFFF8A80);

class SkyrootScreen extends StatelessWidget {
  const SkyrootScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Skyroot Frontier',
      gameId: 'skyroot',
      title: 'Skyroot Frontier',
      story: 'The great Skyroot tree is sick. A grey blight is creeping up from its roots, layer by layer, and the rains will fail if it reaches the crown. Climb the trunk, heal each layer with your knowledge of living things, and then drive the blight out of the crown.',
      howTo: 'Drag to climb the trunk and walk along the branches. Walk to a glowing station and press TEND to heal that layer. Check the blight bars on the right edge, and collect seed pods on the way.',
      icon: Icons.forest_rounded,
      accent: _acc,
      config: config,
      create: (RealmContent c) => SkyrootLogic(c),
      painter: (RealmLogic l, Listenable repaint) => SkyrootPainter(l as SkyrootLogic, repaint: repaint),
      hud: _skyHud,
      actions: const <RealmAction>[RealmAction(0, Icons.eco_rounded, 'TEND')],
      duelSeconds: 300,
      background: const Color(0xFF123D2B),
    );
  }
}

// ---------------------------------------------------------------------------

Widget _skyHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final SkyrootLogic g = logic as SkyrootLogic;
  final List<Widget> kids = <Widget>[];
  if (g.panel == 0 && !g.over) {
    final String? prompt = g.stationPrompt;
    if (prompt != null) kids.add(_promptBar(g, prompt));
    if (g.toastT > 0 && g.toastText.isNotEmpty) kids.add(_toast(g.toastText));
  }
  switch (g.panel) {
    case 1:
      kids.add(_waterPanel(g, refresh));
      break;
    case 2:
      kids.add(_cyclePanel(g, refresh));
      break;
    case 3:
      kids.add(_chainPanel(g, refresh));
      break;
    case 4:
      kids.add(_adaptPanel(g, refresh));
      break;
    case 5:
      kids.add(_bossPanel(g, refresh));
      break;
    case 6:
      kids.add(_summaryPanel(g, refresh));
      break;
    case 7:
      kids.add(_quietPanel(g, refresh));
      break;
    default:
      break;
  }
  return Positioned.fill(child: Stack(children: kids));
}

// ---- shared helpers ------------------------------------------------------------

Widget _barrier() => Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.62)));

BoxDecoration _cardDeco(Color border) => BoxDecoration(
      color: const Color(0xF2101A14),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border, width: 1.4),
    );

Widget _centered(Widget card) => Positioned.fill(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 70, 14, 20),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: card),
        ),
      ),
    );

Widget _title(String t, {double size = 22, Color color = Colors.white}) =>
    Text(t, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, color: color, letterSpacing: 1.2));

Widget _bigButton(String label, VoidCallback? onTap, {Color color = _acc, Color text = _ink}) {
  return SizedBox(
    height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.white12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      onPressed: onTap,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: onTap == null ? Colors.white38 : text, letterSpacing: 1)),
    ),
  );
}

Widget _sectionLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    );

Widget _hintLine(String h) {
  if (h.isEmpty) return const SizedBox(height: 4);
  return Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Text(h, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600)),
  );
}

Widget _promptBar(SkyrootLogic g, String text) {
  final bool ready = g.stationReady(g.nearIdx);
  return Positioned(
    left: 12,
    right: 104,
    bottom: 34,
    child: IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ready ? _acc : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ready ? Colors.white : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(ready ? Icons.eco_rounded : Icons.lock_rounded, size: 20, color: ready ? _ink : Colors.white54),
          const SizedBox(width: 8),
          Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: ready ? _ink : Colors.white70, letterSpacing: 0.4))),
        ]),
      ),
    ),
  );
}

Widget _toast(String t) => Positioned(
      left: 12,
      top: 132,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFE082))),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Icons.spa_rounded, size: 16, color: Color(0xFFFFE082)),
            const SizedBox(width: 6),
            Text(t, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );

/// The common frame of a task panel: dark barrier, card, header and a close button.
Widget _frame(SkyrootLogic g, VoidCallback refresh, {required IconData icon, required String title, required String sub, required List<Widget> body, bool closable = true}) {
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(_acc),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Row(children: <Widget>[
            Icon(icon, color: _acc, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white, letterSpacing: 1)),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.25)),
              ]),
            ),
            if (closable)
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () {
                    g.closePanel();
                    refresh();
                  },
                ),
              ),
          ]),
          const SizedBox(height: 10),
          ...body,
        ]),
      )),
    ]),
  );
}

Widget _shaken(SkyrootLogic g, int key, Widget child) => Transform.translate(offset: Offset(g.shakeOffset(key), 0), child: child);

/// A tap target with a text, which can be marked wrong (red) or locked right (green).
Widget _choice(SkyrootLogic g, int key, String text, {bool wrong = false, bool right = false, VoidCallback? onTap}) {
  Color bg = Colors.white10;
  Color border = Colors.white24;
  if (right) {
    bg = const Color(0xFF1B5E20).withValues(alpha: 0.7);
    border = _good;
  } else if (wrong) {
    bg = const Color(0xFFB71C1C).withValues(alpha: 0.5);
    border = _bad;
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: _shaken(
      g,
      key,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (wrong || right) ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Row(children: <Widget>[
            if (right) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle_rounded, color: _good, size: 20)),
            Expanded(child: Text(text, style: TextStyle(color: wrong ? Colors.white54 : Colors.white, fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    ),
  );
}

// ---- 1 water test -----------------------------------------------------------------

Widget _reading(String label, double v, double lo, double hi, double safeLo, double safeHi, String valueText) {
  final double f = ((v - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
  final double sl = ((safeLo - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
  final double sh = ((safeHi - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
  final bool safe = v >= safeLo && v <= safeHi;
  final Color col = safe ? const Color(0xFF66BB6A) : const Color(0xFFFF7043);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: <Widget>[
      SizedBox(width: 78, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
      Expanded(
        child: LayoutBuilder(builder: (BuildContext c, BoxConstraints cons) {
          final double w = cons.maxWidth;
          return SizedBox(
            height: 18,
            child: Stack(children: <Widget>[
              Container(decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(5))),
              Positioned(left: w * sl, width: w * (sh - sl), top: 0, bottom: 0, child: Container(color: const Color(0xFF66BB6A).withValues(alpha: 0.28))),
              Positioned(left: 0, width: (w * f < 6 ? 6.0 : w * f), top: 4, bottom: 4, child: Container(decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)))),
            ]),
          );
        }),
      ),
      SizedBox(width: 62, child: Text(valueText, textAlign: TextAlign.right, style: TextStyle(color: col, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15))),
    ]),
  );
}

Widget _stripCard(SkyWater w) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF5F0DC).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(w.site.toUpperCase(), style: const TextStyle(color: _acc, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      _reading('pH', w.ph, 0, 14, 6.5, 8.5, w.ph.toStringAsFixed(1)),
      _reading('Nitrate', w.nitrate, 0, 50, 0, 10, '${w.nitrate.round()} mg/L'),
      _reading('Cloudiness', w.turbidity, 0, 100, 0, 25, '${w.turbidity.round()} NTU'),
      const SizedBox(height: 2),
      const Text('The green band on each bar is the safe range.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
    ]),
  );
}

Widget _waterPanel(SkyrootLogic g, VoidCallback refresh) {
  final SkyWater? w = g.water;
  if (w == null) return const SizedBox.shrink();
  final List<Widget> body = <Widget>[
    _stripCard(w),
    const SizedBox(height: 8),
    Text(w.note, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
    const SizedBox(height: 10),
  ];
  if (g.waterStage == 0) {
    body.add(_sectionLabel('1. WHAT IS MOST LIKELY POLLUTING THE WATER?'));
    for (int i = 0; i < g.waterSrcOpts.length; i++) {
      body.add(_choice(g, i, g.waterSrcOpts[i], wrong: g.waterWrong.contains(i), onTap: () {
        g.waterPick(i);
        refresh();
      }));
    }
    body.add(_hintLine(g.hint));
  } else {
    body.add(_choice(g, -1, g.waterSrcOpts[g.waterSrcAns], right: true));
    if (g.waterStage == 1) {
      body.add(_sectionLabel('2. WHAT IS THE BEST FIX?'));
      for (int i = 0; i < g.waterFixOpts.length; i++) {
        body.add(_choice(g, i, g.waterFixOpts[i], wrong: g.waterWrong.contains(i), onTap: () {
          g.waterPick(i);
          refresh();
        }));
      }
      body.add(_hintLine(g.hint));
    } else {
      body.add(_choice(g, -1, g.waterFixOpts[g.waterFixAns], right: true));
      body.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(w.why, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
      ));
      body.add(_bigButton('HEAL THE STREAM', () {
        g.waterFinish();
        refresh();
      }));
    }
  }
  return _frame(g, refresh, icon: Icons.water_drop_rounded, title: 'WATER TEST', sub: 'Read the strip, find the cause, choose the cure.', body: body);
}

// ---- 2 nutrient cycle -------------------------------------------------------------

const List<Color> _roleColors = <Color>[Color(0xFF66BB6A), Color(0xFFFFB74D), Color(0xFFBA8FD6)];

Widget _cyclePanel(SkyrootLogic g, VoidCallback refresh) {
  final List<Widget> body = <Widget>[];
  body.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
    for (int i = 0; i < g.cycItems.length; i++)
      Container(
        width: 26,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: i < g.cycResults.length ? (g.cycResults[i] ? _good : const Color(0xFFFFB74D)) : (i == g.cycIdx ? Colors.white : Colors.white24),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
  ]));
  body.add(const SizedBox(height: 10));
  if (!g.cycDone) {
    final SkyOrg o = g.cycItems[g.cycIdx];
    body.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
      child: Column(children: <Widget>[
        const Text('WHAT IS IT IN THE FOREST?', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(o.name, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white, height: 1.1)),
      ]),
    ));
    body.add(const SizedBox(height: 10));
    for (int r = 0; r < 3; r++) {
      body.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _shaken(
          g,
          r,
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: g.cycWrong.contains(r) ? Colors.white12 : _roleColors[r],
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: g.cycWrong.contains(r)
                  ? null
                  : () {
                      g.cyclePick(r);
                      refresh();
                    },
              child: Text(skyRoleNames[r], style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: _ink, letterSpacing: 1.5, fontSize: 16)),
            ),
          ),
        ),
      ));
    }
    body.add(_hintLine(g.hint));
  } else {
    body.add(const Text('Every organism sorted. The cycle turns again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)));
    body.add(const SizedBox(height: 10));
    body.add(_bigButton('FEED THE SOIL', () {
      g.cycleFinish();
      refresh();
    }));
  }
  if (g.cycLast.isNotEmpty) {
    body.add(const SizedBox(height: 8));
    body.add(Text(g.cycLast, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)));
  }
  return _frame(g, refresh, icon: Icons.sync_rounded, title: 'NUTRIENT CYCLE', sub: 'Tap PRODUCER, CONSUMER or DECOMPOSER for each one.', body: body);
}

// ---- 3 food chain ------------------------------------------------------------------

const List<Offset> _chainSlots = <Offset>[Offset(0.00, 0.02), Offset(0.54, 0.10), Offset(0.06, 0.38), Offset(0.52, 0.52), Offset(0.26, 0.76)];

Widget _popBars(SkyrootLogic g, int code, String a, String lost, String b) {
  final bool aUp = (code & 1) != 0;
  final bool bUp = (code & 2) != 0;
  Widget col(String name, double target, IconData? arrow, Color c) {
    return SizedBox(
      width: 46,
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        SizedBox(height: 14, child: arrow == null ? null : Icon(arrow, size: 14, color: c)),
        SizedBox(
          height: 46,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 24, end: target),
              duration: const Duration(milliseconds: 700),
              builder: (BuildContext ctx, double v, Widget? ch) => Container(width: 18, height: v, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            ),
          ),
        ),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 9)),
      ]),
    );
  }

  return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
    col(a, aUp ? 44 : 10, aUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, aUp ? _good : _bad),
    col(lost, 2, Icons.close_rounded, Colors.white54),
    col(b, bUp ? 44 : 10, bUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, bUp ? _good : _bad),
  ]);
}

Widget _chainPanel(SkyrootLogic g, VoidCallback refresh) {
  final SkyChain? c = g.chain;
  if (c == null) return const SizedBox.shrink();
  final List<Widget> body = <Widget>[];
  if (g.chnStage == 0) {
    body.add(const Text('Tap the living things in the order energy flows, starting with the producer.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600)));
    body.add(const SizedBox(height: 8));
    body.add(LayoutBuilder(builder: (BuildContext ctx, BoxConstraints cons) {
      const double cw = 138;
      const double ch = 50;
      const double areaH = 250;
      final double w = cons.maxWidth;
      return SizedBox(
        height: areaH,
        child: Stack(children: <Widget>[
          for (int s = 0; s < 5; s++)
            Positioned(
              left: _chainSlots[s].dx * (w - cw),
              top: _chainSlots[s].dy * (areaH - ch),
              width: cw,
              height: ch,
              child: _shaken(
                g,
                s,
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    g.chainTap(s);
                    refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: g.chnTaken[s] != 0 ? const Color(0xFF1B5E20).withValues(alpha: 0.75) : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: g.chnTaken[s] != 0 ? _good : Colors.white38, width: 1.4),
                    ),
                    child: Row(children: <Widget>[
                      if (g.chnTaken[s] != 0)
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: _good, shape: BoxShape.circle),
                          child: Text('${g.chnTaken[s]}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      Expanded(child: Text(c.names[g.chnPerm[s]], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.1))),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
    }));
    body.add(_hintLine(g.hint));
  } else {
    body.add(Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: _good)),
      child: Text(c.names.join('  >  '), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3)),
    ));
    body.add(const SizedBox(height: 10));
    body.add(_sectionLabel('WHAT HAPPENS TO THE POPULATIONS?'));
    body.add(Text(g.chnQuestion, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600)));
    body.add(const SizedBox(height: 8));
    final String a = c.names[g.chnRemoved - 1];
    final String lost = c.names[g.chnRemoved];
    final String b = c.names[g.chnRemoved + 1];
    for (int i = 0; i < g.chnOpts.length; i++) {
      final int code = g.chnOpts[i];
      final bool wrong = g.chnWrong.contains(i);
      final bool right = g.chnStage == 2 && code == 1;
      Color bg = Colors.white10;
      Color border = Colors.white24;
      if (right) {
        bg = const Color(0xFF1B5E20).withValues(alpha: 0.7);
        border = _good;
      } else if (wrong) {
        bg = const Color(0xFFB71C1C).withValues(alpha: 0.45);
        border = _bad;
      }
      body.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _shaken(
          g,
          20 + i,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (wrong || g.chnStage != 1)
                ? null
                : () {
                    g.chainPick(i);
                    refresh();
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Row(children: <Widget>[
                Expanded(child: Text(g.chnOptionText(code), style: TextStyle(color: wrong ? Colors.white54 : Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                _popBars(g, code, a, lost, b),
              ]),
            ),
          ),
        ),
      ));
    }
    if (g.chnStage == 1) {
      body.add(_hintLine(g.hint));
    } else {
      body.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(g.hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
      ));
      body.add(_bigButton('RESTORE THE WEB', () {
        g.chainFinish();
        refresh();
      }));
    }
  }
  return _frame(g, refresh, icon: Icons.hub_rounded, title: 'FOOD CHAIN', sub: g.chnStage == 0 ? 'Put the five species in order.' : 'Predict what changes when one species is lost.', body: body);
}

// ---- 4 adaptations --------------------------------------------------------------------

Widget _adaptCard(SkyrootLogic g, int key, String text, {required bool locked, required bool selected, required VoidCallback onTap, IconData? icon}) {
  Color bg = Colors.white12;
  Color border = Colors.white30;
  if (locked) {
    bg = const Color(0xFF1B5E20).withValues(alpha: 0.7);
    border = _good;
  } else if (selected) {
    bg = _acc.withValues(alpha: 0.28);
    border = _acc;
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: _shaken(
      g,
      key,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: selected ? 2 : 1.2)),
          child: Row(children: <Widget>[
            if (locked) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.check_circle_rounded, color: _good, size: 16)),
            if (!locked && icon != null) Padding(padding: const EdgeInsets.only(right: 5), child: Icon(icon, color: Colors.white54, size: 16)),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    ),
  );
}

Widget _adaptPanel(SkyrootLogic g, VoidCallback refresh) {
  if (g.adPairs.isEmpty) return const SizedBox.shrink();
  final List<Widget> body = <Widget>[
    const Text('Tap an animal or plant, then tap the trait that fits it. Right pairs lock green.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Expanded(
        child: Column(children: <Widget>[
          for (int i = 0; i < g.adPairs.length; i++)
            _adaptCard(g, i, g.adPairs[i].who, locked: g.adLocked[i], selected: g.adSel == i, icon: Icons.pets_rounded, onTap: () {
              g.adaptTapAnimal(i);
              refresh();
            }),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(children: <Widget>[
          for (int s = 0; s < g.adTraitOrder.length; s++)
            _adaptCard(g, 10 + s, g.adPairs[g.adTraitOrder[s]].trait, locked: g.adTraitLocked[s], selected: false, onTap: () {
              g.adaptTapTrait(s);
              refresh();
            }),
        ]),
      ),
    ]),
    _hintLine(g.hint),
  ];
  if (g.adDone) {
    body.add(const SizedBox(height: 4));
    body.add(_bigButton('WAKE THE CANOPY', () {
      g.adaptFinish();
      refresh();
    }));
  }
  return _frame(g, refresh, icon: Icons.category_rounded, title: 'ADAPTATIONS', sub: 'Match each living thing to the trait that helps it live.', body: body);
}

// ---- 5 boss ------------------------------------------------------------------------------

Widget _bossPanel(SkyrootLogic g, VoidCallback refresh) {
  final OdyQuestion? q = g.bossQ;
  if (q == null) return const SizedBox.shrink();
  final bool answered = g.bossChosen != null;
  String cont = 'NEXT QUESTION';
  if (g.bossCleared >= 5) cont = 'CLEAR THE CROWN';
  if (g.bossLeaves <= 0) cont = 'CONTINUE';
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDeco(const Color(0xFFB0A89A)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Row(children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD7CCC8), size: 24),
              const SizedBox(width: 8),
              const Expanded(child: Text('THE BLIGHT BOSS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 19, color: Colors.white, letterSpacing: 1.2))),
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.eco_rounded, size: 26, color: i < g.bossLeaves ? _good : Colors.white24),
                ),
              if (!answered)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () {
                      g.closePanel();
                      refresh();
                    },
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: <Widget>[
              for (int i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: i < g.bossCleared ? _good : const Color(0xFF5D5750), borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text('${g.bossCleared} of 5 fifths of the crown are clear. Blight ${g.blight[4].round()}%.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(height: 8),
        RealmQuestionPanel(
          question: q,
          accent: _acc,
          header: 'Fifth ${g.bossCleared >= 5 ? 5 : g.bossCleared + 1} of 5',
          chosen: g.bossChosen,
          resultLine: g.bossResult,
          onPick: (int i) {
            g.bossAnswer(i);
            refresh();
          },
          onContinue: () {
            g.bossContinue();
            refresh();
          },
          continueLabel: cont,
        ),
      ])),
    ]),
  );
}

// ---- summary and ending -------------------------------------------------------------------

Widget _summaryPanel(SkyrootLogic g, VoidCallback refresh) {
  final Color col = g.sumGood ? _good : const Color(0xFFFFB74D);
  String label = 'CONTINUE CLIMBING';
  if (g.bossWon) label = 'FINISH';
  if (!g.sumGood) label = 'CLIMB DOWN';
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(col),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Icon(g.sumGood ? Icons.local_florist_rounded : Icons.warning_amber_rounded, color: col, size: 40),
          const SizedBox(height: 6),
          _title(g.sumTitle, size: 24, color: col),
          const SizedBox(height: 10),
          Text(g.sumBody, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 8),
          Text(g.sumLine, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.3)),
          if (g.sumPoints > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text('+${g.sumPoints} points', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: col)),
          ],
          const SizedBox(height: 14),
          _bigButton(label, () {
            g.closeSummary();
            refresh();
          }, color: col),
        ]),
      )),
    ]),
  );
}

Widget _quietPanel(SkyrootLogic g, VoidCallback refresh) {
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(const Color(0xFFB0A89A)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          const Icon(Icons.forest_rounded, color: Color(0xFFB0A89A), size: 40),
          const SizedBox(height: 6),
          _title('THE CANOPY WENT QUIET', size: 22, color: const Color(0xFFD7CCC8)),
          const SizedBox(height: 10),
          const Text('The blight reached the crown and the birds fell silent. The tree still stands, and what you learned about living things will help it heal. Your score is saved.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 8),
          Text('Layers bloomed: ${g.layersBloomed} of 4.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
          const SizedBox(height: 14),
          _bigButton('SEE RESULT', () {
            g.closeQuiet();
            refresh();
          }, color: const Color(0xFFB0A89A)),
        ]),
      )),
    ]),
  );
}
