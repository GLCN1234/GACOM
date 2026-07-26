import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/edu_mode_provider.dart';
import '../../core/services/supabase_service.dart';

// ── Edu Home — matches the reference image exactly ───────────────────────────
class EduHomeScreen extends ConsumerStatefulWidget {
  const EduHomeScreen({super.key});
  @override ConsumerState<EduHomeScreen> createState() => _EduHomeState();
}

class _EduHomeState extends ConsumerState<EduHomeScreen> {
  Map<String,dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final p = await SupabaseService.client.from('profiles').select('display_name,avatar_url,wallet_balance').eq('id', uid).single();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  static const _skills = [
    {'label': 'Math',      'pct': 0.85, 'color': 0xFFFF6A00},
    {'label': 'Science',   'pct': 0.72, 'color': 0xFF00C2A8},
    {'label': 'English',   'pct': 0.68, 'color': 0xFF3D8BFF},
    {'label': 'Logic',     'pct': 0.63, 'color': 0xFF8B5CF6},
    {'label': 'Geography', 'pct': 0.70, 'color': 0xFFE85B8A},
  ];

  static const _subjects = [
    {'icon': '🧮', 'label': 'Mathematics', 'route': '/edu/subject/math'},
    {'icon': '🔬', 'label': 'Science',     'route': '/edu/subject/science'},
    {'icon': '📖', 'label': 'English',     'route': '/edu/subject/english'},
    {'icon': '🌍', 'label': 'Geography',   'route': '/edu/subject/geography'},
    {'icon': '📜', 'label': 'History',     'route': '/edu/subject/history'},
    {'icon': '💻', 'label': 'Coding',      'route': '/edu/subject/coding'},
    {'icon': '🧠', 'label': 'Logic',       'route': '/edu/subject/logic'},
    {'icon': '🌐', 'label': 'Languages',   'route': '/edu/subject/languages'},
    {'icon': '💰', 'label': 'Finance',     'route': '/edu/subject/finance'},
    {'icon': '⚙',  'label': 'Engineering', 'route': '/edu/subject/engineering'},
    {'icon': '🎨', 'label': 'Creativity',  'route': '/edu/subject/creativity'},
    {'icon': '•••', 'label': 'More',       'route': '/edu/subjects'},
  ];

