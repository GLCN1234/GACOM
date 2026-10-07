import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../edu_progress_recorder.dart';
import 'odyssey_bank.dart';

/// One subject region of the world.
class OdySubject {
  final String id;
  final String label;
  final Color color;
  const OdySubject(this.id, this.label, this.color);
}

const List<OdySubject> odySubjects = <OdySubject>[
  OdySubject('math', 'Mathematics', Color(0xFFE65100)),
  OdySubject('physics', 'Physics', Color(0xFF00ACC1)),
  OdySubject('chemistry', 'Chemistry', Color(0xFF8E24AA)),
  OdySubject('biology', 'Biology', Color(0xFF2E7D32)),
  OdySubject('english', 'English', Color(0xFF1E88E5)),
  OdySubject('geography', 'Geography', Color(0xFF00897B)),
  OdySubject('history', 'History', Color(0xFFB8860B)),
  OdySubject('economics', 'Economics', Color(0xFF43A047)),
  OdySubject('civics', 'Civic Education', Color(0xFF5E35B1)),
  OdySubject('coding', 'Computer Science', Color(0xFF00C853)),
  OdySubject('logic', 'Logic', Color(0xFFD81B60)),
  OdySubject('bst', 'Basic Science', Color(0xFF039BE5)),
];

/// Known subjects keep their colour; a subject only a school has (for
/// example Yoruba or Agricultural Science) gets its own region too.
OdySubject odySubjectById(String id, [String? label]) {
  for (final OdySubject s in odySubjects) {
    if (s.id == id) return s;
  }
  int h = 0;
  for (final int c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final HSLColor hsl = HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.6, 0.42);
  final String pretty = label ?? (id.isEmpty ? 'General' : id[0].toUpperCase() + id.substring(1).replaceAll('_', ' '));
  return OdySubject(id, pretty, hsl.toColor());
}

class OdyQuestion {
  final String text;
  final List<String> options;
  final int answerIndex;
  final String subject;
  final String topic;
  final bool fromSchool;
  const OdyQuestion({
    required this.text,
    required this.options,
    required this.answerIndex,
    required this.subject,
    required this.topic,
    required this.fromSchool,
  });

  String get answer => options[answerIndex];
}

/// Infinite maths questions so the Mathematics region never runs dry.
class OdyMath {
  static String _commas(int v) {
    final String s = v.abs().toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return v < 0 ? '-$b' : b.toString();
  }

  /// Returns [question, correct, wrong1, wrong2, wrong3].
  static List<String> generate(Random r) {
    final int kind = r.nextInt(8);
    String q;
    int a;
    final Set<int> wrong = <int>{};
    switch (kind) {
      case 0: {
        final int x = 12 + r.nextInt(88);
        final int y = 12 + r.nextInt(88);
        q = 'What is $x + $y?';
        a = x + y;
        break;
      }
      case 1: {
        final int x = 60 + r.nextInt(140);
        final int y = 11 + r.nextInt(x - 30);
        q = 'What is $x - $y?';
        a = x - y;
        break;
      }
      case 2: {
        final int x = 3 + r.nextInt(10);
        final int y = 3 + r.nextInt(10);
        q = 'What is $x × $y?';
        a = x * y;
        break;
      }
      case 3: {
        final int y = 3 + r.nextInt(10);
        final int z = 3 + r.nextInt(10);
        q = 'What is ${y * z} ÷ $y?';
        a = z;
        break;
      }
      case 4: {
        final List<int> pcts = <int>[10, 20, 25, 50, 75];
        final int p = pcts[r.nextInt(pcts.length)];
        final int base = (4 + r.nextInt(25)) * 20;
        q = 'What is $p% of $base?';
        a = base * p ~/ 100;
        break;
      }
      case 5: {
        final int x = 2 + r.nextInt(12);
        final int m = 2 + r.nextInt(8);
        final int c = 1 + r.nextInt(20);
        q = 'Solve: ${m}x + $c = ${m * x + c}. What is x?';
        a = x;
        break;
      }
      case 6: {
        final int x = 4 + r.nextInt(17);
        q = 'What is $x squared?';
        a = x * x;
        break;
      }
      default: {
        final int l = 4 + r.nextInt(15);
        final int w = 2 + r.nextInt(10);
        q = 'A rectangle is $l cm long and $w cm wide. What is its area in cm²?';
        a = l * w;
        break;
      }
    }
    int guard = 0;
    while (wrong.length < 3 && guard++ < 60) {
      final int off = 1 + r.nextInt(max(3, (a.abs() ~/ 5) + 2));
      final int cand = r.nextBool() ? a + off : a - off;
      if (cand != a && cand >= 0) wrong.add(cand);
    }
    int pad = 1;
    while (wrong.length < 3) {
      wrong.add(a + pad * 7);
      pad++;
    }
    final List<int> w = wrong.toList();
    return <String>[q, _commas(a), _commas(w[0]), _commas(w[1]), _commas(w[2])];
  }
}

