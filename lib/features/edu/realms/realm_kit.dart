import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/services/duel_session.dart';
import '../odyssey/odyssey_engine.dart' show OdyMistake;
import '../odyssey/odyssey_questions.dart';

/// What the player chose before starting a realm game.
class RealmConfig {
  /// 'mix' for every subject, or one subject id.
  final String subjectId;
  final bool useSchool;
  const RealmConfig({this.subjectId = 'mix', this.useSchool = true});
}

/// Questions, subjects and the random source for one run of a realm game.
class RealmContent {
  final QuestionPool pool;
  final List<String> subjectIds;
  final Map<String, OdySubject> subjects;
  final bool schoolUsed;
  final bool inDuel;
  final Random rng;
  final int seed;
  const RealmContent({
    required this.pool,
    required this.subjectIds,
    required this.subjects,
    required this.schoolUsed,
    required this.inDuel,
    required this.rng,
    required this.seed,
  });

  bool get mixed => subjectIds.length > 1;

  OdySubject subject(String id) => subjects[id] ?? odySubjectById(id);

  /// A random subject from this run's subject list.
  String randomSubject() => subjectIds[rng.nextInt(subjectIds.length)];

  /// A fresh multiple choice question. Pass a subject id to stay in one subject.
  OdyQuestion ask([String? subjectId]) => pool.pick(subjectId ?? randomSubject());

  static Future<RealmContent> load(RealmConfig config) async {
    final bool inDuel = DuelSession.current != null;
    SchoolContent school = const SchoolContent(<String, List<Map<String, dynamic>>>{}, <String, String>{});
    // Duels use only the built-in questions so both players get the same ones.
    if (config.useSchool && !inDuel) {
      try {
        school = await OdysseyData.loadSchool();
      } catch (e) {
        school = const SchoolContent(<String, List<Map<String, dynamic>>>{}, <String, String>{});
      }
    }
    final bool mixed = config.subjectId == 'mix';
    List<String> ids;
    bool schoolUsed = false;
    if (mixed) {
      if (!school.isEmpty) {
        ids = school.bySubject.keys.toList()..sort();
        schoolUsed = true;
      } else {
        ids = odySubjects.map((OdySubject s) => s.id).toList();
      }
    } else {
      ids = <String>[config.subjectId];
      schoolUsed = school.bySubject.containsKey(config.subjectId);
    }
    final Map<String, OdySubject> subs = <String, OdySubject>{};
    for (final String id in ids) {
      subs[id] = odySubjectById(id, school.labels[id]);
    }
    final Random rng = duelRandom();
    return RealmContent(
      pool: QuestionPool(rng: rng, school: school.bySubject),
      subjectIds: ids,
      subjects: subs,
      schoolUsed: schoolUsed,
      inDuel: inDuel,
      rng: rng,
      seed: rng.nextInt(1 << 30),
    );
  }
}

/// Answer tracking shared by every realm game. The shell reads it for the
/// result screen and for saving progress.
class RealmStats {
  int asked = 0;
  int correct = 0;
  int streak = 0;
  int bestStreak = 0;
  final Map<String, int> askedBy = <String, int>{};
  final Map<String, int> correctBy = <String, int>{};
  final List<OdyMistake> mistakes = <OdyMistake>[];

  /// Record one answered question. [chosen] is the text of the wrong choice.
  void record(OdyQuestion q, bool ok, {String chosen = 'No answer'}) {
    asked++;
    askedBy[q.subject] = (askedBy[q.subject] ?? 0) + 1;
    if (ok) {
      correct++;
      correctBy[q.subject] = (correctBy[q.subject] ?? 0) + 1;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
      if (mistakes.length < 40) {
        mistakes.add(OdyMistake(q.text, chosen, q.answer, q.subject));
      }
    }
  }

  double get accuracy => asked == 0 ? 0 : correct / asked;

  /// XP for the run before any game specific bonus.
  int get baseXp => correct * 8 + (bestStreak >= 5 ? 15 : 0);
}

/// A line shown in the stats row at the top of the screen.
class RealmChip {
  final String text;
  final IconData icon;
  final Color color;
  const RealmChip(this.text, this.icon, this.color);
}

/// The rules of one realm game, with no drawing code, so they can be tested alone.
///
/// The shell calls [tick] every frame while the game is running. Games set
/// [over] to end the run and report [finalScore] and [xp].
abstract class RealmLogic {
  final RealmContent content;
  final RealmStats stats = RealmStats();
  double time = 0;
  bool over = false;

