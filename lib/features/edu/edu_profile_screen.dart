import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class EduProfileScreen extends StatelessWidget {
  const EduProfileScreen({super.key});

  static const _skills = [
    {'label': 'Mathematics', 'pct': 0.85, 'icon': '🧮', 'color': 0xFFFF6A00},
    {'label': 'Science',     'pct': 0.72, 'icon': '🔬', 'color': 0xFF00C2A8},
    {'label': 'English',     'pct': 0.68, 'icon': '📖', 'color': 0xFF3D8BFF},
    {'label': 'Logic',       'pct': 0.95, 'icon': '🧠', 'color': 0xFFE85B8A},
    {'label': 'Geography',   'pct': 0.70, 'icon': '🌍', 'color': 0xFF34D399},
    {'label': 'History',     'pct': 0.66, 'icon': '📜', 'color': 0xFFFF8A33},
    {'label': 'Coding',      'pct': 0.62, 'icon': '💻', 'color': 0xFF8B5CF6},
    {'label': 'Languages',   'pct': 0.58, 'icon': '🌐', 'color': 0xFF00E5FF},
  ];

  static const _badges = [
    {'icon': '🏆', 'name': 'Math Master',       'earned': true},
    {'icon': '🔥', 'name': '100 Day Streak',    'earned': true},
    {'icon': '⚡', 'name': 'Fast Thinker',      'earned': true},
    {'icon': '🔬', 'name': 'Science Expert',    'earned': false},
    {'icon': '♟',  'name': 'Puzzle King',       'earned': true},
    {'icon': '🧠', 'name': 'Memory Champion',   'earned': false},
    {'icon': '🌍', 'name': 'Globe Trotter',     'earned': false},
    {'icon': '💻', 'name': 'Code Wizard',       'earned': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('ACADEMIC PROFILE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined, color: GacomColors.textMuted), onPressed: () {}),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Rank card ─────────────────────────────────────────────────────
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
          child: Column(children: [
            Row(children: [
              Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 3), color: GacomColors.elevatedCard),
                child: const Center(child: Text('#', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.deepOrange)))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('142', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 40, color: GacomColors.textPrimary)),
                const Text('Young Brain Explorer', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange)),
                const Text('Top 0.8% globally', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 16),
            Row(children: const [
              Expanded(child: Text('3,400 / 4,000 XP', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12))),
              Text('85% to next rank', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: const LinearProgressIndicator(value: 0.85, backgroundColor: Color(0xFF1A1A22), valueColor: AlwaysStoppedAnimation(GacomColors.deepOrange), minHeight: 8)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {},
              style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.deepOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('View Leaderboard →', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)))),
          ])),
        const SizedBox(height: 16),

        // ── Skill analysis ────────────────────────────────────────────────
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('YOUR ACADEMIC SKILLS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
            const SizedBox(height: 16),
            ..._skills.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
              Text(s['icon'] as String, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s['label'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                  const Spacer(),
                  Text('${((s['pct'] as double) * 100).round()}%', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: Color(s['color'] as int))),
                ]),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: s['pct'] as double, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(Color(s['color'] as int)), minHeight: 6)),
              ])),
            ]))),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AI INSIGHT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Row(children: [
                  Text('🏅 Strongest: ', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                  Text('Logic', style: TextStyle(color: GacomColors.success, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
                const Row(children: [
                  Text('⚠️ Needs work: ', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                  Text('Languages', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
                const SizedBox(height: 6),
                const Text('Recommended:', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                const Text('Vocabulary Quest, Word Scramble', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
              ])),
          ])),
        const SizedBox(height: 16),

        // ── Achievements ──────────────────────────────────────────────────
        const Text('ACHIEVEMENTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 12),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10,
          children: _badges.map((b) {
            final earned = b['earned'] as bool;
            return Column(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: earned ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.elevatedCard, border: Border.all(color: earned ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border)),
                child: Center(child: Text(b['icon'] as String, style: TextStyle(fontSize: 24, color: earned ? null : Colors.black)))),
              const SizedBox(height: 4),
              Text(b['name'] as String, textAlign: TextAlign.center, maxLines: 2,
                style: TextStyle(fontSize: 9, color: earned ? GacomColors.textSecondary : GacomColors.textMuted, height: 1.2)),
            ]);
          }).toList()),
        const SizedBox(height: 16),

        // ── Holiday event ─────────────────────────────────────────────────
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [GacomColors.deepOrange.withOpacity(0.2), GacomColors.cardDark]), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
          child: Row(children: [
            const Text('🏖', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Holiday Brain Challenge', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
              const Text('Complete daily games. Earn exclusive badges + coins.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              GestureDetector(onTap: () {},
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Join Event', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)))),
            ])),
          ])),
        const SizedBox(height: 100),
      ]),
    );
  }
}
