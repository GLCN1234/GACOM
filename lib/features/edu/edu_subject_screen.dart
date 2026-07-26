import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class EduSubjectScreen extends StatefulWidget {
  final String subjectId;
  const EduSubjectScreen({super.key, required this.subjectId});
  @override State<EduSubjectScreen> createState() => _EduSubjectState();
}

class _EduSubjectState extends State<EduSubjectScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _subjectData = {
    'math': {'name': 'Mathematics', 'icon': '🧮', 'color': 0xFFFF6A00, 'desc': 'Master numbers and problem solving.', 'skill': 0.85, 'level': 12, 'skills': [
      {'name': 'Arithmetic', 'pct': 0.92}, {'name': 'Fractions', 'pct': 0.86},
      {'name': 'Algebra', 'pct': 0.78}, {'name': 'Problem Solving', 'pct': 0.80},
      {'name': 'Geometry', 'pct': 0.81}, {'name': 'Data & Stats', 'pct': 0.75},
    ]},
    'science': {'name': 'Science', 'icon': '🔬', 'color': 0xFF00C2A8, 'desc': 'Explore physics, chemistry and biology.', 'skill': 0.72, 'level': 8, 'skills': [
      {'name': 'Physics', 'pct': 0.80}, {'name': 'Chemistry', 'pct': 0.65},
      {'name': 'Biology', 'pct': 0.72}, {'name': 'Lab Skills', 'pct': 0.68},
    ]},
    'english': {'name': 'English', 'icon': '📖', 'color': 0xFF3D8BFF, 'desc': 'Build vocabulary, grammar and writing.', 'skill': 0.68, 'level': 7, 'skills': [
      {'name': 'Vocabulary', 'pct': 0.75}, {'name': 'Grammar', 'pct': 0.70},
      {'name': 'Spelling', 'pct': 0.65}, {'name': 'Reading', 'pct': 0.60},
    ]},
    'geography': {'name': 'Geography', 'icon': '🌍', 'color': 0xFF34D399, 'desc': 'Explore the world, its countries and people.', 'skill': 0.70, 'level': 6, 'skills': [
      {'name': 'World Maps', 'pct': 0.78}, {'name': 'Capitals', 'pct': 0.72},
      {'name': 'Climate', 'pct': 0.65}, {'name': 'Populations', 'pct': 0.60},
    ]},
    'history': {'name': 'History', 'icon': '📜', 'color': 0xFFFF8A33, 'desc': 'Discover civilisations and world events.', 'skill': 0.66, 'level': 5, 'skills': [
      {'name': 'African History', 'pct': 0.72}, {'name': 'World Wars', 'pct': 0.65},
      {'name': 'Civilisations', 'pct': 0.60}, {'name': 'Nigerian History', 'pct': 0.75},
    ]},
    'coding': {'name': 'Coding', 'icon': '💻', 'color': 0xFF8B5CF6, 'desc': 'Learn programming, logic and algorithms.', 'skill': 0.62, 'level': 4, 'skills': [
      {'name': 'Logic', 'pct': 0.70}, {'name': 'Algorithms', 'pct': 0.60},
      {'name': 'Binary', 'pct': 0.55}, {'name': 'Web Basics', 'pct': 0.65},
    ]},
    'logic': {'name': 'Logic & IQ', 'icon': '🧠', 'color': 0xFFE85B8A, 'desc': 'Sharpen reasoning and problem-solving.', 'skill': 0.95, 'level': 14, 'skills': [
      {'name': 'Pattern Recognition', 'pct': 0.95}, {'name': 'Sequences', 'pct': 0.90},
      {'name': 'Spatial Reasoning', 'pct': 0.88}, {'name': 'Deduction', 'pct': 0.92},
    ]},
    'languages': {'name': 'Languages', 'icon': '🌐', 'color': 0xFF00E5FF, 'desc': 'Yoruba, Hausa, Igbo, French & more.', 'skill': 0.58, 'level': 3, 'skills': [
      {'name': 'Yoruba', 'pct': 0.60}, {'name': 'Hausa', 'pct': 0.55},
      {'name': 'French', 'pct': 0.52}, {'name': 'Igbo', 'pct': 0.65},
    ]},
    'finance': {'name': 'Financial Literacy', 'icon': '💰', 'color': 0xFF34D399, 'desc': 'Learn money, investing and business.', 'skill': 0.61, 'level': 5, 'skills': [
      {'name': 'Budgeting', 'pct': 0.70}, {'name': 'Investing', 'pct': 0.55},
      {'name': 'Business', 'pct': 0.65}, {'name': 'Economics', 'pct': 0.58},
    ]},
    'engineering': {'name': 'Engineering', 'icon': '⚙', 'color': 0xFF3D8BFF, 'desc': 'Build, design and solve real problems.', 'skill': 0.55, 'level': 4, 'skills': [
      {'name': 'Structures', 'pct': 0.60}, {'name': 'Circuits', 'pct': 0.50},
      {'name': 'Machines', 'pct': 0.55}, {'name': 'Robotics', 'pct': 0.45},
    ]},
    'creativity': {'name': 'Creativity', 'icon': '🎨', 'color': 0xFFFF6A00, 'desc': 'Art, music, design and expression.', 'skill': 0.74, 'level': 6, 'skills': [
      {'name': 'Drawing', 'pct': 0.80}, {'name': 'Music', 'pct': 0.70},
      {'name': 'Design', 'pct': 0.75}, {'name': 'Animation', 'pct': 0.65},
    ]},
  };

  static const _gamesBySubject = {
    'math': [
      {'name': 'Math Quest',       'desc': 'Answer questions and defeat monsters!', 'players': '12.4K', 'tag': 'HOT', 'route': '/arena/practice/speedmath'},
      {'name': 'Speed Math',       'desc': 'Solve as many problems as you can in 60s', 'players': '9.8K', 'tag': 'NEW', 'route': '/arena/practice/speedmath'},
      {'name': 'Number Duel',      'desc': 'Race the AI — solve maths first', 'players': '8.1K', 'tag': '', 'route': '/arena/practice/numberduel'},
      {'name': 'Fraction Master',  'desc': 'Learn fractions with exciting challenges', 'players': '6.4K', 'tag': '', 'route': '/arena/practice/speedmath'},
      {'name': 'Geometry Builder', 'desc': 'Build shapes and solve geometry puzzles', 'players': '7.2K', 'tag': '', 'route': '/arena/practice/2048'},
    ],
    'science': [
      {'name': 'Science Trivia',  'desc': 'Test your science knowledge', 'players': '10.1K', 'tag': 'HOT', 'route': '/arena/practice/trivia'},
      {'name': 'Lab Simulator',   'desc': 'Run virtual experiments', 'players': '7.3K', 'tag': '', 'route': '/arena/practice/trivia'},
    ],
    'english': [
      {'name': 'Word Scramble',   'desc': 'Unscramble the hidden word', 'players': '11.2K', 'tag': 'HOT', 'route': '/arena/practice/wordscramble'},
      {'name': 'Hangman',         'desc': 'Guess the word before time runs out', 'players': '9.5K', 'tag': '', 'route': '/arena/practice/hangman'},
      {'name': 'Grammar Battle',  'desc': 'Fix sentences to defeat opponents', 'players': '6.8K', 'tag': 'NEW', 'route': '/arena/practice/trivia'},
    ],
    'logic': [
      {'name': 'Chess',           'desc': 'The ultimate strategy game', 'players': '15.2K', 'tag': 'HOT', 'route': '/arena/practice/chess'},
      {'name': 'Connect Four',    'desc': '4 in a row — beat the AI', 'players': '8.9K', 'tag': '', 'route': '/arena/practice/connect4'},
      {'name': 'Memory Match',    'desc': 'Flip and match all pairs', 'players': '7.1K', 'tag': '', 'route': '/arena/practice/memory'},
      {'name': 'Dots & Boxes',    'desc': 'Claim the most boxes vs AI', 'players': '5.4K', 'tag': '', 'route': '/arena/practice/dotsboxes'},
    ],
  };

  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data = _subjectData[widget.subjectId] ?? _subjectData['math']!;
    final color = Color(data['color'] as int);
    final skills = data['skills'] as List;
    final games = _gamesBySubject[widget.subjectId] ?? _gamesBySubject['math']!;
    final skill = data['skill'] as double;
    final level = data['level'] as int;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('Edu Gaming', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        actions: [
          IconButton(icon: const Icon(Icons.sports_esports_outlined, size: 20, color: GacomColors.textMuted), onPressed: () {}),
          IconButton(icon: const Icon(Icons.school_outlined, size: 20, color: GacomColors.deepOrange), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        // Subject hero card
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
          child: Row(children: [
            Text(data['icon'] as String, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)),
              Text(data['desc'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('Your Skill: ${(skill * 100).round()}%', style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))),
            ])),
          ])),

        // Tabs
        TabBar(controller: _tab, indicatorColor: GacomColors.deepOrange, labelColor: GacomColors.deepOrange, unselectedLabelColor: GacomColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'GAMES'), Tab(text: 'LEADERBOARD'), Tab(text: 'PROGRESS')]),

        Expanded(child: TabBarView(controller: _tab, children: [
          // ── GAMES tab ───────────────────────────────────────────────────
          ListView(padding: const EdgeInsets.all(16), children: [
            const Text('SUBJECT PROGRESS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(onTap: () => context.push('/edu/profile'),
                child: const Text('View full analysis', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Level $level', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
                  const SizedBox(width: 8),
                  const Text('Advanced', style: TextStyle(color: GacomColors.success, fontSize: 12)),
                  const Spacer(),
                  Text('${(skill * 100).round()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)),
                ]),
                const Text('Overall Proficiency', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: skill, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color), minHeight: 6)),
                const SizedBox(height: 4),
                Text('3,400 / 4,000 XP', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ])),
            const SizedBox(height: 16),
            const Text('TOP SKILLS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 10),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 3.2, crossAxisSpacing: 8, mainAxisSpacing: 8,
              children: skills.map<Widget>((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.border)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: s['pct'] as double, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color), minHeight: 3)),
                  ])),
                  const SizedBox(width: 8),
                  Text('${((s['pct'] as double) * 100).round()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textPrimary)),
                ]))).toList()),
            const SizedBox(height: 20),
            Text('GAMES IN ${(data['name'] as String).toUpperCase()}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 10),
            ...games.map((g) => _GameRow(name: g['name'] as String, desc: g['desc'] as String, players: g['players'] as String, tag: g['tag'] as String, route: g['route'] as String, color: color)),
            const SizedBox(height: 12),
            GestureDetector(onTap: () {},
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('View All ${data['name']} Games', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: color, size: 16),
                ]))),
            const SizedBox(height: 16),
            const Text('DAILY MATH CHALLENGE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(data['icon'] as String, style: const TextStyle(fontSize: 24)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Solve 15 ${data['name']} questions', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
                  const Text('and earn 100 Edu Points!', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                ])),
                GestureDetector(onTap: () => context.push((games.first['route'] as String)),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Start', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)))),
              ])),
          ]),

          // ── LEADERBOARD tab ────────────────────────────────────────────
          ListView.builder(padding: const EdgeInsets.all(16), itemCount: 10, itemBuilder: (_, i) {
            final isMe = i == 4;
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isMe ? color.withOpacity(0.1) : GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: isMe ? color.withOpacity(0.3) : GacomColors.border)),
              child: Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: i < 3 ? [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)][i] : GacomColors.elevatedCard),
                  child: Center(child: Text('${i + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: i < 3 ? Colors.black : GacomColors.textMuted)))),
                const SizedBox(width: 12),
                Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.elevatedCard),
                  child: Center(child: Text(['🧑', '👩', '👨', '🧒', '👦', '👧', '🧑', '👩', '👨', '🧒'][i], style: const TextStyle(fontSize: 16)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isMe ? 'You' : 'Player ${i + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: isMe ? color : GacomColors.textPrimary)),
                  Text('Level ${20 - i}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ])),
                Text('${(4200 - i * 300)} XP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              ]));
          }),

          // ── PROGRESS tab ───────────────────────────────────────────────
          ListView(padding: const EdgeInsets.all(16), children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('WEEKLY PROGRESS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
                const SizedBox(height: 16),
                Row(children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].asMap().entries.map((e) {
                  final h = [0.4, 0.7, 0.5, 0.9, 0.6, 0.3, 0.8][e.key];
                  return Expanded(child: Column(children: [
                    SizedBox(height: 80, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(width: 24, height: 80 * h, decoration: BoxDecoration(color: e.key == 3 ? color : color.withOpacity(0.4), borderRadius: BorderRadius.circular(4))),
                    ])),
                    const SizedBox(height: 4),
                    Text(e.value, style: const TextStyle(color: GacomColors.textMuted, fontSize: 9)),
                  ]));
                }).toList()),
              ])),
            const SizedBox(height: 16),
            ...skills.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                  const Spacer(),
                  Text('${((s['pct'] as double) * 100).round()}%', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: s['pct'] as double, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color), minHeight: 8)),
              ])))),
          ]),
        ])),
      ]),
    );
  }
}

class _GameRow extends StatelessWidget {
  final String name, desc, players, tag, route; final Color color;
  const _GameRow({required this.name, required this.desc, required this.players, required this.tag, required this.route, required this.color});
  @override Widget build(BuildContext ctx) => GestureDetector(onTap: () => GoRouter.of(ctx).push(route),
    child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('🎮', style: TextStyle(fontSize: 24)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
            if (tag.isNotEmpty) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(tag, style: const TextStyle(color: GacomColors.deepOrange, fontSize: 9, fontWeight: FontWeight.w800)))],
          ]),
          Text(desc, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          Text('$players players', style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
        ])),
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)),
      ])));
}
