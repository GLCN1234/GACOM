import 'package:flutter/material.dart';
import '../../edu/competition/flyer_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/pick_upload.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// Admin list of competitions with create, edit, delete, flyer upload and
/// start/end date and time. Used by the web and the app admin dashboard.
class CompetitionsAdminSection extends StatefulWidget {
  const CompetitionsAdminSection({super.key});
  @override
  State<CompetitionsAdminSection> createState() => _CompetitionsAdminSectionState();
}

class _CompetitionsAdminSectionState extends State<CompetitionsAdminSection> {
  List<Map<String, dynamic>> _comps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      try {
        await SupabaseService.client.rpc('edu_comp_banners');
      } catch (_) {}
      final data = await SupabaseService.client
          .from('competitions')
          .select('*')
          .order('created_at', ascending: false)
          .limit(60);
      if (mounted) setState(() { _comps = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Delete competition?', style: TextStyle(color: GacomColors.textPrimary)),
        content: Text('"${c['title']}" and all of its entries and points will be removed. This cannot be undone.', style: const TextStyle(color: GacomColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL', style: TextStyle(color: GacomColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: GacomColors.error, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await SupabaseService.client.rpc('admin_delete_competition', params: {'p_id': c['id']});
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        GacomSnackbar.show(context, 'Competition deleted', isSuccess: true);
        _load();
      } else {
        GacomSnackbar.show(context, (res is Map ? res['error'] : null)?.toString() ?? 'Could not delete', isError: true);
      }
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not delete: $e', isError: true);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    List<Map<String, dynamic>> institutions = [];
    try {
      final data = await SupabaseService.client.from('institutions').select('id, name, state, country').eq('is_active', true).order('name');
      institutions = List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompetitionForm(existing: existing, institutions: institutions),
    );
    if (saved == true) {
      _load();
      if (mounted) GacomSnackbar.show(context, existing == null ? 'Competition created' : 'Competition updated', isSuccess: true);
    }
  }

  String _fmt(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '-';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('COMPETITIONS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('CREATE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else if (_comps.isEmpty)
        const Expanded(child: Center(child: Text('No competitions yet', style: TextStyle(color: GacomColors.textMuted))))
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _comps.length,
            itemBuilder: (_, i) {
              final c = _comps[i];
              final status = (c['status'] as String?) ?? 'upcoming';
              final statusColor = status == 'live' ? GacomColors.error : status == 'upcoming' ? GacomColors.info : GacomColors.textMuted;
              final isEdu = c['kind'] == 'edu';
              final scope = c['scope_type'] == 'institution'
                  ? 'One school'
                  : c['scope_type'] == 'state'
                      ? '${c['scope_state']} state'
                      : c['scope_type'] == 'country'
                          ? '${c['scope_country']}'
                          : 'Open to everyone';
              final banner = (c['banner_url'] as String?) ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (banner.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(width: 64, height: 64, child: FlyerImage(url: banner, showError: false)),
                        ),
                      ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c['title'] ?? 'Untitled'}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${isEdu ? 'GACOM Edu' : c['game_name']} | ₦${c['prize_pool'] ?? 0} prize | $scope', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('${_fmt(c['starts_at'])}  to  ${_fmt(c['ends_at'])}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(50)),
                      child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: statusColor)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(onPressed: () => _openForm(c), icon: const Icon(Icons.edit_rounded, size: 16, color: GacomColors.accentCyan), label: const Text('EDIT', style: TextStyle(color: GacomColors.accentCyan, fontWeight: FontWeight.w800))),
                    TextButton.icon(onPressed: () => _delete(c), icon: const Icon(Icons.delete_outline_rounded, size: 16, color: GacomColors.error), label: const Text('DELETE', style: TextStyle(color: GacomColors.error, fontWeight: FontWeight.w800))),
                  ]),
                ]),
              );
            },
          ),
        ),
    ]);
  }
}

class _CompetitionForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> institutions;
  const _CompetitionForm({required this.existing, required this.institutions});
  @override
  State<_CompetitionForm> createState() => _CompetitionFormState();
}

