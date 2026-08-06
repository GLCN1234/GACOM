import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class BulkCurriculumUploaderWidget extends StatefulWidget {
  final String institutionId;
  final VoidCallback onQueued;
  const BulkCurriculumUploaderWidget({super.key, required this.institutionId, required this.onQueued});
  @override State<BulkCurriculumUploaderWidget> createState() => _BulkCurriculumUploaderWidgetState();
}

class _BulkCurriculumUploaderWidgetState extends State<BulkCurriculumUploaderWidget> {
  bool _submitting = false;
  bool _queuing = false;
  String? _error;
  String? _jobId;
  int _chunkIndex = 0;
  int _totalChunks = 0;
  bool _jobReady = false;
  Timer? _pollTimer;
  List<Map<String,dynamic>> _proposedTopics = [];
  static const _classLevels = ['Primary 1','Primary 2','Primary 3','Primary 4','Primary 5','Primary 6','JSS 1','JSS 2','JSS 3','SS 1','SS 2','SS 3'];

  @override void initState() { super.initState(); _resumeExistingJob(); }
  @override void dispose() { _pollTimer?.cancel(); super.dispose(); }

  Future<void> _resumeExistingJob() async {
    try {
      final row = await SupabaseService.client
          .from('pdf_segmentation_jobs')
          .select('id,status,next_chunk_index,total_chunks,accumulated_topics')
          .eq('institution_id', widget.institutionId)
          .inFilter('status', ['processing', 'ready'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null || !mounted) return;
      setState(() {
        _jobId = row['id'] as String;
        _chunkIndex = row['next_chunk_index'] as int? ?? 0;
        _totalChunks = row['total_chunks'] as int? ?? 0;
      });
      if (row['status'] == 'ready') {
        _onJobReady(List<Map<String,dynamic>>.from((row['accumulated_topics'] as List).map((t) => Map<String,dynamic>.from(t as Map))));
      } else {
        _startPolling();
      }
    } catch (_) {}
  }

  Future<void> _pickAndSubmit() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final bytes = result.files.first.bytes!;
    final filename = result.files.first.name;
    setState(() { _submitting = true; _error = null; _proposedTopics = []; _jobReady = false; });
    try {
      final base64Str = base64Encode(bytes);
      final res = await SupabaseService.client.functions.invoke('extract-and-segment-curriculum', body: {
        'pdf_base64': base64Str,
        'institution_id': widget.institutionId,
        'uploaded_by': SupabaseService.currentUserId,
        'filename': filename,
      });
      final data = res.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);
      final map = Map<String,dynamic>.from(data as Map);
      setState(() {
        _jobId = map['job_id'] as String;
        _totalChunks = map['total_chunks'] as int? ?? 0;
        _chunkIndex = 0;
        _submitting = false;
      });
      _startPolling();
    } catch (e) {
      setState(() { _submitting = false; _error = 'Upload failed: $e'; });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkJob());
  }

  Future<void> _checkJob() async {
    if (_jobId == null) return;
    try {
      final row = await SupabaseService.client
          .from('pdf_segmentation_jobs')
          .select('status,next_chunk_index,total_chunks,accumulated_topics')
          .eq('id', _jobId!)
          .single();
      if (!mounted) return;
      final status = row['status'] as String;
      if (status == 'ready') {
        _onJobReady(List<Map<String,dynamic>>.from((row['accumulated_topics'] as List).map((t) => Map<String,dynamic>.from(t as Map))));
      } else if (status == 'failed') {
        _pollTimer?.cancel();
        setState(() => _error = 'PDF reading stalled after repeated errors. Try uploading again.');
      } else {
        setState(() {
          _chunkIndex = row['next_chunk_index'] as int? ?? _chunkIndex;
          _totalChunks = row['total_chunks'] as int? ?? _totalChunks;
        });
      }
    } catch (_) {}
  }

  void _onJobReady(List<Map<String,dynamic>> topics) {
    _pollTimer?.cancel();
    setState(() { _jobReady = true; _proposedTopics = topics; });
  }

  void _removeTopic(int index) => setState(() => _proposedTopics.removeAt(index));

  Future<void> _queueAll() async {
    if (_proposedTopics.isEmpty) return;
    setState(() { _queuing = true; _error = null; });
    try {
      final rows = _proposedTopics.map((t) => {
        'institution_id': widget.institutionId,
        'subject': (t['subject'] as String? ?? '').trim(),
        'class_level': t['class_level'] as String? ?? 'JSS 1',
        'topic': (t['topic'] as String? ?? '').trim(),
        'content': (t['content'] as String? ?? '').trim(),
        'status': 'queued',
        'next_batch_number': 0,
        'batch_error_count': 0,
        'uploaded_by': SupabaseService.currentUserId,
      }).toList();
      await SupabaseService.client.from('institution_curricula').insert(rows);
      setState(() { _queuing = false; _proposedTopics = []; _jobReady = false; _jobId = null; });
      widget.onQueued();
    } catch (e) {
      setState(() { _queuing = false; _error = 'Queueing failed: $e'; });
    }
  }

  bool get _isProcessing => _jobId != null && !_jobReady;

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.2))),
      child: const Row(children: [Icon(Icons.picture_as_pdf_rounded, color: GacomColors.accentCyan, size: 18), SizedBox(width: 10),
        Expanded(child: Text('Upload once — reading happens in the background, even if you close this tab. Come back anytime to review the topics found.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4)))])),
    const SizedBox(height: 16),
    if (!_isProcessing && !_jobReady) SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: _submitting ? null : _pickAndSubmit,
      icon: _submitting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file_rounded, size: 16),
      label: Text(_submitting ? 'Starting...' : 'Choose PDF', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: GacomColors.border)))),
    if (_isProcessing) ...[
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
        child: Column(children: [
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: _totalChunks > 0 ? _chunkIndex / _totalChunks : null,
            backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange), minHeight: 6)),
          const SizedBox(height: 10),
          Text('Reading document: part $_chunkIndex of $_totalChunks', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Safe to close this tab — it keeps going and you can check back anytime.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
        ])),
    ],
    if (_error != null) ...[
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Text(_error!, style: const TextStyle(color: GacomColors.error, fontSize: 12))),
    ],
    if (_jobReady && _proposedTopics.isNotEmpty) ...[
      const SizedBox(height: 20),
      Text('${_proposedTopics.length} topics found — review before queueing', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
      const SizedBox(height: 12),
      ..._proposedTopics.asMap().entries.map((e) => _topicCard(e.key, e.value)),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _queuing ? null : _queueAll,
        icon: _queuing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.playlist_add_check_rounded, size: 16),
        label: Text(_queuing ? 'Queueing...' : 'Queue All ${_proposedTopics.length} Topics', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ],
  ]));

  Widget _topicCard(int index, Map<String,dynamic> t) {
    final subjectCtrl = TextEditingController(text: t['subject'] as String? ?? '');
    final topicCtrl = TextEditingController(text: t['topic'] as String? ?? '');
    final contentCtrl = TextEditingController(text: t['content'] as String? ?? '');
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(controller: subjectCtrl, onChanged: (v) => t['subject'] = v,
            style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
            decoration: const InputDecoration(labelText: 'Subject', labelStyle: TextStyle(fontSize: 11, color: GacomColors.textMuted), isDense: true))),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: DropdownButtonFormField<String>(
            value: _classLevels.contains(t['class_level']) ? t['class_level'] as String : 'JSS 1',
            isExpanded: true, dropdownColor: GacomColors.elevatedCard,
            style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
            decoration: const InputDecoration(labelText: 'Class', labelStyle: TextStyle(fontSize: 11, color: GacomColors.textMuted), isDense: true),
            items: _classLevels.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => t['class_level'] = v))),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: GacomColors.textMuted), onPressed: () => _removeTopic(index)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: topicCtrl, onChanged: (v) => t['topic'] = v,
          style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'Topic', labelStyle: TextStyle(fontSize: 11, color: GacomColors.textMuted), isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: contentCtrl, onChanged: (v) => t['content'] = v, maxLines: 3,
          style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12),
          decoration: const InputDecoration(labelText: 'Content excerpt', labelStyle: TextStyle(fontSize: 11, color: GacomColors.textMuted), isDense: true)),
      ]));
  }
}
