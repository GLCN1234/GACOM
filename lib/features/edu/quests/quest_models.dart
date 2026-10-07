import 'dart:convert';
import 'package:flutter/material.dart';

Color questColor(String? hex, [Color fallback = const Color(0xFFFF6A00)]) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return fallback;
  final int? v = int.tryParse(hex.substring(1), radix: 16);
  if (v == null) return fallback;
  return Color(0xFF000000 | v);
}

const Map<String, IconData> _questIcons = <String, IconData>{
  'payments': Icons.payments_rounded,
  'storefront': Icons.storefront_rounded,
  'star': Icons.star_rounded,
  'schedule': Icons.schedule_rounded,
  'favorite': Icons.favorite_rounded,
  'groups': Icons.groups_rounded,
  'water_drop': Icons.water_drop_rounded,
  'savings': Icons.savings_rounded,
  'trending_up': Icons.trending_up_rounded,
  'health_and_safety': Icons.health_and_safety_rounded,
  'bolt': Icons.bolt_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'school': Icons.school_rounded,
  'local_fire_department': Icons.local_fire_department_rounded,
  'science': Icons.science_rounded,
  'public': Icons.public_rounded,
  'menu_book': Icons.menu_book_rounded,
  'calculate': Icons.calculate_rounded,
  'eco': Icons.eco_rounded,
  'account_balance': Icons.account_balance_rounded,
};

IconData questIcon(String? name) => _questIcons[name] ?? Icons.auto_stories_rounded;

int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

Map<String, int> _effects(dynamic raw) {
  final Map<String, int> out = <String, int>{};
  if (raw is Map) {
    raw.forEach((dynamic k, dynamic v) {
      if (v is num) out[k as String] = v.toInt();
    });
  }
  return out;
}

class QuestCond {
  final String stat;
  final String op;
  final num value;
  const QuestCond(this.stat, this.op, this.value);

  factory QuestCond.fromJson(Map<String, dynamic> j) => QuestCond(j['stat'] as String, j['op'] as String, (j['value'] as num?) ?? 0);

  bool test(Map<String, int> stats) {
    final int v = stats[stat] ?? 0;
    switch (op) {
      case '>=': return v >= value;
      case '>': return v > value;
      case '<=': return v <= value;
      case '<': return v < value;
      case '==': return v == value;
      default: return false;
    }
  }
}

