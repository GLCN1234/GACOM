import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'flyer_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// The student's page for one GACOM Edu competition: status, their points and
/// rank, where to play (only the competition's subjects), and the standings for
/// students and schools. Points are added automatically when the student
/// finishes a game in one of the competition subjects.
class EduCompetitionScreen extends StatefulWidget {
  final String competitionId;
  const EduCompetitionScreen({super.key, required this.competitionId});
  @override
  State<EduCompetitionScreen> createState() => _EduCompetitionScreenState();
}

class _EduCompetitionScreenState extends State<EduCompetitionScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _comp;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _schools = [];
  int _total = 0;
  bool _loading = true;
  bool _registering = false;
  String? _error;
  late final TabController _tabs;
  Timer? _tick;

  static const _names = {'math': 'Maths', 'english': 'English'};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      Map<String, dynamic>? comp;
      final banners = await SupabaseService.client.rpc('edu_comp_banners');
      if (banners is List) {
        for (final b in banners) {
          if (b is Map && '${b['id']}' == widget.competitionId) comp = Map<String, dynamic>.from(b);
        }
      }
      if (comp == null) {
        // Closed competitions drop off the banner list; still show their final standings.
        final c = await SupabaseService.client.from('competitions').select('*').eq('id', widget.competitionId).maybeSingle();
        if (c != null) {
          final mine = await SupabaseService.client
              .from('competition_participants')
              .select('id')
              .eq('competition_id', widget.competitionId)
              .eq('user_id', SupabaseService.currentUserId ?? '')
              .maybeSingle();
          comp = Map<String, dynamic>.from(c)
            ..['subjects'] = c['edu_subjects']
            ..['registered'] = mine != null;
        }
      }
      if (comp == null) {
        if (mounted) setState(() { _loading = false; _error = 'This competition was not found.'; });
        return;
      }
      List<Map<String, dynamic>> rows = [];
      Map<String, dynamic>? me;
      int total = 0;
      List<Map<String, dynamic>> schools = [];
      try {
        final st = await SupabaseService.client.rpc('edu_comp_standings', params: {'p_comp': widget.competitionId, 'p_limit': 50});
        if (st is Map) {
          final r = st['rows'];
          if (r is List) rows = r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          final m = st['me'];
          if (m is Map) me = Map<String, dynamic>.from(m);
          total = (st['total'] as num?)?.toInt() ?? rows.length;
        }
        final sc = await SupabaseService.client.rpc('edu_comp_school_standings', params: {'p_comp': widget.competitionId});
        if (sc is List) schools = sc.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _comp = comp;
        _rows = rows;
        _me = me;
        _total = total;
        _schools = schools;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load the competition. Check your connection.'; });
    }
  }

  Future<void> _register() async {
    setState(() => _registering = true);
    try {
      final res = await SupabaseService.client.rpc('edu_comp_register', params: {'p_comp': widget.competitionId});
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        GacomSnackbar.show(context, 'You are registered', isSuccess: true);
        await _load();
      } else if (res is Map && res['code'] == 'need_school') {
        GacomSnackbar.show(context, 'Choose your school first, then register again.');
        context.go('/edu/setup');
      } else {
        GacomSnackbar.show(context, (res is Map ? res['error'] : null)?.toString() ?? 'Could not register', isError: true);
      }
    } catch (_) {
      if (mounted) GacomSnackbar.show(context, 'Could not register. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  // 'upcoming' | 'live' | 'ended' decided from the clock so it never lags the database.
  String get _phase {
    final c = _comp;
    if (c == null) return 'upcoming';
    if (c['status'] == 'cancelled') return 'ended';
    final s = DateTime.tryParse('${c['starts_at']}')?.toLocal();
    final e = DateTime.tryParse('${c['ends_at']}')?.toLocal();
    final now = DateTime.now();
    if (e != null && !e.isAfter(now)) return 'ended';
    if (s != null && s.isAfter(now)) return 'upcoming';
    return 'live';
  }

  String _countdown() {
    final c = _comp!;
    final target = DateTime.tryParse('${_phase == 'upcoming' ? c['starts_at'] : c['ends_at']}')?.toLocal();
    if (target == null) return '';
    final d = target.difference(DateTime.now());
    if (d.isNegative) return '';
    final parts = <String>[];
    if (d.inDays > 0) parts.add('${d.inDays}d');
    if (d.inHours % 24 > 0 || d.inDays > 0) parts.add('${d.inHours % 24}h');
    parts.add('${d.inMinutes % 60}m');
    return parts.join(' ');
  }

  List<String> get _subjects {
    final s = _comp?['subjects'];
    if (s is List && s.isNotEmpty) return s.map((e) => '$e').toList();
    return const ['math', 'english'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        backgroundColor: GacomColors.obsidian,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () { if (context.canPop()) { context.pop(); } else { context.go('/edu/home'); } }),
        title: const Text('COMPETITION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary))))
              : RefreshIndicator(color: GacomColors.deepOrange, onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final c = _comp!;
    final registered = c['registered'] == true;
    final phase = _phase;
    final banner = (c['banner_url'] as String?) ?? '';
    final description = (c['description'] as String?)?.trim() ?? '';
    final rules = (c['rules'] as String?)?.trim() ?? '';
    final prize = num.tryParse('${c['prize_pool'] ?? 0}') ?? 0;
    final ppc = c['points_per_correct'] ?? 10;
    final cap = c['daily_point_cap'] ?? 1500;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (banner.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlyerImage(url: banner, natural: true),
        ),
      const SizedBox(height: 12),
      Text('${c['title'] ?? ''}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: GacomColors.textPrimary)),
      const SizedBox(height: 4),
      Text(
        [
          '${_subjects.map((s) => _names[s] ?? s).join(' and ')} only',
          if (prize > 0) 'Prize pool ₦${prize.toInt()}',
        ].join('  |  '),
        style: const TextStyle(color: GacomColors.textMuted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      _statusCard(phase),
      const SizedBox(height: 12),
      if (!registered && phase != 'ended') _registerCard(),
      if (registered) ...[
        _myCard(),
        const SizedBox(height: 12),
        if (phase == 'live') _playCard(),
        if (phase == 'upcoming')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
            child: const Text('You are registered. Play opens when the competition starts. You can still practise in GACOM Edu, but points count only after the start.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.35)),
          ),
        const SizedBox(height: 12),
      ],
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HOW POINTS WORK', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('Every correct answer in ${_subjects.map((s) => _names[s] ?? s).join(' or ')} earns $ppc points, in any GACOM Edu game. Points are added by themselves when you finish a game. You can earn up to $cap points a day. Other subjects are great practice but do not count here.', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.35)),
          if (description.isNotEmpty) ...[const SizedBox(height: 10), Text(description, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.35))],
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('RULES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(rules, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.35)),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      _standings(),
    ]);
  }

  Widget _statusCard(String phase) {
    final color = phase == 'live' ? GacomColors.success : phase == 'upcoming' ? GacomColors.info : GacomColors.textMuted;
    final label = phase == 'live' ? 'LIVE' : phase == 'upcoming' ? 'STARTS IN' : 'ENDED';
    final cd = phase == 'ended' ? '' : _countdown();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.45))),
      child: Row(children: [
        Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: color, letterSpacing: 1.2)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            phase == 'live' ? (cd.isEmpty ? '' : '$cd left') : phase == 'upcoming' ? cd : 'Final standings below',
            style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        Text('${_total > 0 ? _total : (_comp?['participants'] ?? 0)} students', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      ]),
    );
  }

  Widget _registerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Register to compete', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Registration is free. You need to have chosen your school in GACOM Edu.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _registering ? null : _register,
            child: _registering
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('REGISTER NOW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _myCard() {
    final me = _me;
    final pts = (me?['pts'] as num?)?.toInt() ?? 0;
    final rank = (me?['rk'] as num?)?.toInt();
    final cor = (me?['cor'] as num?)?.toInt() ?? 0;
    final qs = (me?['qs'] as num?)?.toInt() ?? 0;
    final mp = (me?['mp'] as num?)?.toInt() ?? 0;
    final ep = (me?['ep'] as num?)?.toInt() ?? 0;
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)),
            Text(l, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
      child: Column(children: [
        Row(children: [
          stat('$pts', 'POINTS'),
          stat(rank == null ? '-' : '#$rank', 'RANK'),
          stat(qs == 0 ? '-' : '${(cor * 100 / qs).round()}%', 'ACCURACY'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          stat('$mp', 'FROM MATHS'),
          stat('$ep', 'FROM ENGLISH'),
          stat('$cor', 'CORRECT'),
        ]),
      ]),
    );
  }

  Widget _playCard() {
    final subs = _subjects;
    Widget tile(String subject) {
      final name = _names[subject] ?? subject;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => context.push('/edu/realms?subject=$subject').then((_) { if (mounted) _load(); }),
              icon: const Icon(Icons.public_rounded, size: 16),
              label: const Text('OPEN WORLDS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => context.push('/edu/subject/$subject').then((_) { if (mounted) _load(); }),
              icon: const Icon(Icons.menu_book_rounded, size: 16, color: GacomColors.textSecondary),
              label: Text('$name GAMES', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textSecondary)),
            ),
          ]),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('PLAY AND EARN POINTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 1))),
      for (final s in subs) tile(s),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: () => context.push('/edu/odyssey').then((_) { if (mounted) _load(); }),
        icon: const Icon(Icons.explore_rounded, size: 16, color: GacomColors.textSecondary),
        label: const Text('ODYSSEY (counts for Maths and English questions)', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
      ),
    ]);
  }

  Widget _standings() {
    return Container(
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
      child: Column(children: [
        TabBar(
          controller: _tabs,
          indicatorColor: GacomColors.deepOrange,
          labelColor: GacomColors.deepOrange,
          unselectedLabelColor: GacomColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1),
          tabs: const [Tab(text: 'STUDENTS'), Tab(text: 'SCHOOLS'), Tab(text: 'ME')],
        ),
        AnimatedBuilder(
          animation: _tabs,
          builder: (_, __) {
            switch (_tabs.index) {
              case 1:
                return _schoolList();
              case 2:
                return _meList();
              default:
                return _studentList();
            }
          },
        ),
      ]),
    );
  }

  Widget _empty(String t) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13))));

  Widget _studentList() {
    if (_rows.isEmpty) return _empty('No students yet. Be the first to score.');
    final myId = SupabaseService.currentUserId;
    return Column(children: [
      for (final r in _rows)
        Container(
          color: '${r['user_id']}' == myId ? GacomColors.deepOrange.withOpacity(0.08) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            SizedBox(width: 34, child: Text('#${r['rk']}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: ((r['rk'] as num?)?.toInt() ?? 99) <= 3 ? GacomColors.deepOrange : GacomColors.textMuted))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['display_name'] ?? 'Student'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                if ((r['school'] ?? '').toString().isNotEmpty) Text('${r['school']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ]),
            ),
            Text('${r['pts'] ?? 0}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
          ]),
        ),
      if (_total > _rows.length) _empty('Showing the top ${_rows.length} of $_total'),
    ]);
  }

  Widget _schoolList() {
    if (_schools.isEmpty) return _empty('No schools yet.');
    return Column(children: [
      for (var i = 0; i < _schools.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            SizedBox(width: 34, child: Text('#${i + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: i < 3 ? GacomColors.deepOrange : GacomColors.textMuted))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_schools[i]['school']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${_schools[i]['students']} student${_schools[i]['students'] == 1 ? '' : 's'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ]),
            ),
            Text('${_schools[i]['points'] ?? 0}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
          ]),
        ),
    ]);
  }

  Widget _meList() {
    final me = _me;
    if (me == null) return _empty('Register to see your own standing.');
    final rank = (me['rk'] as num?)?.toInt();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rank == null ? 'Not ranked yet' : 'You are #$rank of $_total', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
        const SizedBox(height: 4),
        Text('${me['pts'] ?? 0} points from ${me['cor'] ?? 0} correct answers.', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
      ]),
    );
  }
}
