import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'sundial_content.dart';
import 'sundial_logic.dart';
import 'sundial_painter.dart';

const Color _sdAccent = Color(0xFFF6B93B);
const Color _sdInk = Color(0xFF14161C);
const Color _sdGood = Color(0xFF69F0AE);
const Color _sdBad = Color(0xFFFF8A80);

class SundialScreen extends StatelessWidget {
  const SundialScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Sundial City',
      gameId: 'sundial',
      title: 'Sundial City',
      story: 'The bell of Sundial City cracked and the whole square lost its voice. Rumours drift from door to door like grey smoke. Walk the square, repair the sentences inside each building and ring the bell again from the Town Hall.',
      howTo: 'Drag to walk, or tap a building to head to its door. At a door, press FIX to open its job. Mend each job to bring the building back to life and clear its rumour. Fix all five, then hold the debate in the Town Hall.',
      icon: Icons.history_edu_rounded,
      accent: _sdAccent,
      config: config,
      create: (RealmContent c) => SundialLogic(c),
      painter: (RealmLogic l, Listenable repaint) => SundialPainter(l as SundialLogic, repaint: repaint),
      hud: _sdHud,
      actions: const <RealmAction>[RealmAction(0, Icons.edit_note_rounded, 'FIX')],
      duelSeconds: 300,
      background: const Color(0xFF86B058),
    );
  }
}

// ---------------------------------------------------------------------------

Widget _sdHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final SundialLogic g = logic as SundialLogic;
  final List<Widget> kids = <Widget>[];
  if (g.phase == 0) {
    kids.add(_voiceBar(g));
    kids.add(_nextWhisper(g));
    if (g.atDoor >= 0) kids.add(_doorPrompt(g, refresh));
  }
  if (g.phase == 1) kids.add(_jobPanel(g, refresh));
  if (g.phase == 2) kids.add(_doneCard(g, refresh));
  if (g.phase == 3) kids.add(_rumourCard(g, refresh));
  if (g.phase == 4) kids.add(_victoryCard(g, refresh));
  return Positioned.fill(child: Stack(children: kids));
}

Widget _voiceBar(SundialLogic g) {
  final double v = (g.voice / 100).clamp(0.0, 1.0).toDouble();
  return Positioned(
    left: 12,
    right: 104,
    bottom: 8,
    child: IgnorePointer(
      child: Row(children: <Widget>[
        const Icon(Icons.record_voice_over_rounded, color: _sdAccent, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: Colors.black45, color: _sdAccent),
          ),
        ),
      ]),
    ),
  );
}

Widget _nextWhisper(SundialLogic g) {
  final int n = g.whisperCount;
  final bool hot = n >= 3;
  final String t = n >= 5 ? 'The rumour is everywhere' : 'Next whisper in ${g.nextWhisperIn.ceil()} s';
  return Positioned(
    left: 12,
    bottom: 100,
    child: IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: hot ? const Color(0xFFFF5252) : Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(Icons.hearing_rounded, size: 14, color: hot ? const Color(0xFFFF5252) : Colors.white70),
          const SizedBox(width: 5),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

Widget _doorPrompt(SundialLogic g, VoidCallback refresh) {
  final SdBuilding b = sdBuildings[g.atDoor];
  final bool done = g.fixed[b.id];
  final bool locked = !g.canEnter(b.id) && !done;
  final String label = done ? '${b.name.toUpperCase()}: ALREADY SPEAKING' : (locked ? 'LOCKED: FIX THE OTHER FIVE FIRST' : 'FIX: ${b.name.toUpperCase()}');
  return Positioned(
    left: 12,
    right: 104,
    bottom: 38,
    child: SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: (done || locked) ? Colors.black54 : _sdAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: (done || locked)
            ? null
            : () {
                g.openJob(b.id);
                refresh();
              },
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: (done || locked) ? Colors.white70 : _sdInk, letterSpacing: 0.8)),
      ),
    ),
  );
}

// ---- shared pieces ---------------------------------------------------------

Widget _barrier() => Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.62)));

BoxDecoration _cardDeco(Color border) => BoxDecoration(
      color: const Color(0xF2101218),
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

Widget _title(String t, {double size = 22, Color color = Colors.white}) => Text(t, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, color: color, letterSpacing: 1.2));

Widget _bigButton(String label, VoidCallback? onTap, {Color color = _sdAccent, Color text = _sdInk}) {
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

Widget _smallLabel(String t, {Color color = Colors.white54}) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 5),
      child: Text(t, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
    );