List<QuestCond> _conds(dynamic raw) {
  if (raw is! List) return const <QuestCond>[];
  return raw.map((dynamic e) => QuestCond.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}

bool allConds(List<QuestCond> conds, Map<String, int> stats) {
  for (final QuestCond c in conds) {
    if (!c.test(stats)) return false;
  }
  return true;
}

class QuestStat {
  final String id;
  final String label;
  final String icon;
  final int start;
  final int? min;
  final int? max;
  final String format;
  const QuestStat({required this.id, required this.label, required this.icon, required this.start, this.min, this.max, this.format = 'int'});

  factory QuestStat.fromJson(Map<String, dynamic> j) => QuestStat(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? (j['id'] as String),
        icon: (j['icon'] as String?) ?? 'star',
        start: _int(j['start']),
        min: j['min'] is num ? (j['min'] as num).toInt() : null,
        max: j['max'] is num ? (j['max'] as num).toInt() : null,
        format: (j['format'] as String?) ?? 'int',
      );

  int clampValue(int v) {
    int r = v;
    if (min != null && r < min!) r = min!;
    if (max != null && r > max!) r = max!;
    return r;
  }

  String show(int v) {
    switch (format) {
      case 'naira':
        return '₦${_commas(v)}';
      case 'min':
        return '$v min';
      default:
        return '$v';
    }
  }

  static String _commas(int v) {
    final String s = v.abs().toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return v < 0 ? '-$b' : b.toString();
  }
}

class QuestCast {
  final String id;
  final String name;
  final String role;
  final Color color;
  const QuestCast({required this.id, required this.name, required this.role, required this.color});
}

class QuestChoice {
  final String text;
  final String next;
  final Map<String, int> effects;
  final bool? learn;
  final String? feedback;
  final List<QuestCond> cond;
  const QuestChoice({required this.text, required this.next, required this.effects, required this.learn, required this.feedback, required this.cond});

  factory QuestChoice.fromJson(Map<String, dynamic> j) => QuestChoice(
        text: j['text'] as String,
        next: j['next'] as String,
        effects: _effects(j['effects']),
        learn: j['learn'] is bool ? j['learn'] as bool : null,
        feedback: j['feedback'] as String?,
        cond: _conds(j['if']),
      );
}

class QuestOutcome {
  final String next;
  final String? feedback;
  final Map<String, int> effects;
  const QuestOutcome({required this.next, required this.feedback, required this.effects});

  factory QuestOutcome.fromJson(Map<String, dynamic> j) =>
      QuestOutcome(next: j['next'] as String, feedback: j['feedback'] as String?, effects: _effects(j['effects']));
}

class QuestBranch {
  final String next;
  final List<QuestCond> cond;
  const QuestBranch(this.next, this.cond);
}

enum SceneKind { say, choice, input, branch, end }

class QuestScene {
  final String id;
  final SceneKind kind;
  final String? speaker;
  final String text;
  final String? bg;
  final String? next;
  final Map<String, int> effects;
  final List<QuestChoice> choices;
  final double answer;
  final double tolerance;
  final String? unit;
  final String? hint;
  final QuestOutcome? right;
  final QuestOutcome? wrong;
  final List<QuestBranch> branches;
  final String title;
  final String summary;
  final String outcome;

  const QuestScene({
    required this.id,
    required this.kind,
    required this.speaker,
    required this.text,
    required this.bg,
    required this.next,
    required this.effects,
    required this.choices,
    required this.answer,
    required this.tolerance,
    required this.unit,
    required this.hint,
    required this.right,
    required this.wrong,
    required this.branches,
    required this.title,
    required this.summary,
    required this.outcome,
  });

  factory QuestScene.fromJson(String id, Map<String, dynamic> j) {
    final String k = (j['kind'] as String?) ?? 'say';
    final SceneKind kind = SceneKind.values.firstWhere((SceneKind e) => e.name == k, orElse: () => SceneKind.say);
    return QuestScene(
      id: id,
      kind: kind,
      speaker: j['speaker'] as String?,
      text: (j['text'] as String?) ?? '',
      bg: j['bg'] as String?,
      next: j['next'] as String?,
      effects: _effects(j['effects']),
      choices: ((j['choices'] as List?) ?? const <dynamic>[]).map((dynamic e) => QuestChoice.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      answer: (j['answer'] as num?)?.toDouble() ?? 0,
      tolerance: (j['tolerance'] as num?)?.toDouble() ?? 0,
      unit: j['unit'] as String?,
      hint: j['hint'] as String?,
      right: j['right'] is Map ? QuestOutcome.fromJson(Map<String, dynamic>.from(j['right'] as Map)) : null,
      wrong: j['wrong'] is Map ? QuestOutcome.fromJson(Map<String, dynamic>.from(j['wrong'] as Map)) : null,
      branches: ((j['branches'] as List?) ?? const <dynamic>[]).map((dynamic e) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
        return QuestBranch(m['next'] as String, _conds(m['if']));
      }).toList(),
      title: (j['title'] as String?) ?? '',
      summary: (j['summary'] as String?) ?? '',
      outcome: (j['outcome'] as String?) ?? 'ok',
    );
  }
}

class Quest {
  final String id;
  final String title;
  final String subject;
  final String level;
  final String blurb;
  final String icon;
  final List<Color> colors;
  final int xp;
  final List<QuestStat> stats;
  final Map<String, QuestCast> cast;
  final String start;
  final Map<String, QuestScene> scenes;

  const Quest({
    required this.id,
    required this.title,
    required this.subject,
    required this.level,
    required this.blurb,
    required this.icon,
    required this.colors,
    required this.xp,
    required this.stats,
    required this.cast,
    required this.start,
    required this.scenes,
  });

  factory Quest.fromJson(Map<String, dynamic> j) {
    final Map<String, QuestScene> scenes = <String, QuestScene>{};
    (j['scenes'] as Map).forEach((dynamic k, dynamic v) {
      scenes[k as String] = QuestScene.fromJson(k, Map<String, dynamic>.from(v as Map));
    });
    final Map<String, QuestCast> cast = <String, QuestCast>{};
    if (j['cast'] is Map) {
      (j['cast'] as Map).forEach((dynamic k, dynamic v) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(v as Map);
        cast[k as String] = QuestCast(id: k, name: (m['name'] as String?) ?? k, role: (m['role'] as String?) ?? '', color: questColor(m['color'] as String?));
      });
    }
    final List<dynamic> cols = (j['colors'] as List?) ?? const <dynamic>['#FF6A00', '#B23B00'];
    return Quest(
      id: j['id'] as String,
      title: j['title'] as String,
      subject: (j['subject'] as String?) ?? 'math',
      level: (j['level'] as String?) ?? '',
      blurb: (j['blurb'] as String?) ?? '',
      icon: (j['icon'] as String?) ?? 'school',
      colors: <Color>[questColor(cols.isNotEmpty ? cols[0] as String : null), questColor(cols.length > 1 ? cols[1] as String : null)],
      xp: _int(j['xp'], 25),
      stats: ((j['stats'] as List?) ?? const <dynamic>[]).map((dynamic e) => QuestStat.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      cast: cast,
      start: j['start'] as String,
      scenes: scenes,
    );
  }

  static Quest? tryParse(String source) {
    try {
      final dynamic j = jsonDecode(source);
      if (j is! Map) return null;
      final Quest q = Quest.fromJson(Map<String, dynamic>.from(j));
      return q.scenes.containsKey(q.start) ? q : null;
    } catch (_) {
      return null;
    }
  }

  QuestStat? statById(String id) {
    for (final QuestStat s in stats) {
      if (s.id == id) return s;
    }
    return null;
  }
}
