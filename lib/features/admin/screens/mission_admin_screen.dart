import '../../../core/utils/safe_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../houses/house_service.dart';
import '../../missions/missions_service.dart';
import '../../missions/widgets/mission_style.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

Future<bool> _openUrl(String url) async {
  final u = safeHttpsUri(url);
  if (u == null) return false;
  try {
    return await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> _copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  GacomSnackbar.show(context, 'Copied', isSuccess: true);
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Opens a searchable picker. Returns null on cancel, or a map whose 'id' is null for "no item".
Future<Map<String, dynamic>?> _pickItem(BuildContext context, List<Map<String, dynamic>> items) {
  return showDialog<Map<String, dynamic>>(context: context, builder: (_) => _ItemPickerDialog(items: items));
}

class _ItemPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _ItemPickerDialog({required this.items});
  @override
  State<_ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<_ItemPickerDialog> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = widget.items.where((i) {
      if (q.isEmpty) return true;
      return (i['name']?.toString() ?? '').toLowerCase().contains(q) || (i['category']?.toString() ?? '').toLowerCase().contains(q);
    }).take(120).toList();
    return AlertDialog(
      backgroundColor: MTac.panel,
      shape: const RoundedRectangleBorder(side: BorderSide(color: MTac.keyline)),
      title: Text('Pick an item', style: mHead(size: 18)),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(children: [
          TextField(
            controller: _q,
            style: kMInput,
            onChanged: (v) => setState(() => _query = v),
            decoration: mField('Search by name or category'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text('No items match.', style: mBody()))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, k) {
                      final it = rows[k];
                      return InkWell(
                        onTap: () => Navigator.pop(context, it),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                          child: Row(children: [
                            Expanded(child: MItemTag(name: it['name']?.toString() ?? '', rarity: it['rarity']?.toString())),
                            const SizedBox(width: 8),
                            Text(missionCategoryLabel(it['category']?.toString()), style: mBody(size: 12, color: MTac.textMuted)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: mBody(color: MTac.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, <String, dynamic>{'id': null}), child: Text('No item', style: mBody(color: MTac.gold, weight: FontWeight.w700))),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String label;
  final String? itemId;
  final List<Map<String, dynamic>> items;
  final ValueChanged<String?> onChanged;
  const _ItemTile({required this.label, required this.itemId, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? sel;
    for (final i in items) {
      if (i['id']?.toString() == itemId) { sel = i; break; }
    }
    return InkWell(
      onTap: () async {
        final p = await _pickItem(context, items);
        if (p == null) return;
        onChanged(p['id']?.toString());
      },
      child: InputDecorator(
        decoration: mField(label),
        child: Row(children: [
          Expanded(
            child: sel != null
                ? MItemTag(name: sel['name']?.toString() ?? '', rarity: sel['rarity']?.toString())
                : Text(itemId != null ? 'Unknown item' : 'None', style: mBody(size: 14, color: MTac.textMuted)),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: MTac.textMuted),
        ]),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _ReasonDialog({required this.title, this.hint = 'Reason shown to the player'});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: MTac.panel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: MTac.keyline)),
        title: Text(widget.title, style: mHead(size: 18)),
        content: TextField(controller: _c, maxLines: 3, style: kMInput, decoration: mField('Reason', hint: widget.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: mBody(color: MTac.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, _c.text.trim()), child: Text('Confirm', style: mBody(color: MTac.bad, weight: FontWeight.w700))),
        ],
      );
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: MTac.panel,
      shape: const RoundedRectangleBorder(side: BorderSide(color: MTac.keyline)),
      title: Text(title, style: mHead(size: 18)),
      content: Text(body, style: mBody(size: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: mBody(color: MTac.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: mBody(color: MTac.bad, weight: FontWeight.w700))),
      ],
    ),
  );
  return ok == true;
}

Widget _sectionLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: mHead(size: 13, color: MTac.cyan, letterSpacing: 1.2)),
    );

Widget _dropdown({
  required String label,
  required String? value,
  required List<String> values,
  required ValueChanged<String?> onChanged,
  Map<String, String>? names,
}) {
  return DropdownButtonFormField<String>(
    value: values.contains(value) ? value : null,
    isExpanded: true,
    dropdownColor: MTac.panel,
    style: kMInput,
    decoration: mField(label),
    items: values.map((v) => DropdownMenuItem<String>(value: v, child: Text(names?[v] ?? v, style: kMInput))).toList(),
    onChanged: onChanged,
  );
}

class MissionAdminScreen extends StatefulWidget {
  const MissionAdminScreen({super.key});
  @override
  State<MissionAdminScreen> createState() => _MissionAdminScreenState();
}

class _MissionAdminScreenState extends State<MissionAdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _trophies = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadLookups();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final items = await MissionsService.cosmeticItems();
      final trophies = await MissionsService.trophyDefs();
      if (!mounted) return;
      setState(() { _items = items; _trophies = trophies; });
    } catch (_) {
      if (mounted) GacomSnackbar.show(context, 'Could not load items and trophies', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MTac.ground,
        appBar: AppBar(
          title: const Text('MISSION ADMIN'),
          bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [
            Tab(text: 'REVIEW QUEUE'),
            Tab(text: 'MISSIONS'),
            Tab(text: 'SEASON'),
            Tab(text: 'GRANTS'),
          ]),
        ),
        body: TabBarView(controller: _tab, children: [
          const _ReviewTab(),
          _MissionsTab(items: _items, trophies: _trophies),
          _SeasonTab(items: _items, trophies: _trophies),
          _GrantsTab(items: _items, trophies: _trophies),
        ]),
      );
}

// ---------------------------------------------------------------- review

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();
  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> with AutomaticKeepAliveClientMixin {
  static const List<List<String>> _filters = [
    ['pending', 'PENDING'],
    ['spot', 'SPOT CHECK'],
    ['approved', 'APPROVED'],
    ['rejected', 'REJECTED'],
  ];
  String _filter = 'pending';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String? _busyId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final rows = await MissionsService.adminQueue(_filter);
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = MissionsService.friendlyError(e); });
    }
  }

  Future<void> _review(Map<String, dynamic> r, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(title: r['status'] == 'approved' ? 'Remove reward' : 'Reject submission'),
      );
      if (reason == null || !mounted) return;
    }
    final id = r['id'].toString();
    setState(() => _busyId = id);
    final res = await MissionsService.review(id, approve, reason: reason);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (res.success) {
      GacomSnackbar.show(context, approve ? 'Approved' : 'Done', isSuccess: true);
      _load(silent: true);
    } else {
      GacomSnackbar.show(context, res.message, isError: true);
    }
  }

  Future<void> _viewClip(String path) async {
    final url = await MissionsService.signedClipUrl(path);
    if (!mounted) return;
    if (url == null) {
      GacomSnackbar.show(context, 'Could not create a link for that clip', isError: true);
      return;
    }
    final ok = await _openUrl(url);
    if (!mounted) return;
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      GacomSnackbar.show(context, 'Could not open the clip. Its link was copied instead.');
    }
  }

  Future<void> _openLink(String url) async {
    final ok = await _openUrl(url);
    if (!mounted) return;
    if (!ok) GacomSnackbar.show(context, 'Could not open the link', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          children: _filters.map((f) {
            final sel = _filter == f[0];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (_filter == f[0]) return;
                  setState(() => _filter = f[0]);
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? MTac.gold.withOpacity(0.16) : MTac.panel,
                    border: Border.all(color: sel ? MTac.gold : MTac.keyline),
                  ),
                  child: Text(f[1], style: mHead(size: 13, color: sel ? MTac.gold : MTac.textDim, letterSpacing: 1)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: MTac.gold))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: mBody(size: 14)),
                    const SizedBox(height: 12),
                    MButton(label: 'TRY AGAIN', onTap: () => _load()),
                  ]))
                : RefreshIndicator(
                    onRefresh: () => _load(silent: true),
                    color: MTac.gold,
                    child: _rows.isEmpty
                        ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                            const SizedBox(height: 80),
                            Center(child: Text('Nothing here.', style: mBody(size: 14))),
                          ])
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                            itemCount: _rows.length,
                            itemBuilder: (_, k) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _row(_rows[k])),
                          ),
                  ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> r) {
    final display = r['display_name']?.toString() ?? '';
    final user = r['username']?.toString() ?? '';
    final name = display.isNotEmpty ? display : (user.isNotEmpty ? user : 'Player');
    final status = r['status']?.toString() ?? '';
    final proof = r['proof_url']?.toString();
    final path = r['storage_path']?.toString();
    final code = r['code']?.toString();
    final note = r['note']?.toString();
    final needsSpot = r['needs_spot_check'] == true;
    final spotDone = r['spot_checked_at'] != null;
    final auto = r['auto_approved'] == true;
    final busy = _busyId == r['id'].toString();
    final platform = r['platform']?.toString() ?? 'any';
    final canApprove = status != 'approved';
    final canConfirm = status == 'approved' && needsSpot && !spotDone;
    final canReject = status == 'pending';
    final canRemove = status == 'approved';

    final Color statusColor = status == 'approved' ? MTac.ok : (status == 'rejected' ? MTac.bad : MTac.warn);

    return MPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(user.isNotEmpty ? '$name  @$user' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mHead(size: 15))),
          MChip(label: status.toUpperCase(), color: statusColor),
        ]),
        const SizedBox(height: 4),
        Text('Day ${_i(r['day_number'])} - ${r['mission_title'] ?? ''}', style: mBody(size: 14, color: MTac.text, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          MChip(label: (r['type']?.toString() ?? '').toUpperCase().replaceAll('_', ' '), color: MTac.textDim),
          if (platform != 'any') MChip(label: platform.toUpperCase(), color: MTac.cyan),
          if (auto) const MChip(label: 'AUTO APPROVED', color: MTac.textDim),
          if (needsSpot && !spotDone) const MChip(label: 'SPOT CHECK', color: MTac.warn),
          if (needsSpot && spotDone) const MChip(label: 'CHECKED', color: MTac.ok),
        ]),
        const SizedBox(height: 8),
        if (proof != null && proof.isNotEmpty)
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openLink(proof),
                child: Text(proof, maxLines: 2, overflow: TextOverflow.ellipsis, style: mBody(size: 13, color: MTac.cyan, weight: FontWeight.w600)),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyText(context, proof),
              icon: const Icon(Icons.copy_rounded, size: 16, color: MTac.textMuted),
            ),
          ]),
        if (path != null && path.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: MButton(label: 'VIEW UPLOADED CLIP', icon: Icons.play_arrow_rounded, outlined: true, color: MTac.cyan, onTap: () => _viewClip(path)),
          ),
        if (code != null && code.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Text('SHARE CODE', style: mHead(size: 11, color: MTac.textMuted, letterSpacing: 1)),
            const SizedBox(width: 8),
            Text(code, style: mHead(size: 15, color: MTac.gold, letterSpacing: 2)),
          ]),
        ],
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Note: $note', style: mBody(size: 12)),
        ],
        if (status == 'rejected' && (r['reject_reason']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Reason: ${r['reject_reason']}', style: mBody(size: 12, color: MTac.bad)),
        ],
        const SizedBox(height: 4),
        Text('Submitted ${missionWhen(r['created_at'])}', style: mBody(size: 11, color: MTac.textMuted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (canApprove) MButton(label: 'APPROVE', color: MTac.ok, busy: busy, onTap: busy ? null : () => _review(r, true)),
          if (canConfirm) MButton(label: 'CONFIRM', color: MTac.ok, busy: busy, onTap: busy ? null : () => _review(r, true)),
          if (canReject) MButton(label: 'REJECT', color: MTac.bad, outlined: true, onTap: busy ? null : () => _review(r, false)),
          if (canRemove) MButton(label: 'REMOVE REWARD', color: MTac.bad, outlined: true, onTap: busy ? null : () => _review(r, false)),
        ]),
      ]),
    );
  }
}

