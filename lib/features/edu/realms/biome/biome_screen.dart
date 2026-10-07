import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'biome_logic.dart';
import 'biome_painter.dart';

class BiomeScreen extends StatelessWidget {
  const BiomeScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Biome',
      title: 'BIOME',
      story: 'Wild echoes are born from lessons the world forgot. They roam the biomes, restless and strong. '
          'You are a Keeper. Walk the land, answer what the echoes ask, calm them and tame them, '
          'and build a team that can restore every biome.',
      howTo: 'Drag to walk. Touch a wild creature to start a battle. Every attack is a question: '
          'FIGHT to strike, TAME to use an orb on a weakened creature (half health or less), RUN to escape. '
          'Collect orbs and coins, and rest at campfires to heal your team. Keep your team alive.',
      icon: Icons.pets_rounded,
      accent: const Color(0xFF69F0AE),
      config: config,
      create: (RealmContent content) => BiomeLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => BiomePainter(logic as BiomeLogic, repaint: repaint),
      hud: _hud,
      background: const Color(0xFF10261A),
    );
  }
}

Widget _hud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final BiomeLogic g = logic as BiomeLogic;
  final BiomeBattle? b = g.battle;
  if (b == null || g.over && b.outcome != 4) return const SizedBox.shrink();
  final Color accent = g.content.subject(b.wild.subjectId).color;
  return Positioned.fill(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 96, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(child: _card(g.active, true, g)),
          const SizedBox(width: 8),
          Expanded(child: _card(b.wild, false, g)),
        ]),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(child: _panel(g, b, accent, refresh)),
          ),
        ),
      ]),
    ),
  );
}

Widget _card(BiomeCreature c, bool mine, BiomeLogic g) {
  final double f = c.hpFrac;
  final Color bar = f > 0.5 ? const Color(0xFF69F0AE) : (f > 0.25 ? const Color(0xFFFFD54F) : const Color(0xFFFF5252));
  return Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: BoxDecoration(
      color: const Color(0xDD0B0B0F),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: mine ? const Color(0xFF69F0AE) : const Color(0xFFFF8A65), width: 1.2),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
      Row(children: <Widget>[
        Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14))),
        Text('Lv ${c.level}', style: const TextStyle(color: Colors.white70, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: f < 0 ? 0.0 : (f > 1 ? 1.0 : f), minHeight: 8, backgroundColor: Colors.white12, color: bar),
      ),
      const SizedBox(height: 3),
      Row(children: <Widget>[
        Text('${c.hp}/${c.maxHp}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const Spacer(),
        if (mine)
          for (int i = 0; i < g.team.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(Icons.circle, size: 9, color: g.team[i].hp <= 0 ? Colors.white24 : (i == g.activeIdx ? const Color(0xFF69F0AE) : Colors.white70)),
            ),
        if (!mine && c.hpFrac <= 0.5)
          const Text('Ready to tame', style: TextStyle(color: Color(0xFFB388FF), fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ]),
  );
}

Widget _panel(BiomeLogic g, BiomeBattle b, Color accent, VoidCallback refresh) {
  if (b.phase == 1 || b.phase == 2) {
    final OdyQuestion? q = b.question;
    if (q != null) {
      return RealmQuestionPanel(
        question: q,
        accent: accent,
        header: (b.mode == 0 ? 'Fight' : 'Tame') + ' - ' + g.content.subject(b.wild.subjectId).label,
        chosen: b.chosen,
        resultLine: b.resultLine,
        continueLabel: 'CONTINUE',
        onPick: (int i) {
          g.battleAnswer(i);
          refresh();
        },
        onContinue: () {
          g.battleContinue();
          refresh();
        },
      );
    }
  }
  if (b.phase == 3) {
    return _box(<Widget>[
      Text(b.log, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      _btn('CONTINUE', const Color(0xFFFF6A00), () {
        g.battleContinue();
        refresh();
      }),
    ]);
  }
  final bool hasOrb = g.orbs > 0;
  return _box(<Widget>[
    Text(b.log, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600)),
    const SizedBox(height: 12),
    Row(children: <Widget>[
      Expanded(
        child: _btn('FIGHT', const Color(0xFFFF6A00), () {
          g.battleFight();
          refresh();
        }),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _btn('TAME ${g.orbs}', hasOrb ? const Color(0xFF7C4DFF) : const Color(0xFF4A4A55), () {
          g.battleTame();
          refresh();
        }),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _btn('RUN', const Color(0xFF455A64), () {
          g.battleRun();
          refresh();
        }),
      ),
    ]),
  ]);
}

Widget _box(List<Widget> children) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xEE0B0B0F),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white24, width: 1.2),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

Widget _btn(String label, Color color, VoidCallback onTap) {
  return SizedBox(
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      onPressed: onTap,
      child: Text(label, maxLines: 1, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1, fontSize: 15)),
    ),
  );
}