IconData _jobIcon(int id) {
  switch (id) {
    case 0:
      return Icons.mail_rounded;
    case 1:
      return Icons.storefront_rounded;
    case 2:
      return Icons.gavel_rounded;
    case 3:
      return Icons.school_rounded;
    case 4:
      return Icons.local_library_rounded;
    default:
      return Icons.account_balance_rounded;
  }
}

/// The frame every job shares: title, item counter, the job body, a message
/// line and the buttons.
Widget _frame(SundialLogic g, VoidCallback refresh, {required Widget body, String primaryLabel = 'CHECK', VoidCallback? primary, bool showPrimary = true, String? hint}) {
  final SdBuilding b = sdBuildings[g.job < 0 ? 0 : g.job];
  final Color c = realmLighten(Color(b.color), 0.12);
  final bool last = g.itemIx + 1 >= b.items;
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(c),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Row(children: <Widget>[
            Icon(_jobIcon(b.id), color: c, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('${b.name.toUpperCase()}  -  ${b.job.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: c, letterSpacing: 1))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: Text('${g.itemIx + 1} / ${b.items}', style: const TextStyle(color: Colors.white70, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(hint ?? b.verb, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
          const SizedBox(height: 8),
          body,
          if (g.msg.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(g.msg, textAlign: TextAlign.center, style: TextStyle(color: g.msgGood ? _sdGood : _sdBad, fontWeight: FontWeight.w800, fontSize: 13.5)),
          ],
          const SizedBox(height: 12),
          if (g.itemDone)
            _bigButton(last ? 'FINISH JOB' : 'NEXT', () {
              g.nextItem();
              refresh();
            })
          else if (showPrimary)
            _bigButton(primaryLabel, primary),
          if (g.canStepOut) ...<Widget>[
            const SizedBox(height: 8),
            _bigButton('STEP OUT', () {
              g.stepOut();
              refresh();
            }, color: Colors.white12, text: Colors.white),
          ],
        ]),
      )),
    ]),
  );
}

Widget _jobPanel(SundialLogic g, VoidCallback refresh) {
  switch (g.job) {
    case 0:
      return _letterPanel(g, refresh);
    case 1:
      return _signPanel(g, refresh);
    case 2:
      return _courtPanel(g, refresh);
    case 3:
      return _schoolPanel(g, refresh);
    case 4:
      return g.itemIx < 2 ? _libraryQuestion(g, refresh) : _vocabPanel(g, refresh);
    default:
      return _debatePanel(g, refresh);
  }
}

Widget _tile(Widget child, {Color border = Colors.white24, Color? fill, VoidCallback? onTap, double minHeight = 48}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: BoxConstraints(minHeight: minHeight),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: fill ?? Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: border == Colors.white24 ? 1 : 1.8)),
      child: child,
    ),
  );
}

// ---- Post Office: letter order ---------------------------------------------

Widget _letterPanel(SundialLogic g, VoidCallback refresh) {
  final SdLetter L = g.letter;
  return _frame(
    g,
    refresh,
    hint: 'Tap the sentences in the order they belong. Words like First, Then, However and Finally are clues. Tap a numbered sentence to undo it.',
    primaryLabel: 'SEND',
    primary: g.lPicks.length == 5
        ? () {
            g.sendLetter();
            refresh();
          }
        : null,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      _smallLabel('LETTER: ${L.title.toUpperCase()}'),
      for (int p = 0; p < 5; p++) _letterTile(g, p, refresh),
    ]),
  );
}

Widget _letterTile(SundialLogic g, int p, VoidCallback refresh) {
  final int idx = g.lPicks.indexOf(p);
  final bool picked = idx >= 0;
  return _tile(
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: picked ? _sdAccent : Colors.transparent, border: Border.all(color: picked ? _sdAccent : Colors.white38, width: 1.6)),
        child: Text(picked ? '${idx + 1}' : '', style: const TextStyle(color: _sdInk, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(g.letter.lines[g.lOrder[p]], style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3))),
      if (g.retry) ...<Widget>[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.75), borderRadius: BorderRadius.circular(8), border: Border.all(color: _sdGood)),
          child: Text('${g.letterRightNumber(p)}', style: const TextStyle(color: _sdGood, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    ]),
    border: picked ? _sdAccent : Colors.white24,
    fill: picked ? _sdAccent.withValues(alpha: 0.14) : null,
    onTap: g.itemDone
        ? null
        : () {
            g.tapLetter(p);
            refresh();
          },
  );
}

// ---- Market: sign repair ---------------------------------------------------

