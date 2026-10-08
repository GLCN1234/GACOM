import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'signal_boards.dart';
import 'signal_logic.dart';

const Color _ink = Color(0xFF14161C);
const Color _good = Color(0xFF69F0AE);
const Color _bad = Color(0xFFFF8A80);

Color sgKindColor(SKind k) {
  switch (k) {
    case SKind.forward:
      return const Color(0xFF4FC3F7);
    case SKind.left:
    case SKind.right:
      return const Color(0xFFBA68C8);
    case SKind.act:
      return const Color(0xFFFFD54F);
    case SKind.rep:
      return const Color(0xFF81C784);
    case SKind.iff:
      return const Color(0xFFFF8A65);
  }
}

IconData sgKindIcon(SKind k) {
  switch (k) {
    case SKind.forward:
      return Icons.arrow_upward_rounded;
    case SKind.left:
      return Icons.rotate_left_rounded;
    case SKind.right:
      return Icons.rotate_right_rounded;
    case SKind.act:
      return Icons.bolt_rounded;
    case SKind.rep:
      return Icons.repeat_rounded;
    case SKind.iff:
      return Icons.call_split_rounded;
  }
}

const List<String> _palLabels = <String>['FORWARD', 'LEFT', 'RIGHT', 'ACTIVATE', 'REPEAT', 'IF WALL'];

// ---------------------------------------------------------------------------

/// The Signal Ridge HUD: route map panel, puzzle panels and the key question.
Widget signalHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final SignalLogic g = logic as SignalLogic;
  final EdgeInsets pad = MediaQuery.of(context).viewPadding;
  g.safeTop = pad.top;
  g.safeBottom = pad.bottom;
  final List<Widget> kids = <Widget>[];
  if (g.phase == 0) {
    kids.add(_mapPanel(g, refresh));
  } else if (g.phase == 1) {
    kids.add(_puzzlePanel(g, refresh));
  } else if (g.phase == 3) {
    kids.add(_keyOverlay(g, refresh));
  }
  return Positioned.fill(child: Stack(children: kids));
}

VoidCallback _do(VoidCallback f, VoidCallback refresh) => () {
      f();
      refresh();
    };

Widget _dock(Widget child, {double height = SignalLogic.panelH}) => Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height + 4,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            height: height,
            margin: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xEB0E1018),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sgAccentColor.withValues(alpha: 0.7), width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );

Widget _btn(String label, VoidCallback? onTap, {IconData? icon, Color color = sgAccentColor, Color fg = _ink, double height = 44, bool glow = false}) {
  final bool on = onTap != null;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: on ? color : Colors.white12,
        borderRadius: BorderRadius.circular(14),
        boxShadow: glow && on ? <BoxShadow>[BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        if (icon != null) Icon(icon, size: 18, color: on ? fg : Colors.white38),
        if (icon != null) const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: 0.6, color: on ? fg : Colors.white38),
          ),
        ),
      ]),
    ),
  );
}

Widget _tiny(String label, VoidCallback onTap, Color color) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: SizedBox(width: 58, child: _btn(label, onTap, color: color, fg: Colors.white, height: 38)),
    );

Widget _status(SignalLogic g, VoidCallback refresh, String fallback, {Widget? lead, double height = 38, int lines = 2}) {
  final String text = g.msg.isNotEmpty ? g.msg : fallback;
  final Color c = g.msg.isEmpty ? Colors.white70 : (g.msgGood ? _good : _bad);
  return SizedBox(
    height: height,
    child: Row(children: <Widget>[
      if (lead != null) ...<Widget>[lead, const SizedBox(width: 8)],
      Expanded(
        child: Text(text, maxLines: lines, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w700)),
      ),
      if (g.fails >= 3 && g.kind != 1 && !g.solved && !g.running) _tiny('SHOW', _do(g.showSolution, refresh), const Color(0xFF3F51B5)),
      if (g.fails >= 4 && !g.solved && !g.running) _tiny('SKIP', _do(g.skipStage, refresh), const Color(0xFFB71C1C)),
    ]),
  );
}

Widget _puzzlePanel(SignalLogic g, VoidCallback refresh) {
  if (g.solved) return _clearPanel(g, refresh);
  if (g.kind == 1) return _circuitPanel(g, refresh);
  if (g.kind == 2) return _debugPanel(g, refresh);
  return _botPanel(g, refresh);
}

