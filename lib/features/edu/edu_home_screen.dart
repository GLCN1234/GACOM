import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/edu_mode_provider.dart';
import '../../core/services/supabase_service.dart';

class EduHomeScreen extends ConsumerStatefulWidget {
  const EduHomeScreen({super.key});
  @override ConsumerState<EduHomeScreen> createState() => _EduHomeState();
}

class _EduHomeState extends ConsumerState<EduHomeScreen> {
  Map<String,dynamic>? _profile;
  Map<String,dynamic>? _eduStats; // edu_progress aggregate
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) { setState(() => _loading = false); return; }
      final p = await SupabaseService.client.from('profiles')
          .select('display_name,avatar_url,wallet_balance').eq('id', uid).single();
      // Try to load edu progress — if table doesn't exist yet, handle gracefully
      Map<String,dynamic>? stats;
      try {
        final rows = await SupabaseService.client.from('edu_progress')
            .select('subject,xp,level,accuracy,streak').eq('user_id', uid);
        if ((rows as List).isNotEmpty) {
          int totalXp = 0, totalAcc = 0, maxStreak = 0;
          for (final r in rows) {
            totalXp += (r['xp'] as int? ?? 0);
            totalAcc += (r['accuracy'] as int? ?? 0);
            if ((r['streak'] as int? ?? 0) > maxStreak) maxStreak = r['streak'] as int? ?? 0;
          }
          stats = {'xp': totalXp, 'accuracy': rows.isEmpty ? 0 : totalAcc ~/ rows.length, 'streak': maxStreak, 'subjects': rows};
        }
      } catch (_) {} // table may not exist yet — that's fine
      if (mounted) setState(() { _profile = p; _eduStats = stats; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  static const _subjects = [
    {'icon': '🧮', 'label': 'Mathematics',  'id': 'math'},
    {'icon': '🔬', 'label': 'Science',      'id': 'science'},
    {'icon': '📖', 'label': 'English',      'id': 'english'},
    {'icon': '🌍', 'label': 'Geography',    'id': 'geography'},
    {'icon': '📜', 'label': 'History',      'id': 'history'},
    {'icon': '💻', 'label': 'Coding',       'id': 'coding'},
    {'icon': '🧠', 'label': 'Logic',        'id': 'logic'},
    {'icon': '🌐', 'label': 'Languages',    'id': 'languages'},
    {'icon': '💰', 'label': 'Finance',      'id': 'finance'},
    {'icon': '⚙',  'label': 'Engineering', 'id': 'engineering'},
    {'icon': '🎨', 'label': 'Creativity',   'id': 'creativity'},
    {'icon': '•••','label': 'More',         'id': 'math'},
  ];

  static const _quickGames = [
    {'name': 'Speed Math',    'icon': '🧮', 'subject': 'Mathematics', 'route': '/arena/practice/speedmath'},
    {'name': 'Word Scramble', 'icon': '📖', 'subject': 'English',     'route': '/arena/practice/wordscramble'},
    {'name': 'Chess',         'icon': '♟',  'subject': 'Logic',       'route': '/arena/practice/chess'},
    {'name': 'Trivia',        'icon': '❓',  'subject': 'General',     'route': '/arena/practice/trivia'},
    {'name': 'Number Duel',   'icon': '🔢',  'subject': 'Maths',      'route': '/arena/practice/numberduel'},
    {'name': 'Hangman',       'icon': '📝',  'subject': 'English',     'route': '/arena/practice/hangman'},
  ];

  @override
  Widget build(BuildContext context) {
    final name = _profile?['display_name'] ?? 'Student';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final xp    = _eduStats?['xp'] as int? ?? 0;
    final acc   = _eduStats?['accuracy'] as int? ?? 0;
    final streak= _eduStats?['streak'] as int? ?? 0;
    final hasData = _eduStats != null;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
        : CustomScrollView(slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true, floating: false,
            backgroundColor: GacomColors.obsidian, elevation: 0,
            title: Row(children: [
              const Text('GACOM', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.5)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('EDU', style: TextStyle(color: GacomColors.accentCyan, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1))),
            ]),
            actions: [
              // Switch back to normal mode
              Consumer(builder: (ctx, ref, _) => GestureDetector(
                onTap: () => ref.read(eduModeProvider.notifier).state = false,
                child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sports_esports_rounded, size: 13, color: GacomColors.textMuted),
                    SizedBox(width: 5),
                    Text('Gaming', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted)),
                  ])),
              )),
              Stack(children: [
                IconButton(icon: const Icon(Icons.notifications_outlined, color: GacomColors.textSecondary), onPressed: () {}),
                Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: GacomColors.deepOrange, shape: BoxShape.circle))),
              ]),
            ],
          ),

          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── User greeting row ─────────────────────────────────────────
            Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 2), color: GacomColors.elevatedCard),
                child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$greeting 👋', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani')),
                Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
                Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(hasData ? 'Edu Level ${_eduStats?['level'] ?? 1}' : 'New Learner 🎓',
                    style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
              ])),
              GestureDetector(onTap: () => context.push('/edu/profile'),
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.border)),
                  child: const Icon(Icons.person_outline_rounded, color: GacomColors.textSecondary, size: 18))),
            ]),
            const SizedBox(height: 20),

            // ── Hero card ─────────────────────────────────────────────────
            Container(width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border),
                gradient: LinearGradient(colors: [GacomColors.deepOrange.withOpacity(0.08), GacomColors.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Stack(children: [
                Positioned(right: 0, top: 0, child: Text('∑ π ÷', style: TextStyle(fontSize: 16, color: GacomColors.deepOrange.withOpacity(0.12), fontWeight: FontWeight.w900))),
                Positioned(right: 16, bottom: 16, child: Text('∫ √ ×', style: TextStyle(fontSize: 13, color: GacomColors.accentCyan.withOpacity(0.10), fontWeight: FontWeight.w900))),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('EDU GAMING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: GacomColors.textPrimary)),
                      const Text('Learn. Compete. Grow.', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      const Text('Play educational games across 12 subjects.\nBuild real academic skills while competing on leaderboards.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.5)),
                    ])),
                    const SizedBox(width: 12),
                    const Text('🎓', style: TextStyle(fontSize: 44)),
                  ]),
                  const SizedBox(height: 16),
                  GestureDetector(onTap: () => context.push('/edu/subjects'),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(12)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Explore Games', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ]))),
                ]),
              ])),
            const SizedBox(height: 20),

            // ── Stats row — real data when available, zeros when not ──────
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
              child: Row(children: [
                _StatChip(icon: '⭐', value: hasData ? '$xp' : '0', label: 'Edu Points', color: GacomColors.deepOrange),
                _Divider(),
                _StatChip(icon: '🎯', value: hasData ? '$acc%' : '—', label: 'Accuracy', color: GacomColors.accentCyan),
                _Divider(),
                _StatChip(icon: '🔥', value: hasData ? '$streak' : '0', label: 'Day Streak', color: const Color(0xFFFF4D4D)),
                _Divider(),
                GestureDetector(onTap: () => context.push('/edu/profile'),
                  child: _StatChip(icon: '🏆', value: hasData ? 'View' : 'View', label: 'My Rank', color: const Color(0xFFFFD700))),
              ])),
            const SizedBox(height: 20),

            // ── Quick play games ──────────────────────────────────────────
            Row(children: [
              const Text('PLAY NOW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(onTap: () => context.push('/edu/subjects'),
                child: const Text('See all', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            SizedBox(height: 100, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickGames.length,
              itemBuilder: (_, i) {
                final g = _quickGames[i];
                return GestureDetector(
                  onTap: () => context.push(g['route'] as String),
                  child: Container(width: 88, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(g['icon'] as String, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(g['name'] as String, textAlign: TextAlign.center, maxLines: 2,
                        style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textPrimary, height: 1.2)),
                    ])),
                );
              },
            )),
            const SizedBox(height: 20),

            // ── Getting started (if no data) or subject skill overview ────
            if (!hasData) ...[
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🚀 GET STARTED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Play your first game to start tracking progress, earning XP, and climbing the leaderboards!', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 12),
                  GestureDetector(onTap: () => context.push('/arena/practice/speedmath'),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Start First Game →', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)))),
                ])),
            ] else ...[
              Row(children: [
                const Text('SKILL OVERVIEW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
                const Spacer(),
                GestureDetector(onTap: () => context.push('/edu/profile'),
                  child: const Text('View all', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              SizedBox(height: 90, child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (_eduStats!['subjects'] as List).length,
                itemBuilder: (_, i) {
                  final s = (_eduStats!['subjects'] as List)[i] as Map<String,dynamic>;
                  final pct = (s['accuracy'] as int? ?? 0) / 100.0;
                  return Container(width: 72, margin: const EdgeInsets.only(right: 10), child: Column(children: [
                    SizedBox(width: 56, height: 56, child: Stack(alignment: Alignment.center, children: [
                      SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: pct, strokeWidth: 5, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange))),
                      Text('${(pct * 100).round()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textPrimary)),
                    ])),
                    const SizedBox(height: 6),
                    Text(s['subject'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
                  ]));
                })),
            ],
            const SizedBox(height: 20),

            // ── Subjects grid ─────────────────────────────────────────────
            Row(children: [
              const Text('SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(onTap: () => context.push('/edu/subjects'),
                child: const Text('See all', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.15),
              itemCount: _subjects.length,
              itemBuilder: (_, i) {
                final s = _subjects[i];
                return GestureDetector(
                  onTap: () => context.push('/edu/subject/${s['id']}'),
                  child: Container(
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s['icon'] as String, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 6),
                      Text(s['label'] as String, textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textPrimary)),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 20),

            // ── Parent/Teacher access ─────────────────────────────────────
            GestureDetector(onTap: () => context.push('/edu/parent'),
              child: Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 20)))),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Parent / Teacher Dashboard', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                    Text('View student progress reports', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted, size: 20),
                ]))),
            const SizedBox(height: 100),
          ]))),
        ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon, value, label; final Color color;
  const _StatChip({required this.icon, required this.value, required this.label, required this.color});
  @override Widget build(BuildContext ctx) => Expanded(child: Column(children: [
    Text(icon, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: color)),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 9, height: 1.2)),
  ]));
}

class _Divider extends StatelessWidget {
  @override Widget build(BuildContext ctx) => Container(width: 1, height: 36, color: GacomColors.border, margin: const EdgeInsets.symmetric(horizontal: 4));
}