  /// Joystick or keyboard direction, each between -1 and 1.
  double inputX = 0;
  double inputY = 0;

  /// Sound cues for the shell to play and clear: tap, good, bad, win, lose.
  final List<String> cues = <String>[];

  RealmLogic(this.content);

  Random get rng => content.rng;

  void tick(double dt) {
    final double d = dt > 0.05 ? 0.05 : dt;
    time += d;
    step(d);
  }

  void step(double dt);

  void setInput(double x, double y) {
    final double m = sqrt(x * x + y * y);
    if (m > 1) {
      inputX = x / m;
      inputY = y / m;
    } else {
      inputX = x;
      inputY = y;
    }
  }

  /// An action button (id 0, 1, ...) was pressed.
  void onAction(int id) {}

  /// 0 to 1, where 1 means the action is ready.
  double actionReady(int id) => 1;

  /// A tap on the world, in screen coordinates of the canvas.
  void onTap(Offset point, Size size) {}

  /// The score saved to the leaderboard and used in duels.
  int get finalScore;

  /// Total XP for the run.
  int get xp => stats.baseXp;

  /// Hearts to draw in the top bar, or -1 to hide them.
  int get hearts => -1;
  int get maxHearts => 5;

  /// Chips for the stats row.
  List<RealmChip> get chips => const <RealmChip>[];

  /// Extra lines for the result screen, label to value.
  Map<String, String> get extraStats => const <String, String>{};

  /// True while a question panel or other modal blocks the world, so the
  /// shell stops reading the joystick.
  bool get modal => false;
}

// ---------------------------------------------------------------------------
// Small helpers shared by realm games.

/// A repeatable hash of three integers, for procedural worlds.
int realmHash(int a, int b, int c) {
  int h = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791);
  h = (h ^ (h >> 13)) & 0x7fffffff;
  h = (h * 1274126177) & 0x7fffffff;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// A repeatable number between 0 and 1.
double realmUnit(int a, int b, int c) => (realmHash(a, b, c) % 100000) / 100000.0;

Color realmLighten(Color c, double amount) {
  final HSLColor h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color realmDarken(Color c, double amount) {
  final HSLColor h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).withSaturation((h.saturation * 0.85).clamp(0.0, 1.0)).toColor();
}

/// Drawing helpers shared by realm games.
class RealmDraw {
  static final Paint _p = Paint();

  /// Centered text on a canvas.
  static void text(Canvas canvas, String text, Offset center, double size, Color color, {bool bold = true, double maxWidth = 200, int maxLines = 2}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontFamily: 'Rajdhani', height: 1.1)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// A dark rounded label with white text, hanging from [topCenter].
  static void label(Canvas canvas, String text, Offset topCenter, {double size = 13, double maxWidth = 150}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w700, height: 1.15)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    final Rect r = Rect.fromLTWH(topCenter.dx - tp.width / 2 - 8, topCenter.dy - 2, tp.width + 16, tp.height + 8);
    _p.color = Colors.black.withValues(alpha: 0.72);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), _p);
    tp.paint(canvas, Offset(r.left + 8, r.top + 4));
  }

  static void shadow(Canvas canvas, double x, double y, double width) {
    _p.color = Colors.black.withValues(alpha: 0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: width, height: width * 0.32), _p);
  }

  static void glow(Canvas canvas, Offset c, double radius, Color color, {double alpha = 0.25}) {
    _p.color = color.withValues(alpha: alpha);
    canvas.drawCircle(c, radius, _p);
  }

  /// A small person. (x, y) is the middle of the torso; the feet touch y + 18.
  /// [phase] drives the walking swing, [moving] turns it on, [facing] is
  /// -1 or 1 for left or right.
  static void person(Canvas canvas, double x, double y, {double phase = 0, bool moving = false, double facing = 1, Color shirt = const Color(0xFFFF6A00), Color pants = const Color(0xFF2A3A63), Color skin = const Color(0xFFF2B785), Color hair = const Color(0xFF2B1B12), double scale = 1.0}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale, scale);
    final double swing = moving ? sin(phase) : 0.0;
    final double bob = moving ? (sin(phase * 2).abs() * 2.2) : 0.0;
    final double fx = facing >= 0 ? 1.0 : -1.0;
    final double footY = 18;
    shadow(canvas, 0, footY + 1, 30);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    stroke.strokeWidth = 5;
    stroke.color = realmDarken(skin, 0.06);
    canvas.drawLine(Offset(-8 * fx, -3 - bob), Offset(-11 * fx - swing * 6 * fx, 8 - bob), stroke);
    stroke.strokeWidth = 6;
    stroke.color = realmDarken(pants, 0.08);
    canvas.drawLine(Offset(-3, 7 - bob), Offset(-3 - swing * 7 * fx, footY - 1), stroke);
    _p.color = shirt;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9, -8 - bob, 18, 20), const Radius.circular(7)), _p);
    _p.color = realmLighten(shirt, 0.15);
    canvas.drawRect(Rect.fromLTWH(-9, 1 - bob, 18, 3), _p);
    stroke.strokeWidth = 6;
    stroke.color = pants;
    canvas.drawLine(Offset(3, 7 - bob), Offset(3 + swing * 7 * fx, footY - 1), stroke);
    stroke.strokeWidth = 5;
    stroke.color = skin;
    canvas.drawLine(Offset(8 * fx, -3 - bob), Offset(11 * fx + swing * 6 * fx, 8 - bob), stroke);
    _p.color = Colors.white;
    canvas.drawCircle(Offset(-3 - swing * 7 * fx, footY), 3.4, _p);
    canvas.drawCircle(Offset(3 + swing * 7 * fx, footY), 3.4, _p);
    final double hy = -17 - bob;
    _p.color = skin;
    canvas.drawCircle(Offset(0, hy), 9.5, _p);
    _p.color = hair;
    canvas.drawArc(Rect.fromCircle(center: Offset(0, hy), radius: 10), pi, pi, true, _p);
    canvas.drawCircle(Offset(-6 * fx, hy - 2), 4.2, _p);
    _p.color = Colors.white;
    canvas.drawCircle(Offset(-3.4 + fx, hy + 1), 2.6, _p);
    canvas.drawCircle(Offset(3.4 + fx, hy + 1), 2.6, _p);
    _p.color = const Color(0xFF14101A);
    canvas.drawCircle(Offset(-3.4 + fx * 2.4, hy + 1), 1.3, _p);
    canvas.drawCircle(Offset(3.4 + fx * 2.4, hy + 1), 1.3, _p);
    canvas.restore();
  }
}