// ---- map ------------------------------------------------------------------------------

Widget _mapPanel(SignalLogic g, VoidCallback refresh) {
  final int s = g.stage.clamp(0, 5).toInt();
  return _dock(
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text('RIDGE ${s + 1}  -  ${sgStageNames[s].toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: 1.2, color: sgAccentColor)),
      const SizedBox(height: 4),
      Expanded(
        child: Text(sgStageBlurbs[s], maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
      ),
      _btn('START RIDGE ${s + 1}', _do(g.startStage, refresh), icon: Icons.cell_tower_rounded, height: 48, glow: true),
    ]),
    height: 150,
  );
}

// ---- clear -----------------------------------------------------------------------------

Widget _clearPanel(SignalLogic g, VoidCallback refresh) {
  final SBoard? b = g.board;
  String detail = '';
  if (g.kind == 0 && b != null) detail = 'Blocks used: ${g.used}   Goal: ${b.par}   Budget: ${b.allowed}';
  if (g.kind == 1) detail = 'Fewest switches ON: ${g.minOn}';
  if (g.kind == 2) detail = g.msg;
  return _dock(
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text('RIDGE ${g.stage + 1} CLEARED', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 1.5, color: _good)),
      const SizedBox(height: 2),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        for (int i = 0; i < 3; i++) Icon(i < g.starsNow ? Icons.star_rounded : Icons.star_border_rounded, size: 38, color: i < g.starsNow ? sgGold : Colors.white30),
      ]),
      Expanded(
        child: Center(
          child: Text(detail, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
        ),
      ),
      _btn('CONTINUE', _do(g.continueFromClear, refresh), icon: Icons.vpn_key_rounded, height: 48, glow: true),
    ]),
  );
}

// ---- bot programming ---------------------------------------------------------------------

Widget _botPanel(SignalLogic g, VoidCallback refresh) {
  final SBoard? b = g.board;
  final int u = g.used;
  final int par = b?.par ?? 0;
  final int allowed = b?.allowed ?? 0;
  final Color uc = u <= par ? _good : (u <= allowed ? sgGold : _bad);
  final Widget lead = Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
    const Text('BLOCKS', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    Text('$u/$allowed', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 19, color: uc)),
  ]);
  final String fallback = (b != null && b.fog) ? 'Fog hides the ridge. Use IF and REPEAT, then RUN.' : 'Tap blocks to build the program, then press RUN.';
  final _SC sc = _SC(g, refresh, g.tapBlock, true, g.sel);
  return _dock(
    Column(children: <Widget>[
      _status(g, refresh, fallback, lead: lead),
      _strip(sc, g.program, 84),
      const SizedBox(height: 4),
      _palette(g, refresh),
      const SizedBox(height: 4),
      _controls(g, refresh),
    ]),
  );
}

class _SC {
  final SignalLogic g;
  final VoidCallback refresh;
  final void Function(SBlock) onTap;
  final bool cursor;
  final SBlock? selBlock;
  const _SC(this.g, this.refresh, this.onTap, this.cursor, this.selBlock);
}

Widget _strip(_SC sc, List<SBlock> prog, double height) {
  return Container(
    height: height,
    width: double.infinity,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
    child: LayoutBuilder(builder: (BuildContext c, BoxConstraints cons) {
      return SingleChildScrollView(child: SizedBox(width: cons.maxWidth, child: _list(sc, prog, null, 0, cons.maxWidth)));
    }),
  );
}

Widget _list(_SC sc, List<SBlock> list, SBlock? owner, int branch, double maxW) {
  final SignalLogic g = sc.g;
  final bool isTarget = sc.cursor && identical(g.tgtOwner, owner) && g.tgtBranch == branch;
  final List<Widget> kids = <Widget>[];
  for (final SBlock b in list) {
    kids.add(b.isContainer ? _container(sc, b, maxW) : _chip(sc, b));
  }
  if (sc.cursor) kids.add(_endChip(sc, owner, branch, isTarget, list.isEmpty));
  return Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: kids);
}