Widget _signPanel(SundialLogic g, VoidCallback refresh) {
  final SdSign s = g.sign ?? sdSigns[0];
  final List<String> pcs = s.pieces;
  final List<Widget> words = <Widget>[];
  const TextStyle ws = TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani', height: 1.2);
  String carry = '';
  for (int i = 0; i < pcs.length; i++) {
    String txt = pcs[i];
    if (i > 0 && carry.isNotEmpty && txt.startsWith(carry)) txt = txt.substring(carry.length);
    for (final String w in txt.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      words.add(Text(w, style: ws));
    }
    carry = '';
    if (i < s.gaps) {
      final String next = i + 1 < pcs.length ? pcs[i + 1] : '';
      final Match? m = RegExp(r'^\S+').firstMatch(next);
      carry = m == null ? '' : (m.group(0) ?? '');
      words.add(_gapBox(g, i, carry, refresh));
    }
  }
  return _frame(
    g,
    refresh,
    hint: 'Tap a word tile to fill the gap in the sign. Tap a filled gap to take the word back.',
    primaryLabel: 'FIX SIGN',
    primary: g.signFull
        ? () {
            g.checkSign();
            refresh();
          }
        : null,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1F5C3B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 3)),
        child: Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: words),
      ),
      if (g.retry && !g.itemDone)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: _sdGood)),
            child: Text('The sign should read: ${s.solved}', style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w700)),
          ),
        ),
      _smallLabel('WORD TILES'),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        for (int i = 0; i < g.tiles.length; i++) _wordTile(g, i, refresh),
      ]),
    ]),
  );
}

Widget _gapBox(SundialLogic g, int gap, String glue, VoidCallback refresh) {
  final int t = gap < g.gapTile.length ? g.gapTile[gap] : -1;
  final bool filled = t >= 0 && t < g.tiles.length;
  final Widget box = GestureDetector(
    onTap: filled && !g.itemDone
        ? () {
            g.tapGap(gap);
            refresh();
          }
        : null,
    child: Container(
      constraints: const BoxConstraints(minWidth: 70, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? _sdAccent : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: filled ? Colors.white : Colors.white70, width: 2),
      ),
      child: Text(filled ? g.tiles[t] : '', style: const TextStyle(color: _sdInk, fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani')),
    ),
  );
  if (glue.isEmpty) return box;
  return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
    box,
    Text(glue, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani')),
  ]);
}

Widget _wordTile(SundialLogic g, int i, VoidCallback refresh) {
  final bool used = g.tileUsed[i];
  return GestureDetector(
    onTap: used || g.itemDone
        ? null
        : () {
            g.tapTile(i);
            refresh();
          },
    child: Container(
      constraints: const BoxConstraints(minWidth: 58, minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: used ? Colors.white10 : const Color(0xFFFFF3D0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: used ? Colors.white12 : _sdAccent, width: 1.6),
      ),
      child: Text(g.tiles[i], style: TextStyle(color: used ? Colors.white24 : _sdInk, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani')),
    ),
  );
}

// ---- Courthouse: witness ---------------------------------------------------

Widget _courtPanel(SundialLogic g, VoidCallback refresh) {
  final SdCase c = g.witness;
  return _frame(
    g,
    refresh,
    hint: 'The first witness is certain of every word. One sentence in the second statement cannot be true if the first is true. Tap it.',
    primaryLabel: 'THIS ONE CONTRADICTS',
    primary: g.cPick >= 0
        ? () {
            g.confirmWitness();
            refresh();
          }
        : null,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(c.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
      _smallLabel('FIRST STATEMENT  -  ${c.nameA}'),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF1F3A5F).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF64B5F6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          for (final String line in c.a)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(line, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3)),
            ),
        ]),
      ),
      _smallLabel('SECOND STATEMENT  -  ${c.nameB}'),
      for (int i = 0; i < c.b.length; i++) _courtTile(g, c, i, refresh),
      if (g.retry && c.why.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(c.why, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
        ),
    ]),
  );
}

Widget _courtTile(SundialLogic g, SdCase c, int i, VoidCallback refresh) {
  final bool sel = g.cPick == i;
  final bool wrong = g.cWrong == i;
  final bool right = (g.retry || g.itemDone) && i == c.bad;
  Color border = Colors.white24;
  Color? fill;
  if (right) {
    border = _sdGood;
    fill = const Color(0xFF1B5E20).withValues(alpha: 0.55);
  } else if (wrong) {
    border = _sdBad;
    fill = const Color(0xFFB71C1C).withValues(alpha: 0.4);
  } else if (sel) {
    border = _sdAccent;
    fill = _sdAccent.withValues(alpha: 0.16);
  }
  return _tile(
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Icon(right ? Icons.check_circle_rounded : (wrong ? Icons.cancel_rounded : (sel ? Icons.gavel_rounded : Icons.format_quote_rounded)), color: right ? _sdGood : (wrong ? _sdBad : (sel ? _sdAccent : Colors.white38)), size: 22),
      const SizedBox(width: 8),
      Expanded(child: Text(c.b[i], style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3))),
    ]),
    border: border,
    fill: fill,
    onTap: g.itemDone
        ? null
        : () {
            g.pickStatement(i);
            refresh();
          },
  );
}