// -------------------------------------------------------------- missions

const List<String> _types = ['in_app', 'social_link', 'clip', 'code_word'];
const Map<String, String> _typeNames = {
  'in_app': 'In-app (automatic)',
  'social_link': 'Social post (link)',
  'clip': 'Clip / screen recording',
  'code_word': 'Code word',
};
const List<String> _metrics = ['duels_played', 'duels_won', 'games_played', 'game_wins', 'streak_days', 'house_joined'];
const List<String> _platforms = ['any', 'x', 'instagram', 'tiktok', 'youtube', 'facebook'];
const List<String> _verifies = ['auto', 'auto_spotcheck', 'manual'];
const Map<String, String> _verifyNames = {
  'auto': 'Auto approve',
  'auto_spotcheck': 'Auto approve with spot checks',
  'manual': 'Manual review',
};

class _MissionsTab extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> trophies;
  const _MissionsTab({required this.items, required this.trophies});
  @override
  State<_MissionsTab> createState() => _MissionsTabState();
}

class _MissionsTabState extends State<_MissionsTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _season;
  List<Map<String, dynamic>> _missions = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final seasons = await MissionsService.seasons();
      Map<String, dynamic>? season;
      for (final s in seasons) {
        if (s['is_active'] == true) { season = s; break; }
      }
      season ??= seasons.isEmpty ? null : seasons.first;
      final missions = season == null ? <Map<String, dynamic>>[] : await MissionsService.missionsForSeason(season['id'].toString());
      if (!mounted) return;
      setState(() { _season = season; _missions = missions; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = MissionsService.friendlyError(e); });
    }
  }

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    final season = _season;
    if (season == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MTac.panel,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
      builder: (_) => _MissionSheet(season: season, existing: existing, items: widget.items, trophies: widget.trophies),
    );
    if (saved == true && mounted) {
      GacomSnackbar.show(context, 'Mission saved', isSuccess: true);
      _load(silent: true);
    }
  }

  Future<void> _toggle(Map<String, dynamic> m, bool v) async {
    final res = await MissionsService.saveMission({'is_active': v}, id: m['id'].toString());
    if (!mounted) return;
    if (!res.success) GacomSnackbar.show(context, res.message, isError: true);
    _load(silent: true);
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await _confirm(context, 'Delete mission?', 'This also deletes every submission for "${m['title']}". Deactivate it instead to keep the history.');
    if (!ok || !mounted) return;
    final res = await MissionsService.deleteMission(m['id'].toString());
    if (!mounted) return;
    if (res.success) {
      GacomSnackbar.show(context, 'Mission deleted', isSuccess: true);
    } else {
      GacomSnackbar.show(context, res.message, isError: true);
    }
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: MTac.gold));
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: mBody(size: 14)),
        const SizedBox(height: 12),
        MButton(label: 'TRY AGAIN', onTap: () => _load()),
      ]));
    }
    final season = _season;
    if (season == null) {
      return Center(child: Text('No season yet. Create one in the Season tab.', style: mBody(size: 14)));
    }
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final m in _missions) {
      byDay.putIfAbsent(_i(m['day_number']), () => <Map<String, dynamic>>[]).add(m);
    }
    final days = byDay.keys.toList()..sort();
    final byId = <String, Map<String, dynamic>>{for (final i in widget.items) i['id'].toString(): i};

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: MTac.gold,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Row(children: [
            Expanded(child: Text('${season['name']}', style: mHead(size: 18, color: MTac.gold))),
            if (season['is_active'] != true) const MChip(label: 'NOT ACTIVE', color: MTac.warn),
          ]),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: MButton(label: 'ADD MISSION', icon: Icons.add_rounded, onTap: () => _edit())),
          const SizedBox(height: 14),
          if (days.isEmpty) Text('No missions in this season yet.', style: mBody(size: 14)),
          ...days.expand((d) => <Widget>[
                _sectionLabel('DAY $d'),
                ...byDay[d]!.map((m) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _missionRow(m, byId))),
                const SizedBox(height: 6),
              ]),
        ],
      ),
    );
  }

  Widget _missionRow(Map<String, dynamic> m, Map<String, Map<String, dynamic>> byId) {
    final active = m['is_active'] != false;
    final item = byId[m['reward_item_id']?.toString()];
    final pts = _i(m['reward_house_points']);
    final bits = <String>[];
    if (pts > 0) bits.add('+$pts House points');
    if (item != null) bits.add('${item['name']}');
    if ((m['reward_trophy_key']?.toString() ?? '').isNotEmpty) bits.add('Trophy ${m['reward_trophy_key']}');
    return Opacity(
      opacity: active ? 1 : 0.55,
      child: MPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['title']}', style: mHead(size: 15)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                MChip(label: (m['type']?.toString() ?? '').toUpperCase().replaceAll('_', ' '), color: MTac.cyan),
                if (m['type'] == 'in_app') MChip(label: '${(m['metric'] ?? '').toString().replaceAll('_', ' ').toUpperCase()} x${_i(m['target'])}', color: MTac.textDim),
                if (m['max_winners'] != null) MChip(label: 'MAX ${_i(m['max_winners'])}', color: MTac.warn),
              ]),
              if (bits.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(bits.join('  /  '), style: mBody(size: 12, color: MTac.gold)),
              ],
            ]),
          ),
          Column(children: [
            Switch(value: active, activeColor: MTac.gold, onChanged: (v) => _toggle(m, v)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(visualDensity: VisualDensity.compact, onPressed: () => _edit(existing: m), icon: const Icon(Icons.edit_rounded, size: 18, color: MTac.cyan)),
              IconButton(visualDensity: VisualDensity.compact, onPressed: () => _delete(m), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: MTac.bad)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _MissionSheet extends StatefulWidget {
  final Map<String, dynamic> season;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> trophies;
  const _MissionSheet({required this.season, required this.existing, required this.items, required this.trophies});
  @override
  State<_MissionSheet> createState() => _MissionSheetState();
}

class _MissionSheetState extends State<_MissionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _instr;
  late final TextEditingController _example;
  late final TextEditingController _day;
  late final TextEditingController _target;
  late final TextEditingController _points;
  late final TextEditingController _winners;
  late final TextEditingController _sort;
  final _answer = TextEditingController();
  String _type = 'in_app';
  String _metric = 'games_played';
  String _platform = 'any';
  String _verify = 'auto_spotcheck';
  String? _itemId;
  String? _trophy;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _active = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    String s(String k) => e?[k]?.toString() ?? '';
    _title = TextEditingController(text: s('title'));
    _desc = TextEditingController(text: s('description'));
    _instr = TextEditingController(text: s('instructions'));
    _example = TextEditingController(text: s('example_url'));
    _day = TextEditingController(text: e == null ? '1' : '${_i(e['day_number'])}');
    _target = TextEditingController(text: e == null ? '1' : '${_i(e['target'])}');
    _points = TextEditingController(text: e == null ? '0' : '${_i(e['reward_house_points'])}');
    _winners = TextEditingController(text: e?['max_winners'] == null ? '' : '${_i(e!['max_winners'])}');
    _sort = TextEditingController(text: e == null ? '0' : '${_i(e['sort_order'])}');
    if (e != null) {
      _type = _types.contains(e['type']) ? e['type'].toString() : 'in_app';
      _metric = _metrics.contains(e['metric']) ? e['metric'].toString() : 'games_played';
      _platform = _platforms.contains(e['platform']) ? e['platform'].toString() : 'any';
      _verify = _verifies.contains(e['verify']) ? e['verify'].toString() : 'auto_spotcheck';
      _itemId = e['reward_item_id']?.toString();
      final tk = e['reward_trophy_key']?.toString();
      _trophy = (tk == null || tk.isEmpty) ? null : tk;
      _startsAt = DateTime.tryParse(e['starts_at']?.toString() ?? '')?.toLocal();
      _endsAt = DateTime.tryParse(e['ends_at']?.toString() ?? '')?.toLocal();
      _active = e['is_active'] != false;
      if (e['type'] == 'code_word') _loadSecret(e['id'].toString());
    }
  }

  Future<void> _loadSecret(String id) async {
    final a = await MissionsService.missionSecret(id);
    if (!mounted || a == null) return;
    if (_answer.text.isEmpty) _answer.text = a;
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _instr, _example, _day, _target, _points, _winners, _sort, _answer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final day = int.tryParse(_day.text.trim()) ?? 0;
    final target = int.tryParse(_target.text.trim()) ?? 0;
    final points = int.tryParse(_points.text.trim()) ?? 0;
    final winnersText = _winners.text.trim();
    final winners = winnersText.isEmpty ? null : int.tryParse(winnersText);
    if (title.isEmpty) { setState(() => _error = 'Add a title'); return; }
    if (day < 1) { setState(() => _error = 'Day number must be 1 or more'); return; }
    if (target < 1) { setState(() => _error = 'Target must be 1 or more'); return; }
    if (points < 0) { setState(() => _error = 'House points cannot be negative'); return; }
    if (winnersText.isNotEmpty && (winners == null || winners < 1)) { setState(() => _error = 'Max winners must be 1 or more, or empty for no limit'); return; }
    if (_type == 'code_word' && _answer.text.trim().isEmpty) { setState(() => _error = 'Add the code word answer'); return; }
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) { setState(() => _error = 'End time must be after the start time'); return; }

    String? nn(String v) => v.trim().isEmpty ? null : v.trim();
    final values = <String, dynamic>{
      'season_id': widget.season['id'].toString(),
      'day_number': day,
      'title': title,
      'description': nn(_desc.text),
      'instructions': nn(_instr.text),
      'example_url': nn(_example.text),
      'type': _type,
      'metric': _type == 'in_app' ? _metric : null,
      'target': target,
      'platform': (_type == 'social_link' || _type == 'clip') ? _platform : 'any',
      'verify': _verify,
      'reward_item_id': _itemId,
      'reward_house_points': points,
      'reward_trophy_key': _trophy,
      'max_winners': winners,
      'starts_at': _startsAt?.toUtc().toIso8601String(),
      'ends_at': _endsAt?.toUtc().toIso8601String(),
      'is_active': _active,
      'sort_order': int.tryParse(_sort.text.trim()) ?? 0,
    };
    setState(() { _busy = true; _error = null; });
    final res = await MissionsService.saveMission(values, id: widget.existing?['id']?.toString(), codeAnswer: _answer.text);
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() { _busy = false; _error = res.message; });
    }
  }

  Widget _gap() => const SizedBox(height: 10);

  Widget _dateRow(String label, DateTime? value, ValueChanged<DateTime?> onChanged) => Row(children: [
        Expanded(
          child: InputDecorator(
            decoration: mField(label),
            child: Text(value == null ? 'Not set' : missionWhen(value.toUtc().toIso8601String()), style: mBody(size: 14, color: value == null ? MTac.textMuted : MTac.text)),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () async {
            final d = await _pickDateTime(value);
            if (d != null) onChanged(d);
          },
          icon: const Icon(Icons.event_rounded, color: MTac.cyan),
        ),
        IconButton(onPressed: value == null ? null : () => onChanged(null), icon: const Icon(Icons.close_rounded, color: MTac.textMuted)),
      ]);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final trophyKeys = widget.trophies.map((t) => t['key'].toString()).toList();
    final trophyNames = <String, String>{for (final t in widget.trophies) t['key'].toString(): '${t['name']}'};
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing == null ? 'ADD MISSION' : 'EDIT MISSION', style: mHead(size: 20, color: MTac.gold)),
          const SizedBox(height: 12),
          TextField(controller: _title, style: kMInput, decoration: mField('Title')),
          _gap(),
          TextField(controller: _desc, style: kMInput, maxLines: 2, decoration: mField('Description')),
          _gap(),
          Row(children: [
            Expanded(child: TextField(controller: _day, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Day number'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _sort, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Sort order'))),
          ]),
          _gap(),
          _dropdown(label: 'Type', value: _type, values: _types, names: _typeNames, onChanged: (v) => setState(() => _type = v ?? _type)),
          _gap(),
          if (_type == 'in_app') ...[
            _dropdown(label: 'Metric', value: _metric, values: _metrics, names: {for (final m in _metrics) m: m.replaceAll('_', ' ')}, onChanged: (v) => setState(() => _metric = v ?? _metric)),
            _gap(),
          ],
          TextField(controller: _target, style: kMInput, keyboardType: TextInputType.number, decoration: mField(_type == 'in_app' ? 'Target (count to reach)' : 'Target (keep at 1)')),
          _gap(),
          if (_type == 'social_link' || _type == 'clip') ...[
            _dropdown(label: 'Platform', value: _platform, values: _platforms, onChanged: (v) => setState(() => _platform = v ?? _platform)),
            _gap(),
            TextField(controller: _instr, style: kMInput, maxLines: 3, decoration: mField('Instructions for the player')),
            _gap(),
            TextField(controller: _example, style: kMInput, keyboardType: TextInputType.url, decoration: mField('Example link')),
            _gap(),
            _dropdown(label: 'Verification', value: _verify, values: _verifies, names: _verifyNames, onChanged: (v) => setState(() => _verify = v ?? _verify)),
            _gap(),
          ],
          if (_type == 'code_word') ...[
            TextField(controller: _instr, style: kMInput, maxLines: 3, decoration: mField('Instructions for the player')),
            _gap(),
            TextField(controller: _answer, style: kMInput, decoration: mField('Code word answer (not case sensitive)')),
            _gap(),
          ],
          _sectionLabel('REWARD'),
          _ItemTile(label: 'Reward item', itemId: _itemId, items: widget.items, onChanged: (v) => setState(() => _itemId = v)),
          _gap(),
          Row(children: [
            Expanded(child: TextField(controller: _points, style: kMInput, keyboardType: TextInputType.number, decoration: mField('House points'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _winners, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Max winners', hint: 'No limit'))),
          ]),
          _gap(),
          DropdownButtonFormField<String?>(
            value: trophyKeys.contains(_trophy) ? _trophy : null,
            isExpanded: true,
            dropdownColor: MTac.panel,
            style: kMInput,
            decoration: mField('Trophy'),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('None', style: kMInput)),
              ...trophyKeys.map((k) => DropdownMenuItem<String?>(value: k, child: Text(trophyNames[k] ?? k, style: kMInput))),
            ],
            onChanged: (v) => setState(() => _trophy = v),
          ),
          _gap(),
          _sectionLabel('WINDOW (OPTIONAL, DEVICE TIME)'),
          _dateRow('Starts at', _startsAt, (d) => setState(() => _startsAt = d)),
          _dateRow('Ends at', _endsAt, (d) => setState(() => _endsAt = d)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            activeColor: MTac.gold,
            title: Text('Active', style: mBody(size: 15, color: MTac.text, weight: FontWeight.w700)),
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_error != null) ...[
            Text(_error!, style: mBody(size: 13, color: MTac.bad, weight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: MButton(label: 'CANCEL', outlined: true, color: MTac.textDim, onTap: _busy ? null : () => Navigator.pop(context, false))),
            const SizedBox(width: 10),
            Expanded(child: MButton(label: 'SAVE', busy: _busy, onTap: _save)),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- season

class _SeasonTab extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> trophies;
  const _SeasonTab({required this.items, required this.trophies});
  @override
  State<_SeasonTab> createState() => _SeasonTabState();
}

class _SeasonTabState extends State<_SeasonTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _seasons = [];
  List<Map<String, dynamic>> _rewards = [];
  String? _selectedId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final seasons = await MissionsService.seasons();
      var sel = _selectedId;
      if (sel == null || !seasons.any((s) => s['id'].toString() == sel)) {
        sel = null;
        for (final s in seasons) {
          if (s['is_active'] == true) { sel = s['id'].toString(); break; }
        }
        sel ??= seasons.isEmpty ? null : seasons.first['id'].toString();
      }
      final rewards = sel == null ? <Map<String, dynamic>>[] : await MissionsService.seasonRewards(sel);
      if (!mounted) return;
      setState(() { _seasons = seasons; _selectedId = sel; _rewards = rewards; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = MissionsService.friendlyError(e); });
    }
  }

  Future<void> _selectSeason(String id) async {
    setState(() => _selectedId = id);
    try {
      final rewards = await MissionsService.seasonRewards(id);
      if (!mounted) return;
      setState(() => _rewards = rewards);
    } catch (e) {
      if (!mounted) return;
      GacomSnackbar.show(context, MissionsService.friendlyError(e), isError: true);
    }
  }

  Future<void> _editSeason({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MTac.panel,
      builder: (_) => _SeasonSheet(existing: existing),
    );
    if (saved == true && mounted) {
      GacomSnackbar.show(context, 'Season saved', isSuccess: true);
      _load(silent: true);
    }
  }

  Future<void> _editReward({Map<String, dynamic>? existing}) async {
    final sel = _selectedId;
    if (sel == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MTac.panel,
      builder: (_) => _RewardSheet(seasonId: sel, existing: existing, items: widget.items, trophies: widget.trophies),
    );
    if (saved == true && mounted) {
      GacomSnackbar.show(context, 'Reward saved', isSuccess: true);
      _load(silent: true);
    }
  }

  Future<void> _deleteReward(Map<String, dynamic> r) async {
    final ok = await _confirm(context, 'Delete reward?', 'Remove the ${r['threshold']} mission reward "${r['label']}"? Players who already received it keep it.');
    if (!ok || !mounted) return;
    final res = await MissionsService.deleteSeasonReward(r['id'].toString());
    if (!mounted) return;
    if (!res.success) GacomSnackbar.show(context, res.message, isError: true);
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: MTac.gold));
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: mBody(size: 14)),
        const SizedBox(height: 12),
        MButton(label: 'TRY AGAIN', onTap: () => _load()),
      ]));
    }
    final byId = <String, Map<String, dynamic>>{for (final i in widget.items) i['id'].toString(): i};
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: MTac.gold,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _sectionLabel('SEASONS'),
          Align(alignment: Alignment.centerLeft, child: MButton(label: 'ADD SEASON', icon: Icons.add_rounded, onTap: () => _editSeason())),
          const SizedBox(height: 10),
          if (_seasons.isEmpty) Text('No seasons yet.', style: mBody(size: 14)),
          ..._seasons.map((s) {
            final id = s['id'].toString();
            final sel = id == _selectedId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _selectSeason(id),
                child: MPanel(
                  line: sel ? MTac.gold : MTac.keyline,
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['name']}', style: mHead(size: 16)),
                        const SizedBox(height: 2),
                        Text('Starts ${s['starts_on']}  /  ${_i(s['total_days'])} days', style: mBody(size: 12)),
                      ]),
                    ),
                    if (s['is_active'] == true) const MChip(label: 'ACTIVE', color: MTac.ok),
                    IconButton(onPressed: () => _editSeason(existing: s), icon: const Icon(Icons.edit_rounded, size: 18, color: MTac.cyan)),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          _sectionLabel('REWARD TRACK FOR THE SELECTED SEASON'),
          if (_selectedId == null)
            Text('Create a season first.', style: mBody(size: 14))
          else ...[
            Align(alignment: Alignment.centerLeft, child: MButton(label: 'ADD REWARD', icon: Icons.add_rounded, outlined: true, onTap: () => _editReward())),
            const SizedBox(height: 10),
            if (_rewards.isEmpty) Text('No reward milestones yet.', style: mBody(size: 14)),
            ..._rewards.map((r) {
              final item = byId[r['item_id']?.toString()];
              final trophy = r['trophy_key']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MPanel(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(children: [
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text('${_i(r['threshold'])}', style: mHead(size: 22, color: MTac.gold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['label']}', style: mHead(size: 15)),
                        if (item != null) MItemTag(name: '${item['name']}', rarity: item['rarity']?.toString()),
                        if (trophy.isNotEmpty) Text('Trophy: $trophy', style: mBody(size: 12)),
                      ]),
                    ),
                    IconButton(onPressed: () => _editReward(existing: r), icon: const Icon(Icons.edit_rounded, size: 18, color: MTac.cyan)),
                    IconButton(onPressed: () => _deleteReward(r), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: MTac.bad)),
                  ]),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SeasonSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _SeasonSheet({required this.existing});
  @override
  State<_SeasonSheet> createState() => _SeasonSheetState();
}

