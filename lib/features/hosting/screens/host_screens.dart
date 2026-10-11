import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/hosting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pick_upload.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

String _naira(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₦$b';
}

String _dt(dynamic v) {
  final t = DateTime.tryParse('$v')?.toLocal();
  if (t == null) return '-';
  return '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Opens the right screen for the "create competition" button: the host form
/// for verified members, the subscription sheet for everyone else.
Future<void> openHostEntry(BuildContext context) async {
  final st = await HostingService.verificationState();
  if (!context.mounted) return;
  if (st['host'] == true) {
    context.push('/host/new');
  } else {
    await showVerificationSheet(context, st);
  }
}

/// Opens the verification levels screen. Returns true when the member subscribed during the visit.
Future<bool> showVerificationSheet(BuildContext context, [Map<String, dynamic>? state]) async {
  final r = await context.push<bool>('/verification');
  return r == true;
}

// =============================================================== dashboard

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});
  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic> _st = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Future.wait([HostingService.mine(), HostingService.verificationState()]);
    if (!mounted) return;
    setState(() {
      _list = r[0] as List<Map<String, dynamic>>;
      _st = r[1] as Map<String, dynamic>;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (_st['host'] != true) {
      await showVerificationSheet(context, _st);
      _load();
      return;
    }
    await context.push('/host/new');
    _load();
  }

  Future<void> _cancel(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              backgroundColor: GacomColors.cardDark,
              title: const Text('Cancel this competition?', style: TextStyle(color: GacomColors.textPrimary)),
              content: const Text('Every player is refunded their entry fee and your prize pool returns to your wallet.', style: TextStyle(color: GacomColors.textMuted)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep it')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Cancel it')),
              ],
            ));
    if (ok != true) return;
    final r = await HostingService.cancel('${c['id']}');
    if (!mounted) return;
    GacomSnackbar.show(context, r.success ? 'Cancelled and refunded' : (r.error ?? 'Could not cancel'), isError: !r.success, isSuccess: r.success);
    _load();
  }

  Future<void> _settle(Map<String, dynamic> c) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SettleScreen(competition: c)));
    if (done == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _st['active'] == true;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('MY COMPETITIONS')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GacomColors.deepOrange,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('HOST', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
                  child: Row(children: [
                    Icon(Icons.verified_rounded, color: active ? GacomColors.success : GacomColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            active ? 'Verified host. ${_st['days_left']} days left on your subscription.' : 'Hosting is for verified members.',
                            style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13))),
                    TextButton(onPressed: () async { await showVerificationSheet(context, _st); _load(); }, child: Text(active ? 'MANAGE' : 'SUBSCRIBE')),
                  ]),
                ),
                const SizedBox(height: 16),
                if (_list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('You have not hosted a competition yet.', style: TextStyle(color: GacomColors.textMuted))),
                  ),
                for (final c in _list) _HostCard(c: c, onCancel: () => _cancel(c), onSettle: () => _settle(c)),
              ]),
            ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final Map<String, dynamic> c;
  final VoidCallback onCancel, onSettle;
  const _HostCard({required this.c, required this.onCancel, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final status = '${c['status']}';
    final col = status == 'live' ? GacomColors.success : (status == 'upcoming' ? GacomColors.info : GacomColors.textMuted);
    final fee = (c['entry_fee'] as num?) ?? 0;
    final players = (c['players'] as num?)?.toInt() ?? 0;
    final settled = c['fee_status'] == 'settled';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(status.toUpperCase(), style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ]),
        Text('${c['game_name']}  |  ${_dt(c['starts_at'])}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: [
          _Mini('Players', '$players / ${c['max_participants']}'),
          _Mini('Entry', fee == 0 ? 'Free' : _naira(fee)),
          _Mini('Prize pool', _naira((c['prize_pool'] as num?) ?? 0)),
          if (fee > 0) _Mini(settled ? 'You earned' : 'Entry fees held', _naira(settled ? ((c['host_net'] as num?) ?? 0) : fee * players)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(onPressed: () => context.push('/competitions/${c['id']}'), child: const Text('VIEW')),
          const SizedBox(width: 8),
          if (c['can_finish'] == true) ElevatedButton(onPressed: onSettle, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange), child: const Text('PICK WINNERS', style: TextStyle(color: Colors.white))),
          if (c['can_cancel'] == true) TextButton(onPressed: onCancel, child: const Text('Cancel', style: TextStyle(color: GacomColors.error))),
        ]),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String k, v;
  const _Mini(this.k, this.v);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
        Text(v, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
      ]);
}