  @override
  Widget build(BuildContext context) {
    final name = _profile?['display_name'] ?? 'Student';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: CustomScrollView(slivers: [
        // ── App bar ──────────────────────────────────────────────────────────
        SliverAppBar(
          pinned: true, floating: false,
          backgroundColor: GacomColors.obsidian,
          elevation: 0,
          title: const Text('GACOM', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.5)),
          actions: [
            Container(margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_balance_wallet_rounded, color: GacomColors.deepOrange, size: 14),
                const SizedBox(width: 4),
                Text('₦${((_profile?['wallet_balance'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
              ])),
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications_outlined, color: GacomColors.textSecondary), onPressed: () {}),
              Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: GacomColors.deepOrange, shape: BoxShape.circle))),
            ]),
          ],
        ),

        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── User row ──────────────────────────────────────────────────────
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 2), color: GacomColors.elevatedCard),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting 👋', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani')),
              Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
              Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('Brain Level 12', style: TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            ])),
            GestureDetector(onTap: () {},
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.border)),
                child: const Icon(Icons.edit_square, color: GacomColors.textSecondary, size: 16))),
          ]),
          const SizedBox(height: 20),

          // ── Hero card — "EDU GAMING" ───────────────────────────────────────
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GacomColors.border),
              gradient: LinearGradient(colors: [GacomColors.deepOrange.withOpacity(0.08), GacomColors.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Stack(children: [
              // floating math symbols (decorative)
              Positioned(right: 0, top: 0, child: Text('∑ π ÷', style: TextStyle(fontSize: 18, color: GacomColors.deepOrange.withOpacity(0.15), fontWeight: FontWeight.w900))),
              Positioned(right: 20, bottom: 20, child: Text('∫ √ ×', style: TextStyle(fontSize: 14, color: GacomColors.accentCyan.withOpacity(0.12), fontWeight: FontWeight.w900))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('EDU GAMING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary, letterSpacing: 0.5)),
                    const Text('Learn. Compete. Grow.', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),
                    const Text('Play educational games across 12 subjects.\nBuild real academic skills while competing\non leaderboards.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.5)),
                  ])),
                  const SizedBox(width: 12),
                  const Text('🎓', style: TextStyle(fontSize: 48)),
                ]),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.push('/edu/subjects'),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Explore Games', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ])),
                ),
              ]),
            ])),
          const SizedBox(height: 20),

          // ── Stats row (Edu Points, Badges, Win Streak, Day Streak) ────────
          Row(children: [
            _StatChip(icon: '⭐', value: '3,450', label: 'Edu Points', color: const Color(0xFFFF6A00)),
            _StatChip(icon: '🏆', value: '142',   label: 'Badges',     color: const Color(0xFFFFD700)),
            _StatChip(icon: '🔥', value: '78',    label: 'Win Streak', color: const Color(0xFFFF4D4D)),
            _StatChip(icon: '📅', value: '7',     label: 'Day Streak', color: const Color(0xFF00C2A8)),
          ].map((w) => Expanded(child: w)).toList()),
          const SizedBox(height: 20),

          // ── Skill overview ────────────────────────────────────────────────
          Row(children: [
            const Text('SKILL OVERVIEW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
            const Spacer(),
            GestureDetector(onTap: () => context.push('/edu/profile'),
              child: const Text('View all', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _skills.map((s) => _SkillRing(label: s['label'] as String, pct: s['pct'] as double, color: Color(s['color'] as int))).toList()),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Keep it up! Your Math skill is your strongest.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
              const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted, size: 20),
            ])),
          const SizedBox(height: 20),

          // ── Recommended for you ───────────────────────────────────────────
          Row(children: [
            const Text('RECOMMENDED FOR YOU', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
            const Spacer(),
            GestureDetector(onTap: () {},
              child: const Text('See all', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('🎮', style: TextStyle(fontSize: 36)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Math Quest', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
                const Text('Mathematics', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                const Text('Sharpen your math skills\nwith fun quests!', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4)),
                const SizedBox(height: 10),
                GestureDetector(onTap: () => context.push('/arena/practice/speedmath'),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Play Now', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)))),
              ])),
            ])),
          const SizedBox(height: 20),

          // ── This week activity ────────────────────────────────────────────
          const Text('THIS WEEK ACTIVITY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [
              _ActivityStat(icon: '🎮', value: '18',      label: 'Games\nPlayed'),
              _ActivityStat(icon: '❓', value: '245',     label: 'Questions\nAnswered'),
              _ActivityStat(icon: '🎯', value: '82%',    label: 'Accuracy'),
              _ActivityStat(icon: '⏱', value: '5h 40m', label: 'Time\nSpent'),
            ])),
          const SizedBox(height: 20),

          // ── Popular subjects ──────────────────────────────────────────────
          Row(children: [
            const Text('POPULAR SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
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
              final isActive = i == 0;
              return GestureDetector(
                onTap: () => context.push(s['route'] as String),
                child: Container(
                  decoration: BoxDecoration(
                    color: isActive ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isActive ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(s['icon'] as String, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(s['label'] as String, textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: isActive ? GacomColors.deepOrange : GacomColors.textPrimary)),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 100), // nav clearance
        ]))),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon, value, label; final Color color;
  const _StatChip({required this.icon, required this.value, required this.label, required this.color});
  @override Widget build(BuildContext ctx) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: color)),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, height: 1.2)),
  ]);
}

class _ActivityStat extends StatelessWidget {
  final String icon, value, label;
  const _ActivityStat({required this.icon, required this.value, required this.label});
  @override Widget build(BuildContext ctx) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, height: 1.2)),
  ]);
}

class _SkillRing extends StatelessWidget {
  final String label; final double pct; final Color color;
  const _SkillRing({required this.label, required this.pct, required this.color});
  @override Widget build(BuildContext ctx) => Column(children: [
    SizedBox(width: 56, height: 56, child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: pct, strokeWidth: 5, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color))),
      Text('${(pct * 100).round()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textPrimary)),
    ])),
    const SizedBox(height: 6),
    Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontFamily: 'Rajdhani')),
  ]);
}
