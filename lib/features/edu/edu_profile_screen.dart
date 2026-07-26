import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

class EduProfileScreen extends StatefulWidget {
  const EduProfileScreen({super.key});
  @override State<EduProfileScreen> createState() => _EduProfileState();
}
class _EduProfileState extends State<EduProfileScreen> {
  Map<String,dynamic>? _profile;
  List<Map<String,dynamic>> _progress = [];
  bool _loading = true;

  static const _subjectMeta = {
    'math':        {'icon': '🧮', 'label': 'Mathematics',       'color': 0xFFFF6A00},
    'science':     {'icon': '🔬', 'label': 'Science',            'color': 0xFF00C2A8},
    'english':     {'icon': '📖', 'label': 'English',            'color': 0xFF3D8BFF},
    'logic':       {'icon': '🧠', 'label': 'Logic & IQ',         'color': 0xFFE85B8A},
    'geography':   {'icon': '🌍', 'label': 'Geography',          'color': 0xFF34D399},
    'history':     {'icon': '📜', 'label': 'History',            'color': 0xFFFF8A33},
    'coding':      {'icon': '💻', 'label': 'Coding',             'color': 0xFF8B5CF6},
    'languages':   {'icon': '🌐', 'label': 'Languages',          'color': 0xFF00E5FF},
    'finance':     {'icon': '💰', 'label': 'Finance',            'color': 0xFF34D399},
    'engineering': {'icon': '⚙',  'label': 'Engineering',        'color': 0xFF3D8BFF},
    'creativity':  {'icon': '🎨', 'label': 'Creativity',         'color': 0xFFFF6A00},
  };

