import 'package:flutter/material.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../missions/missions_service.dart';
import '../../missions/widgets/mission_style.dart';

/// Ask Ryan to write a batch of social missions. They arrive as drafts.
class RyanMissionsSheet extends StatefulWidget {
  final String seasonId;
  const RyanMissionsSheet({super.key, required this.seasonId});
  @override
  State<RyanMissionsSheet> createState() => _RyanMissionsSheetState();
}

class _RyanMissionsSheetState extends State<RyanMissionsSheet> {
  final _days = TextEditingController(text: '3');
  final _perDay = TextEditingController(text: '2');
  final _start = TextEditingController(text: '1');
  final _focus = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _days.dispose();
    _perDay.dispose();
    _start.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final per = int.tryParse(_perDay.text.trim()) ?? 0;
    final start = int.tryParse(_start.text.trim()) ?? 0;
    if (days < 1 || days > 14) { setState(() => _error = 'Days must be between 1 and 14'); return; }
    if (per < 1 || per > 4) { setState(() => _error = 'Missions per day must be between 1 and 4'); return; }
    if (start < 1) { setState(() => _error = 'Start day must be 1 or more'); return; }
    setState(() { _busy = true; _error = null; });
    final res = await MissionsService.askRyan(seasonId: widget.seasonId, days: days, perDay: per, startDay: start, focus: _focus.text.trim());
    if (!mounted) return;
    if (res.success) {
      GacomSnackbar.show(context, 'Ryan wrote ${res.status ?? ''} missions. They are drafts: review them, then switch them on.', isSuccess: true);
      Navigator.pop(context, true);
    } else {
      setState(() { _busy = false; _error = res.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RYAN: WRITE MISSIONS', style: mHead(size: 18, color: MTac.gold)),
          const SizedBox(height: 6),
          Text('Ryan reads your brand accounts and the missions already in this season, then writes new follow, post and gameplay missions. They are saved switched off so you can read them first.', style: mBody(size: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: TextField(controller: _start, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Start on day'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _days, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Number of days'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _perDay, style: kMInput, keyboardType: TextInputType.number, decoration: mField('Per day'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _focus, style: kMInput, maxLines: 2, decoration: mField('Anything to focus on? (optional)', hint: 'e.g. more screen recordings of Maths games')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: mBody(size: 13, color: MTac.warn)),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: MButton(label: 'WRITE THEM', icon: Icons.auto_awesome_rounded, busy: _busy, onTap: _go)),
        ]),
      ),
    );
  }
}

/// Edit the GACOM accounts (X, Instagram, TikTok...) that missions point players to.
class BrandAccountsSheet extends StatefulWidget {
  const BrandAccountsSheet({super.key});
  @override
  State<BrandAccountsSheet> createState() => _BrandAccountsSheetState();
}

class _BrandAccountsSheetState extends State<BrandAccountsSheet> {
  static const _platforms = ['x', 'instagram', 'tiktok', 'youtube', 'facebook'];
  final Map<String, TextEditingController> _handle = {};
  final Map<String, TextEditingController> _url = {};
  final Map<String, TextEditingController> _tags = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final p in _platforms) {
      _handle[p] = TextEditingController();
      _url[p] = TextEditingController();
      _tags[p] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._handle.values, ..._url.values, ..._tags.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await MissionsService.brandSocials();
    for (final r in rows) {
      final p = '${r['platform']}';
      if (!_platforms.contains(p)) continue;
      _handle[p]!.text = '${r['handle'] ?? ''}';
      _url[p]!.text = '${r['url'] ?? ''}';
      _tags[p]!.text = '${r['hashtags'] ?? ''}';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() { _busy = true; _error = null; });
    var order = 0;
    for (final p in _platforms) {
      order++;
      final h = _handle[p]!.text.trim();
      final u = _url[p]!.text.trim();
      if (h.isEmpty && u.isEmpty) {
        await MissionsService.deleteBrandSocial(p);
        continue;
      }
      if (h.isEmpty || !u.startsWith('https://')) {
        setState(() { _busy = false; _error = 'For ${p.toUpperCase()}, add the username and a link starting with https://'; });
        return;
      }
      final r = await MissionsService.saveBrandSocial(p, h, u, _tags[p]!.text, order);
      if (!r.success) {
        if (mounted) setState(() { _busy = false; _error = r.message; });
        return;
      }
    }
    if (!mounted) return;
    GacomSnackbar.show(context, 'Brand accounts saved', isSuccess: true);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: _loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: MTac.gold)))
          : SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GACOM ACCOUNTS', style: mHead(size: 18, color: MTac.gold)),
                const SizedBox(height: 6),
                Text('Players are sent to these accounts to follow and tag. Leave a platform empty to remove it.', style: mBody(size: 13)),
                for (final p in _platforms) ...[
                  const SizedBox(height: 14),
                  Text(p.toUpperCase(), style: mHead(size: 13)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(controller: _handle[p], style: kMInput, decoration: mField('Username (no @)'))),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: TextField(controller: _url[p], style: kMInput, keyboardType: TextInputType.url, decoration: mField('Profile link'))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: _tags[p], style: kMInput, decoration: mField('Hashtags players should use (optional)')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: mBody(size: 13, color: MTac.warn)),
                ],
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: MButton(label: 'SAVE', busy: _busy, onTap: _save)),
              ]),
            ),
    );
  }
}