// ---------------------------------------------------------------------------

/// A multiple choice question as a panel. The game owns the state: it passes
/// which option was [chosen] (null before answering) and handles [onPick] and
/// [onContinue]. Nothing here is timed unless [timeFraction] is given.
class RealmQuestionPanel extends StatelessWidget {
  final OdyQuestion question;
  final Color accent;
  final String header;
  final int? chosen;
  final void Function(int index) onPick;
  final VoidCallback? onContinue;
  final String continueLabel;
  final String? resultLine;
  final double? timeFraction;

  const RealmQuestionPanel({
    super.key,
    required this.question,
    required this.accent,
    required this.onPick,
    this.header = '',
    this.chosen,
    this.onContinue,
    this.continueLabel = 'CONTINUE',
    this.resultLine,
    this.timeFraction,
  });

  @override
  Widget build(BuildContext context) {
    final bool answered = chosen != null;
    final bool ok = answered && chosen == question.answerIndex;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE0B0B0F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent, width: 1.4),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        if (header.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(header.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
          ),
        Text(question.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600)),
        if (timeFraction != null) ...<Widget>[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: timeFraction!.clamp(0.0, 1.0), minHeight: 5, backgroundColor: Colors.white12, color: timeFraction! > 0.3 ? accent : const Color(0xFFFF5252)),
          ),
        ],
        const SizedBox(height: 10),
        for (int i = 0; i < question.options.length; i++) _option(i),
        if (answered && resultLine != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(resultLine!, textAlign: TextAlign.center, style: TextStyle(color: ok ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80), fontWeight: FontWeight.w700, fontSize: 13)),
        ],
        if (answered && onContinue != null) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6A00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: onContinue,
              child: Text(continueLabel, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _option(int i) {
    Color bg = Colors.white10;
    Color border = Colors.white24;
    if (chosen != null) {
      if (i == question.answerIndex) {
        bg = const Color(0xFF1B5E20).withValues(alpha: 0.7);
        border = const Color(0xFF69F0AE);
      } else if (i == chosen) {
        bg = const Color(0xFFB71C1C).withValues(alpha: 0.6);
        border = const Color(0xFFFF8A80);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: GestureDetector(
        onTap: chosen != null ? null : () => onPick(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Row(children: <Widget>[
            Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(child: Text(question.options[i], style: const TextStyle(color: Colors.white, fontSize: 14))),
          ]),
        ),
      ),
    );
  }
}