// ---- School: punctuation ---------------------------------------------------

Widget _optionTiles(SundialLogic g, VoidCallback refresh) {
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    for (int i = 0; i < g.opts.length; i++)
      _tile(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(g.opts[i], style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3))),
        ]),
        border: (g.retry || g.itemDone) && i == g.optRight ? _sdGood : (g.optWrong.contains(i) ? _sdBad : Colors.white24),
        fill: (g.retry || g.itemDone) && i == g.optRight ? const Color(0xFF1B5E20).withValues(alpha: 0.55) : (g.optWrong.contains(i) ? const Color(0xFFB71C1C).withValues(alpha: 0.4) : null),
        onTap: g.itemDone || g.optWrong.contains(i)
            ? null
            : () {
                g.pickOption(i);
                refresh();
              },
      ),
  ]);
}

Widget _schoolPanel(SundialLogic g, VoidCallback refresh) {
  final SdPunct p = g.punct;
  return _frame(
    g,
    refresh,
    hint: 'Read the sentence with no punctuation. Choose the version that is punctuated and capitalised correctly.',
    showPrimary: false,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      _smallLabel('THE SENTENCE ON THE BOARD'),
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: const Color(0xFF2E5E3E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF8D6E63), width: 3)),
        child: Text(p.raw, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
      ),
      _optionTiles(g, refresh),
    ]),
  );
}

// ---- Library ---------------------------------------------------------------

Widget _libraryQuestion(SundialLogic g, VoidCallback refresh) {
  final OdyQuestion? q = g.libQ;
  if (q == null) return const SizedBox.shrink();
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        RealmQuestionPanel(
          question: q,
          accent: realmLighten(Color(sdBuildings[4].color), 0.2),
          header: 'Library  -  question ${g.itemIx + 1} of 3',
          chosen: g.libChosen,
          resultLine: g.msg,
          onPick: (int i) {
            g.answerLib(i);
            refresh();
          },
          onContinue: () {
            g.nextItem();
            refresh();
          },
          continueLabel: 'NEXT',
        ),
        if (g.libChosen == null) ...<Widget>[
          const SizedBox(height: 8),
          _bigButton('STEP OUT', () {
            g.stepOut();
            refresh();
          }, color: Colors.white12, text: Colors.white),
        ],
      ])),
    ]),
  );
}

Widget _vocabPanel(SundialLogic g, VoidCallback refresh) {
  final SdVocab v = g.vocab;
  return _frame(
    g,
    refresh,
    hint: 'Read the sentence. What does the highlighted word mean in this sentence?',
    showPrimary: false,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
            children: <InlineSpan>[
              TextSpan(text: v.before),
              TextSpan(text: v.word, style: const TextStyle(color: _sdInk, backgroundColor: _sdAccent, fontWeight: FontWeight.w800)),
              TextSpan(text: v.after),
            ],
          ),
        ),
      ),
      _optionTiles(g, refresh),
    ]),
  );
}

// ---- Town Hall: the debate -------------------------------------------------

Widget _debatePanel(SundialLogic g, VoidCallback refresh) {
  final SdDebate d = g.debate;
  return _frame(
    g,
    refresh,
    hint: 'Build one strong argument. Tap three cards: first the claim, then the evidence, then the reasoning that links them. Tap a slot to take a card back.',
    primaryLabel: 'SUBMIT ARGUMENT',
    primary: g.debateFull
        ? () {
            g.submitDebate();
            refresh();
          }
        : null,
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(d.question, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.3, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(d.stance, style: const TextStyle(color: _sdAccent, fontSize: 13, fontWeight: FontWeight.w800)),
      _smallLabel('YOUR ARGUMENT'),
      for (int s = 0; s < 3; s++) _slotTile(g, d, s, refresh),
      if (g.retry && !g.itemDone)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: _sdGood)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('THE STRONGEST ARGUMENT', style: TextStyle(color: _sdGood, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
            const SizedBox(height: 3),
            for (int s = 0; s < 3; s++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${sdDebateSlots[s]}: ${d.cards[sdDebateAnswer[s]]}', style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
              ),
            const SizedBox(height: 3),
            Text(d.why, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ]),
        ),
      _smallLabel('CARDS'),
      for (final int c in g.dOrder) _cardTile(g, d, c, refresh),
    ]),
  );
}

