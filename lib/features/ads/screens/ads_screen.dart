import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pick_upload.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../widgets/sponsored.dart';
import 'campaign_detail_screen.dart';

String _naira(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₦$b';
}

String _compact(num v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
  return v.round().toString();
}

class AdsScreen extends ConsumerStatefulWidget {
  const AdsScreen({super.key});
  @override
  ConsumerState<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends ConsumerState<AdsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _rates = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Future.wait([AdsService.myCampaigns(), AdsService.rates(), AdsService.platformStats()]);
    if (!mounted) return;
    setState(() {
      _campaigns = r[0] as List<Map<String, dynamic>>;
      _rates = r[1] as List<Map<String, dynamic>>;
      _stats = r[2] as Map<String, dynamic>;
      _loading = false;
    });
  }

  Future<void> _launch() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CampaignBuilder(rates: _rates)));
    if (created == true) {
      _tab.animateTo(1);
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaign: c)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('ADVERTISE'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'MY CAMPAIGNS')],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _Overview(rates: _rates, stats: _stats, onLaunch: _launch),
        _CampaignList(campaigns: _campaigns, loading: _loading, onCreate: _launch, onOpen: _open, onRefresh: _load),
      ]),
    );
  }
}

// ---------------------------------------------------------------- overview

class _Overview extends StatelessWidget {
  final List<Map<String, dynamic>> rates;
  final Map<String, dynamic> stats;
  final VoidCallback onLaunch;
  const _Overview({required this.rates, required this.stats, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final active = (stats['active_30d'] as num?)?.toInt() ?? 0;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: GacomColors.orangeGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.campaign_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(active > 0 ? '${_compact(active)} gamers\nactive this month' : 'Reach competitive\ngamers',
              style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, height: 1.2)),
          const SizedBox(height: 8),
          const Text(
              'Choose who sees your ad, set a daily budget and the number of days. You only pay for real views or clicks, and anything unspent returns to your wallet.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onLaunch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
              child: const Text('LAUNCH CAMPAIGN',
                  style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
            ),
          ),
        ]),
      ).animate().fadeIn(),
      const SizedBox(height: 28),
      const _Head('HOW IT WORKS'),
      ...[
        (Icons.flag_rounded, 'Pick a goal', 'Awareness shows your ad to as many people as your budget allows and bills per 1,000 views. Traffic bills only when someone taps through.'),
        (Icons.tune_rounded, 'Choose your audience', 'Target by country and by what people play: Darkom City, chess, quiz games, shooters, football games, tournaments or the store.'),
        (Icons.calendar_month_rounded, 'Set budget and days', 'Daily budget times 1 to 30 days. Spend is paced through each day, and the ad stops on the last day.'),
        (Icons.bar_chart_rounded, 'Watch the results', 'Reach, views, taps, click rate and spend update as people see the ad.'),
      ].asMap().entries.map((e) => _Feature(icon: e.value.$1, title: e.value.$2, desc: e.value.$3).animate(delay: (e.key * 80).ms).fadeIn()),
      const SizedBox(height: 24),
      const _Head('PRICING'),
      const SizedBox(height: 12),
      if (rates.isEmpty)
        const Text('Prices load when you are online.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))
      else
        ...rates.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
              child: Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['label']}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${r['blurb']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${_naira(r['cpm'] as num)} / 1,000 views',
                      style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                  Text('${_naira(r['cpc'] as num)} / click', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ]),
            )),
      const SizedBox(height: 6),
      const Text(
          'Small audiences cost a little more because fewer people compete for the same views. The exact price for your setup is shown before you pay.',
          style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.5)),
      const SizedBox(height: 24),
      GacomButton(label: 'LAUNCH YOUR FIRST CAMPAIGN', onPressed: onLaunch),
      const SizedBox(height: 40),
    ]);
  }
}