// =============================================================== settle

class SettleScreen extends StatefulWidget {
  final Map<String, dynamic> competition;
  const SettleScreen({super.key, required this.competition});
  @override
  State<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends State<SettleScreen> {
  List<Map<String, dynamic>> _players = [];
  final List<String> _picked = []; // user ids in place order
  final Map<String, TextEditingController> _pct = {};
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    HostingService.players('${widget.competition['id']}').then((p) {
      if (mounted) setState(() { _players = p; _loading = false; });
    });
  }

  @override
  void dispose() {
    for (final c in _pct.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
        _pct.remove(id)?.dispose();
      } else if (_picked.length < 10) {
        _picked.add(id);
        _pct[id] = TextEditingController();
      }
      _evenSplit();
    });
  }

  void _evenSplit() {
    if (_picked.isEmpty) return;
    final base = 100 ~/ _picked.length;
    var rest = 100 - base * _picked.length;
    for (final id in _picked) {
      _pct[id]!.text = '${base + (rest > 0 ? 1 : 0)}';
      if (rest > 0) rest--;
    }
  }

  double get _total => _picked.fold<double>(0, (a, id) => a + (double.tryParse(_pct[id]?.text ?? '') ?? 0));

  Future<void> _submit() async {
    if (_picked.isEmpty) {
      GacomSnackbar.show(context, 'Pick at least one winner', isError: true);
      return;
    }
    if (_total > 100.0001) {
      GacomSnackbar.show(context, 'The shares add up to more than 100', isError: true);
      return;
    }
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              backgroundColor: GacomColors.cardDark,
              title: const Text('Pay out now?', style: TextStyle(color: GacomColors.textPrimary)),
              content: const Text('Winners are paid from the prize pool, the competition closes and your entry-fee earnings are released. This cannot be undone.', style: TextStyle(color: GacomColors.textMuted)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Go back')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Pay out')),
              ],
            ));
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await HostingService.finish('${widget.competition['id']}', [
      for (final id in _picked) {'user_id': id, 'percent': double.tryParse(_pct[id]!.text) ?? 0},
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Could not settle', isError: true);
      return;
    }
    GacomSnackbar.show(context, 'Paid out. You earned ${_naira((r.data['host_net'] as num?) ?? 0)} from entry fees.', isSuccess: true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final prize = (widget.competition['prize_pool'] as num?) ?? 0;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('PICK WINNERS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Tap players in finishing order (1st, 2nd, ...). Set what percent of the ${_naira(prize)} prize pool each one gets. Anything not given out returns to your wallet.',
                    style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.5)),
              ),
              Expanded(
                child: _players.isEmpty
                    ? const Center(child: Text('Nobody has joined yet.', style: TextStyle(color: GacomColors.textMuted)))
                    : ListView.builder(
                        itemCount: _players.length,
                        itemBuilder: (_, i) {
                          final p = _players[i];
                          final id = '${p['user_id']}';
                          final idx = _picked.indexOf(id);
                          final sel = idx >= 0;
                          return ListTile(
                            onTap: () => _toggle(id),
                            leading: CircleAvatar(
                              backgroundColor: sel ? GacomColors.deepOrange : GacomColors.surfaceDark,
                              backgroundImage: (p['avatar_url'] as String?) != null ? NetworkImage(p['avatar_url'] as String) : null,
                              child: sel ? Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)) : ((p['avatar_url'] as String?) == null ? const Icon(Icons.person, color: GacomColors.textMuted) : null),
                            ),
                            title: Text('${p['display_name'] ?? p['username']}', style: const TextStyle(color: GacomColors.textPrimary)),
                            subtitle: Text('@${p['username']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                            trailing: sel
                                ? SizedBox(
                                    width: 90,
                                    child: TextField(
                                      controller: _pct[id],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.right,
                                      onChanged: (_) => setState(() {}),
                                      style: const TextStyle(color: GacomColors.textPrimary),
                                      decoration: const InputDecoration(suffixText: '%', isDense: true),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_picked.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Shares: ${_total.toStringAsFixed(_total % 1 == 0 ? 0 : 1)}%  |  Paid out: ${_naira(prize * _total / 100)}',
                            style: TextStyle(color: _total > 100 ? GacomColors.error : GacomColors.textMuted, fontSize: 12)),
                      ),
                    GacomButton(label: _busy ? 'PAYING OUT...' : 'PAY OUT AND CLOSE', onPressed: _busy ? null : _submit),
                  ]),
                ),
              ),
            ]),
    );
  }
}