Widget _endChip(_SC sc, SBlock? owner, int branch, bool isTarget, bool empty) {
  final SignalLogic g = sc.g;
  final bool blink = (g.time * 2).floor() % 2 == 0;
  String label = owner == null ? 'END' : 'add here';
  if (owner == null && empty) label = 'Tap blocks below to build here';
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      g.setTarget(owner, branch);
      sc.refresh();
    },
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isTarget ? sgAccentColor.withValues(alpha: 0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isTarget ? sgAccentColor : Colors.white24, width: isTarget ? 1.8 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Container(width: 3, height: 18, margin: const EdgeInsets.only(right: 6), color: isTarget ? sgAccentColor.withValues(alpha: blink ? 1.0 : 0.25) : Colors.transparent),
        Text(label, style: TextStyle(color: isTarget ? sgAccentColor : Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

Widget _chip(_SC sc, SBlock b) {
  final SignalLogic g = sc.g;
  final Color c = sgKindColor(b.kind);
  final bool active = g.isActive(b);
  final bool selected = identical(sc.selBlock, b);
  final bool hinted = identical(g.hintBad, b) || g.hintRegion.contains(b);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      sc.onTap(b);
      sc.refresh();
    },
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: active ? c : c.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hinted ? _bad : (selected ? Colors.white : c), width: (hinted || selected || active) ? 2.4 : 1.2),
        boxShadow: active ? <BoxShadow>[BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 10)] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(sgKindIcon(b.kind), size: 16, color: active ? _ink : realmLighten(c, 0.12)),
        const SizedBox(width: 4),
        Text(sgName(b.kind), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: active ? _ink : Colors.white)),
      ]),
    ),
  );
}

Widget _stepBtn(IconData icon, VoidCallback f) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );

Widget _container(_SC sc, SBlock b, double maxW) {
  final SignalLogic g = sc.g;
  final Color c = sgKindColor(b.kind);
  final bool active = g.isActive(b);
  final bool selected = identical(sc.selBlock, b);
  final bool hinted = identical(g.hintBad, b) || g.hintRegion.contains(b);
  final bool rep = b.kind == SKind.rep;
  final Widget title = GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      sc.onTap(b);
      sc.refresh();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(sgKindIcon(b.kind), size: 16, color: realmLighten(c, 0.12)),
        const SizedBox(width: 4),
        Text(rep ? 'REPEAT' : 'IF WALL AHEAD', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
      ]),
    ),
  );
  final List<Widget> header = <Widget>[title];
  if (rep) {
    if (sc.cursor) {
      header.add(const SizedBox(width: 8));
      header.add(_stepBtn(Icons.remove_rounded, () {
        g.changeCount(b, -1);
        sc.refresh();
      }));
      header.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${b.n}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white))));
      header.add(_stepBtn(Icons.add_rounded, () {
        g.changeCount(b, 1);
        sc.refresh();
      }));
      header.add(const SizedBox(width: 6));
      header.add(const Text('times', style: TextStyle(color: Colors.white60, fontSize: 12)));
    } else {
      header.add(Padding(padding: const EdgeInsets.only(left: 8), child: Text('${b.n} times', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))));
    }
  }
  final double inner = maxW - 22;
  final List<Widget> kids = <Widget>[
    Row(crossAxisAlignment: CrossAxisAlignment.center, children: header),
    if (!rep) _branchLabel(sc, b, 0, 'THEN'),
    _list(sc, b.body, b, 0, inner),
    if (!rep) ...<Widget>[
      const SizedBox(height: 4),
      _branchLabel(sc, b, 1, 'ELSE'),
      _list(sc, b.els, b, 1, inner),
    ],
  ];
  return SizedBox(
    width: maxW,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 6, 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: active ? 0.38 : 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hinted ? _bad : (selected ? Colors.white : c), width: (hinted || selected || active) ? 2.4 : 1.2),
        boxShadow: active ? <BoxShadow>[BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 10)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
    ),
  );
}

Widget _branchLabel(_SC sc, SBlock b, int branch, String text) {
  final bool on = sc.cursor && identical(sc.g.tgtOwner, b) && sc.g.tgtBranch == branch;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      sc.g.setTarget(b, branch);
      sc.refresh();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(text, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: on ? sgAccentColor : Colors.white60)),
    ),
  );
}