class _Head extends StatelessWidget {
  final String t;
  const _Head(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary, letterSpacing: 1)),
      );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _Feature({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: GacomColors.deepOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
          ])),
        ]),
      );
}

// ---------------------------------------------------------------- my campaigns

Color statusColor(String s) {
  switch (s) {
    case 'active':
      return GacomColors.success;
    case 'pending_review':
    case 'paused':
      return GacomColors.warning;
    case 'rejected':
      return GacomColors.error;
    default:
      return GacomColors.textMuted;
  }
}

String statusLabel(String s) => s == 'pending_review' ? 'IN REVIEW' : s.replaceAll('_', ' ').toUpperCase();

class _CampaignList extends StatelessWidget {
  final List<Map<String, dynamic>> campaigns;
  final bool loading;
  final VoidCallback onCreate;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function() onRefresh;
  const _CampaignList({required this.campaigns, required this.loading, required this.onCreate, required this.onOpen, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (campaigns.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.campaign_rounded, size: 64, color: GacomColors.border),
        const SizedBox(height: 16),
        const Text('No campaigns yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
        const SizedBox(height: 24),
        GacomButton(label: 'LAUNCH FIRST CAMPAIGN', onPressed: onCreate),
      ]));
    }
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: campaigns.length,
        itemBuilder: (_, i) {
          final c = campaigns[i];
          final status = c['status'] as String? ?? 'pending_review';
          final col = statusColor(status);
          final spend = (c['spend'] as num?) ?? 0;
          final total = (c['total_budget'] as num?) ?? 0;
          return GestureDetector(
            onTap: () => onOpen(c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: (c['image'] as String?) == null
                        ? Container(color: GacomColors.surfaceDark)
                        : Image.network(c['image'] as String, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: GacomColors.surfaceDark)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('${c['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(statusLabel(status), style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (spend / total).clamp(0, 1).toDouble() : 0,
                      minHeight: 4,
                      backgroundColor: GacomColors.surfaceDark,
                      valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${_compact((c['reach'] as num?) ?? 0)} reached  ·  ${_compact((c['impressions'] as num?) ?? 0)} views  ·  ${_compact((c['clicks'] as num?) ?? 0)} clicks  ·  ${_naira(spend)} of ${_naira(total)}',
                      style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- builder

/// Guided campaign builder: goal and places, the ad itself, audience, budget and days, review.
class CampaignBuilder extends StatefulWidget {
  final List<Map<String, dynamic>> rates;
  /// When set, the form starts from this campaign (used to duplicate a finished one).
  final Map<String, dynamic>? from;
  const CampaignBuilder({super.key, required this.rates, this.from});
  @override
  State<CampaignBuilder> createState() => _CampaignBuilderState();
}

class _CampaignBuilderState extends State<CampaignBuilder> {
  int _step = 0;
  static const _steps = ['Goal', 'Ad', 'Audience', 'Budget'];

  String _objective = 'awareness';
  final Set<String> _places = {'feed'};
  final _title = TextEditingController();
  final _headline = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String _cta = 'Learn more';
  String? _image;
  bool _uploading = false;
  final Set<String> _countries = {'Nigeria'};
  final Set<String> _interests = {};
  double _daily = 2000;
  double _minDaily = 1000;
  double _maxDaily = 100000;
  double _days = 3;
  DateTime? _startAt; // null = start now
  Map<String, dynamic>? _est;
  bool _estLoading = false;
  Timer? _debounce;
  double? _balance;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final f = widget.from;
    if (f != null) {
      _objective = (f['objective'] as String?) ?? 'awareness';
      _places
        ..clear()
        ..addAll(((f['placements'] as List?) ?? ['feed']).map((e) => '$e'));
      _title.text = '${f['title'] ?? ''} copy';
      _headline.text = '${f['headline'] ?? ''}';
      _body.text = '${f['body'] ?? ''}';
      _link.text = '${f['url'] ?? ''}';
      _cta = (f['cta'] as String?) ?? 'Learn more';
      _image = f['image'] as String?;
      _countries
        ..clear()
        ..addAll(((f['countries'] as List?) ?? []).map((e) => '$e'));
      _interests
        ..clear()
        ..addAll(((f['interests'] as List?) ?? []).map((e) => '$e'));
      _daily = ((f['daily_budget'] as num?) ?? 2000).toDouble();
      _days = ((f['days'] as num?) ?? 3).toDouble();
    }
    for (final c in [_title, _headline, _body, _link]) {
      c.addListener(() => setState(() {}));
    }
    _loadBalance();
    AdsService.platformStats().then((st) {
      if (!mounted) return;
      final mn = (st['min_daily'] as num?)?.toDouble() ?? 1000;
      final mx = ((st['max_daily'] as num?)?.toDouble() ?? 100000).clamp(mn + 1000, 100000000).toDouble();
      setState(() { _minDaily = mn; _maxDaily = mx; _daily = _daily.clamp(mn, mx).toDouble(); });
      _refreshEstimate();
    });
    _refreshEstimate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_title, _headline, _body, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final w = await SupabaseService.client.rpc('my_wallet');
      if (w is Map && mounted) setState(() => _balance = (w['wallet_balance'] as num?)?.toDouble());
    } catch (_) {}
  }

  Map<String, dynamic> get _cfg => {
        'objective': _objective,
        'placements': _places.toList(),
        'countries': _countries.toList(),
        'interests': _interests.toList(),
        'daily_budget': _daily.round(),
        'days': _days.round(),
      };

  void _refreshEstimate() {
    _debounce?.cancel();
    setState(() => _estLoading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final e = await AdsService.estimate(_cfg);
      if (!mounted) return;
      setState(() {
        _est = e;
        _estLoading = false;
      });
    });
  }

  double get _total => _daily.round() * _days.round().toDouble();

  bool get _linkOk => RegExp(r'^https://[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}(/\S*)?$').hasMatch(_link.text.trim());

  String? _stepError(int s) {
    if (s == 0 && _places.isEmpty) return 'Pick at least one place for the ad to appear';
    if (s == 1) {
      if (_title.text.trim().length < 2) return 'Give the campaign a name';
      if (_headline.text.trim().length < 2) return 'Write a headline';
      if (_image == null) return 'Add a picture for the ad';
      if (!_linkOk) return 'The link must start with https://';
    }
    return null;
  }

  void _next() {
    final err = _stepError(_step);
    if (err != null) {
      GacomSnackbar.show(context, err, isError: true);
      return;
    }
    setState(() => _step++);
  }

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadImage(bucket: 'ad-creatives');
      if (url != null && mounted) setState(() => _image = url);
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, '$e', isError: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: _startAt ?? now, firstDate: now, lastDate: now.add(const Duration(days: 30)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startAt ?? now.add(const Duration(hours: 1))));
    if (t == null) return;
    var s = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (s.isBefore(now)) s = now;
    setState(() => _startAt = s);
  }

  Future<void> _submit() async {
    final err = _stepError(1) ?? _stepError(0);
    if (err != null) {
      GacomSnackbar.show(context, err, isError: true);
      return;
    }
    if (_balance != null && _balance! < _total) {
      final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                backgroundColor: GacomColors.cardDark,
                title: const Text('Add funds first', style: TextStyle(color: GacomColors.textPrimary)),
                content: Text('This campaign needs ${_naira(_total)} and your wallet has ${_naira(_balance!)}.', style: const TextStyle(color: GacomColors.textMuted)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open wallet')),
                ],
              ));
      if (go == true && mounted) context.go('/wallet');
      return;
    }
    setState(() => _submitting = true);
    final res = await AdsService.create({
      ..._cfg,
      'title': _title.text.trim(),
      'headline': _headline.text.trim(),
      'body': _body.text.trim(),
      'cta': _cta,
      'destination_url': _link.text.trim(),
      'creative_url': _image,
      if (_startAt != null) 'start_at': _startAt!.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.success) {
      GacomSnackbar.show(context, res.error ?? 'Could not launch the campaign', isError: true);
      return;
    }
    final inReview = res.data['status'] == 'pending_review';
    GacomSnackbar.show(
        context, inReview ? 'Submitted. It goes live as soon as it is approved.' : 'Your campaign is live.',
        isSuccess: true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('NEW CAMPAIGN')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(children: [
            for (var i = 0; i < _steps.length; i++) ...[
              Expanded(
                child: Column(children: [
                  Container(height: 3, decoration: BoxDecoration(color: i <= _step ? GacomColors.deepOrange : GacomColors.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 4),
                  Text(_steps[i].toUpperCase(),
                      style: TextStyle(fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: i == _step ? GacomColors.deepOrange : GacomColors.textMuted)),
                ]),
              ),
              if (i < _steps.length - 1) const SizedBox(width: 6),
            ]
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            if (_step == 0) ..._goalStep(),
            if (_step == 1) ..._adStep(),
            if (_step == 2) ..._audienceStep(),
            if (_step == 3) ..._budgetStep(),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              if (_step > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => setState(() => _step--),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
                    child: const Text('BACK', style: TextStyle(color: GacomColors.textMuted)),
                  ),
                ),
              Expanded(
                child: _step < 3
                    ? GacomButton(label: 'CONTINUE', onPressed: _next)
                    : GacomButton(label: _submitting ? 'LAUNCHING...' : 'PAY ${_naira(_total)} AND LAUNCH', onPressed: _submitting ? null : _submit),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---- step 1
  List<Widget> _goalStep() {
    Widget obj(String key, IconData icon, String name, String desc) {
      final sel = _objective == key;
      return GestureDetector(
        onTap: () {
          setState(() => _objective = key);
          _refreshEstimate();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: sel ? GacomColors.deepOrange.withOpacity(0.1) : GacomColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
          child: Row(children: [
            Icon(icon, color: sel ? GacomColors.deepOrange : GacomColors.textMuted),
            const SizedBox(width: 14),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
            ])),
          ]),
        ),
      );
    }

    final rateMap = {for (final r in widget.rates) '${r['placement']}': r};
    Widget place(String key, IconData icon, String name) {
      final sel = _places.contains(key);
      final r = rateMap[key];
      return GestureDetector(
        onTap: () {
          setState(() {
            if (sel) {
              _places.remove(key);
            } else {
              _places.add(key);
            }
          });
          _refreshEstimate();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: sel ? GacomColors.deepOrange.withOpacity(0.1) : GacomColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
          child: Row(children: [
            Icon(icon, color: sel ? GacomColors.deepOrange : GacomColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              if (r != null) Text('${r['blurb']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ])),
            if (r != null)
              Text(_objective == 'traffic' ? '${_naira(r['cpc'] as num)}/click' : '${_naira(r['cpm'] as num)}/1K',
                  style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(width: 8),
            Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined, color: sel ? GacomColors.deepOrange : GacomColors.border, size: 20),
          ]),
        ),
      );
    }

    return [
      const _Head('WHAT DO YOU WANT?'),
      obj('awareness', Icons.visibility_rounded, 'Get seen', 'Show the ad to as many of the right people as possible. You pay per 1,000 views.'),
      obj('traffic', Icons.ads_click_rounded, 'Get visits', 'Send people to your website or page. You pay only when someone taps the ad.'),
      const SizedBox(height: 14),
      const _Head('WHERE SHOULD IT APPEAR?'),
      place('feed', Icons.view_stream_rounded, 'In-feed'),
      place('banner', Icons.view_agenda_rounded, 'Banner'),
      place('fullscreen', Icons.fullscreen_rounded, 'Full screen'),
    ];
  }

  // ---- step 2
  List<Widget> _adStep() {
    InputDecoration dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: GacomColors.textMuted),
        hintStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: GacomColors.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
        counterStyle: const TextStyle(color: GacomColors.textMuted));
    const style = TextStyle(color: GacomColors.textPrimary);
    return [
      const _Head('YOUR AD'),
      GestureDetector(
        onTap: _uploading ? null : _pickImage,
        child: Container(
          height: 170,
          decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          clipBehavior: Clip.antiAlias,
          child: _uploading
              ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
              : _image == null
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_photo_alternate_rounded, color: GacomColors.deepOrange, size: 36),
                      SizedBox(height: 8),
                      Text('Add a picture', style: TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600)),
                      Text('JPG, PNG or WebP, up to 5 MB. Wide pictures look best.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    ]))
                  : Stack(fit: StackFit.expand, children: [
                      Image.network(_image!, fit: BoxFit.cover),
                      Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                              child: const Text('CHANGE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
                    ]),
        ),
      ),
      const SizedBox(height: 14),
      TextField(controller: _title, style: style, maxLength: 60, decoration: dec('Campaign name', 'Only you see this')),
      const SizedBox(height: 4),
      TextField(controller: _headline, style: style, maxLength: 40, decoration: dec('Headline', 'e.g. Play and win real prizes')),
      const SizedBox(height: 4),
      TextField(controller: _body, style: style, maxLength: 200, maxLines: 3, decoration: dec('Text (optional)', 'What do you want gamers to know?')),
      const SizedBox(height: 4),
      TextField(
          controller: _link,
          style: style,
          keyboardType: TextInputType.url,
          decoration: dec('Link', 'https://yoursite.com').copyWith(
              errorText: _link.text.isNotEmpty && !_linkOk ? 'Must start with https://' : null)),
      const SizedBox(height: 14),
      const Text('Button', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AdsService.ctas.map((c) {
          final sel = _cta == c;
          return GestureDetector(
            onTap: () => setState(() => _cta = c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
              child: Text(c, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      const _Head('PREVIEW'),
      SponsoredCard(
        ad: {'headline': _headline.text.isEmpty ? 'Your headline' : _headline.text, 'body': _body.text, 'cta': _cta, 'image': _image},
        preview: true,
      ),
    ];
  }

  // ---- step 3
  List<Widget> _audienceStep() {
    Widget chip(String label, bool sel, VoidCallback tap) => GestureDetector(
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
            child: Text(label, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        );
    final aud = (_est?['audience'] as num?)?.toInt();
    return [
      const _Head('WHERE'),
      const Text('Leave empty to reach everyone, in every country.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in AdsService.countries)
          chip(c, _countries.contains(c), () {
            setState(() => _countries.contains(c) ? _countries.remove(c) : _countries.add(c));
            _refreshEstimate();
          }),
      ]),
      const SizedBox(height: 22),
      const _Head('WHO'),
      const Text('People are matched from what they play and do in the app. Leave empty for all players.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in AdsService.interests.entries)
          chip(e.value, _interests.contains(e.key), () {
            setState(() => _interests.contains(e.key) ? _interests.remove(e.key) : _interests.add(e.key));
            _refreshEstimate();
          }),
      ]),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Row(children: [
          const Icon(Icons.groups_rounded, color: GacomColors.deepOrange, size: 30),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Potential audience', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            Text(_estLoading && aud == null ? '...' : (aud == null ? 'Unavailable' : '${_compact(aud)} people'),
                style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24)),
            if (_est?['small_audience'] == true)
              const Text('This is a small audience, so views cost more. Add countries or remove interests to widen it.',
                  style: TextStyle(color: GacomColors.warning, fontSize: 11, height: 1.4)),
          ])),
        ]),
      ),
      const SizedBox(height: 10),
      const Text('Age and gender targeting is not available because players do not share that on GACOM.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.4)),
    ];
  }

  // ---- step 4
  List<Widget> _budgetStep() {
    final e = _est;
    String range(String lo, String hi) {
      final a = (e?[lo] as num?) ?? 0, b = (e?[hi] as num?) ?? 0;
      return e == null ? '...' : '${_compact(a)} - ${_compact(b)}';
    }

    final start = _startAt ?? DateTime.now();
    final end = start.add(Duration(days: _days.round()));
    String d(DateTime t) => '${t.day}/${t.month}/${t.year}';
    return [
      const _Head('DAILY BUDGET'),
      Row(children: [
        Text(_naira(_daily), style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30)),
        const Text('  per day', style: TextStyle(color: GacomColors.textMuted)),
      ]),
      Slider(
        value: _daily.clamp(_minDaily, _maxDaily).toDouble(),
        min: _minDaily,
        max: _maxDaily,
        divisions: ((_maxDaily - _minDaily) / 1000).round().clamp(1, 400),
        activeColor: GacomColors.deepOrange,
        onChanged: (v) => setState(() => _daily = (v / 100).round() * 100.0),
        onChangeEnd: (_) => _refreshEstimate(),
      ),
      const SizedBox(height: 8),
      const _Head('DURATION'),
      Row(children: [
        Text('${_days.round()} ${_days.round() == 1 ? 'day' : 'days'}',
            style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30)),
      ]),
      Slider(
        value: _days,
        min: 1,
        max: 30,
        divisions: 29,
        activeColor: GacomColors.deepOrange,
        onChanged: (v) => setState(() => _days = v.roundToDouble()),
        onChangeEnd: (_) => _refreshEstimate(),
      ),
      const SizedBox(height: 8),
      const _Head('START'),
      Row(children: [
        Expanded(
            child: _Pill('Start now', _startAt == null, () => setState(() => _startAt = null))),
        const SizedBox(width: 10),
        Expanded(
            child: _Pill(_startAt == null ? 'Schedule' : '${d(_startAt!)} ${_startAt!.hour.toString().padLeft(2, '0')}:${_startAt!.minute.toString().padLeft(2, '0')}', _startAt != null, _pickStart)),
      ]),
      const SizedBox(height: 4),
      Text('Runs ${d(start)} to ${d(end)}. The ad stops after day ${_days.round()}.', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Text('ESTIMATED RESULTS', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          _Row('People reached per day', range('reach_low', 'reach_high')),
          _Row('Views per day', range('impressions_low', 'impressions_high')),
          _Row('Clicks per day', range('clicks_low', 'clicks_high')),
          const Divider(color: GacomColors.border, height: 22),
          if (((e?['discount'] as num?) ?? 0) > 0) _Row('Your verification discount', '${e!['discount']}% off'),
          _Row(_objective == 'traffic' ? 'Price per click' : 'Price per 1,000 views',
              e == null ? '...' : _naira((_objective == 'traffic' ? e['cpc'] : e['cpm']) as num)),
          _Row('Total budget', _naira(_total), bold: true),
          if (_balance != null) _Row('Your wallet', _naira(_balance!)),
        ]),
      ),
      if (e?['budget_too_big'] == true)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('This daily budget is more than this audience can use, because each person sees an ad at most 3 times a day. Unspent money is returned when the campaign ends. A wider audience would use it all.',
              style: TextStyle(color: GacomColors.warning, fontSize: 11, height: 1.4)),
        ),
      const SizedBox(height: 10),
      const Text(
          'The full budget is taken from your wallet now. When the campaign ends or you cancel it, whatever was not spent goes back to your wallet. Estimates are a guide, not a promise. New advertisers have their first campaign checked before it goes live.',
          style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.5)),
    ];
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _Pill(this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
          child: Text(label, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))),
          Text(value, style: TextStyle(color: bold ? GacomColors.deepOrange : GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: bold ? 16 : 13)),
        ]),
      );
}
