import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'edu_paywall_screen.dart';

class EduSubjectsScreen extends StatelessWidget {
  const EduSubjectsScreen({super.key});

  static const _subjects = [
    // Mathematics branch
    {'icon': Icons.calculate_outlined,       'label': 'Mathematics',       'id': 'math',        'color': 0xFFFF6A00, 'games': 19, 'desc': 'Algebra, Geometry, Calculus, Statistics'},
    {'icon': Icons.functions_rounded,        'label': 'Algebra',           'id': 'algebra',     'color': 0xFFFF8A33, 'games': 8,  'desc': 'Linear equations, Quadratics, Polynomials'},
    {'icon': Icons.gesture_rounded,          'label': 'Geometry',          'id': 'geometry',    'color': 0xFFE85B8A, 'games': 6,  'desc': 'Shapes, Angles, Theorems, Proofs'},
    {'icon': Icons.show_chart_rounded,       'label': 'Statistics',        'id': 'statistics',  'color': 0xFF3D8BFF, 'games': 5,  'desc': 'Data, Probability, Graphs, Analysis'},
    {'icon': Icons.swap_horiz_rounded,       'label': 'Simultaneous Eqn', 'id': 'simultaneous','color': 0xFF8B5CF6, 'games': 4,  'desc': 'Systems of equations, Substitution, Elimination'},
    // Sciences
    {'icon': Icons.science_outlined,         'label': 'Physics',           'id': 'physics',     'color': 0xFF00C2A8, 'games': 9,  'desc': 'Motion, Forces, Energy, Waves, Electricity'},
    {'icon': Icons.biotech_outlined,         'label': 'Chemistry',         'id': 'chemistry',   'color': 0xFF8B5CF6, 'games': 8,  'desc': 'Elements, Reactions, Bonding, Organic'},
    {'icon': Icons.eco_outlined,             'label': 'Biology',           'id': 'biology',     'color': 0xFF34D399, 'games': 7,  'desc': 'Cells, Genetics, Ecology, Human Body'},
    {'icon': Icons.precision_manufacturing_outlined, 'label': 'Basic Science and Technology', 'id': 'bst', 'color': 0xFF00C2A8, 'games': 8, 'desc': 'Basic Science, PHE, Basic Technology, IT'},
    // Languages
    {'icon': Icons.translate_outlined,       'label': 'English Language',  'id': 'english',     'color': 0xFF3D8BFF, 'games': 10, 'desc': 'Grammar, Comprehension, Essay, Vocabulary'},
    {'icon': Icons.record_voice_over_outlined,'label': 'Literature',       'id': 'literature',  'color': 0xFFFF8A33, 'games': 5,  'desc': 'Prose, Poetry, Drama, African Literature'},
    // Social Sciences
    {'icon': Icons.public_outlined,          'label': 'Geography',         'id': 'geography',   'color': 0xFF00C2A8, 'games': 7,  'desc': 'Physical, Human, Climate, Map Reading'},
    {'icon': Icons.history_edu_outlined,     'label': 'History',           'id': 'history',     'color': 0xFFFF8A33, 'games': 6,  'desc': 'African, World, Nigerian, Colonial History'},
    {'icon': Icons.account_balance_outlined, 'label': 'Economics',         'id': 'economics',   'color': 0xFF34D399, 'games': 5,  'desc': 'Supply & Demand, Markets, GDP, Trade'},
    {'icon': Icons.groups_outlined,          'label': 'Civic Education',   'id': 'civics',      'color': 0xFFFF6A00, 'games': 4,  'desc': 'Government, Rights, Democracy, Constitution'},
    // Technology
    {'icon': Icons.code_outlined,            'label': 'Computer Science',  'id': 'coding',      'color': 0xFF8B5CF6, 'games': 9,  'desc': 'Algorithms, Programming, Networks, Databases'},
    {'icon': Icons.memory_outlined,          'label': 'ICT',               'id': 'ict',         'color': 0xFF00E5FF, 'games': 5,  'desc': 'Hardware, Software, Internet, Cybersecurity'},
    // Cognitive
    {'icon': Icons.psychology_outlined,      'label': 'Logic & IQ',        'id': 'logic',       'color': 0xFFE85B8A, 'games': 10, 'desc': 'Reasoning, Puzzles, Patterns, Critical Thinking'},
    // Exam prep
    {'icon': Icons.school_outlined,          'label': 'WAEC/NECO Prep',    'id': 'waec',        'color': 0xFFFF6A00, 'games': 12, 'desc': 'Past questions, Time management, All subjects'},
    {'icon': Icons.star_border_rounded,      'label': 'JAMB Prep',         'id': 'jamb',        'color': 0xFFFFD700, 'games': 10, 'desc': 'UTME questions, CBT practice, All subjects'},
    {'icon': Icons.format_list_bulleted_rounded,'label': 'Common Entrance', 'id': 'entrance',   'color': 0xFF00C2A8, 'games': 8,  'desc': 'Primary to secondary school entrance exam prep'},
    // Local languages
    {'icon': Icons.language_outlined,        'label': 'Yoruba',            'id': 'yoruba',      'color': 0xFF34D399, 'games': 4,  'desc': 'Vocabulary, Grammar, Literature, Proverbs'},
    {'icon': Icons.language_outlined,        'label': 'Igbo',              'id': 'igbo',        'color': 0xFFFF8A33, 'games': 4,  'desc': 'Vocabulary, Grammar, Literature, Proverbs'},
    {'icon': Icons.language_outlined,        'label': 'Hausa',             'id': 'hausa',       'color': 0xFF3D8BFF, 'games': 4,  'desc': 'Vocabulary, Grammar, Literature, Proverbs'},
    // Others
    {'icon': Icons.paid_outlined,            'label': 'Financial Literacy', 'id': 'finance',    'color': 0xFF34D399, 'games': 5,  'desc': 'Budgeting, Savings, Investing, Banking'},
    {'icon': Icons.engineering_outlined,     'label': 'Engineering',        'id': 'engineering','color': 0xFF3D8BFF, 'games': 4,  'desc': 'Structures, Circuits, Machines, Design'},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('ALL SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop())),
    body: Column(children: [
      // Free plan upgrade banner
      GestureDetector(
        onTap: () => context.push('/edu/paywall'),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [GacomColors.deepOrange.withOpacity(0.15), GacomColors.cardDark]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.lock_open_rounded, color: GacomColors.deepOrange, size: 20),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Free Plan — Mathematics only', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
              Text('Upgrade to ₦3,500/month to unlock all 24 subjects', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, color: GacomColors.deepOrange, size: 14),
          ]),
        ),
      ),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.35),
        itemCount: _subjects.length,
        itemBuilder: (_, i) {
          final s = _subjects[i];
          final color = Color(s['color'] as int);
          final isFree = s['id'] == 'math';
          return GestureDetector(
            onTap: () {
              if (isFree) {
                context.push('/edu/subject/${s['id']}');
              } else {
                // Show paywall for locked subjects
                context.push('/edu/paywall', extra: s['label']);
              }
            },
            child: Stack(children: [
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isFree ? GacomColors.cardDark : GacomColors.cardDark.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isFree ? color.withOpacity(0.2) : GacomColors.border.withOpacity(0.4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: isFree ? color.withOpacity(0.12) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(10)),
                      child: Icon(s['icon'] as IconData, color: isFree ? color : GacomColors.textMuted, size: 20)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: isFree ? color.withOpacity(0.1) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
                      child: Text('${s['games']}', style: TextStyle(color: isFree ? color : GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 10),
                  Text(s['label'] as String, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: isFree ? GacomColors.textPrimary : GacomColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(s['desc'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isFree ? GacomColors.textMuted : GacomColors.textMuted.withOpacity(0.5), fontSize: 10, height: 1.3)),
                ])),
              // Lock overlay for non-free subjects
              if (!isFree)
                Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: GacomColors.obsidian.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.lock_rounded, color: GacomColors.textMuted, size: 14))),
              if (isFree)
                Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('FREE', style: TextStyle(color: GacomColors.success, fontSize: 8, fontWeight: FontWeight.w800)))),
            ]),
          );
        })),
    ]),
  );
}