Widget _palette(SignalLogic g, VoidCallback refresh) {
  const List<SKind> kinds = <SKind>[SKind.forward, SKind.left, SKind.right, SKind.act, SKind.rep, SKind.iff];
  return SizedBox(
    height: 46,
    child: Row(children: <Widget>[
      for (int i = 0; i < kinds.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _palBtn(g, refresh, kinds[i], _palLabels[i]),
          ),
        ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _palCell(Icons.delete_rounded, 'DELETE', const Color(0xFFEF5350), g.editable, false, _do(g.deleteSelected, refresh)),
        ),
      ),
    ]),
  );
}

Widget _palBtn(SignalLogic g, VoidCallback refresh, SKind k, String label) {
  final bool on = g.editable && g.kindAllowed(k);
  final bool hint = g.hintKind == k;
  return _palCell(sgKindIcon(k), label, sgKindColor(k), on, hint, on ? () {
    g.addBlock(k);
    refresh();
  } : null);
}

Widget _palCell(IconData icon, String label, Color c, bool on, bool hint, VoidCallback? tap) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: on ? tap : null,
    child: Container(
      decoration: BoxDecoration(
        color: on ? c.withValues(alpha: 0.28) : Colors.white10,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: hint ? Colors.white : (on ? c : Colors.white12), width: hint ? 2.8 : 1.3),
        boxShadow: hint ? <BoxShadow>[BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 12)] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(icon, size: 19, color: on ? Colors.white : Colors.white24),
        const SizedBox(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: on ? Colors.white70 : Colors.white24))),
        ),
      ]),
    ),
  );
}

Widget _controls(SignalLogic g, VoidCallback refresh) {
  final bool run = g.running;
  return SizedBox(
    height: 44,
    child: Row(children: <Widget>[
      Expanded(flex: 3, child: _btn(run ? 'STOP' : 'RUN', _do(g.runPressed, refresh), icon: run ? Icons.stop_rounded : Icons.play_arrow_rounded, color: run ? const Color(0xFFEF5350) : sgAccentColor, fg: run ? Colors.white : _ink, glow: !run)),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: _btn(g.speedIdx == 0 ? '1x' : '2x', _do(g.toggleSpeed, refresh), icon: Icons.fast_forward_rounded, color: Colors.white24, fg: Colors.white)),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: _btn('STEP', _do(g.stepPressed, refresh), color: Colors.white24, fg: Colors.white)),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: _btn('HINT', run ? null : _do(g.useHint, refresh), color: sgGold)),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: _btn('CLEAR', g.editable ? _do(g.clearAll, refresh) : null, color: Colors.white24, fg: Colors.white)),
    ]),
  );
}

// ---- debug ---------------------------------------------------------------------------------

