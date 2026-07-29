import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/edu_prefs.dart' as edu_prefs;

class EduHomeScreen extends StatefulWidget {
  const EduHomeScreen({super.key});
  @override State<EduHomeScreen> createState() => _EduHomeState();
}

class _EduHomeState extends State<EduHomeScreen> {
  String _name = 'Student';

  @override void initState() { super.initState(); _loadName(); }

  Future<void> _loadName() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final p = await SupabaseService.client.from('profiles').select('display_name').eq('id', uid).single();
      if (mounted) setState(() => _name = p['display_name'] ?? 'Student');
    } catch (_) {}
  }

  // Non-const because IconData can't be stored in const maps
  final _subjects = [
    {'icon': Icons.calculate_outlined,         'label': 'Mathematics',  'id': 'math',        'color': 0xFFFF6A00},
    {'icon': Icons.science_outlined,           'label': 'Physics',      'id': 'physics',     'color': 0xFF00C2A8},
    {'icon': Icons.biotech_outlined,           'label': 'Chemistry',    'id': 'chemistry',   'color': 0xFF8B5CF6},
    {'icon': Icons.eco_outlined,               'label': 'Biology',      'id': 'biology',     'color': 0xFF34D399},
    {'icon': Icons.translate_outlined,         'label': 'English',      'id': 'english',     'color': 0xFF3D8BFF},
    {'icon': Icons.public_outlined,            'label': 'Geography',    'id': 'geography',   'color': 0xFF00C2A8},
    {'icon': Icons.history_edu_outlined,       'label': 'History',      'id': 'history',     'color': 0xFFFF8A33},
    {'icon': Icons.code_outlined,              'label': 'Coding',       'id': 'coding',      'color': 0xFF8B5CF6},
    {'icon': Icons.psychology_outlined,        'label': 'Logic',        'id': 'logic',       'color': 0xFFE85B8A},
    {'icon': Icons.account_balance_outlined,   'label': 'Economics',    'id': 'economics',   'color': 0xFF34D399},
    {'icon': Icons.construction_outlined,      'label': 'Engineering',  'id': 'engineering', 'color': 0xFF3D8BFF},
    {'icon': Icons.more_horiz_rounded,         'label': 'More',         'id': 'math',        'color': 0xFF6B6B80},
  ];

  final _quickGames = [
    {'name': 'Speed Math',    'icon': Icons.bolt_rounded,          'route': '/arena/practice/speedmath'},
    {'name': 'Word Scramble', 'icon': Icons.spellcheck_rounded,    'route': '/arena/practice/wordscramble'},
    {'name': 'Chess',         'icon': Icons.extension_rounded,     'route': '/arena/practice/chess'},
    {'name': 'Trivia',        'icon': Icons.quiz_outlined,         'route': '/arena/practice/trivia'},
    {'name': 'Number Duel',   'icon': Icons.timer_rounded,         'route': '/arena/practice/numberduel'},
    {'name': 'Hangman',       'icon': Icons.abc_rounded,           'route': '/arena/practice/hangman'},
  ];

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        backgroundColor: GacomColors.obsidian,
        elevation: 0,
        title: Row(children: [
          const Text('GACOM', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Text('EDU', style: TextStyle(color: GacomColors.accentCyan, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1))),
        ]),
        actions: [
          // Return to portal — only for institution users
          Builder(builder: (ctx) {
            final email = SupabaseService.client.auth.currentUser?.email ?? '';
            if (email.contains('@gacom.edu.ng')) {
              return GestureDetector(
                onTap: () => context.go('/edu/portal'),
                child: Container(margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.4))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_balance_outlined, size: 13, color: GacomColors.accentCyan),
                    SizedBox(width: 4),
                    Text('Portal', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.accentCyan)),
                  ])));
            }
            return const SizedBox.shrink();
          }),
          GestureDetector(
            onTap: () { edu_prefs.setEduMode(false); context.go(AppConstants.homeRoute); },
            child: Container(margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sports_esports_rounded, size: 14, color: GacomColors.textMuted),
                SizedBox(width: 5),
                Text('Exit Edu', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted)),
              ])),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Greeting
        Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 2), color: GacomColors.elevatedCard),
            child: Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S',
              style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$greeting', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani')),
            Text(_name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
          ]),
          const Spacer(),
          GestureDetector(onTap: () => context.push('/edu/profile'),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.border)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart_rounded, size: 14, color: GacomColors.deepOrange),
                SizedBox(width: 4),
                Text('Progress', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.deepOrange)),
              ]))),
        ]),
        const SizedBox(height: 20),

        // Hero card
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.school_rounded, color: GacomColors.deepOrange, size: 26)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edu Gaming', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)),
                Text('Learn. Compete. Grow.', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 12),
            const Text('Play educational games across 12 subjects. Build real academic skills while competing on leaderboards with students worldwide.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            GestureDetector(onTap: () => context.push('/edu/subjects'),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Explore All Subjects', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ]))),
          ])),
        const SizedBox(height: 20),

        // Quick play
        Row(children: [
          const Text('PLAY NOW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
          const Spacer(),
          GestureDetector(onTap: () => context.push('/edu/subjects'),
            child: const Text('All games', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 88, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _quickGames.length,
          itemBuilder: (_, i) {
            final g = _quickGames[i];
            return GestureDetector(
              onTap: () => context.push(g['route'] as String),
              child: Container(width: 76, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(g['icon'] as IconData, color: GacomColors.deepOrange, size: 26),
                  const SizedBox(height: 6),
                  Text(g['name'] as String, textAlign: TextAlign.center, maxLines: 2,
                    style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 10, color: GacomColors.textPrimary, height: 1.2)),
                ])),
            );
          },
        )),
        const SizedBox(height: 20),

        // Upgrade banner — visible to all non-institution users
        Builder(builder: (ctx) {
          final email = SupabaseService.client.auth.currentUser?.email ?? '';
          if (email.contains('@gacom.edu.ng')) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => context.push('/edu/paywall'),
            child: Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [GacomColors.deepOrange.withOpacity(0.15), GacomColors.cardDark]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.workspace_premium_rounded, color: GacomColors.deepOrange, size: 20)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Free Plan — Math only', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textPrimary)),
                  Text('Upgrade to ₦3,500/month → unlock all 24 subjects', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                  child: const Text('UPGRADE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11))),
              ])),
          );
        }),

        // Subjects
        Row(children: [
          const Text('SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
          const Spacer(),
          GestureDetector(onTap: () => context.push('/edu/subjects'),
            child: const Text('See all', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.2),
          itemCount: _subjects.length,
          itemBuilder: (_, i) {
            final s = _subjects[i];
            final color = Color(s['color'] as int);
            return GestureDetector(
              onTap: () => context.push('/edu/subject/${s['id']}'),
              child: Container(
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(s['icon'] as IconData, color: color, size: 26),
                  const SizedBox(height: 8),
                  Text(s['label'] as String, textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textPrimary)),
                ]),
              ),
            );
          }),
        const SizedBox(height: 20),

        // Bottom action row
        Row(children: [
          _ActionCard(icon: Icons.emoji_events_outlined, label: 'Compete', color: GacomColors.deepOrange, onTap: () => context.push('/edu/compete')),
          const SizedBox(width: 10),
          _ActionCard(icon: Icons.chat_outlined, label: 'Study Chat', color: GacomColors.accentCyan, onTap: () => context.push('/edu/chat')),
          const SizedBox(width: 10),
          _ActionCard(icon: Icons.family_restroom_rounded, label: 'Parents', color: GacomColors.textSecondary, onTap: () => context.push('/edu/parent')),
        ]),
        const SizedBox(height: 100),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext ctx) => Expanded(child: GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
      child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textPrimary))]))));
}