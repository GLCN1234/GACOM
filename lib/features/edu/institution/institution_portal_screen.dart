import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/app_constants.dart';

/// Institution admin portal — accessed via generated login credentials.
/// Shows student roster, per-student progress, curriculum uploads.
class InstitutionPortalScreen extends StatefulWidget {
  const InstitutionPortalScreen({super.key});
  @override State<InstitutionPortalScreen> createState() => _InstitutionPortalState();
}

class _InstitutionPortalState extends State<InstitutionPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String,dynamic>? _institution;
  List<Map<String,dynamic>> _students = [];
  List<Map<String,dynamic>> _curricula = [];
  bool _loading = true;

  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); _load(); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) { setState(() => _loading = false); return; }

      final email = user.email ?? '';

      // Try to find institution by email match
      // Use .select('*') with no filter first to check RLS isn't blocking
      List<Map<String,dynamic>> allInst = [];
      try {
        final rows = await SupabaseService.client
            .from('institutions').select('*').eq('login_email', email);
        allInst = List<Map<String,dynamic>>.from(rows as List);
      } catch (_) {}

      // If RLS blocked it, try fetching via login_code from user metadata
      if (allInst.isEmpty) {
        final instId = user.userMetadata?['institution_id'] as String?;
        if (instId != null) {
          try {
            final row = await SupabaseService.client
                .from('institutions').select('*').eq('id', instId).maybeSingle();
            if (row != null) allInst = [row];
          } catch (_) {}
        }
      }

      if (allInst.isEmpty) { setState(() => _loading = false); return; }

      final inst = allInst.first;

      List<Map<String,dynamic>> students = [];
      List<Map<String,dynamic>> curricula = [];

      try {
        final s = await SupabaseService.client.from('student_institutions')
            .select('*, student:profiles!student_id(display_name,username,avatar_url)')
            .eq('institution_id', inst['id'] as String);
        students = List<Map<String,dynamic>>.from(s as List);
      } catch (_) {}

      try {
        final c = await SupabaseService.client.from('institution_curricula')
            .select('*').eq('institution_id', inst['id'] as String)
            .order('created_at', ascending: false);
        curricula = List<Map<String,dynamic>>.from(c as List);
      } catch (_) {}

      if (mounted) setState(() {
        _institution = inst;
        _students = students;
        _curricula = curricula;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(_institution?['name'] ?? 'Institution Portal', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: GacomColors.error),
          tooltip: 'Log out',
          onPressed: () async {
            await SupabaseService.client.auth.signOut();
            if (context.mounted) context.go(AppConstants.loginRoute);
          }),
      ],
    ),
    body: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
      : _institution == null ? _buildNotLinked()
      : Column(children: [
          Container(color: GacomColors.cardDark, padding: const EdgeInsets.all(16),
            child: Row(children: [
              _PortalStat(label: 'Students', value: '${_students.length}', icon: Icons.people_outline_rounded, color: GacomColors.deepOrange),
              _PortalStat(label: 'Curricula', value: '${_curricula.length}', icon: Icons.upload_file_rounded, color: GacomColors.accentCyan),
              _PortalStat(label: 'Active Today', value: '${_students.where((s) => s['progress'] != null && (s['progress'] as List).isNotEmpty).length}', icon: Icons.trending_up_rounded, color: GacomColors.success),
            ])),
          TabBar(controller: _tab, indicatorColor: GacomColors.deepOrange, labelColor: GacomColors.deepOrange, unselectedLabelColor: GacomColors.textMuted,
            labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'STUDENTS'), Tab(text: 'CURRICULUM'), Tab(text: 'UPLOAD')]),
          Expanded(child: TabBarView(controller: _tab, children: [
            _buildStudents(),
            _buildCurricula(),
            _buildUpload(),
          ])),
        ]),
  );

  Widget _buildNotLinked() {
    final email = SupabaseService.client.auth.currentUser?.email ?? 'unknown';
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.account_balance_outlined, size: 64, color: GacomColors.textMuted),
      const SizedBox(height: 16),
      const Text('Institution Not Found', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)),
      const SizedBox(height: 8),
      Text('Logged in as: $email', style: const TextStyle(color: GacomColors.accentCyan, fontSize: 12, fontFamily: 'Courier')),
      const SizedBox(height: 8),
      const Text('No institution is linked to this email address.\nAsk your GACOM admin to add your institution and ensure the login email matches.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () async {
          await SupabaseService.client.auth.signOut();
          if (context.mounted) context.go(AppConstants.loginRoute);
        },
        icon: const Icon(Icons.logout_rounded, size: 16, color: GacomColors.error),
        label: const Text('Log out', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
    ])));
  }

  Widget _buildStudents() => _students.isEmpty
    ? const Center(child: Text('No students enrolled yet.\nShare your institution code with students.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13), textAlign: TextAlign.center))
    : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _students.length, itemBuilder: (_, i) {
        final s = _students[i];
        final profile = s['student'] as Map? ?? {};
        final progress = s['progress'] as List? ?? [];
        final totalXp = progress.fold<int>(0, (sum, p) => sum + (p['xp'] as int? ?? 0));
        final avgAcc = progress.isEmpty ? 0 : progress.fold<int>(0, (sum, p) => sum + (p['accuracy'] as int? ?? 0)) ~/ progress.length;
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.elevatedCard, border: Border.all(color: GacomColors.deepOrange, width: 2)),
              child: Center(child: Text((profile['display_name'] ?? 'S').toString()[0].toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile['display_name'] ?? 'Student', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
              Text('${s['class_level'] ?? 'Class not set'} · ${progress.length} subjects tracked', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$totalXp XP', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.deepOrange)),
              Text('$avgAcc% avg', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ]),
          ]));
      });

  Widget _buildCurricula() => _curricula.isEmpty
    ? const Center(child: Text('No curriculum uploaded yet.\nGo to Upload tab to add curriculum.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13), textAlign: TextAlign.center))
    : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _curricula.length, itemBuilder: (_, i) {
        final c = _curricula[i];
        final status = c['status'] as String? ?? 'pending';
        final statusColor = status == 'ready' ? GacomColors.success : status == 'processing' ? GacomColors.accentCyan : status == 'failed' ? GacomColors.error : GacomColors.textMuted;
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.description_outlined, color: GacomColors.accentCyan, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['topic'] as String? ?? 'Topic', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
              Text('${c['subject']} · ${c['class_level']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
          ]));
      });

  Widget _buildUpload() => _CurriculumUploader(institutionId: _institution?['id'] as String? ?? '', onUploaded: _load);
}