Widget _debugPanel(SignalLogic g, VoidCallback refresh) {
  final List<SBlock> flat = sgFlatten(g.program);
  SBlock? selBlock;
  if (g.dbgSel >= 0 && g.dbgSel < flat.length && g.runState == 0) selBlock = flat[g.dbgSel];
  final _SC sc = _SC(g, refresh, g.tapDebugBlock, false, selBlock);
  final bool picking = g.dbgSel >= 0 && g.runState == 0 && g.dbgOptions.isNotEmpty;
  Widget middle;
  if (picking) {
    middle = Row(children: <Widget>[
      for (int i = 0; i < g.dbgOptions.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                g.chooseFix(i);
                refresh();
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: sgAccentColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12), border: Border.all(color: sgAccentColor, width: 1.4)),
                child: Text(g.dbgOptions[i].label, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
    ]);
  } else {
    middle = Center(
      child: Text(g.running ? 'Testing the program...' : 'Tap the block you think is wrong.', style: const TextStyle(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
  return _dock(
    Column(children: <Widget>[
      _status(g, refresh, 'One block is wrong. The goal is to switch on every ringed tower.'),
      _strip(sc, g.shownProgram, 84),
      const SizedBox(height: 4),
      SizedBox(height: 52, child: middle),
      const SizedBox(height: 4),
      SizedBox(
        height: 44,
        child: Row(children: <Widget>[
          Expanded(flex: 3, child: _btn(g.running ? 'RUNNING' : 'WATCH IT RUN', g.running ? null : _do(g.watchBuggy, refresh), icon: Icons.play_arrow_rounded, color: Colors.white24, fg: Colors.white)),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _btn('HINT', g.running ? null : _do(g.useHint, refresh), color: sgGold)),
        ]),
      ),
    ]),
  );
}

// ---- circuit ---------------------------------------------------------------------------------

Widget _circuitPanel(SignalLogic g, VoidCallback refresh) {
  final List<Widget> kids = <Widget>[];
  if (g.bSub < 2) {
    kids.add(_status(g, refresh, 'The switches are set. Work out each gate, then predict the lamp.', height: 70, lines: 4));
    kids.add(const Spacer());
    if (!g.predAnswered) {
      kids.add(SizedBox(
        height: 56,
        child: Row(children: <Widget>[
          Expanded(child: _btn('LAMP ON', _do(() => g.answerPredict(true), refresh), icon: Icons.lightbulb_rounded, color: sgGold, height: 56)),
          const SizedBox(width: 8),
          Expanded(child: _btn('LAMP OFF', _do(() => g.answerPredict(false), refresh), icon: Icons.lightbulb_outline_rounded, color: Colors.white24, fg: Colors.white, height: 56)),
        ]),
      ));
      kids.add(const SizedBox(height: 6));
      kids.add(SizedBox(height: 44, child: _btn('HINT', _do(g.useHint, refresh), color: sgGold)));
    } else {
      kids.add(_btn(g.predCorrect ? 'NEXT' : 'TRY AGAIN', _do(g.nextPredict, refresh), icon: Icons.play_arrow_rounded, height: 52, glow: true));
    }
  } else {
    kids.add(_status(g, refresh, 'Tap the switches on the diagram. Light the lamp with as few switches ON as you can.', height: 60, lines: 3));
    kids.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        Text('Switches ON: ${g.onCount}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        Text((g.circ2?.lamp(g.sw) ?? false) ? 'Lamp: ON' : 'Lamp: OFF', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: (g.circ2?.lamp(g.sw) ?? false) ? sgGold : Colors.white54)),
      ]),
    ));
    kids.add(const Spacer());
    if (g.makePending) {
      kids.add(SizedBox(
        height: 52,
        child: Row(children: <Widget>[
          Expanded(child: _btn('KEEP IT', _do(g.keepMake, refresh), color: Colors.white24, fg: Colors.white, height: 52)),
          const SizedBox(width: 8),
          Expanded(child: _btn('TRY FEWER', _do(g.tryFewer, refresh), glow: true, height: 52)),
        ]),
      ));
    } else {
      final bool lit = g.circ2?.lamp(g.sw) ?? false;
      kids.add(SizedBox(
        height: 52,
        child: Row(children: <Widget>[
          Expanded(flex: 3, child: _btn('LIGHT IT', lit ? _do(g.makeSubmit, refresh) : null, icon: Icons.lightbulb_rounded, height: 52, glow: lit)),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _btn('HINT', _do(g.useHint, refresh), color: sgGold, height: 52)),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _btn('RESET', _do(g.resetSwitches, refresh), color: Colors.white24, fg: Colors.white, height: 52)),
        ]),
      ));
    }
  }
  return _dock(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids));
}

// ---- key question ---------------------------------------------------------------------------------

Widget _keyOverlay(SignalLogic g, VoidCallback refresh) {
  final OdyQuestion? q = g.question;
  if (q == null) return const SizedBox.shrink();
  String? result;
  final int? ch = g.keyChosen;
  if (ch != null) {
    result = ch == q.answerIndex ? 'Key earned! Bonus points added.' : 'Not this time. The right answer is: ${q.answer}';
  }
  return Positioned.fill(
    child: Stack(children: <Widget>[
      Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.62))),
      Positioned.fill(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 70, 14, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: RealmQuestionPanel(
                question: q,
                accent: sgAccentColor,
                header: 'Signal key  -  Ridge ${g.stage + 1}',
                chosen: ch,
                resultLine: result,
                onPick: (int i) {
                  g.answerKey(i);
                  refresh();
                },
                onContinue: () {
                  g.closeKey();
                  refresh();
                },
                continueLabel: g.stage >= SignalLogic.stageCount - 1 ? 'FINISH' : 'CONTINUE',
              ),
            ),
          ),
        ),
      ),
    ]),
  );
}