class _SeasonSheetState extends State<_SeasonSheet> {
  late final TextEditingController _name;
  late final TextEditingController _days;
  late DateTime _start;
  bool _active = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _days = TextEditingController(text: e == null ? '7' : '${_i(e['total_days'])}');
    _start = DateTime.tryParse(e?['starts_on']?.toString() ?? '') ?? DateTime.now();
    _active = e?['is_active'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || !mounted) return;
    setState(() => _start = d);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final days = int.tryParse(_days.text.trim()) ?? 0;
    if (name.isEmpty) { setState(() => _error = 'Add a season name'); return; }
    if (days < 1 || days > 60) { setState(() => _error = 'Total days must be between 1 and 60'); return; }
    setState(() { _busy = true; _error = null; });
    final id = widget.existing?['id']?.toString();
    final wasActive = widget.existing?['is_active'] == true;
    if (_active && !wasActive) {
      final d = await MissionsService.deactivateOtherSeasons(exceptId: id);
      if (!mounted) return;
      if (!d.success) {
        setState(() { _busy = false; _error = d.message; });
        return;
      }
    }
    final res = await MissionsService.saveSeason({
      'name': name,
      'starts_on': _fmtDate(_start),
      'total_days': days,
      'is_active': _active,
    }, id: id);
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() { _busy = false; _error = res.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing == null ? 'ADD SEASON' : 'EDIT SEASON', style: mHead(size: 20, color: MTac.gold)),
          const SizedBox(height: 12),
          TextField(controller: _name, style: kMInput, decoration: mField('Season name')),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickStart,
            child: InputDecorator(decoration: mField('Start date'), child: Text(_fmtDate(_start), style: kMInput)),
          ),
          const SizedBox(height: 10),
          TextField(controller: _days, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Total days (1 to 60)')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            activeColor: MTac.gold,
            title: Text('Active', style: mBody(size: 15, color: MTac.text, weight: FontWeight.w700)),
            subtitle: Text('Only one season can be active. Turning this on deactivates the current one.', style: mBody(size: 12)),
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_error != null) ...[
            Text(_error!, style: mBody(size: 13, color: MTac.bad, weight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: MButton(label: 'CANCEL', outlined: true, color: MTac.textDim, onTap: _busy ? null : () => Navigator.pop(context, false))),
            const SizedBox(width: 10),
            Expanded(child: MButton(label: 'SAVE', busy: _busy, onTap: _save)),
          ]),
        ]),
      ),
    );
  }
}