// =============================================================== create

class HostCreateScreen extends StatefulWidget {
  const HostCreateScreen({super.key});
  @override
  State<HostCreateScreen> createState() => _HostCreateScreenState();
}

class _HostCreateScreenState extends State<HostCreateScreen> {
  bool _checking = true, _allowed = false, _busy = false, _uploading = false;
  Map<String, dynamic> _st = {};
  final _title = TextEditingController();
  final _game = TextEditingController();
  final _desc = TextEditingController();
  final _rules = TextEditingController();
  final _region = TextEditingController();
  final _tags = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _prize = TextEditingController(text: '0');
  final _max = TextEditingController(text: '32');
  String _platform = 'Any';
  String? _banner;
  DateTime? _starts, _ends, _deadline;
  String _scope = 'all';
  String? _country;

  static const _platforms = ['Any', 'Mobile', 'PC', 'Console'];

  @override
  void initState() {
    super.initState();
    for (final c in [_fee, _prize, _max]) {
      c.addListener(() => setState(() {}));
    }
    HostingService.verificationState().then((s) {
      if (!mounted) return;
      setState(() {
        _st = s;
        _allowed = s['host'] == true;
        _checking = false;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _game, _desc, _rules, _region, _tags, _fee, _prize, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _lim => (_st['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
  int get _maxPrizeL => (_lim['max_prize'] as num?)?.toInt() ?? 500000;
  int get _maxPlayersL => (_lim['max_players'] as num?)?.toInt() ?? 1000;
  int get _feePct => (_lim['fee_percent'] as num?)?.toInt() ?? 10;
  bool get _idOk => _st['id_status'] == 'approved';
  int get _feeV => int.tryParse(_fee.text.trim()) ?? 0;
  int get _prizeV => int.tryParse(_prize.text.trim()) ?? 0;
  int get _maxV => int.tryParse(_max.text.trim()) ?? 0;

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: initial ?? now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 120)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 2))));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _banner_() async {
    setState(() => _uploading = true);
    try {
      final u = await pickAndUploadImage(bucket: 'competition-banners');
      if (u != null && mounted) setState(() => _banner = u);
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, '$e', isError: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  String? _validate() {
    if (_title.text.trim().length < 4) return 'Give the competition a name (at least 4 letters)';
    if (_game.text.trim().length < 2) return 'Enter the game';
    if (_feeV != 0 && (_feeV < 100 || _feeV > 50000)) return 'Entry fee is free, or between ₦100 and ₦50,000';
    if (_feeV > 0 && !_idOk) return 'Competitions with an entry fee need a verified ID. Tap the note under the fee to complete the ID check.';
    if (_prizeV > _maxPrizeL) return 'Your level allows a prize pool of up to ${_naira(_maxPrizeL)}';
    if (_maxV < 2 || _maxV > _maxPlayersL) return 'Your level allows 2 to $_maxPlayersL players';
    if (_starts == null) return 'Pick when it starts';
    if (_ends == null) return 'Pick when it ends';
    if (!_starts!.isAfter(DateTime.now().add(const Duration(hours: 1)))) return 'Start at least 1 hour from now';
    if (!_ends!.isAfter(_starts!)) return 'It must end after it starts';
    if (_ends!.difference(_starts!).inDays > 30) return 'A competition can run for at most 30 days';
    if (_scope == 'country' && (_country == null || _country!.isEmpty)) return 'Choose the country';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      GacomSnackbar.show(context, err, isError: true);
      return;
    }
    setState(() => _busy = true);
    final tags = _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).take(6).toList();
    final r = await HostingService.create({
      'p_title': _title.text.trim(),
      'p_game': _game.text.trim(),
      'p_description': _desc.text.trim(),
      'p_rules': _rules.text.trim(),
      'p_banner_url': _banner,
      'p_platform': _platform == 'Any' ? null : _platform,
      'p_region': _region.text.trim().isEmpty ? null : _region.text.trim(),
      'p_entry_fee': _feeV,
      'p_prize_pool': _prizeV,
      'p_max': _maxV,
      'p_starts': _starts!.toUtc().toIso8601String(),
      'p_ends': _ends!.toUtc().toIso8601String(),
      'p_deadline': (_deadline ?? _starts)!.toUtc().toIso8601String(),
      'p_tags': tags,
      'p_scope_type': _scope,
      'p_scope_country': _scope == 'country' ? _country : null,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Could not create the competition', isError: true);
      if ((r.error ?? '').toLowerCase().contains('balance')) context.go('/wallet');
      return;
    }
    GacomSnackbar.show(context, 'Your competition is live for sign-ups', isSuccess: true);
    context.pushReplacement('/competitions/${r.data['id']}');
  }

  InputDecoration _dec(String label, [String? hint]) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: GacomColors.textMuted),
        hintStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: GacomColors.surfaceDark,
        counterStyle: const TextStyle(color: GacomColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
      );

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    }
    if (!_allowed) {
      return Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('HOST A COMPETITION')),
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_rounded, color: GacomColors.deepOrange, size: 54),
            const SizedBox(height: 14),
            const Text('Hosting is for verified members', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Subscribe to verification to create competitions of your own.', textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted)),
            const SizedBox(height: 22),
            GacomButton(
                label: 'GET VERIFIED',
                onPressed: () async {
                  await showVerificationSheet(context, _st);
                  final fresh = await HostingService.verificationState();
                  if (mounted) setState(() { _st = fresh; _allowed = fresh['host'] == true; });
                }),
          ]),
        ),
      );
    }

    final pool = _feeV * _maxV;
    final cut = (pool * _feePct / 100).floor();
    const style = TextStyle(color: GacomColors.textPrimary);
    String d(DateTime? t) => t == null ? 'Pick' : '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    Widget dateTile(String label, DateTime? v, ValueChanged<DateTime> set) => Expanded(
          child: GestureDetector(
            onTap: () async {
              final t = await _pick(v);
              if (t != null) set(t);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(d(v), style: TextStyle(color: v == null ? GacomColors.textMuted : GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('HOST A COMPETITION')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
        GestureDetector(
          onTap: _uploading ? null : _banner_,
          child: Container(
            height: 150,
            decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
            clipBehavior: Clip.antiAlias,
            child: _uploading
                ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                : _banner == null
                    ? const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_photo_alternate_rounded, color: GacomColors.deepOrange, size: 34),
                        SizedBox(height: 6),
                        Text('Add a banner (optional)', style: TextStyle(color: GacomColors.textMuted)),
                      ]))
                    : Image.network(_banner!, fit: BoxFit.cover, width: double.infinity),
          ),
        ),
        const SizedBox(height: 14),
        TextField(controller: _title, maxLength: 80, style: style, decoration: _dec('Competition name', 'e.g. Lagos Weekend Cup')),
        const SizedBox(height: 6),
        TextField(controller: _game, maxLength: 60, style: style, decoration: _dec('Game', 'e.g. eFootball, Chess, Call of Duty')),
        const SizedBox(height: 6),
        TextField(controller: _desc, maxLength: 1500, maxLines: 4, style: style, decoration: _dec('About', 'What is this competition about?')),
        const SizedBox(height: 6),
        TextField(controller: _rules, maxLength: 3000, maxLines: 5, style: style, decoration: _dec('Rules', 'Format, match settings, what is not allowed')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _platform,
          dropdownColor: GacomColors.cardDark,
          decoration: _dec('Platform'),
          items: _platforms.map((e) => DropdownMenuItem(value: e, child: Text(e, style: style))).toList(),
          onChanged: (v) => setState(() => _platform = v ?? 'Any'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _region, style: style, decoration: _dec('Region or server (optional)', 'e.g. West Africa')),
        const SizedBox(height: 18),
        const Text('MONEY', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _fee, keyboardType: TextInputType.number, style: style, decoration: _dec('Entry fee (₦)', '0 = free'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _prize, keyboardType: TextInputType.number, style: style, decoration: _dec('Prize pool (₦)', 'Up to ${_naira(_maxPrizeL)}'))),
        ]),
        if (!_idOk)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: () async { await context.push('/verification/id'); final f = await HostingService.verificationState(); if (mounted) setState(() => _st = f); },
              child: const Text('Entry fees need a verified ID. Tap to complete the ID check.', style: TextStyle(color: GacomColors.warning, fontSize: 12)),
            ),
          ),
        const SizedBox(height: 12),
        TextField(controller: _max, keyboardType: TextInputType.number, style: style, decoration: _dec('Maximum players', '2 to $_maxPlayersL')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Column(children: [
            _L('Taken from your wallet now (prize pool)', _naira(_prizeV)),
            if (_feeV > 0) ...[
              _L('Entry fees if full', _naira(pool)),
              _L('Platform fee ($_feePct%)', '- ${_naira(cut)}'),
              _L('You receive after you settle', _naira(pool - cut), bold: true),
            ],
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('The prize pool is held until you pick winners, or returned if you cancel. Entry fees stay locked until then. If you do not settle within 7 days of the end time, everyone is refunded.',
                  style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.4)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('SCHEDULE', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          dateTile('Starts', _starts, (t) => setState(() => _starts = t)),
          const SizedBox(width: 10),
          dateTile('Ends', _ends, (t) => setState(() => _ends = t)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          dateTile('Sign-up closes (optional)', _deadline, (t) => setState(() => _deadline = t)),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 18),
        const Text('WHO CAN JOIN', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Opt('Everyone', _scope == 'all', () => setState(() => _scope = 'all'))),
          const SizedBox(width: 10),
          Expanded(child: _Opt('One country', _scope == 'country', () => setState(() => _scope = 'country'))),
        ]),
        if (_scope == 'country') ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _country,
            dropdownColor: GacomColors.cardDark,
            decoration: _dec('Country'),
            items: const ['Nigeria', 'Ghana', 'Kenya', 'South Africa', 'Egypt', 'Tanzania', 'Uganda', 'Cameroon', 'Senegal', 'Ethiopia', 'Rwanda', 'Zambia']
                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: style)))
                .toList(),
            onChanged: (v) => setState(() => _country = v),
          ),
        ],
        const SizedBox(height: 14),
        TextField(controller: _tags, style: style, decoration: _dec('Tags (optional)', 'comma separated, up to 6')),
        const SizedBox(height: 24),
        GacomButton(label: _busy ? 'CREATING...' : 'CREATE COMPETITION', onPressed: _busy ? null : _submit),
        const SizedBox(height: 8),
        const Text('You can edit the name, text and banner until it starts. You cannot change the money or dates after it is created.',
            textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _L extends StatelessWidget {
  final String k, v;
  final bool bold;
  const _L(this.k, this.v, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))),
          Text(v, style: TextStyle(color: bold ? GacomColors.deepOrange : GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: bold ? 16 : 13)),
        ]),
      );
}

class _Opt extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _Opt(this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
          child: Text(label, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
        ),
      );
}