class _CompetitionFormState extends State<_CompetitionForm> {
  late final TextEditingController _title, _game, _desc, _rules, _prize, _entry, _target, _points, _cap, _max;
  String _type = 'free';
  String _kind = 'general';
  String _scope = 'all';
  String? _institutionId, _state, _country;
  String _bannerUrl = '';
  bool _featured = false;
  bool _uploading = false;
  bool _saving = false;
  DateTime? _starts, _ends;
  final Set<String> _subjects = {'math', 'english'};

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing ?? const <String, dynamic>{};
    String t(dynamic v) => v == null ? '' : '$v';
    String num0(dynamic v) {
      final n = num.tryParse('${v ?? ''}');
      if (n == null || n == 0) return '';
      return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
    }
    _title = TextEditingController(text: t(c['title']));
    _game = TextEditingController(text: t(c['game_name']));
    _desc = TextEditingController(text: t(c['description']));
    _rules = TextEditingController(text: t(c['rules']));
    _prize = TextEditingController(text: num0(c['prize_pool']));
    _entry = TextEditingController(text: num0(c['entry_fee']));
    _target = TextEditingController(text: t(c['target_score']));
    _points = TextEditingController(text: t(c['points_per_correct'] ?? 10));
    _cap = TextEditingController(text: t(c['daily_point_cap'] ?? 1500));
    _max = TextEditingController(text: t(c['max_participants']));
    _type = (c['competition_type'] as String?) ?? 'free';
    _kind = (c['kind'] as String?) ?? 'general';
    _scope = (c['scope_type'] as String?) ?? 'all';
    _institutionId = c['institution_id'] as String?;
    _state = c['scope_state'] as String?;
    _country = c['scope_country'] as String?;
    _bannerUrl = (c['banner_url'] as String?) ?? '';
    _featured = c['is_featured'] == true;
    _starts = DateTime.tryParse(t(c['starts_at']))?.toLocal();
    _ends = DateTime.tryParse(t(c['ends_at']))?.toLocal();
    final subs = c['edu_subjects'];
    if (subs is List && subs.isNotEmpty) {
      _subjects
        ..clear()
        ..addAll(subs.map((e) => '$e'));
    }
    if (!_isEdit) {
      _kind = 'general';
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _game, _desc, _rules, _prize, _entry, _target, _points, _cap, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final base = (isStart ? _starts : _ends) ?? DateTime.now().add(Duration(days: isStart ? 1 : 7));
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 900)),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (tm == null || !mounted) return;
    setState(() {
      final v = DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
      if (isStart) {
        _starts = v;
      } else {
        _ends = v;
      }
    });
  }

  Future<void> _uploadFlyer() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadImage(bucket: 'competition-banners');
      if (url != null && mounted) setState(() => _bannerUrl = url);
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _dt(DateTime? d, String empty) {
    if (d == null) return empty;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.day}/${d.month}/${d.year}  $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final isEdu = _kind == 'edu';
    final game = isEdu ? 'GACOM Edu' : _game.text.trim();
    if (title.isEmpty || game.isEmpty || _starts == null || _ends == null) {
      GacomSnackbar.show(context, 'Fill the title, game, start and end', isError: true);
      return;
    }
    if (!_ends!.isAfter(_starts!)) {
      GacomSnackbar.show(context, 'The end must be after the start', isError: true);
      return;
    }
    if (_scope == 'institution' && _institutionId == null) { GacomSnackbar.show(context, 'Choose the school', isError: true); return; }
    if (_scope == 'state' && _state == null) { GacomSnackbar.show(context, 'Choose the state', isError: true); return; }
    if (_scope == 'country' && _country == null) { GacomSnackbar.show(context, 'Choose the country', isError: true); return; }
    if (isEdu && _subjects.isEmpty) { GacomSnackbar.show(context, 'Pick at least one subject', isError: true); return; }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': title,
        'game_name': game,
        'description': _desc.text.trim(),
        'rules': _rules.text.trim(),
        'banner_url': _bannerUrl,
        'competition_type': _type,
        'prize_pool': double.tryParse(_prize.text.trim()) ?? 0,
        'entry_fee': _type == 'paid' ? (double.tryParse(_entry.text.trim()) ?? 0) : 0,
        'max_participants': int.tryParse(_max.text.trim()),
        'target_score': isEdu ? null : int.tryParse(_target.text.trim()),
        'is_featured': _featured,
        'scope_type': _scope,
        'institution_id': _scope == 'institution' ? _institutionId : null,
        'scope_state': _scope == 'state' ? _state : null,
        'scope_country': _scope == 'country' ? _country : null,
        'kind': _kind,
        'edu_subjects': _subjects.toList(),
        'points_per_correct': int.tryParse(_points.text.trim()) ?? 10,
        'daily_point_cap': int.tryParse(_cap.text.trim()) ?? 1500,
        'starts_at': _starts!.toUtc().toIso8601String(),
        'ends_at': _ends!.toUtc().toIso8601String(),
      };
      if (_isEdit) {
        final res = await SupabaseService.client.rpc('admin_update_competition', params: {'p_id': widget.existing!['id'], 'p': body});
        if (res is Map && res['success'] != true) throw (res['error'] ?? 'Could not save').toString();
      } else {
        final now = DateTime.now();
        final insert = Map<String, dynamic>.from(body)
          ..remove('max_participants')
          ..['status'] = _starts!.isAfter(now) ? 'upcoming' : (_ends!.isAfter(now) ? 'live' : 'ended')
          ..['created_by'] = SupabaseService.currentUserId
          ..['is_admin_created'] = true;
        if (body['max_participants'] != null) insert['max_participants'] = body['max_participants'];
        if (_bannerUrl.isEmpty) insert.remove('banner_url');
        await SupabaseService.client.from('competitions').insert(insert);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        GacomSnackbar.show(context, 'Error: $e', isError: true);
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: GacomColors.textMuted),
        hintStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: GacomColors.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
      );

  Widget _field(TextEditingController c, String label, {bool number = false, int lines = 1, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : (lines > 1 ? TextInputType.multiline : TextInputType.text),
          minLines: lines,
          maxLines: lines,
          style: const TextStyle(color: GacomColors.textPrimary),
          decoration: _dec(label, hint: hint),
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: GacomColors.deepOrange,
        backgroundColor: GacomColors.surfaceDark,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(color: selected ? Colors.white : GacomColors.textMuted),
      );

  Widget _dateBox(String label, DateTime? v, bool isStart) => Expanded(
        child: GestureDetector(
          onTap: () => _pickDateTime(isStart),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(_dt(v, 'Pick date and time'), style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final states = widget.institutions.map((i) => i['state'] as String?).whereType<String>().toSet().toList()..sort();
    final countries = widget.institutions.map((i) => i['country'] as String?).whereType<String>().toSet().toList()..sort();
    final isEdu = _kind == 'edu';
    return AlertDialog(
      backgroundColor: GacomColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_isEdit ? 'EDIT COMPETITION' : 'CREATE COMPETITION', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary, fontSize: 18)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kind', style: TextStyle(color: GacomColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              _chip('Game competition', !isEdu, () => setState(() => _kind = 'general')),
              _chip('GACOM Edu (Maths and English)', isEdu, () => setState(() { _kind = 'edu'; _type = 'free'; })),
            ]),
            const SizedBox(height: 14),
            _field(_title, 'Title *'),
            if (!isEdu) _field(_game, 'Game name *'),
            _field(_desc, 'Description', lines: 3),
            _field(_rules, 'Rules', lines: 3),
            const Text('Flyer', style: TextStyle(color: GacomColors.textSecondary)),
            const SizedBox(height: 6),
            if (_bannerUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: 16 / 9, child: FlyerImage(url: _bannerUrl)),
              ),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadFlyer,
                icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange)) : const Icon(Icons.upload_rounded, size: 18, color: GacomColors.deepOrange),
                label: Text(_bannerUrl.isEmpty ? 'UPLOAD FLYER' : 'REPLACE FLYER', style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.deepOrange)),
              ),
              if (_bannerUrl.isNotEmpty) TextButton(onPressed: () => setState(() => _bannerUrl = ''), child: const Text('REMOVE', style: TextStyle(color: GacomColors.error))),
            ]),
            const SizedBox(height: 14),
            Row(children: [_dateBox('Starts', _starts, true), const SizedBox(width: 8), _dateBox('Ends', _ends, false)]),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 14),
              child: Text('The competition opens and closes by itself at these times (Nigeria time on this device).', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ),
            if (isEdu) ...[
              const Text('Subjects that earn points', style: TextStyle(color: GacomColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                _chip('Maths', _subjects.contains('math'), () => setState(() => _subjects.contains('math') ? _subjects.remove('math') : _subjects.add('math'))),
                _chip('English', _subjects.contains('english'), () => setState(() => _subjects.contains('english') ? _subjects.remove('english') : _subjects.add('english'))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field(_points, 'Points per correct answer', number: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_cap, 'Daily points limit', number: true)),
              ]),
            ] else
              _field(_target, 'Target score to win (optional)', number: true, hint: 'If set, the first player to reach it wins'),
            _field(_prize, 'Prize pool (₦)', number: true),
            _field(_max, 'Maximum participants (optional)', number: true),
            DropdownButtonFormField<String>(
              value: _scope,
              dropdownColor: GacomColors.elevatedCard,
              style: const TextStyle(color: GacomColors.textPrimary),
              decoration: _dec('Who can compete'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Open to everyone')),
                DropdownMenuItem(value: 'institution', child: Text('One specific school')),
                DropdownMenuItem(value: 'state', child: Text('Schools in one state')),
                DropdownMenuItem(value: 'country', child: Text('Schools in one country')),
              ],
              onChanged: (v) => setState(() { _scope = v ?? 'all'; _institutionId = null; _state = null; _country = null; }),
            ),
            if (_scope == 'institution') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: widget.institutions.any((i) => i['id'] == _institutionId) ? _institutionId : null,
                isExpanded: true,
                dropdownColor: GacomColors.elevatedCard,
                style: const TextStyle(color: GacomColors.textPrimary),
                decoration: _dec('School'),
                items: widget.institutions.map((i) => DropdownMenuItem<String?>(value: i['id'] as String, child: Text('${i['name']}', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _institutionId = v),
              ),
            ],
            if (_scope == 'state') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: states.contains(_state) ? _state : null,
                dropdownColor: GacomColors.elevatedCard,
                style: const TextStyle(color: GacomColors.textPrimary),
                decoration: _dec('State'),
                items: states.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _state = v),
              ),
            ],
            if (_scope == 'country') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: countries.contains(_country) ? _country : null,
                dropdownColor: GacomColors.elevatedCard,
                style: const TextStyle(color: GacomColors.textPrimary),
                decoration: _dec('Country'),
                items: countries.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _country = v),
              ),
            ],
            const SizedBox(height: 12),
            if (!isEdu) ...[
              Row(children: [
                const Text('Type: ', style: TextStyle(color: GacomColors.textSecondary)),
                const SizedBox(width: 8),
                _chip('Free', _type == 'free', () => setState(() => _type = 'free')),
                const SizedBox(width: 8),
                _chip('Paid', _type == 'paid', () => setState(() => _type = 'paid')),
              ]),
              if (_type == 'paid') ...[const SizedBox(height: 12), _field(_entry, 'Entry fee (₦)', number: true)],
            ],
            if (!isEdu)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _featured,
              activeColor: GacomColors.deepOrange,
              onChanged: (v) => setState(() => _featured = v),
              title: const Text('Feature on the home feed', style: TextStyle(color: GacomColors.textPrimary, fontSize: 14)),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'SAVING...' : (_isEdit ? 'SAVE' : 'CREATE'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }
}