class _RewardSheet extends StatefulWidget {
  final String seasonId;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> trophies;
  const _RewardSheet({required this.seasonId, required this.existing, required this.items, required this.trophies});
  @override
  State<_RewardSheet> createState() => _RewardSheetState();
}

class _RewardSheetState extends State<_RewardSheet> {
  late final TextEditingController _threshold;
  late final TextEditingController _label;
  String? _itemId;
  String? _trophy;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _threshold = TextEditingController(text: e == null ? '' : '${_i(e['threshold'])}');
    _label = TextEditingController(text: e?['label']?.toString() ?? '');
    _itemId = e?['item_id']?.toString();
    final tk = e?['trophy_key']?.toString();
    _trophy = (tk == null || tk.isEmpty) ? null : tk;
  }

  @override
  void dispose() {
    _threshold.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final threshold = int.tryParse(_threshold.text.trim()) ?? 0;
    final label = _label.text.trim();
    if (threshold < 1) { setState(() => _error = 'Missions needed must be 1 or more'); return; }
    if (label.isEmpty) { setState(() => _error = 'Add a label'); return; }
    if (_itemId == null && _trophy == null) { setState(() => _error = 'Pick an item or a trophy'); return; }
    setState(() { _busy = true; _error = null; });
    final res = await MissionsService.saveSeasonReward({
      'season_id': widget.seasonId,
      'threshold': threshold,
      'label': label,
      'item_id': _itemId,
      'trophy_key': _trophy,
    }, id: widget.existing?['id']?.toString());
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() { _busy = false; _error = res.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final trophyKeys = widget.trophies.map((t) => t['key'].toString()).toList();
    final trophyNames = <String, String>{for (final t in widget.trophies) t['key'].toString(): '${t['name']}'};
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing == null ? 'ADD REWARD' : 'EDIT REWARD', style: mHead(size: 20, color: MTac.gold)),
          const SizedBox(height: 12),
          TextField(controller: _threshold, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Missions needed')),
          const SizedBox(height: 10),
          TextField(controller: _label, style: kMInput, decoration: mField('Label')),
          const SizedBox(height: 10),
          _ItemTile(label: 'Reward item', itemId: _itemId, items: widget.items, onChanged: (v) => setState(() => _itemId = v)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: trophyKeys.contains(_trophy) ? _trophy : null,
            isExpanded: true,
            dropdownColor: MTac.panel,
            style: kMInput,
            decoration: mField('Trophy'),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('None', style: kMInput)),
              ...trophyKeys.map((k) => DropdownMenuItem<String?>(value: k, child: Text(trophyNames[k] ?? k, style: kMInput))),
            ],
            onChanged: (v) => setState(() => _trophy = v),
          ),
          const SizedBox(height: 10),
          if (_error != null) ...[
            Text(_error!, style: mBody(size: 13, color: MTac.bad, weight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: MButton(label: 'CANCEL', outlined: true, color: MTac.textDim, onTap: _busy ? null : () => Navigator.pop(context, false))),
            const SizedBox(width: 10),
            Expanded(child: MButton(label: 'SAVE', busy: _busy, onTap: _save)),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- grants

class _GrantsTab extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> trophies;
  const _GrantsTab({required this.items, required this.trophies});
  @override
  State<_GrantsTab> createState() => _GrantsTabState();
}

class _GrantsTabState extends State<_GrantsTab> with AutomaticKeepAliveClientMixin {
  final _player = TextEditingController();
  final _note = TextEditingController();
  final _points = TextEditingController();
  final _reason = TextEditingController();
  String? _itemId;
  String? _trophy;
  String? _houseId;
  List<HouseSummary> _houses = [];
  String? _busyKey;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  @override
  void dispose() {
    _player.dispose();
    _note.dispose();
    _points.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadHouses() async {
    try {
      final h = await HouseService.leaderboard();
      if (!mounted) return;
      setState(() => _houses = h);
    } catch (_) {
      if (mounted) GacomSnackbar.show(context, 'Could not load houses', isError: true);
    }
  }

  Future<String?> _resolvePlayer() async {
    final p = await MissionsService.findProfile(_player.text);
    if (!mounted) return null;
    if (p == null) {
      GacomSnackbar.show(context, 'No player found with that username or id', isError: true);
      return null;
    }
    return p['id'].toString();
  }

  Future<void> _grantItem() async {
    final item = _itemId;
    if (item == null) {
      GacomSnackbar.show(context, 'Pick an item first', isError: true);
      return;
    }
    setState(() => _busyKey = 'item');
    final uid = await _resolvePlayer();
    if (uid == null) {
      if (mounted) setState(() => _busyKey = null);
      return;
    }
    final res = await MissionsService.grantItem(uid, item, note: _note.text);
    if (!mounted) return;
    setState(() => _busyKey = null);
    GacomSnackbar.show(context, res.success ? 'Item granted' : res.message, isSuccess: res.success, isError: !res.success);
  }

  Future<void> _grantTrophy() async {
    final key = _trophy;
    if (key == null) {
      GacomSnackbar.show(context, 'Pick a trophy first', isError: true);
      return;
    }
    setState(() => _busyKey = 'trophy');
    final uid = await _resolvePlayer();
    if (uid == null) {
      if (mounted) setState(() => _busyKey = null);
      return;
    }
    final res = await MissionsService.grantTrophy(uid, key);
    if (!mounted) return;
    setState(() => _busyKey = null);
    GacomSnackbar.show(context, res.success ? 'Trophy granted' : res.message, isSuccess: res.success, isError: !res.success);
  }

  Future<void> _grantPoints() async {
    final house = _houseId;
    final pts = int.tryParse(_points.text.trim());
    if (house == null) {
      GacomSnackbar.show(context, 'Pick a house first', isError: true);
      return;
    }
    if (pts == null || pts == 0) {
      GacomSnackbar.show(context, 'Enter the number of points', isError: true);
      return;
    }
    setState(() => _busyKey = 'points');
    final res = await MissionsService.grantHousePoints(house, pts, reason: _reason.text);
    if (!mounted) return;
    setState(() => _busyKey = null);
    GacomSnackbar.show(context, res.success ? 'House points granted' : res.message, isSuccess: res.success, isError: !res.success);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final trophyKeys = widget.trophies.map((t) => t['key'].toString()).toList();
    final trophyNames = <String, String>{for (final t in widget.trophies) t['key'].toString(): '${t['name']}'};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        MPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('PLAYER'),
            TextField(controller: _player, style: kMInput, autocorrect: false, decoration: mField('Username or user id', hint: '@username')),
            const SizedBox(height: 14),
            _sectionLabel('GRANT AN ITEM'),
            _ItemTile(label: 'Item', itemId: _itemId, items: widget.items, onChanged: (v) => setState(() => _itemId = v)),
            const SizedBox(height: 10),
            TextField(controller: _note, style: kMInput, decoration: mField('Note shown to the player (optional)')),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: MButton(label: 'GRANT ITEM', busy: _busyKey == 'item', onTap: _busyKey != null ? null : _grantItem)),
            const SizedBox(height: 18),
            _sectionLabel('GRANT A TROPHY'),
            _dropdown(label: 'Trophy', value: _trophy, values: trophyKeys, names: trophyNames, onChanged: (v) => setState(() => _trophy = v)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: MButton(label: 'GRANT TROPHY', busy: _busyKey == 'trophy', onTap: _busyKey != null ? null : _grantTrophy)),
          ]),
        ),
        const SizedBox(height: 14),
        MPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('GRANT HOUSE POINTS'),
            _dropdown(
              label: 'House',
              value: _houseId,
              values: _houses.map((h) => h.id).toList(),
              names: {for (final h in _houses) h.id: h.name},
              onChanged: (v) => setState(() => _houseId = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: _points, style: kMInput, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: mField('Points')),
            const SizedBox(height: 10),
            TextField(controller: _reason, style: kMInput, decoration: mField('Reason (optional)')),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: MButton(label: 'GRANT POINTS', busy: _busyKey == 'points', onTap: _busyKey != null ? null : _grantPoints)),
          ]),
        ),
      ],
    );
  }
}