/// Hands out questions subject by subject without repeating until a
/// subject's questions have all been used.
class QuestionPool {
  final Random rng;
  final Map<String, List<Map<String, dynamic>>> school;
  late final Map<String, List<Map<String, dynamic>>> _bank;
  final Map<String, List<int>> _bagSchool = <String, List<int>>{};
  final Map<String, List<int>> _bagBank = <String, List<int>>{};

  QuestionPool({required this.rng, Map<String, List<Map<String, dynamic>>>? school})
      : school = school ?? <String, List<Map<String, dynamic>>>{} {
    final dynamic raw = jsonDecode(odysseyBankJson);
    _bank = <String, List<Map<String, dynamic>>>{};
    (raw as Map).forEach((dynamic k, dynamic v) {
      _bank[k as String] = (v as List).map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  bool hasSchool(String subject) => (school[subject] ?? const <Map<String, dynamic>>[]).isNotEmpty;

  int _next(Map<String, List<int>> bags, String key, int n) {
    List<int>? bag = bags[key];
    if (bag == null || bag.isEmpty) {
      bag = List<int>.generate(n, (int i) => i)..shuffle(rng);
      bags[key] = bag;
    }
    return bag.removeLast();
  }

  OdyQuestion pick(String subject) {
    final List<Map<String, dynamic>> sch = school[subject] ?? const <Map<String, dynamic>>[];
    if (sch.isNotEmpty && (rng.nextDouble() < 0.75 || !_bank.containsKey(subject))) {
      for (int tries = 0; tries < 6; tries++) {
        final Map<String, dynamic> raw = sch[_next(_bagSchool, subject, sch.length)];
        final OdyQuestion? q = fromRaw(raw, subject, (raw['topic'] as String?) ?? '', true, rng);
        if (q != null) return q;
      }
    }
    if (subject == 'math' && rng.nextDouble() < 0.5) {
      final List<String> g = OdyMath.generate(rng);
      return _build(g[0], g[1], <String>[g[2], g[3], g[4]], subject, 'Practice', false, rng);
    }
    final List<Map<String, dynamic>>? list = _bank[subject];
    if (list == null || list.isEmpty) {
      // A school-only subject with no usable questions yet: use any subject.
      final List<String> keys = _bank.keys.toList();
      final String k = keys[rng.nextInt(keys.length)];
      return pick(k).withSubject(subject);
    }
    final Map<String, dynamic> e = list[_next(_bagBank, subject, list.length)];
    return _build(e['q'] as String, e['a'] as String, List<String>.from(e['w'] as List), subject, 'Core ideas', false, rng);
  }

  static OdyQuestion _build(String text, String correct, List<String> wrong, String subject, String topic, bool school, Random rng) {
    final List<String> opts = <String>[correct, ...wrong.where((String w) => w != correct)];
    while (opts.length > 4) {
      opts.removeLast();
    }
    opts.shuffle(rng);
    return OdyQuestion(text: text, options: opts, answerIndex: opts.indexOf(correct), subject: subject, topic: topic, fromSchool: school);
  }

  /// Understands the school curriculum format (question, options, answer)
  /// and the older short keys (q, opts, a). Returns null if unusable.
  static OdyQuestion? fromRaw(Map<String, dynamic> m, String subject, String topic, bool school, Random rng) {
    final dynamic qd = m['question'] ?? m['q'];
    final dynamic od = m['options'] ?? m['opts'];
    dynamic ad = m['answer'] ?? m['a'] ?? m['correct'];
    if (qd is! String || qd.trim().isEmpty || od is! List || od.length < 2) return null;
    final List<String> options = od.map((dynamic e) => e.toString()).toList();
    String? answer;
    if (ad is int && ad >= 0 && ad < options.length) {
      answer = options[ad];
    } else if (ad != null) {
      answer = ad.toString();
      if (!options.contains(answer)) {
        // Answers like "B" or "b" point at an option by letter.
        final String t = answer.trim().toUpperCase();
        if (t.length == 1) {
          final int idx = t.codeUnitAt(0) - 'A'.codeUnitAt(0);
          if (idx >= 0 && idx < options.length) answer = options[idx];
        }
      }
    }
    if (answer == null || !options.contains(answer)) return null;
    final List<String> wrong = options.where((String o) => o != answer).toList()..shuffle(rng);
    return _build(qd.trim(), answer, wrong.take(3).toList(), subject, topic, school, rng);
  }
}

extension on OdyQuestion {
  OdyQuestion withSubject(String s) => OdyQuestion(text: text, options: options, answerIndex: answerIndex, subject: s, topic: topic, fromSchool: fromSchool);
}

class SchoolContent {
  /// subject id -> raw questions (each carries its topic)
  final Map<String, List<Map<String, dynamic>>> bySubject;
  final Map<String, String> labels;
  const SchoolContent(this.bySubject, this.labels);
  bool get isEmpty => bySubject.isEmpty;
}

class OdysseyData {
  /// The student's own school curriculum, grouped by subject. Empty when
  /// the student has no school or the school has uploaded nothing yet.
  static Future<SchoolContent> loadSchool() async {
    final Map<String, List<Map<String, dynamic>>> out = <String, List<Map<String, dynamic>>>{};
    final Map<String, String> labels = <String, String>{};
    final String? uid = SupabaseService.currentUserId;
    if (uid == null) return SchoolContent(out, labels);
    try {
      final dynamic link = await SupabaseService.client.from('student_institutions').select('institution_id').eq('student_id', uid).maybeSingle();
      final String? inst = link == null ? null : (link as Map)['institution_id'] as String?;
      if (inst == null) return SchoolContent(out, labels);
      final dynamic rows = await SupabaseService.client
          .from('institution_curricula')
          .select('subject, topic, generated_questions')
          .eq('institution_id', inst)
          .eq('status', 'ready')
          .limit(300);
      for (final dynamic r in (rows as List)) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
        final String label = (m['subject'] as String?) ?? '';
        if (label.isEmpty) continue;
        final String sid = EduProgressRecorder.subjectIdFromLabel(label);
        final String topic = (m['topic'] as String?) ?? '';
        final dynamic gq = m['generated_questions'];
        if (gq is! List) continue;
        for (final dynamic q in gq) {
          if (q is Map) {
            final Map<String, dynamic> qm = Map<String, dynamic>.from(q);
            qm['topic'] = topic;
            out.putIfAbsent(sid, () => <Map<String, dynamic>>[]).add(qm);
            labels[sid] = label;
          }
        }
      }
    } catch (e) {
      debugPrint('school curriculum unavailable: $e');
    }
    // Teachers and admins can also add questions straight to the table.
    try {
      final dynamic rows = await SupabaseService.client.from('odyssey_questions').select('subject, topic, question, options, answer').eq('active', true).limit(500);
      for (final dynamic r in (rows as List)) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
        final String sid = (m['subject'] as String?) ?? 'general';
        out.putIfAbsent(sid, () => <Map<String, dynamic>>[]).add(m);
      }
    } catch (_) {}
    return SchoolContent(out, labels);
  }
}
