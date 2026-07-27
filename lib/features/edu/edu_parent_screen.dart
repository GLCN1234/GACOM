import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

// ── Parent / Teacher Dashboard ─────────────────────────────────────────────
// Students can be assigned to parents by admin or by institution.
// This shows reports, subject progress, streaks, and session time.
class EduParentScreen extends StatefulWidget {
  const EduParentScreen({super.key});
  @override State<EduParentScreen> createState() => _EduParentState();
}

class _EduParentState extends State<EduParentScreen> {
  List<Map<String,dynamic>> _students = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) { setState(() => _loading = false); return; }
      // student_parent_links: parent_id | student_id | institution_id | approved
      final links = await SupabaseService.client
          .from('student_parent_links')
          .select('student_id, profiles!student_id(display_name, avatar_url)')
          .eq('parent_id', uid)
          .eq('approved', true);
      if (mounted) setState(() {
        _students = List<Map<String,dynamic>>.from(links);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  static const _mockStudents = [
    {'name': 'Chidinma Obi',    'level': 12, 'streak': 7,  'accuracy': 82, 'xp': 3450, 'today': '1h 20m'},
    {'name': 'Emeka Nwosu',     'level': 8,  'streak': 3,  'accuracy': 74, 'xp': 2100, 'today': '45m'},
    {'name': 'Fatimah Bello',   'level': 10, 'streak': 14, 'accuracy': 90, 'xp': 2900, 'today': '2h 10m'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('PARENT DASHBOARD', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.person_add_outlined, color: GacomColors.deepOrange), onPressed: () {})],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.2))),
                child: const Row(children: [
                  const Icon(Icons.family_restroom_rounded, size: 24, color: GacomColors.deepOrange),
                  SizedBox(width: 12),
                  Expanded(child: Text('Students assigned to you by their schools or directly. You can view their daily progress and subject reports here.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4))),
                ])),
              const SizedBox(height: 20),
              const Text('YOUR STUDENTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
              const SizedBox(height: 12),
              ..._mockStudents.map((s) => _StudentCard(s)),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('WEEKLY CERTIFICATE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Chidinma completed 7-day streak and earned the "Consistent Learner" badge this week!', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.deepOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Download Certificate', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))),
                ])),
            ]),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String,dynamic> s;
  const _StudentCard(this.s);
  @override Widget build(BuildContext ctx) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.elevatedCard, border: Border.all(color: GacomColors.deepOrange, width: 2)),
          child: Center(child: Text((s['name'] as String)[0], style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
          Text('Brain Level ${s['level']} · ${s['today']} today', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, color: GacomColors.success, size: 12),
            const SizedBox(width: 3),
            Text('${s['streak']} day streak', style: const TextStyle(color: GacomColors.success, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
          ])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _StatBadge(Icons.gps_fixed_rounded, '${s['accuracy']}%', 'Accuracy'),
        const SizedBox(width: 8),
        _StatBadge('⭐', '${s['xp']}', 'Edu XP'),
        const SizedBox(width: 8),
        _StatBadge('⏱', s['today'] as String, 'Today'),
      ]),
    ]));
}

class _StatBadge extends StatelessWidget {
  final dynamic icon; final String value, label;
  const _StatBadge(this.icon, this.value, this.label);
  @override Widget build(BuildContext ctx) => Expanded(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      icon is IconData ? Icon(icon as IconData, size: 18, color: GacomColors.deepOrange) : Text(icon.toString(), style: const TextStyle(fontSize: 14)),
      Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 9)),
    ])));
}
