import 'package:flutter/foundation.dart';
import 'quest_models.dart';

/// Plays one quest from start to finish. All story logic lives here so the
/// screen only has to draw the current scene.
class QuestRunner extends ChangeNotifier {
  final Quest quest;
  late Map<String, int> stats;
  late QuestScene scene;
  int asked = 0;
  int correct = 0;
  int steps = 0;

  /// Stat changes caused by the last action, for the on-screen pop-ups.
  Map<String, int> lastDelta = <String, int>{};

  /// Shown after a choice or answer; the player taps to continue.
  String? feedback;
  bool? feedbackGood;
  String? _pendingNext;

  QuestRunner(this.quest) {
    stats = <String, int>{for (final QuestStat s in quest.stats) s.id: s.start};
    scene = quest.scenes[quest.start]!;
    _resolve(quest.start);
  }

  bool get finished => scene.kind == SceneKind.end;
  bool get hasFeedback => feedback != null;

  List<QuestChoice> get visibleChoices => scene.choices.where((QuestChoice c) => allConds(c.cond, stats)).toList();

  /// Text with {stat} placeholders filled in.
  String get text {
    String t = scene.text;
    for (final QuestStat s in quest.stats) {
      t = t.replaceAll('{${s.id}}', s.show(stats[s.id] ?? 0));
    }
    return t;
  }

  void _apply(Map<String, int> eff) {
    eff.forEach((String k, int d) {
      final QuestStat? def = quest.statById(k);
      final int before = stats[k] ?? 0;
      final int after = def == null ? before + d : def.clampValue(before + d);
      stats[k] = after;
      if (after != before) lastDelta[k] = (lastDelta[k] ?? 0) + (after - before);
    });
  }

  /// Moves to [id], applying scene effects and following branches.
  void _resolve(String id) {
    String cur = id;
    int guard = 0;
    while (guard++ < 50) {
      final QuestScene? s = quest.scenes[cur];
      if (s == null) {
        // Broken story link: finish gracefully instead of crashing.
        scene = QuestScene.fromJson('_missing', <String, dynamic>{'kind': 'end', 'title': 'The end', 'summary': 'This story ended early.', 'outcome': 'ok'});
        return;
      }
      _apply(s.effects);
      steps++;
      if (s.kind == SceneKind.branch) {
        String? target;
        for (final QuestBranch b in s.branches) {
          if (allConds(b.cond, stats)) {
            target = b.next;
            break;
          }
        }
        if (target == null) {
          scene = QuestScene.fromJson('_missing', <String, dynamic>{'kind': 'end', 'title': 'The end', 'summary': 'This story ended early.', 'outcome': 'ok'});
          return;
        }
        cur = target;
        continue;
      }
      scene = s;
      return;
    }
  }

  /// Tap to continue on a plain dialogue scene.
  void advance() {
    if (scene.kind != SceneKind.say || hasFeedback || scene.next == null) return;
    lastDelta = <String, int>{};
    _resolve(scene.next!);
    notifyListeners();
  }

  void choose(QuestChoice c) {
    if (scene.kind != SceneKind.choice || hasFeedback) return;
    lastDelta = <String, int>{};
    _apply(c.effects);
    if (c.learn != null) {
      asked++;
      if (c.learn == true) correct++;
    }
    if (c.feedback != null && c.feedback!.isNotEmpty) {
      feedback = c.feedback;
      feedbackGood = c.learn;
      _pendingNext = c.next;
    } else {
      _resolve(c.next);
    }
    notifyListeners();
  }

  static double? parseNumber(String raw) {
    final String cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    return double.tryParse(cleaned);
  }

  /// Returns false when the typed text is not a number at all.
  bool submitAnswer(String raw) {
    if (scene.kind != SceneKind.input || hasFeedback) return false;
    final double? v = parseNumber(raw);
    if (v == null) return false;
    final bool ok = (v - scene.answer).abs() <= scene.tolerance + 1e-9;
    final QuestOutcome? o = ok ? scene.right : scene.wrong;
    if (o == null) return false;
    lastDelta = <String, int>{};
    asked++;
    if (ok) correct++;
    _apply(o.effects);
    if (o.feedback != null && o.feedback!.isNotEmpty) {
      feedback = o.feedback;
      feedbackGood = ok;
      _pendingNext = o.next;
    } else {
      _resolve(o.next);
    }
    notifyListeners();
    return true;
  }

  void dismissFeedback() {
    if (!hasFeedback) return;
    final String? n = _pendingNext;
    feedback = null;
    feedbackGood = null;
    _pendingNext = null;
    lastDelta = <String, int>{};
    if (n != null) _resolve(n);
    notifyListeners();
  }

  // ---- results -----------------------------------------------------------

  double get accuracy => asked == 0 ? 1 : correct / asked;

  int get stars {
    int s = accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);
    if (scene.outcome == 'bad' && s > 1) s = 1;
    if (scene.outcome == 'ok' && s > 2) s = 2;
    return s;
  }

  int get xpEarned => quest.xp + correct * 10 + (stars == 3 ? 10 : 0);
}
