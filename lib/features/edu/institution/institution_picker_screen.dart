import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/edu_prefs.dart' as edu_prefs;

/// Shown once when a student enables Edu Gaming mode.
/// They pick their institution from the list (or say they have none).
/// The choice is saved to student_institutions and localStorage.
class InstitutionPickerScreen extends StatefulWidget {
  const InstitutionPickerScreen({super.key});
  @override State<InstitutionPickerScreen> createState() => _InstitutionPickerState();
}

class _InstitutionPickerState extends State<InstitutionPickerScreen> {
  List<Map<String,dynamic>> _institutions = [];
  List<Map<String,dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _selectedId;
  String? _selectedName;
  String? _selectedLevel;
  bool _noInstitution = false;
  bool _saving = false;

  static const _classLevels = [
    'Primary 1','Primary 2','Primary 3','Primary 4','Primary 5','Primary 6',
    'JSS 1','JSS 2','JSS 3',
    'SS 1','SS 2','SS 3',
    'University / Tertiary',
    'Self-study',
  ];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.client.from('institutions').select('id,name,type,state').eq('is_active', true).order('name');
      if (mounted) setState(() { _institutions = List<Map<String,dynamic>>.from(rows as List); _filtered = _institutions; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _filter(String q) {
    setState(() {
      _search = q;
      _filtered = q.isEmpty ? _institutions : _institutions.where((i) => (i['name'] as String).toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Future<void> _save() async {
    if (!_noInstitution && _selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your institution or choose "No institution"')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = SupabaseService.currentUserId!;
      await SupabaseService.client.from('student_institutions').upsert({
        'student_id': uid,
        'institution_id': _noInstitution ? null : _selectedId,
        'class_level': _selectedLevel,
        'no_institution': _noInstitution,
      }, onConflict: 'student_id');
      edu_prefs.setEduMode(true);
      if (mounted) context.go('/edu/home');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('EDU GAMING SETUP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      automaticallyImplyLeading: false,
    ),
    body: Column(children: [
      // Progress indicator
      Container(color: GacomColors.cardDark, padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.school_rounded, color: GacomColors.accentCyan, size: 20),
            SizedBox(width: 10),
            Text('Select Your Institution', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
          ]),
          const SizedBox(height: 4),
          const Text('This helps your school monitor your learning progress and assign curriculum-based games.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
        ])),

      // Class level selector
      Container(color: GacomColors.elevatedCard, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          const Text('Your class:', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(child: DropdownButton<String>(
            value: _selectedLevel,
            hint: const Text('Select class level', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            isExpanded: true, dropdownColor: GacomColors.elevatedCard,
            style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
            underline: Container(height: 1, color: GacomColors.border),
            onChanged: (v) => setState(() => _selectedLevel = v),
            items: _classLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          )),
        ])),

      // Search
      Padding(padding: const EdgeInsets.all(16),
        child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(child: TextField(onChanged: _filter,
              style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(hintText: 'Search for your school...', hintStyle: TextStyle(color: GacomColors.textMuted, fontSize: 13), border: InputBorder.none, isCollapsed: true))),
          ]))),

      // Institution list
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _filtered.length + 1, // +1 for "No institution"
            itemBuilder: (_, i) {
              if (i == _filtered.length) {
                // "No institution" option at bottom
                return GestureDetector(
                  onTap: () => setState(() { _noInstitution = true; _selectedId = null; _selectedName = null; }),
                  child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _noInstitution ? GacomColors.deepOrange.withOpacity(0.08) : GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _noInstitution ? GacomColors.deepOrange : GacomColors.border, width: _noInstitution ? 1.5 : 1)),
                    child: Row(children: [
                      Icon(Icons.person_outline_rounded, color: _noInstitution ? GacomColors.deepOrange : GacomColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('I don\'t belong to an institution', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                        Text('Self-study mode — full access to all games', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                      ])),
                      if (_noInstitution) const Icon(Icons.check_circle_rounded, color: GacomColors.deepOrange, size: 20),
                    ])),
                );
              }
              final inst = _filtered[i];
              final sel = _selectedId == inst['id'];
              return GestureDetector(
                onTap: () => setState(() { _selectedId = inst['id']; _selectedName = inst['name']; _noInstitution = false; }),
                child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: sel ? GacomColors.accentCyan.withOpacity(0.06) : GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? GacomColors.accentCyan : GacomColors.border, width: sel ? 1.5 : 1)),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.account_balance_outlined, color: GacomColors.accentCyan, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(inst['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                      Text('${inst['type'] ?? ''} · ${inst['state'] ?? 'Nigeria'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    ])),
                    if (sel) const Icon(Icons.check_circle_rounded, color: GacomColors.accentCyan, size: 20),
                  ])),
              );
            })),

      // Save button
      Padding(padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: (_saving || (_selectedId == null && !_noInstitution)) ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            disabledBackgroundColor: GacomColors.elevatedCard),
          child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text(_noInstitution ? 'Continue in Self-Study Mode' : 'Join ${_selectedName ?? 'Institution'}',
              style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))))),
    ]),
  );
}
