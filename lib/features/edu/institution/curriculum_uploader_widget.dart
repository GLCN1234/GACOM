import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Curriculum uploader — orchestrates the multi-batch generation loop.
///
/// The edge function does ONE small batch per call (a few seconds each)
/// because Supabase kills any function that takes longer than 150 seconds
/// to respond. This widget calls it repeatedly — 21 times total — showing
/// real progress, instead of one long call that used to get silently
/// killed mid-way and leave the curriculum stuck on "processing" forever.
class CurriculumUploaderWidget extends StatefulWidget {
  final String institutionId;
  final VoidCallback onUploaded;
  const CurriculumUploaderWidget({super.key, required this.institutionId, required this.onUploaded});
  @override State<CurriculumUploaderWidget> createState() => _CurriculumUploaderWidgetState();
}

class _CurriculumUploaderWidgetState extends State<CurriculumUploaderWidget> {
  final _subjectCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String? _classLevel;
  bool _uploading = false;
  String _status = '';
  int _currentBatch = 0;
  int _totalBatches = 21;

  static const _classLevels = ['Primary 1','Primary 2','Primary 3','Primary 4','Primary 5','Primary 6','JSS 1','JSS 2','JSS 3','SS 1','SS 2','SS 3'];

  @override void dispose() { _subjectCtrl.dispose(); _topicCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  Future<void> _upload() async {
    if (_subjectCtrl.text.isEmpty || _topicCtrl.text.isEmpty || _contentCtrl.text.isEmpty || _classLevel == null) {
      setState(() => _status = 'Please fill all fields'); return;
    }
    setState(() { _uploading = true; _status = 'Creating adventure...'; _currentBatch = 0; });

    try {
      final row = await SupabaseService.client.from('institution_curricula').insert({
        'institution_id': widget.institutionId,
        'subject': _subjectCtrl.text.trim(),
        'class_level': _classLevel,
        'topic': _topicCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'status': 'processing',
        'uploaded_by': SupabaseService.currentUserId,
      }).select().single();

      final curriculumId = row['id'] as String;

      int? nextBatch = 0;
      while (nextBatch != null) {
        final res = await _callBatch(curriculumId, nextBatch);

        if (res == null) {
          await SupabaseService.client.from('institution_curricula').update({'status': 'failed'}).eq('id', curriculumId);
          if (mounted) setState(() { _uploading = false; _status = 'Generation failed at batch $_currentBatch/$_totalBatches. You can try uploading again.'; });
          return;
        }

        _totalBatches = res['total_batches'] as int? ?? _totalBatches;
        _currentBatch = (nextBatch) + 1;
        final progressLabel = res['progress_label'] as String? ?? '';
        if (mounted) setState(() => _status = 'Generating: $progressLabel  ($_currentBatch/$_totalBatches)');

        final done = res['done'] as bool? ?? false;
        nextBatch = done ? null : res['next_batch'] as int?;
      }

      if (mounted) {
        setState(() { _uploading = false; _status = 'Done! 300 questions generated across 5 levels.'; });
        _subjectCtrl.clear(); _topicCtrl.clear(); _contentCtrl.clear(); _classLevel = null;
        widget.onUploaded();
      }
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _status = 'Error: $e'; });
    }
  }

  Future<Map<String,dynamic>?> _callBatch(String curriculumId, int batchNumber, {int attempt = 1}) async {
    try {
      final res = await SupabaseService.client.functions.invoke('generate-curriculum-games', body: {
        'curriculum_id': curriculumId,
        'subject': _subjectCtrl.text.trim(),
        'class_level': _classLevel,
        'topic': _topicCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'batch_number': batchNumber,
      });
      final data = res.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);
      return Map<String,dynamic>.from(data as Map);
    } catch (e) {
      if (attempt < 3) {
        await Future.delayed(Duration(seconds: attempt * 3));
        return _callBatch(curriculumId, batchNumber, attempt: attempt + 1);
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.2))),
      child: const Row(children: [Icon(Icons.auto_awesome_rounded, color: GacomColors.accentCyan, size: 18), SizedBox(width: 10),
        Expanded(child: Text('Upload curriculum text and AI will generate 300 gamified questions across 5 difficulty levels. Takes 3-5 minutes — please keep this screen open.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4)))])),
    const SizedBox(height: 16),
    _field(_subjectCtrl, 'Subject *', 'e.g. Mathematics, Physics', Icons.book_outlined),
    const SizedBox(height: 12),
    Row(children: [const Text('Class Level *', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)), const SizedBox(width: 12),
      Expanded(child: DropdownButton<String>(value: _classLevel, hint: const Text('Select', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        isExpanded: true, dropdownColor: GacomColors.elevatedCard,
        style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
        underline: Container(height: 1, color: GacomColors.border),
        onChanged: _uploading ? null : (v) => setState(() => _classLevel = v),
        items: _classLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList()))]),
    const SizedBox(height: 12),
    _field(_topicCtrl, 'Topic *', 'e.g. Quadratic Equations, Photosynthesis', Icons.topic_outlined),
    const SizedBox(height: 12),
    Container(decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
      child: TextField(controller: _contentCtrl, maxLines: 8, enabled: !_uploading,
        style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(hintText: 'Paste curriculum content, lesson notes, key concepts...', hintStyle: TextStyle(color: GacomColors.textMuted, fontSize: 12), contentPadding: EdgeInsets.all(14), border: InputBorder.none))),
    const SizedBox(height: 12),
    if (_uploading) ...[
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _totalBatches > 0 ? _currentBatch / _totalBatches : null, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange), minHeight: 6)),
      const SizedBox(height: 8),
    ],
    if (_status.isNotEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _status.contains('Error') || _status.contains('failed') ? GacomColors.error.withOpacity(0.08) : GacomColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(_status, style: TextStyle(color: _status.contains('Error') || _status.contains('failed') ? GacomColors.error : GacomColors.success, fontSize: 12))),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _uploading ? null : _upload,
      icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(_uploading ? 'Generating...' : 'Upload & Generate 300 Questions', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
  ]));

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) => TextField(controller: ctrl, enabled: !_uploading,
    style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 14),
    decoration: InputDecoration(labelText: label, hintText: hint, labelStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 12), hintStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
      prefixIcon: Icon(icon, color: GacomColors.textMuted, size: 18), filled: true, fillColor: GacomColors.elevatedCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.deepOrange))));
}