  static const _allBadges = [
    {'icon': '🏆', 'name': 'Math Master',    'key': 'math',    'threshold': 80},
    {'icon': '🔥', 'name': '7-Day Streak',   'key': 'streak',  'threshold': 7},
    {'icon': '⚡', 'name': 'Speed Solver',   'key': 'speed',   'threshold': 0},
    {'icon': '🔬', 'name': 'Science Expert', 'key': 'science', 'threshold': 70},
    {'icon': '♟',  'name': 'Puzzle King',    'key': 'logic',   'threshold': 80},
    {'icon': '🧠', 'name': 'Brain Champion', 'key': 'brain',   'threshold': 0},
    {'icon': '🌍', 'name': 'Globe Trotter',  'key': 'geo',     'threshold': 0},
    {'icon': '💻', 'name': 'Code Wizard',    'key': 'coding',  'threshold': 60},
  ];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) { setState(() => _loading = false); return; }
      final p = await SupabaseService.client.from('profiles').select('display_name,avatar_url').eq('id', uid).single();
      List<Map<String,dynamic>> prog = [];
      try {
        final rows = await SupabaseService.client.from('edu_progress').select('*').eq('user_id', uid);
        prog = List<Map<String,dynamic>>.from(rows as List);
      } catch (_) {}
      if (mounted) setState(() { _profile = p; _progress = prog; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  int get _totalXp => _progress.fold(0, (s, r) => s + (r['xp'] as int? ?? 0));
  int get _maxStreak => _progress.fold(0, (m, r) => (r['streak'] as int? ?? 0) > m ? r['streak'] as int : m);
  int get _avgAccuracy => _progress.isEmpty ? 0 : _progress.fold(0, (s, r) => s + (r['accuracy'] as int? ?? 0)) ~/ _progress.length;
  String get _strongest { if (_progress.isEmpty) return '—'; final s = [..._progress]..sort((a,b) => (b['accuracy'] as int? ?? 0).compareTo(a['accuracy'] as int? ?? 0)); return _subjectMeta[s.first['subject']]?['label'] as String? ?? s.first['subject'] as String; }
  String get _weakest { if (_progress.isEmpty) return '—'; final s = [..._progress]..sort((a,b) => (a['accuracy'] as int? ?? 0).compareTo(b['accuracy'] as int? ?? 0)); return _subjectMeta[s.first['subject']]?['label'] as String? ?? s.first['subject'] as String; }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('ACADEMIC PROFILE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
      : ListView(padding: const EdgeInsets.all(16), children: [
          // ── Rank card ─────────────────────────────────────────────────
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: _progress.isEmpty ? GacomColors.border : GacomColors.deepOrange.withOpacity(0.3))),
            child: _progress.isEmpty
              ? const Column(children: [
                  Text('🎓', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('No rank yet', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
                  SizedBox(height: 6),
                  Text('Play educational games to earn XP and start climbing the leaderboard!', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                ])
              : Column(children: [
                  Row(children: [
                    Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 3), color: GacomColors.elevatedCard),
                      child: const Center(child: Text('🏆', style: TextStyle(fontSize: 28)))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$_totalXp XP', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 32, color: GacomColors.textPrimary)),
                      const Text('Your Academic Score', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Top ${_avgAccuracy}% accuracy · $_maxStreak day streak', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_totalXp % 1000) / 1000.0, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange), minHeight: 8)),
                  const SizedBox(height: 4),
                  Text('${1000 - (_totalXp % 1000)} XP to next level', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ])),
          const SizedBox(height: 16),

          // ── Skill analysis ────────────────────────────────────────────
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOUR ACADEMIC SKILLS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
              const SizedBox(height: 16),
              if (_progress.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('No skills tracked yet.\nPlay games to build your profile!', style: TextStyle(color: GacomColors.textMuted, fontSize: 13), textAlign: TextAlign.center)))
              else ...[
                ..._progress.map((s) {
                  final meta = _subjectMeta[s['subject'] as String] ?? {'icon': '📚', 'label': s['subject'], 'color': 0xFFFF6A00};
                  final pct = (s['accuracy'] as int? ?? 0) / 100.0;
                  final color = Color(meta['color'] as int);
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                    Text(meta['icon'] as String, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(meta['label'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                        const Spacer(),
                        Text('${(pct * 100).round()}%', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: color)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color), minHeight: 6)),
                    ])),
                  ]));
                }),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('AI INSIGHT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Row(children: [const Text('🏅 Strongest: ', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)), Text(_strongest, style: const TextStyle(color: GacomColors.success, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))]),
                    Row(children: [const Text('⚠️ Needs work: ', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)), Text(_weakest, style: const TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))]),
                  ])),
              ],
            ])),
          const SizedBox(height: 16),

          // ── Achievements ──────────────────────────────────────────────
          const Text('ACHIEVEMENTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10,
            children: _allBadges.map((b) {
              // Badge is earned if user has progress in that subject above the threshold
              final key = b['key'] as String;
              final threshold = b['threshold'] as int;
              bool earned = false;
              if (key == 'streak') { earned = _maxStreak >= threshold; }
              else if (key == 'speed' || key == 'brain' || key == 'geo') { earned = false; }
              else { earned = _progress.any((p) => p['subject'] == key && (p['accuracy'] as int? ?? 0) >= threshold); }
              return Column(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: earned ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.elevatedCard, border: Border.all(color: earned ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border)),
                  child: Center(child: Text(b['icon'] as String, style: TextStyle(fontSize: 24, color: earned ? null : Colors.black12)))),
                const SizedBox(height: 4),
                Text(b['name'] as String, textAlign: TextAlign.center, maxLines: 2,
                  style: TextStyle(fontSize: 9, color: earned ? GacomColors.textSecondary : GacomColors.textMuted, height: 1.2)),
              ]);
            }).toList()),
          const SizedBox(height: 16),

          // ── Holiday event ─────────────────────────────────────────────
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [GacomColors.deepOrange.withOpacity(0.2), GacomColors.cardDark]), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
            child: Row(children: [
              const Text('🏖', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Holiday Brain Challenge', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
                const Text('Complete daily games. Earn exclusive badges + coins.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 8),
                GestureDetector(onTap: () => context.push('/edu/subjects'),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Join Event', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)))),
              ])),
            ])),
          const SizedBox(height: 100),
        ]),
  );
}
