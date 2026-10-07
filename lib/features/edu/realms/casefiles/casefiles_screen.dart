import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'casefiles_logic.dart';
import 'casefiles_painter.dart';

const Color _caseAccent = Color(0xFFFFB300);
const Color _caseInk = Color(0xFF14161C);
const Color _caseGood = Color(0xFF69F0AE);
const Color _caseBad = Color(0xFFFF8A80);

class CaseFilesScreen extends StatelessWidget {
  const CaseFilesScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Case Files',
      title: 'Case Files',
      story: 'Marrow Bay is a quiet coastal town, but small crimes keep happening. The only witnesses talk to people who know their lessons. Walk the streets, win their trust with the right answers and name the culprit before the clock runs out.',
      howTo: 'Drag to walk, or tap a building to head to its door. At a door, press INSPECT and answer the question to earn a clue. Each inspection costs one of your 12 hours. Open the notebook to mark suspects, then accuse. Solve up to 3 cases.',
      icon: Icons.travel_explore_rounded,
      accent: _caseAccent,
      config: config,
      create: (RealmContent c) => CaseFilesLogic(c),
      painter: (RealmLogic l, Listenable repaint) => CaseFilesPainter(l as CaseFilesLogic, repaint: repaint),
      hud: _caseHud,
      actions: const <RealmAction>[RealmAction(0, Icons.search_rounded, 'INSPECT')],
      duelSeconds: 300,
      background: const Color(0xFF79B05D),
    );
  }
}

// ---------------------------------------------------------------------------

Widget _caseHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final CaseFilesLogic g = logic as CaseFilesLogic;
  final List<Widget> kids = <Widget>[];
  if (g.phase == 0 && !g.notebookOpen) {
    kids.add(Positioned(left: 12, bottom: 26, child: _notebookButton(g, refresh)));
    if (g.atDoor >= 0) kids.add(_doorPrompt(g, refresh));
  }
  if (g.phase == 0 && g.notebookOpen) kids.add(_notebook(g, refresh));
  if (g.phase == 1) kids.add(_askOverlay(g, refresh));
  if (g.phase == 2) kids.add(_storyCard(g, refresh));
  if (g.phase == 3) kids.add(_accuseCard(g, refresh));
  if (g.phase == 4) kids.add(_verdictCard(g, refresh));
  return Positioned.fill(child: Stack(children: kids));
}

Widget _notebookButton(CaseFilesLogic g, VoidCallback refresh) {
  return GestureDetector(
    onTap: () {
      g.toggleNotebook();
      refresh();
    },
    child: Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _caseInk.withValues(alpha: 0.82), border: Border.all(color: _caseAccent, width: 2)),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(Icons.menu_book_rounded, color: _caseAccent, size: 24),
        Text('NOTES', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

Widget _doorPrompt(CaseFilesLogic g, VoidCallback refresh) {
  final CasePlace p = casePlaces[g.atDoor];
  final bool done = g.revealed[p.id];
  return Positioned(
    left: 84,
    right: 104,
    bottom: 34,
    child: SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: done ? Colors.black54 : _caseAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: done
            ? null
            : () {
                g.inspect();
                refresh();
              },
        child: Text(
          done ? 'Clue found at the ${p.name}' : 'INVESTIGATE: ${p.name.toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: done ? Colors.white70 : _caseInk, letterSpacing: 0.8),
        ),
      ),
    ),
  );
}

Widget _barrier() => Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.6)));

BoxDecoration _cardDeco(Color border) => BoxDecoration(
      color: const Color(0xF2101218),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border, width: 1.4),
    );

Widget _title(String t, {double size = 22, Color color = Colors.white}) => Text(t, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, color: color, letterSpacing: 1.2));

Widget _bigButton(String label, VoidCallback? onTap, {Color color = _caseAccent, Color text = _caseInk}) {
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

Widget _centered(Widget card) => Positioned.fill(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 70, 14, 20),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: card),
        ),
      ),
    );

