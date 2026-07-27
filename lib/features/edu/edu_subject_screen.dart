import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

class EduSubjectScreen extends StatefulWidget {
  final String subjectId;
  const EduSubjectScreen({super.key, required this.subjectId});
  @override State<EduSubjectScreen> createState() => _EduSubjectState();
}

class _EduSubjectState extends State<EduSubjectScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  double _realSkill = 0.0; int _realLevel = 1; int _realXp = 0; bool _dataLoaded = false;

  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); _loadProgress(); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadProgress() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final row = await SupabaseService.client.from('edu_progress')
          .select('xp,level,accuracy').eq('user_id', uid).eq('subject', widget.subjectId).maybeSingle();
      if (row != null && mounted) setState(() {
        _realSkill = (row['accuracy'] as int? ?? 0) / 100.0;
        _realLevel = row['level'] as int? ?? 1;
        _realXp    = row['xp'] as int? ?? 0;
        _dataLoaded = true;
      });
    } catch (_) {}
  }

  static const _subjectMeta = {
    'math':        {'label': 'Mathematics',         'icon': Icons.calculate_outlined,        'color': 0xFFFF6A00},
    'algebra':     {'label': 'Algebra',             'icon': Icons.functions_rounded,         'color': 0xFFFF8A33},
    'geometry':    {'label': 'Geometry',            'icon': Icons.gesture_rounded,           'color': 0xFFE85B8A},
    'statistics':  {'label': 'Statistics',          'icon': Icons.show_chart_rounded,        'color': 0xFF3D8BFF},
    'simultaneous':{'label': 'Simultaneous Eqns',  'icon': Icons.swap_horiz_rounded,        'color': 0xFF8B5CF6},
    'physics':     {'label': 'Physics',             'icon': Icons.science_outlined,          'color': 0xFF00C2A8},
    'chemistry':   {'label': 'Chemistry',           'icon': Icons.biotech_outlined,          'color': 0xFF8B5CF6},
    'biology':     {'label': 'Biology',             'icon': Icons.eco_outlined,              'color': 0xFF34D399},
    'english':     {'label': 'English Language',    'icon': Icons.translate_outlined,        'color': 0xFF3D8BFF},
    'literature':  {'label': 'Literature',          'icon': Icons.record_voice_over_outlined,'color': 0xFFFF8A33},
    'geography':   {'label': 'Geography',           'icon': Icons.public_outlined,           'color': 0xFF00C2A8},
    'history':     {'label': 'History',             'icon': Icons.history_edu_outlined,      'color': 0xFFFF8A33},
    'economics':   {'label': 'Economics',           'icon': Icons.account_balance_outlined,  'color': 0xFF34D399},
    'civics':      {'label': 'Civic Education',     'icon': Icons.groups_outlined,           'color': 0xFFFF6A00},
    'coding':      {'label': 'Computer Science',    'icon': Icons.code_outlined,             'color': 0xFF8B5CF6},
    'ict':         {'label': 'ICT',                 'icon': Icons.memory_outlined,           'color': 0xFF00E5FF},
    'logic':       {'label': 'Logic & IQ',          'icon': Icons.psychology_outlined,       'color': 0xFFE85B8A},
    'waec':        {'label': 'WAEC/NECO Prep',      'icon': Icons.school_outlined,           'color': 0xFFFF6A00},
    'jamb':        {'label': 'JAMB Prep',           'icon': Icons.star_border_rounded,       'color': 0xFFFFD700},
    'entrance':    {'label': 'Common Entrance',     'icon': Icons.format_list_bulleted_rounded,'color': 0xFF00C2A8},
    'yoruba':      {'label': 'Yoruba',              'icon': Icons.language_outlined,         'color': 0xFF34D399},
    'igbo':        {'label': 'Igbo',                'icon': Icons.language_outlined,         'color': 0xFFFF8A33},
    'hausa':       {'label': 'Hausa',               'icon': Icons.language_outlined,         'color': 0xFF3D8BFF},
    'finance':     {'label': 'Financial Literacy',  'icon': Icons.paid_outlined,             'color': 0xFF34D399},
    'engineering': {'label': 'Engineering',         'icon': Icons.engineering_outlined,      'color': 0xFF3D8BFF},
  };

  // Real game lists per subject — each entry has a built practice route
  static const _gamesBySubject = {
    'math': [
      {'name': 'Algebra Trainer',   'desc': 'Step-by-step: linear, quadratic, simultaneous equations', 'icon': Icons.functions_rounded,    'tag': 'NEW',  'route': '/arena/practice/algebra'},
      {'name': 'Speed Math',        'desc': 'Solve equations before the clock runs out',           'icon': Icons.bolt_rounded,         'tag': 'HOT',  'route': '/arena/practice/speedmath'},
      {'name': 'Number Duel',       'desc': 'Race the AI to solve problems first',                 'icon': Icons.timer_rounded,         'tag': '',     'route': '/arena/practice/numberduel'},
      {'name': '2048',              'desc': 'Combine tiles to reach 2048',                         'icon': Icons.dashboard_rounded,     'tag': '',     'route': '/arena/practice/2048'},
      {'name': 'Math Trivia',       'desc': 'Answer 10 rapid-fire math questions',                 'icon': Icons.quiz_outlined,         'tag': '',     'route': '/arena/practice/trivia'},
    ],
    'algebra': [
      {'name': 'Algebra Trainer',   'desc': 'Step-by-step linear, quadratic & factorisation',     'icon': Icons.functions_rounded,     'tag': 'NEW',  'route': '/arena/practice/algebra'},
      {'name': 'Equation Solver',   'desc': 'Solve simultaneous equations step by step',           'icon': Icons.swap_horiz_rounded,   'tag': '',     'route': '/edu/game/simultaneous'},
      {'name': 'Speed Math',        'desc': 'Algebraic speed challenge',                           'icon': Icons.bolt_rounded,         'tag': 'HOT',  'route': '/arena/practice/speedmath'},
    ],
    'simultaneous': [
      {'name': 'Algebra Trainer',   'desc': 'Solve simultaneous equations by substitution & elimination', 'icon': Icons.functions_rounded, 'tag': 'NEW', 'route': '/arena/practice/algebra'},
      {'name': 'Speed Math',        'desc': 'Rapid simultaneous equation challenges',              'icon': Icons.bolt_rounded,         'tag': '',     'route': '/arena/practice/speedmath'},
    ],
    'geometry': [
      {'name': 'Shape Identifier', 'desc': 'Identify polygons and their properties',             'icon': Icons.category_outlined,    'tag': 'NEW',  'route': '/edu/game/geometry'},
      {'name': 'Angle Calculator', 'desc': 'Find missing angles in triangles and polygons',      'icon': Icons.architecture_rounded, 'tag': '',     'route': '/edu/game/geometry'},
      {'name': 'Proof Builder',    'desc': 'Construct geometric proofs step by step',            'icon': Icons.build_outlined,       'tag': '',     'route': '/edu/game/geometry'},
    ],
    'physics': [
      {'name': 'Physics Trainer',  'desc': 'Step-by-step: Force, Energy, Waves, Electricity',   'icon': Icons.science_outlined,     'tag': 'NEW',  'route': '/arena/practice/physics'},
      {'name': 'Formula Quiz',     'desc': 'Match physics formulas to their meanings',           'icon': Icons.functions_rounded,    'tag': '',     'route': '/edu/game/physics_quiz'},
      {'name': 'Speed Calc',       'desc': 'Solve physics calculations fast',                    'icon': Icons.bolt_rounded,        'tag': '',     'route': '/arena/practice/speedmath'},
      {'name': 'Science Duel',     'desc': 'Race another student on physics questions',          'icon': Icons.timer_rounded,        'tag': '',     'route': '/arena/practice/numberduel'},
    ],
    'chemistry': [
      {'name': 'Element Match',    'desc': 'Match elements to their symbols on the periodic table','icon': Icons.grid_on_outlined,   'tag': 'HOT',  'route': '/edu/game/chem_quiz'},
      {'name': 'Equation Balancer','desc': 'Balance chemical equations',                         'icon': Icons.balance_rounded,      'tag': 'NEW',  'route': '/edu/game/chem_quiz'},
      {'name': 'Chemistry Trivia', 'desc': 'Test your chemistry knowledge',                      'icon': Icons.quiz_outlined,        'tag': '',     'route': '/edu/game/chem_quiz'},
      {'name': 'Compound Builder', 'desc': 'Identify compounds from formulas',                   'icon': Icons.hub_outlined,         'tag': '',     'route': '/edu/game/chem_quiz'},
    ],
    'biology': [
      {'name': 'Biology Trivia',   'desc': 'Questions on cells, genetics, ecology and the body', 'icon': Icons.quiz_outlined,        'tag': 'HOT',  'route': '/edu/game/bio_quiz'},
      {'name': 'Cell Diagram',     'desc': 'Label parts of plant and animal cells',              'icon': Icons.circle_outlined,      'tag': 'NEW',  'route': '/edu/game/bio_quiz'},
      {'name': 'Classification Game','desc':'Classify living organisms into kingdoms',           'icon': Icons.account_tree_outlined,'tag': '',     'route': '/edu/game/bio_quiz'},
    ],
    'english': [
      {'name': 'Word Scramble',    'desc': 'Unscramble vocabulary words under time pressure',    'icon': Icons.spellcheck_rounded,   'tag': 'HOT',  'route': '/arena/practice/wordscramble'},
      {'name': 'Hangman',          'desc': 'Guess the word before you run out of lives',         'icon': Icons.abc_rounded,          'tag': '',     'route': '/arena/practice/hangman'},
      {'name': 'Grammar Quiz',     'desc': 'Test your grammar with rapid questions',             'icon': Icons.quiz_outlined,        'tag': 'NEW',  'route': '/arena/practice/trivia'},
      {'name': 'Sentence Builder', 'desc': 'Arrange words into correct sentences',               'icon': Icons.format_align_left_rounded,'tag':'',  'route': '/arena/practice/trivia'},
    ],
    'logic': [
      {'name': 'Chess',            'desc': 'The ultimate strategy game — built-in AI opponent',  'icon': Icons.extension_rounded,    'tag': 'HOT',  'route': '/arena/practice/chess'},
      {'name': 'Connect Four',     'desc': 'Strategic 4-in-a-row against the AI',               'icon': Icons.circle_outlined,      'tag': '',     'route': '/arena/practice/connect4'},
      {'name': 'Memory Match',     'desc': 'Train working memory — flip and match pairs',        'icon': Icons.grid_view_rounded,    'tag': '',     'route': '/arena/practice/memory'},
      {'name': 'Reversi',          'desc': 'Flip your opponent\'s tiles to dominate the board', 'icon': Icons.radio_button_checked_rounded,'tag':'','route': '/arena/practice/reversi'},
      {'name': 'Dots & Boxes',     'desc': 'Strategic line-drawing puzzle game',                 'icon': Icons.border_all_rounded,   'tag': '',     'route': '/arena/practice/dotsboxes'},
    ],
    'waec': [
      {'name': 'WAEC Maths Quiz',  'desc': 'Past WAEC mathematics questions, timed',            'icon': Icons.quiz_outlined,        'tag': 'HOT',  'route': '/arena/practice/trivia'},
      {'name': 'WAEC English',     'desc': 'Comprehension and grammar from past papers',         'icon': Icons.translate_outlined,   'tag': '',     'route': '/arena/practice/trivia'},
      {'name': 'WAEC Science',     'desc': 'Physics, Chemistry, Biology past questions',         'icon': Icons.science_outlined,     'tag': '',     'route': '/arena/practice/trivia'},
      {'name': 'Speed Challenge',  'desc': 'Answer as many WAEC questions as possible in 60s',  'icon': Icons.bolt_rounded,        'tag': 'NEW',  'route': '/arena/practice/speedmath'},
    ],
    'jamb': [
      {'name': 'JAMB CBT Practice','desc': 'Simulate the JAMB computer-based test format',      'icon': Icons.computer_outlined,    'tag': 'HOT',  'route': '/arena/practice/trivia'},
      {'name': 'Use of English',   'desc': 'JAMB Use of English past questions',                'icon': Icons.translate_outlined,   'tag': '',     'route': '/arena/practice/trivia'},
      {'name': 'JAMB Mathematics', 'desc': 'Mathematics past questions speed challenge',         'icon': Icons.calculate_outlined,   'tag': '',     'route': '/arena/practice/speedmath'},
    ],
    'finance': [
      {'name': 'Budget Builder',   'desc': 'Allocate income and manage expenses wisely',         'icon': Icons.pie_chart_outline_rounded,'tag':'NEW','route': '/arena/practice/numberduel'},
      {'name': 'Interest Calculator','desc':'Calculate simple and compound interest',            'icon': Icons.percent_rounded,      'tag': '',     'route': '/arena/practice/speedmath'},
      {'name': 'Finance Trivia',   'desc': 'Test your financial literacy knowledge',             'icon': Icons.quiz_outlined,        'tag': '',     'route': '/arena/practice/trivia'},
    ],
  };

  static const _defaultGames = [
    {'name': 'Subject Trivia',  'desc': 'Test your knowledge with rapid questions',  'icon': Icons.quiz_outlined,     'tag': 'NEW', 'route': '/arena/practice/trivia'},
    {'name': 'Speed Challenge', 'desc': 'Fastest answers win in this timed battle',  'icon': Icons.bolt_rounded,      'tag': '',    'route': '/arena/practice/speedmath'},
    {'name': 'Compete Live',    'desc': 'Face another student in a live quiz battle','icon': Icons.emoji_events_outlined,'tag':'HOT','route': '/edu/compete'},
  ];

  @override
  Widget build(BuildContext context) {
    final meta = _subjectMeta[widget.subjectId] ?? _subjectMeta['math']!;
    final color = Color(meta['color'] as int);
    final games = _gamesBySubject[widget.subjectId] ?? _defaultGames;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(meta['label'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
      ),
      body: Column(children: [
        // Subject header
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(meta['icon'] as IconData, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meta['label'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(_dataLoaded ? 'Level $_realLevel' : 'Not started',
                    style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))),
                if (_dataLoaded) ...[const SizedBox(width: 8),
                  Text('${(_realSkill * 100).round()}% accuracy', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))],
              ]),
            ])),
          ])),

        TabBar(controller: _tab, indicatorColor: GacomColors.deepOrange, labelColor: GacomColors.deepOrange, unselectedLabelColor: GacomColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'GAMES'), Tab(text: 'LEADERBOARD'), Tab(text: 'PROGRESS')]),

        Expanded(child: TabBarView(controller: _tab, children: [
          // ── GAMES ────────────────────────────────────────────────────────
          ListView(padding: const EdgeInsets.all(16), children: [
            if (!_dataLoaded)
              Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
                child: Row(children: [
                  Icon(Icons.play_circle_outline_rounded, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Start playing to build your skill', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                    const Text('Your accuracy and XP will appear here after your first game.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                  ])),
                ])),
            const Text('AVAILABLE GAMES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 10),
            ...games.map((g) => GestureDetector(
              onTap: () => context.push(g['route'] as String),
              child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(g['icon'] as IconData, color: color, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(g['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                      if ((g['tag'] as String).isNotEmpty) ...[const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.14), borderRadius: BorderRadius.circular(4)),
                          child: Text(g['tag'] as String, style: const TextStyle(color: GacomColors.deepOrange, fontSize: 9, fontWeight: FontWeight.w800)))],
                    ]),
                    const SizedBox(height: 2),
                    Text(g['desc'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  ])),
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18)),
                ])),
            )),
            const SizedBox(height: 16),
            GestureDetector(onTap: () => context.push('/edu/compete'),
              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.emoji_events_outlined, color: GacomColors.deepOrange, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily Challenge', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
                    Text('Compete live and earn Edu Points', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Compete', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                ]))),
          ]),

          // ── LEADERBOARD ──────────────────────────────────────────────────
          ListView.builder(padding: const EdgeInsets.all(16), itemCount: 10, itemBuilder: (_, i) {
            final medals = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: i == 0 ? color.withOpacity(0.08) : GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: i == 0 ? color.withOpacity(0.3) : GacomColors.border)),
              child: Row(children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: i < 3 ? medals[i] : GacomColors.elevatedCard),
                  child: Center(child: Text('${i + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: i < 3 ? Colors.black : GacomColors.textMuted)))),
                const SizedBox(width: 12),
                Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.elevatedCard, border: Border.all(color: color.withOpacity(0.3))),
                  child: Center(child: Icon(Icons.person_rounded, color: color, size: 18))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Student ${i + 1}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                  Text('Level ${20 - i}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ])),
                Text('${4200 - i * 300} XP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              ]));
          }),

          // ── PROGRESS ────────────────────────────────────────────────────
          ListView(padding: const EdgeInsets.all(16), children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
              child: _dataLoaded ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Level $_realLevel', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
                  const SizedBox(width: 10),
                  Text(_realLevel >= 10 ? 'Expert' : _realLevel >= 5 ? 'Intermediate' : 'Beginner', style: const TextStyle(color: GacomColors.success, fontSize: 12)),
                  const Spacer(),
                  Text('${(_realSkill * 100).round()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: GacomColors.textPrimary)),
                ]),
                const SizedBox(height: 4),
                const Text('Accuracy', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _realSkill, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color), minHeight: 8)),
                const SizedBox(height: 8),
                Text('$_realXp XP earned in this subject', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ]) : Column(children: [
                Icon(Icons.play_circle_outline_rounded, size: 48, color: GacomColors.textMuted),
                const SizedBox(height: 12),
                const Text('No progress yet', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Play a game in this subject to start tracking your progress.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
              ])),
          ]),
        ])),
      ]),
    );
  }
}
