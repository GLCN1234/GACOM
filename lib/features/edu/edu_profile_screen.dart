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
  int? _institutionRank, _institutionTotal, _globalRank, _globalTotal;

  static const _subjectMeta = {
    'math':        {'icon': Icons.calculate_outlined, 'label': 'Mathematics', 'color': 0xFFFF6A00},
    'algebra':     {'icon': Icons.functions_rounded, 'label': 'Algebra', 'color': 0xFFFF8A33},
    'geometry':    {'icon': Icons.gesture_rounded, 'label': 'Geometry', 'color': 0xFFE85B8A},
    'statistics':  {'icon': Icons.show_chart_rounded, 'label': 'Statistics', 'color': 0xFF3D8BFF},
    'simultaneous':{'icon': Icons.swap_horiz_rounded, 'label': 'Simultaneous Eqns', 'color': 0xFF8B5CF6},
    'physics':     {'icon': Icons.science_outlined, 'label': 'Physics', 'color': 0xFF00C2A8},
    'chemistry':   {'icon': Icons.biotech_outlined, 'label': 'Chemistry', 'color': 0xFF8B5CF6},
    'biology':     {'icon': Icons.eco_outlined, 'label': 'Biology', 'color': 0xFF34D399},
    'bst':         {'icon': Icons.precision_manufacturing_outlined, 'label': 'Basic Science and Technology', 'color': 0xFF00C2A8},
    'english':     {'icon': Icons.translate_outlined, 'label': 'English Language', 'color': 0xFF3D8BFF},
    'literature':  {'icon': Icons.record_voice_over_outlined, 'label': 'Literature', 'color': 0xFFFF8A33},
    'geography':   {'icon': Icons.public_outlined, 'label': 'Geography', 'color': 0xFF34D399},
    'history':     {'icon': Icons.history_edu_outlined, 'label': 'History', 'color': 0xFFFF8A33},
    'economics':   {'icon': Icons.account_balance_outlined, 'label': 'Economics', 'color': 0xFF34D399},
    'civics':      {'icon': Icons.groups_outlined, 'label': 'Civic Education', 'color': 0xFFFF6A00},
    'coding':      {'icon': Icons.code_outlined, 'label': 'Computer Science', 'color': 0xFF8B5CF6},
    'logic':       {'icon': Icons.psychology_outlined, 'label': 'Logic & IQ', 'color': 0xFFE85B8A},
    'finance':     {'icon': Icons.paid_outlined, 'label': 'Financial Literacy', 'color': 0xFF34D399},
    'engineering': {'icon': Icons.engineering_outlined, 'label': 'Engineering', 'color': 0xFF3D8BFF},
  };

  static const _allBadges = [
    {'icon': Icons.emoji_events_rounded, 'name': 'Math Master',    'key': 'math',    'threshold': 80},
    {'icon': Icons.local_fire_department_rounded, 'name': '7-Day Streak',   'key': 'streak',  'threshold': 7},
    {'icon': Icons.bolt_rounded, 'name': 'Speed Solver',   'key': 'speed',   'threshold': 0},
    {'icon': Icons.science_outlined, 'name': 'Science Expert', 'key': 'science', 'threshold': 70},
    {'icon': Icons.extension_rounded, 'name': 'Puzzle King',    'key': 'logic',   'threshold': 80},
    {'icon': Icons.psychology_outlined, 'name': 'Brain Champion', 'key': 'brain',   'threshold': 0},
    {'icon': Icons.public_outlined, 'name': 'Globe Trotter',  'key': 'geo',     'threshold': 0},
    {'icon': Icons.code_outlined, 'name': 'Code Wizard',    'key': 'coding',  'threshold': 60},
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
      int? iRank, iTotal, gRank, gTotal;
      try {
        final rankRows = await SupabaseService.client.rpc('get_student_rankings', params: {'p_user_id': uid});
        final rankRow = (rankRows as List).isNotEmpty ? rankRows.first as Map<String,dynamic> : null;
        iRank = rankRow?['institution_rank'] as int?;
        iTotal = rankRow?['institution_total'] as int?;
        gRank = rankRow?['global_rank'] as int?;
        gTotal = rankRow?['global_total'] as int?;
      } catch (_) {}
      if (mounted) setState(() {
        _profile = p; _progress = prog; _loading = false;
        _institutionRank = iRank; _institutionTotal = iTotal; _globalRank = gRank; _globalTotal = gTotal;
      });
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
                  Icon(Icons.school_rounded, color: GacomColors.deepOrange, size: 40),
                  SizedBox(height: 12),
                  Text('No rank yet', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
                  SizedBox(height: 6),
                  Text('Play educational games to earn XP and start climbing the leaderboard!', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                ])
              : Column(children: [
                  Row(children: [
                    Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 3), color: GacomColors.elevatedCard),
                      child: const Center(child: Icon(Icons.emoji_events_rounded, color: GacomColors.deepOrange, size: 28))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$_totalXp XP', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 32, color: GacomColors.textPrimary)),
                      const Text('Your Academic Score', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Top ${_avgAccuracy}% accuracy · $_maxStreak day streak', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    ])),
                  ]),
                  if (_institutionRank != null || _globalRank != null) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      if (_institutionRank != null)
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            Text('#$_institutionRank', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.deepOrange)),
                            Text('of $_institutionTotal in school', style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
                          ]))),
                      if (_institutionRank != null && _globalRank != null) const SizedBox(width: 10),
                      if (_globalRank != null)
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            Text('#$_globalRank', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.accentCyan)),
                            Text('of $_globalTotal globally', style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
                          ]))),
                    ]),
                  ],
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
                  final meta = _subjectMeta[s['subject'] as String] ?? {'icon': Icons.menu_book_rounded, 'label': s['subject'], 'color': 0xFFFF6A00};
                  final pct = (s['accuracy'] as int? ?? 0) / 100.0;
                  final color = Color(meta['color'] as int);
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                    Icon(meta['icon'] as IconData, size: 18, color: color),
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
                    Row(children: [
                      const Icon(Icons.military_tech_rounded, size: 14, color: GacomColors.success),
                      const SizedBox(width: 4),
                      const Text('Strongest: ', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                      Text(_strongest, style: const TextStyle(color: GacomColors.success, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: GacomColors.error),
                      const SizedBox(width: 4),
                      const Text('Needs work: ', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                      Text(_weakest, style: const TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
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
                  child: Center(child: Icon(b['icon'] as IconData, size: 24, color: earned ? GacomColors.deepOrange : Colors.black12))),
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
              const Icon(Icons.beach_access_rounded, size: 32, color: GacomColors.deepOrange),
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