Widget _traitChip(String text, {Color? dot}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (dot != null) ...<Widget>[
          Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 0.8))),
          const SizedBox(width: 4),
        ],
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );

Widget _traits(CaseSuspect s) => Wrap(spacing: 4, runSpacing: 4, children: <Widget>[
      _traitChip(caseTraitLabel(s, 0)),
      _traitChip(caseTraitLabel(s, 1), dot: Color(caseShoeColors[s.shoe])),
      _traitChip(caseTraitLabel(s, 2)),
      _traitChip(caseTraitLabel(s, 3)),
    ]);

Widget _markIcon(int m) {
  if (m == 1) return const Icon(Icons.cancel_rounded, color: Colors.white38, size: 26);
  if (m == 2) return const Icon(Icons.flag_rounded, color: _caseAccent, size: 26);
  return const Icon(Icons.radio_button_unchecked_rounded, color: Colors.white38, size: 26);
}

// ---- notebook ------------------------------------------------------------

Widget _notebook(CaseFilesLogic g, VoidCallback refresh) {
  return Positioned(
    left: 8,
    right: 8,
    top: 100,
    bottom: 96,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDeco(_caseAccent),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            _title('CASE NOTEBOOK', size: 18, color: _caseAccent),
            const SizedBox(height: 4),
            Text(g.hook, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  const Text('SUSPECTS  (tap to mark: ruled out, prime suspect)', style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  for (int i = 0; i < g.suspects.length; i++) _suspectTile(g, i, refresh),
                  const SizedBox(height: 8),
                  const Text('CLUES FOUND', style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  if (g.foundOrder.isEmpty) const Text('Nothing yet. Walk to a door and investigate.', style: TextStyle(color: Colors.white54, fontSize: 12.5)),
                  for (final int loc in g.foundOrder)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: Color(casePlaces[loc].color), width: 4))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        Text(casePlaces[loc].name.toUpperCase(), style: TextStyle(color: realmLighten(Color(casePlaces[loc].color), 0.2), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text(g.clueAt[loc].text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            if (!g.canAccuse)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Accusing unlocks after ${g.cluesNeeded} clues, or when time runs out.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
              ),
            Row(children: <Widget>[
              Expanded(
                child: _bigButton('CLOSE', () {
                  g.toggleNotebook();
                  refresh();
                }, color: Colors.white12, text: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigButton('ACCUSE', g.canAccuse
                    ? () {
                        g.openAccuse();
                        refresh();
                      }
                    : null, color: const Color(0xFFE53935), text: Colors.white),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

Widget _suspectTile(CaseFilesLogic g, int i, VoidCallback refresh) {
  final CaseSuspect s = g.suspects[i];
  final int m = g.marks[i];
  final bool out = m == 1;
  return GestureDetector(
    onTap: () {
      g.cycleMark(i);
      refresh();
    },
    child: Opacity(
      opacity: out ? 0.4 : 1.0,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: m == 2 ? _caseAccent.withValues(alpha: 0.16) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: m == 2 ? _caseAccent : Colors.white24),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          _markIcon(m),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('${s.name}, the ${s.role}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, decoration: out ? TextDecoration.lineThrough : TextDecoration.none)),
              const SizedBox(height: 4),
              _traits(s),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// ---- question ------------------------------------------------------------

Widget _askOverlay(CaseFilesLogic g, VoidCallback refresh) {
  final CasePlace p = casePlaces[g.askLoc < 0 ? 0 : g.askLoc];
  final Color c = Color(p.color);
  final OdyQuestion? question = g.question;
  if (question == null) return const SizedBox.shrink();
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _caseInk.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: realmLighten(c, 0.15))),
          child: Text(p.lead, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        RealmQuestionPanel(
          question: question,
          accent: realmLighten(c, 0.15),
          header: '${p.name}  -  ${g.hoursLeft} h left',
          chosen: g.chosen,
          resultLine: g.resultLine,
          onPick: (int i) {
            g.answer(i);
            refresh();
          },
          onContinue: () {
            g.closeAsk();
            refresh();
          },
          continueLabel: 'CONTINUE',
        ),
      ])),
    ]),
  );
}

// ---- story card ----------------------------------------------------------

Widget _storyCard(CaseFilesLogic g, VoidCallback refresh) {
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(_caseAccent),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Text('CASE ${g.caseNo} OF $caseMaxCases', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 12)),
          const SizedBox(height: 4),
          _title(g.title.toUpperCase(), size: 26, color: _caseAccent),
          const SizedBox(height: 10),
          Text(g.caseIntro, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Text(g.hook, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          const Text('THE SUSPECTS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(g.suspects.map((CaseSuspect s) => '${s.name} (${s.role})').join('  /  '), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          Text('You have $caseStartHours hours. Each inspection costs one.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          _bigButton('START INVESTIGATION', () {
            g.beginCase();
            refresh();
          }),
        ]),
      )),
    ]),
  );
}

