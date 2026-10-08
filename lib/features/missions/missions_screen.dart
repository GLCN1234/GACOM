import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/gacom_snackbar.dart';
import 'missions_service.dart';
import 'widgets/mission_style.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

String _humanize(String s) {
  final t = s.replaceAll('_', ' ').trim();
  if (t.isEmpty) return t;
  return t.substring(0, 1).toUpperCase() + t.substring(1);
}

/// Widgets for "+50 House points and Banner: Agon Day 4".
Widget missionRewardRow(Map<String, dynamic> m) {
  final pts = _i(m['reward_house_points']);
  final item = _map(m['reward_item']);
  final trophy = m['reward_trophy_key']?.toString();
  final parts = <Widget>[];
  if (pts > 0) parts.add(Text('+$pts House points', style: mBody(size: 13, color: MTac.gold, weight: FontWeight.w700)));
  if (item != null) {
    parts.add(MItemTag(
      name: '${missionCategoryLabel(item['category']?.toString())}: ${item['name'] ?? ''}',
      rarity: item['rarity']?.toString(),
    ));
  }
  if (trophy != null && trophy.isNotEmpty) {
    parts.add(Text('Trophy: ${_humanize(trophy)}', style: mBody(size: 13, color: MTac.text, weight: FontWeight.w700)));
  }
  if (parts.isEmpty) return const SizedBox.shrink();
  final children = <Widget>[Text('REWARD', style: mHead(size: 11, color: MTac.textMuted, letterSpacing: 1))];
  for (var k = 0; k < parts.length; k++) {
    if (k > 0) children.add(Text('and', style: mBody(color: MTac.textMuted)));
    children.add(parts[k]);
  }
  return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: children);
}

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});
  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  int _day = 1;
  bool _dayChosen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final res = await MissionsService.myMissions();
    if (!mounted) return;
    final err = res['error']?.toString();
    if (err != null && _data != null) {
      setState(() => _loading = false);
      GacomSnackbar.show(context, err, isError: true);
      return;
    }
    setState(() {
      _loading = false;
      if (err != null) {
        _error = err;
        return;
      }
      _data = res;
      _error = null;
      final season = _map(res['season']);
      if (season != null && !_dayChosen) {
        final total = _i(season['total_days']);
        final today = _i(season['today_day']);
        _day = today < 1 ? 1 : (today > total ? (total < 1 ? 1 : total) : today);
      }
    });
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    GacomSnackbar.show(context, 'Code copied', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MTac.ground,
      appBar: AppBar(title: const Text('MISSIONS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MTac.gold))
          : _error != null
              ? _message(_error!, retry: true)
              : RefreshIndicator(onRefresh: () => _load(silent: true), color: MTac.gold, child: _content()),
    );
  }

  Widget _message(String text, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: mBody(size: 15)),
            if (retry) ...[
              const SizedBox(height: 16),
              MButton(label: 'TRY AGAIN', onTap: () => _load()),
            ],
          ]),
        ),
      );

  Widget _content() {
    final data = _data ?? <String, dynamic>{};
    final season = _map(data['season']);
    if (season == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text('No missions are running right now.\nCheck back soon.', textAlign: TextAlign.center, style: mBody(size: 15))),
        ],
      );
    }
    final total = _i(season['total_days']) < 1 ? 1 : _i(season['total_days']);
    final today = _i(season['today_day']);
    final missions = _list(data['missions']);
    final approved = _i(data['approved_count']);
    final code = data['code']?.toString();
    final dayMissions = missions.where((m) => _i(m['day_number']) == _day).toList();
    final track = _list(data['track']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _header(season['name']?.toString() ?? 'Missions', today, total, approved, missions.length),
        const SizedBox(height: 12),
        if (code != null && code.isNotEmpty) ...[_codePanel(code), const SizedBox(height: 12)],
        _dayStrip(total, today),
        const SizedBox(height: 14),
        Text('DAY $_day MISSIONS', style: mHead(size: 15, color: MTac.cyan, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        if (dayMissions.isEmpty)
          MPanel(child: Text('No missions on this day.', style: mBody(size: 14)))
        else
          ...dayMissions.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionCard(
                  key: ValueKey(m['id']?.toString() ?? ''),
                  mission: m,
                  code: code,
                  onCopy: _copy,
                  onChanged: () => _load(silent: true),
                ),
              )),
        const SizedBox(height: 14),
        _trackPanel(track, approved, missions.length),
      ],
    );
  }

  Widget _header(String name, int today, int total, int approved, int count) {
    String dayText;
    if (today < 1) {
      final n = 1 - today;
      dayText = 'Starts in $n ${n == 1 ? 'day' : 'days'}';
    } else if (today > total) {
      dayText = 'Season finished';
    } else {
      dayText = 'Day $today of $total';
    }
    return MPanel(
      cut: 16,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.toUpperCase(), style: mHead(size: 22, color: MTac.gold, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(dayText, style: mHead(size: 15, color: MTac.text)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$approved of $count', style: mHead(size: 22, color: MTac.cyan)),
          Text('missions done', style: mBody(size: 12, color: MTac.textMuted)),
        ]),
      ]),
    );
  }

  Widget _codePanel(String code) => MPanel(
        fill: MTac.panelAlt,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR SHARE CODE', style: mHead(size: 11, color: MTac.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(code, style: mHead(size: 26, color: MTac.cyan, letterSpacing: 3))),
            MButton(label: 'COPY', icon: Icons.copy_rounded, outlined: true, color: MTac.cyan, onTap: () => _copy(code)),
          ]),
          const SizedBox(height: 6),
          Text('Include your code in the post. We spot check posts and can remove rewards.', style: mBody(size: 12)),
        ]),
      );

  Widget _dayStrip(int total, int today) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, k) {
          final day = k + 1;
          final selected = day == _day;
          final isToday = day == today;
          final locked = day > today;
          final border = selected ? MTac.gold : (isToday ? MTac.cyan : MTac.keyline);
          return GestureDetector(
            onTap: () => setState(() { _day = day; _dayChosen = true; }),
            child: Opacity(
              opacity: locked && !selected ? 0.45 : 1,
              child: SizedBox(
                width: 54,
                child: MPanel(
                  cut: 8,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  fill: selected ? MTac.gold.withOpacity(0.14) : MTac.panel,
                  line: border,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('D$day', style: mHead(size: 17, color: selected ? MTac.gold : MTac.text)),
                    const SizedBox(height: 2),
                    if (isToday)
                      Text('TODAY', style: mHead(size: 9, color: MTac.cyan, letterSpacing: 0.8))
                    else if (locked)
                      const Icon(Icons.lock_rounded, size: 11, color: MTac.textMuted)
                    else
                      const Icon(Icons.check_rounded, size: 11, color: MTac.textMuted),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _trackPanel(List<Map<String, dynamic>> track, int approved, int count) {
    if (track.isEmpty) return const SizedBox.shrink();
    final value = count <= 0 ? 0.0 : (approved / count).clamp(0.0, 1.0).toDouble();
    final nodes = <Widget>[];
    for (var k = 0; k < track.length; k++) {
      if (k > 0) {
        nodes.add(Padding(
          padding: const EdgeInsets.only(top: 15),
          child: Container(width: 22, height: 2, color: _toBool(track[k]['reached']) ? MTac.gold : MTac.keyline),
        ));
      }
      nodes.add(_trackNode(track[k]));
    }
    return MPanel(
      cut: 14,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('SEASON REWARDS', style: mHead(size: 15, color: MTac.gold, letterSpacing: 1.2)),
          const Spacer(),
          Text('$approved of $count missions', style: mBody(size: 13, color: MTac.text, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: MTac.panelAlt, valueColor: const AlwaysStoppedAnimation<Color>(MTac.gold)),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: nodes),
        ),
      ]),
    );
  }

  bool _toBool(dynamic v) => v == true;

  Widget _trackNode(Map<String, dynamic> t) {
    final reached = _toBool(t['reached']);
    final item = _map(t['item']);
    final trophy = t['trophy_key']?.toString();
    final color = reached ? MTac.gold : MTac.textMuted;
    return SizedBox(
      width: 112,
      child: Column(children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? MTac.gold : MTac.panelAlt,
            border: Border.all(color: color, width: 2),
          ),
          child: reached
              ? const Icon(Icons.check_rounded, size: 18, color: MTac.ground)
              : Text('${_i(t['threshold'])}', style: mHead(size: 14, color: MTac.textDim)),
        ),
        const SizedBox(height: 6),
        Text('${_i(t['threshold'])} missions', style: mHead(size: 12, color: reached ? MTac.gold : MTac.textDim)),
        const SizedBox(height: 2),
        Text(t['label']?.toString() ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: mBody(size: 12, color: MTac.text)),
        const SizedBox(height: 4),
        if (item != null)
          MItemTag(name: item['name']?.toString() ?? '', rarity: item['rarity']?.toString(), textColor: reached ? MTac.text : MTac.textDim)
        else if (trophy != null && trophy.isNotEmpty)
          Text('Trophy: ${_humanize(trophy)}', textAlign: TextAlign.center, style: mBody(size: 12, color: MTac.textDim)),
      ]),
    );
  }
}