Widget _slotTile(SundialLogic g, SdDebate d, int s, VoidCallback refresh) {
  final int c = g.dSlot[s];
  final bool has = c >= 0;
  final bool right = g.itemDone && has && g.debateSlotRight(s);
  return _tile(
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: has ? _sdAccent : Colors.white12, borderRadius: BorderRadius.circular(8)),
        child: Text(sdDebateSlots[s], style: TextStyle(color: has ? _sdInk : Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 0.6)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(has ? d.cards[c] : 'Tap a card below', style: TextStyle(color: has ? Colors.white : Colors.white38, fontSize: 13, height: 1.3, fontStyle: has ? FontStyle.normal : FontStyle.italic))),
    ]),
    border: right ? _sdGood : (has ? _sdAccent : Colors.white24),
    fill: right ? const Color(0xFF1B5E20).withValues(alpha: 0.5) : (has ? _sdAccent.withValues(alpha: 0.1) : null),
    minHeight: 52,
    onTap: has && !g.itemDone
        ? () {
            g.tapSlot(s);
            refresh();
          }
        : null,
  );
}

Widget _cardTile(SundialLogic g, SdDebate d, int c, VoidCallback refresh) {
  final bool used = g.dSlot.contains(c);
  return Opacity(
    opacity: used ? 0.35 : 1,
    child: _tile(
      Text(d.cards[c], style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3)),
      onTap: used || g.itemDone
          ? null
          : () {
              g.tapCard(c);
              refresh();
            },
    ),
  );
}

// ---- end cards -------------------------------------------------------------

Widget _doneCard(SundialLogic g, VoidCallback refresh) {
  final SdBuilding b = sdBuildings[g.job < 0 ? 0 : g.job];
  final Color c = realmLighten(Color(b.color), 0.15);
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(_sdAccent),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Icon(_jobIcon(b.id), color: c, size: 40),
          const SizedBox(height: 6),
          _title('${b.name.toUpperCase()} HAS ITS VOICE BACK', size: 21, color: _sdAccent),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _sdAccent, width: 2)),
            child: Text('"${b.bubble}"', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2B2418), fontSize: 15, height: 1.35, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          Text('+${g.lastGain} voice', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _sdGood)),
          Text(g.lastWasWhispered ? 'The rumour here is gone, and the windows glow.' : 'The windows glow, and no rumour can settle here now.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
          const SizedBox(height: 4),
          Text('Buildings fixed ${g.fixedCount} of 6', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          _bigButton('BACK TO THE SQUARE', () {
            g.closeCard();
            refresh();
          }),
        ]),
      )),
    ]),
  );
}

Widget _rumourCard(SundialLogic g, VoidCallback refresh) {
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(const Color(0xFFB5545F)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          const Icon(Icons.hearing_rounded, color: Color(0xFFB5545F), size: 40),
          const SizedBox(height: 6),
          _title('THE RUMOUR TOOK THE SQUARE', size: 21, color: const Color(0xFFFF8A80)),
          const SizedBox(height: 10),
          const Text("Too many doors were whispering at once, and the square fell quiet. Nothing is lost. You restored part of the city's voice, and the next try will go further.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 10),
          Text('Voice restored: ${g.voice.round()}%   -   Buildings fixed: ${g.fixedCount} of 6', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _bigButton('SEE MY RESULT', () {
            g.finishRun();
            refresh();
          }),
        ]),
      )),
    ]),
  );
}

Widget _victoryCard(SundialLogic g, VoidCallback refresh) {
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(_sdAccent),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          const Icon(Icons.notifications_active_rounded, color: _sdAccent, size: 44),
          const SizedBox(height: 6),
          _title('THE BELL RINGS', size: 28, color: _sdAccent),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _sdAccent, width: 2)),
            child: Text('"${sdBuildings[sdHall].bubble}"', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2B2418), fontSize: 15, height: 1.35, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          const Text('Your argument was clear, the council agreed, and every rumour dissolved in the sound of the bell.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 8),
          Text('Voice restored: ${g.voice.round()}%', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: _sdGood)),
          const SizedBox(height: 14),
          _bigButton('FINISH', () {
            g.finishRun();
            refresh();
          }),
        ]),
      )),
    ]),
  );
}