// ---- accuse --------------------------------------------------------------

Widget _accuseCard(CaseFilesLogic g, VoidCallback refresh) {
  final int sel = g.accuseSel;
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(const Color(0xFFE53935)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          _title('WHO DID IT?', size: 24, color: const Color(0xFFFF8A80)),
          const SizedBox(height: 4),
          Text(g.forcedAccuse ? 'The 12 hours are up. You must accuse someone now.' : 'Pick your suspect, then confirm. A wrong accusation loses the case.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 10),
          for (int i = 0; i < g.suspects.length; i++)
            GestureDetector(
              onTap: () {
                g.selectSuspect(i);
                refresh();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: sel == i ? const Color(0xFFE53935).withValues(alpha: 0.25) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel == i ? const Color(0xFFFF8A80) : Colors.white24, width: sel == i ? 1.8 : 1),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Icon(sel == i ? Icons.gavel_rounded : _markData(g.marks[i]), color: sel == i ? const Color(0xFFFF8A80) : (g.marks[i] == 2 ? _caseAccent : Colors.white38), size: 24),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text('${g.suspects[i].name}, the ${g.suspects[i].role}', style: TextStyle(color: g.marks[i] == 1 ? Colors.white38 : Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      _traits(g.suspects[i]),
                    ]),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 4),
          _bigButton(
            sel < 0 ? 'PICK A SUSPECT' : 'CONFIRM: ${g.suspects[sel].name.toUpperCase()}',
            sel < 0
                ? null
                : () {
                    g.confirmAccuse();
                    refresh();
                  },
            color: const Color(0xFFE53935),
            text: Colors.white,
          ),
          if (!g.forcedAccuse) ...<Widget>[
            const SizedBox(height: 8),
            _bigButton('BACK TO THE CASE', () {
              g.closeAccuse();
              refresh();
            }, color: Colors.white12, text: Colors.white),
          ],
        ]),
      )),
    ]),
  );
}

IconData _markData(int m) {
  if (m == 1) return Icons.cancel_rounded;
  if (m == 2) return Icons.flag_rounded;
  return Icons.person_rounded;
}

// ---- verdict -------------------------------------------------------------

Widget _verdictCard(CaseFilesLogic g, VoidCallback refresh) {
  final bool ok = g.verdictOk;
  final Color col = ok ? _caseGood : _caseBad;
  final CaseSuspect c = g.culpritSuspect;
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(col),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          _title(ok ? 'CASE SOLVED' : 'CASE FAILED', size: 28, color: col),
          const SizedBox(height: 8),
          Text(g.verdictText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          Center(child: _traits(c)),
          const SizedBox(height: 12),
          Text('+${g.caseScore} points', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: col)),
          Text(ok ? '${g.hoursLeft} hours left, ${g.correctInCase} correct answers' : 'Better luck with the next one', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          _bigButton(g.runEnds ? 'FINISH' : 'NEXT CASE', () {
            g.nextCase();
            refresh();
          }),
        ]),
      )),
    ]),
  );
}