class _MissionCard extends StatefulWidget {
  final Map<String, dynamic> mission;
  final String? code;
  final Future<void> Function(String code) onCopy;
  final VoidCallback onChanged;
  const _MissionCard({super.key, required this.mission, required this.code, required this.onCopy, required this.onChanged});
  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  final _proof = TextEditingController();
  bool _busy = false;
  Uint8List? _clipBytes;
  String? _clipName;

  @override
  void dispose() {
    _proof.dispose();
    super.dispose();
  }

  Map<String, dynamic> get m => widget.mission;
  String get _id => m['id']?.toString() ?? '';
  String get _type => m['type']?.toString() ?? 'in_app';
  String get _state => m['state']?.toString() ?? 'open';
  String? get _status => m['status']?.toString();

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) GacomSnackbar.show(context, 'Could not open the link', isError: true);
    }
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    final res = await MissionsService.claim(_id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      GacomSnackbar.show(context, 'Mission complete. Reward added.', isSuccess: true);
      widget.onChanged();
    } else {
      GacomSnackbar.show(context, res.message, isError: true);
      widget.onChanged();
    }
  }

  Future<void> _pickClip() async {
    try {
      final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      if (bytes.length > MissionsService.maxClipBytes) {
        GacomSnackbar.show(context, 'That clip is too large. The limit is 50 MB.', isError: true);
        return;
      }
      setState(() { _clipBytes = bytes; _clipName = f.name; });
    } catch (_) {
      if (mounted) GacomSnackbar.show(context, 'Could not open that file', isError: true);
    }
  }

  Future<void> _submit() async {
    var proof = _proof.text.trim();
    final clip = _clipBytes;
    if (_type == 'clip' && clip != null) {
      setState(() => _busy = true);
      String? err;
      final path = await MissionsService.uploadClip(clip, _clipName ?? 'clip.mp4', (e) { err = e; });
      if (!mounted) return;
      if (path == null) {
        setState(() => _busy = false);
        GacomSnackbar.show(context, err ?? 'Upload failed', isError: true);
        return;
      }
      proof = path;
    }
    if (proof.isEmpty) {
      GacomSnackbar.show(context, _type == 'code_word' ? 'Enter the code word first' : 'Add your proof first', isError: true);
      return;
    }
    setState(() => _busy = true);
    final res = await MissionsService.submit(_id, proof);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _proof.clear();
      setState(() { _clipBytes = null; _clipName = null; });
      GacomSnackbar.show(
        context,
        res.status == 'approved' ? 'Mission complete. Reward added.' : 'Submitted. We will review it soon.',
        isSuccess: true,
      );
      widget.onChanged();
    } else {
      GacomSnackbar.show(context, res.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final state = _state;
    final title = m['title']?.toString() ?? '';
    final description = m['description']?.toString() ?? '';
    final winnersLeft = m['winners_left'] == null ? null : _i(m['winners_left']);
    final dim = state == 'locked' || (state == 'closed' && status != 'approved');

    Color borderColor = MTac.keyline;
    if (status == 'approved') borderColor = MTac.ok.withOpacity(0.7);
    if (status == 'rejected') borderColor = MTac.bad.withOpacity(0.7);

    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: MPanel(
        line: borderColor,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_kindLabel(), style: mHead(size: 10, color: MTac.textMuted, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(title, style: mHead(size: 17)),
              ]),
            ),
            const SizedBox(width: 8),
            _statusChip(status, state),
          ]),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: mBody(size: 13)),
          ],
          const SizedBox(height: 8),
          missionRewardRow(m),
          if (winnersLeft != null) ...[
            const SizedBox(height: 6),
            Text(
              winnersLeft == 0 ? 'All rewards for this mission are claimed' : '$winnersLeft ${winnersLeft == 1 ? 'reward' : 'rewards'} left',
              style: mBody(size: 12, color: winnersLeft == 0 ? MTac.bad : MTac.warn, weight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 10),
          ..._body(status, state, winnersLeft),
        ]),
      ),
    );
  }

  String _kindLabel() {
    switch (_type) {
      case 'social_link':
        return 'SOCIAL POST / REVIEW';
      case 'clip':
        return 'CLIP / SCREEN RECORDING';
      case 'code_word':
        return 'CODE WORD';
      default:
        return 'IN-APP / AUTOMATIC';
    }
  }

  Widget _statusChip(String? status, String state) {
    if (status == 'approved') return const MChip(label: 'APPROVED', color: MTac.ok, icon: Icons.check_rounded);
    if (status == 'pending') return const MChip(label: 'PENDING', color: MTac.warn, icon: Icons.hourglass_top_rounded);
    if (status == 'rejected') return const MChip(label: 'REJECTED', color: MTac.bad, icon: Icons.close_rounded);
    if (state == 'locked') return const MChip(label: 'LOCKED', color: MTac.textMuted, icon: Icons.lock_rounded);
    if (state == 'closed') return const MChip(label: 'CLOSED', color: MTac.textMuted);
    return const MChip(label: 'IN PROGRESS', color: MTac.cyan);
  }

  List<Widget> _body(String? status, String state, int? winnersLeft) {
    final out = <Widget>[];
    if (status == 'approved') {
      out.add(Text('Reward added to your account.', style: mBody(size: 13, color: MTac.ok, weight: FontWeight.w700)));
      return out;
    }
    if (status == 'pending') {
      out.add(Text('Waiting for review. You will be notified.', style: mBody(size: 13, color: MTac.warn, weight: FontWeight.w700)));
      final proof = m['proof_url']?.toString();
      if (proof != null && proof.isNotEmpty) out.add(_linkText(proof));
      return out;
    }
    if (status == 'rejected') {
      final reason = m['reject_reason']?.toString() ?? '';
      out.add(Text(reason.isEmpty ? 'This submission was not approved.' : 'Not approved: $reason', style: mBody(size: 13, color: MTac.bad, weight: FontWeight.w700)));
      out.add(const SizedBox(height: 10));
    }
    if (state == 'locked') {
      final when = missionWhen(m['opens_at']);
      out.add(Text(when.isEmpty ? 'This mission has not opened yet.' : 'Opens $when', style: mBody(size: 13, color: MTac.textMuted)));
      return out;
    }
    if (state == 'closed') {
      out.add(Text('This mission has closed.', style: mBody(size: 13, color: MTac.textMuted)));
      return out;
    }
    if (winnersLeft != null && winnersLeft == 0) {
      out.add(Text('Rewards for this mission are fully claimed.', style: mBody(size: 13, color: MTac.textMuted)));
      return out;
    }
    switch (_type) {
      case 'in_app':
        out.addAll(_inApp());
        break;
      case 'code_word':
        out.addAll(_codeWord(status == 'rejected'));
        break;
      case 'clip':
        out.addAll(_proofForm(status == 'rejected', clip: true));
        break;
      default:
        out.addAll(_proofForm(status == 'rejected', clip: false));
    }
    return out;
  }

  Widget _linkText(String url) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: () => _open(url),
          child: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: mBody(size: 12, color: MTac.cyan, weight: FontWeight.w600)),
        ),
      );

  List<Widget> _inApp() {
    final target = _i(m['target']) < 1 ? 1 : _i(m['target']);
    final progress = _i(m['progress']);
    final done = progress >= target;
    return [
      Row(children: [
        Text('PROGRESS', style: mHead(size: 11, color: MTac.textMuted, letterSpacing: 1)),
        const Spacer(),
        Text('${progress > target ? target : progress} / $target', style: mHead(size: 14, color: done ? MTac.ok : MTac.text)),
      ]),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: (progress / target).clamp(0.0, 1.0).toDouble(),
        minHeight: 6,
        backgroundColor: MTac.panelAlt,
        valueColor: AlwaysStoppedAnimation<Color>(done ? MTac.ok : MTac.cyan),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: MButton(label: 'CLAIM', busy: _busy, onTap: done ? _claim : null),
      ),
    ];
  }

  List<Widget> _codeWord(bool resubmit) => [
        TextField(
          controller: _proof,
          style: kMInput,
          textInputAction: TextInputAction.done,
          decoration: mField('Code word', hint: 'Enter the code word'),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: MButton(label: resubmit ? 'RESUBMIT' : 'SUBMIT', busy: _busy, onTap: _submit)),
      ];

  List<Widget> _proofForm(bool resubmit, {required bool clip}) {
    final instructions = m['instructions']?.toString() ?? '';
    final example = m['example_url']?.toString() ?? '';
    final platform = m['platform']?.toString() ?? 'any';
    final code = widget.code;
    return [
      if (instructions.isNotEmpty) ...[
        Text(instructions, style: mBody(size: 13, color: MTac.text)),
        const SizedBox(height: 8),
      ],
      if (platform != 'any') ...[
        MChip(label: platform.toUpperCase(), color: MTac.cyan),
        const SizedBox(height: 8),
      ],
      if (example.isNotEmpty) ...[
        Row(children: [
          Text('EXAMPLE', style: mHead(size: 11, color: MTac.textMuted, letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(child: _linkText(example)),
        ]),
        const SizedBox(height: 8),
      ],
      if (code != null && code.isNotEmpty) ...[
        Row(children: [
          Text('CODE', style: mHead(size: 11, color: MTac.textMuted, letterSpacing: 1)),
          const SizedBox(width: 8),
          Text(code, style: mHead(size: 16, color: MTac.cyan, letterSpacing: 2)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => widget.onCopy(code),
            child: Text('COPY', style: mHead(size: 12, color: MTac.gold, letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Include your code in the post. We spot check posts and can remove rewards.', style: mBody(size: 12)),
        const SizedBox(height: 10),
      ],
      TextField(
        controller: _proof,
        style: kMInput,
        keyboardType: TextInputType.url,
        enabled: _clipBytes == null,
        decoration: mField('Paste link', hint: clip ? 'Paste the link to your clip' : 'Paste the link to your post'),
      ),
      if (clip) ...[
        const SizedBox(height: 8),
        if (_clipBytes == null)
          Align(
            alignment: Alignment.centerLeft,
            child: MButton(label: 'UPLOAD VIDEO', icon: Icons.upload_rounded, outlined: true, color: MTac.cyan, onTap: _busy ? null : _pickClip),
          )
        else
          Row(children: [
            const Icon(Icons.videocam_rounded, size: 16, color: MTac.cyan),
            const SizedBox(width: 6),
            Expanded(child: Text(_clipName ?? 'clip', maxLines: 1, overflow: TextOverflow.ellipsis, style: mBody(size: 13, color: MTac.text))),
            IconButton(
              onPressed: _busy ? null : () => setState(() { _clipBytes = null; _clipName = null; }),
              icon: const Icon(Icons.close_rounded, size: 18, color: MTac.textMuted),
            ),
          ]),
        const SizedBox(height: 2),
        Text('Uploaded clips are always reviewed by a person.', style: mBody(size: 12, color: MTac.textMuted)),
      ],
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight, child: MButton(label: resubmit ? 'RESUBMIT' : 'SUBMIT', busy: _busy, onTap: _submit)),
    ];
  }
}
