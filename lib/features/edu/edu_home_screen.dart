import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

// Plain StatefulWidget — zero Riverpod, zero provider watching, cannot loop
class EduHomeScreen extends StatefulWidget {
  const EduHomeScreen({super.key});
  @override State<EduHomeScreen> createState() => _EduHomeState();
}

class _EduHomeState extends State<EduHomeScreen> {
  String _name = 'Student';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final p = await SupabaseService.client
          .from('profiles').select('display_name').eq('id', uid).single();
      if (mounted) setState(() => _name = p['display_name'] ?? 'Student');
    } catch (_) {}
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
    {'name': 'Speed Math',    'icon': '🧮', 'route': '/arena/practice/speedmath'},
    {'name': 'Word Scramble', 'icon': '📖', 'route': '/arena/practice/wordscramble'},
    {'name': 'Chess',         'icon': '♟',  'route': '/arena/practice/chess'},
    {'name': 'Trivia',        'icon': '❓',  'route': '/arena/practice/trivia'},
    {'name': 'Number Duel',   'icon': '🔢', 'route': '/arena/practice/numberduel'},
    {'name': 'Hangman',       'icon': '📝', 'route': '/arena/practice/hangman'},
  ];

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        backgroundColor: GacomColors.obsidian,
        title: Row(children: [
          const Text('GACOM', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Text('EDU', style: TextStyle(color: GacomColors.accentCyan, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1))),
        ]),
        actions: [
          GestureDetector(
            onTap: () => context.go(AppConstants.homeRoute),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sports_esports_rounded, size: 14, color: GacomColors.textMuted),
                SizedBox(width: 5),
                Text('Exit', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted)),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting
          Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 2), color: GacomColors.elevatedCard),
              child: Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S',
                style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting 👋', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              Text(_name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
            ]),
          ]),
          const SizedBox(height: 20),

          // Hero card
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Text('🎓', style: TextStyle(fontSize: 40)),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EDU GAMING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)),
                  Text('Learn. Compete. Grow.', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
                ])),
              ]),
              const SizedBox(height: 12),
              const Text('Play educational games across 12 subjects. Build real academic skills while competing on leaderboards.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.5)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.push('/edu/subjects'),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Explore Subjects →', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white))),
              ),
            ])),
          const SizedBox(height: 20),

          // Quick play
          const Text('PLAY NOW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          SizedBox(height: 90, child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _quickGames.length,
            itemBuilder: (_, i) {
              final g = _quickGames[i];
              return GestureDetector(
                onTap: () => context.push(g['route']!),
                child: Container(width: 80, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(g['icon']!, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text(g['name']!, textAlign: TextAlign.center, maxLines: 2,
                      style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 10, color: GacomColors.textPrimary, height: 1.2)),
                  ])),
              );
            },
          )),
          const SizedBox(height: 20),

          // Subjects grid
          Row(children: [
            const Text('SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
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
                    Text(s['icon']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text(s['label']!, textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textPrimary)),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 20),

          // Bottom links
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => context.push('/edu/compete'),
              child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: const Column(children: [Text('⚡', style: TextStyle(fontSize: 24)), SizedBox(height: 6), Text('Compete', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textPrimary))])),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => context.push('/edu/profile'),
              child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: const Column(children: [Text('📊', style: TextStyle(fontSize: 24)), SizedBox(height: 6), Text('Progress', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textPrimary))])),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => context.push('/edu/parent'),
              child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: const Column(children: [Text('👨‍👩‍👧', style: TextStyle(fontSize: 24)), SizedBox(height: 6), Text('Parents', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textPrimary))])),
            )),
          ]),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