class _PortalStat extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _PortalStat({required this.label, required this.value, required this.icon, required this.color});
  @override Widget build(BuildContext ctx) => Expanded(child: Column(children: [
    Icon(icon, color: color, size: 22),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: color)),
    Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
  ]));
}

class _CurriculumUploader extends StatefulWidget {
  final String institutionId; final VoidCallback onUploaded;
  const _CurriculumUploader({required this.institutionId, required this.onUploaded});
  @override State<_CurriculumUploader> createState() => _CurriculumUploaderState();
}

class _CurriculumUploaderState extends State<_CurriculumUploader> {
  final _subjectCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String? _classLevel;
  bool _uploading = false;
  String _status = '';

  static const _classLevels = ['Primary 1','Primary 2','Primary 3','Primary 4','Primary 5','Primary 6','JSS 1','JSS 2','JSS 3','SS 1','SS 2','SS 3'];

  @override void dispose() { _subjectCtrl.dispose(); _topicCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  Future<void> _upload() async {
    if (_subjectCtrl.text.isEmpty || _topicCtrl.text.isEmpty || _contentCtrl.text.isEmpty || _classLevel == null) {
      setState(() => _status = 'Please fill all fields'); return;
    }
    setState(() { _uploading = true; _status = 'Uploading curriculum...'; });
    try {
      // 1. Save curriculum to DB with status 'processing'
      final row = await SupabaseService.client.from('institution_curricula').insert({
        'institution_id': widget.institutionId,
        'subject': _subjectCtrl.text.trim(),
        'class_level': _classLevel,
        'topic': _topicCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'status': 'processing',
        'uploaded_by': SupabaseService.currentUserId,
      }).select().single();

      setState(() => _status = 'Generating games with AI...');

      // 2. Call Claude API to generate gamified questions from curriculum
      final response = await SupabaseService.client.functions.invoke('generate-curriculum-games', body: {
        'curriculum_id': row['id'],
        'subject': _subjectCtrl.text.trim(),
        'class_level': _classLevel,
        'topic': _topicCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
      });

      if (mounted) {
        setState(() { _uploading = false; _status = 'Games generated successfully!'; });
        _subjectCtrl.clear(); _topicCtrl.clear(); _contentCtrl.clear(); _classLevel = null;
        widget.onUploaded();
      }
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.2))),
      child: const Row(children: [
        Icon(Icons.auto_awesome_rounded, color: GacomColors.accentCyan, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text('Upload your curriculum content and our AI will automatically generate gamified questions, exercises, and step-by-step learning games for your students.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4))),
      ])),
    const SizedBox(height: 20),
    _field(_subjectCtrl, 'Subject *', 'e.g. Mathematics, Physics, English', Icons.book_outlined),
    const SizedBox(height: 12),
    Row(children: [
      const Text('Class Level *', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontFamily: 'Rajdhani')),
      const SizedBox(width: 12),
      Expanded(child: DropdownButton<String>(value: _classLevel, hint: const Text('Select', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        isExpanded: true, dropdownColor: GacomColors.elevatedCard,
        style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
        underline: Container(height: 1, color: GacomColors.border),
        onChanged: (v) => setState(() => _classLevel = v),
        items: _classLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList())),
    ]),
    const SizedBox(height: 12),
    _field(_topicCtrl, 'Topic / Chapter *', 'e.g. Quadratic Equations, Photosynthesis', Icons.topic_outlined),
    const SizedBox(height: 12),
    Container(decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
      child: TextField(controller: _contentCtrl, maxLines: 8,
        style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, fontFamily: 'Rajdhani'),
        decoration: const InputDecoration(hintText: 'Paste your curriculum content here — chapter text, lesson notes, learning objectives, key concepts, formulas...', hintStyle: TextStyle(color: GacomColors.textMuted, fontSize: 12), contentPadding: EdgeInsets.all(14), border: InputBorder.none))),
    const SizedBox(height: 16),
    if (_status.isNotEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _status.contains('Error') ? GacomColors.error.withOpacity(0.08) : GacomColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(_status, style: TextStyle(color: _status.contains('Error') ? GacomColors.error : GacomColors.success, fontSize: 12))),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _uploading ? null : _upload,
      icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(_uploading ? 'Generating...' : 'Upload & Generate Games', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
  ]));

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) => TextField(controller: ctrl,
    style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 14),
    decoration: InputDecoration(labelText: label, hintText: hint, labelStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 12), hintStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
      prefixIcon: Icon(icon, color: GacomColors.textMuted, size: 18),
      filled: true, fillColor: GacomColors.elevatedCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.deepOrange))));
}
