import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../security_service.dart';

const _sevOrder = ['critical', 'high', 'medium', 'low', 'info'];

Color _sevColor(String s) {
  switch (s) {
    case 'critical': return GacomColors.error;
    case 'high': return GacomColors.deepOrange;
    case 'medium': return GacomColors.warning;
    case 'low': return GacomColors.accentCyan;
    default: return GacomColors.textMuted;
  }
}

String _pretty(String k) => k.replaceAll('_', ' ').toUpperCase();

String _when(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
  return d == null ? '-' : DateFormat('MMM d, h:mm a').format(d);
}

/// Admin side of platform security: posture score, live alert feed, audit
/// trail, admin sign-ins and the owner checklist. Polls every 30 seconds.
class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});
  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  Timer? _poll;
  bool _loading = true;
  bool _scanning = false;
  String? _error;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _posture = {};
  Map<String, dynamic> _events = {};
  Map<String, dynamic> _audit = {};
  Map<String, dynamic> _logins = {};

  String _fSeverity = 'all';
  String _fStatus = 'open';
  String _fKind = 'all';
  String _fTable = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  String? _f(String v) => v == 'all' ? null : v;

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = _overview.isEmpty);
    try {
      final r = await Future.wait([
        SecurityService.overview(),
        SecurityService.posture(),
        SecurityService.events(severity: _f(_fSeverity), status: _f(_fStatus), kind: _f(_fKind), limit: 100),
        SecurityService.auditTrail(table: _f(_fTable)),
        SecurityService.adminLogins(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = r[0];
        _posture = r[1];
        _events = r[2];
        _audit = r[3];
        _logins = r[4];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.contains('forbidden') ? 'Admin access required.' : 'Could not load security data. Pull to retry.';
      setState(() { _loading = false; if (!silent || _overview.isEmpty) _error = msg; });
    }
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final r = await SecurityService.scanNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan complete. ${r['raised'] ?? 0} new alert(s).')));
      }
      await _load(silent: true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan failed.')));
    }
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final open = _map(_overview['open_now']);
    final openCount = open.values.fold<int>(0, (a, b) => a + ((b as num?)?.toInt() ?? 0));
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('SECURITY CENTER'),
        actions: [
          IconButton(
            tooltip: 'Run scan',
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radar_rounded),
          ),
          IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: GacomColors.deepOrange,
          labelColor: GacomColors.deepOrange,
          unselectedLabelColor: GacomColors.textMuted,
          tabs: [
            const Tab(text: 'OVERVIEW'),
            Tab(text: openCount > 0 ? 'ALERTS ($openCount)' : 'ALERTS'),
            const Tab(text: 'AUDIT TRAIL'),
            const Tab(text: 'ADMIN LOGINS'),
            const Tab(text: 'CHECKLIST'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _overview.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    SizedBox(height: 200, child: Center(child: Text(_error!, style: const TextStyle(color: GacomColors.textMuted)))),
                  ]),
                )
              : TabBarView(controller: _tabs, children: [
                  _refreshable(_overviewTab()),
                  _refreshable(_alertsTab()),
                  _refreshable(_auditTab()),
                  _refreshable(_loginsTab()),
                  _refreshable(_checklistTab()),
                ]),
    );
  }

  Widget _refreshable(List<Widget> children) => RefreshIndicator(
        color: GacomColors.deepOrange,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: children,
        ),
      );

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.map((e) => _map(e)).toList() : <Map<String, dynamic>>[];

  // ---------------------------------------------------------------- overview
  List<Widget> _overviewTab() {
    final score = (_overview['posture_score'] as num?)?.toInt() ?? 0;
    final grade = '${_overview['posture_grade'] ?? '-'}';
    final open = _map(_overview['open_now']);
    final d24 = _map(_overview['last_24h']);
    final d7 = _map(_overview['last_7d']);
    final trend = _list(_overview['trend']);
    final kinds = _list(_overview['top_kinds']);
    final inactive = _list(_overview['inactive_admins']);
    final ringColor = score >= 75 ? GacomColors.success : score >= 50 ? GacomColors.warning : GacomColors.error;

    return [
      _card(Row(children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _RingPainter(score / 100, ringColor),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: GacomColors.textPrimary)),
                Text('GRADE $grade', style: TextStyle(fontSize: 10, color: ringColor, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SECURITY POSTURE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.accentCyan)),
            const SizedBox(height: 6),
            Text('${_overview['staff_accounts'] ?? 0} staff accounts', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 2),
            Text(inactive.isEmpty ? 'All admins active in the last 30 days' : '${inactive.length} admin(s) inactive for 30 days',
                style: TextStyle(color: inactive.isEmpty ? GacomColors.textSecondary : GacomColors.warning, fontSize: 12)),
          ]),
        ),
      ])),
      const SizedBox(height: 12),
      _sectionLabel('OPEN ALERTS BY SEVERITY'),
      Row(children: [
        for (final s in _sevOrder.take(4))
          Expanded(child: _counter(s, (open[s] as num?)?.toInt() ?? 0, '${d24[s] ?? 0} in 24h')),
      ]),
      const SizedBox(height: 12),
      _sectionLabel('LAST 7 DAYS'),
      _card(SizedBox(height: 150, child: CustomPaint(painter: _TrendPainter(trend), size: Size.infinite))),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(GacomColors.deepOrange, 'High / critical'),
          const SizedBox(width: 16),
          _legend(GacomColors.accentCyan.withOpacity(0.6), 'Other'),
          const SizedBox(width: 16),
          Text('${d7.values.fold<int>(0, (a, b) => a + ((b as num?)?.toInt() ?? 0))} events in 7 days',
              style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 12),
      _sectionLabel('TOP EVENT TYPES'),
      if (kinds.isEmpty)
        _card(const Text('Nothing recorded this week.', style: TextStyle(color: GacomColors.textMuted)))
      else
        _card(Column(children: [
          for (final k in kinds)
            InkWell(
              onTap: () {
                setState(() { _fKind = '${k['kind']}'; _fStatus = 'all'; _fSeverity = 'all'; });
                _tabs.animateTo(1);
                _load(silent: true);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(_pretty('${k['kind']}'), style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12))),
                  Text('${k['count']}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.deepOrange)),
                ]),
              ),
            ),
        ])),
    ];
  }

  Widget _counter(String sev, int n, String sub) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: n > 0 ? _sevColor(sev).withOpacity(0.5) : GacomColors.border),
        ),
        child: Column(children: [
          Text('$n', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: n > 0 ? _sevColor(sev) : GacomColors.textMuted)),
          Text(sev.toUpperCase(), style: const TextStyle(fontSize: 9, color: GacomColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 9, color: GacomColors.textMuted)),
        ]),
      );

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      ]);

  // ----------------------------------------------------------------- alerts
  List<Widget> _alertsTab() {
    final items = _list(_events['items']);
    final kinds = ['all', ...((_events['kinds'] as List?) ?? []).map((e) => '$e')];
    if (!kinds.contains(_fKind)) kinds.add(_fKind);
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _dropdown('Severity', _fSeverity, ['all', ..._sevOrder], (v) => _setFilter(() => _fSeverity = v)),
        _dropdown('Status', _fStatus, const ['all', 'open', 'acknowledged', 'resolved'], (v) => _setFilter(() => _fStatus = v)),
        _dropdown('Type', _fKind, kinds, (v) => _setFilter(() => _fKind = v)),
      ]),
      const SizedBox(height: 12),
      if (items.isEmpty)
        _card(const Text('No alerts match these filters.', style: TextStyle(color: GacomColors.textMuted)))
      else
        for (final e in items) _eventTile(e),
      if ((_events['total'] as num?) != null && (_events['total'] as num) > items.length)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: Text('Showing ${items.length} of ${_events['total']}. Narrow the filters to see more.', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))),
        ),
    ];
  }

  void _setFilter(VoidCallback f) {
    setState(f);
    _load(silent: true);
  }

  Widget _dropdown(String label, String value, List<String> opts, ValueChanged<String> onChanged) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.borderBright)),
        child: DropdownButton<String>(
          value: opts.contains(value) ? value : opts.first,
          dropdownColor: GacomColors.elevatedCard,
          underline: const SizedBox.shrink(),
          isDense: true,
          style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12),
          items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o == 'all' ? '$label: All' : _pretty(o)))],
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      );

  Widget _eventTile(Map<String, dynamic> e) {
    final sev = '${e['severity']}';
    final status = '${e['status']}';
    final who = e['subject_name'] ?? e['actor_name'];
    return GestureDetector(
      onTap: () => _openDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: _sevColor(sev), width: 3), top: const BorderSide(color: GacomColors.border), right: const BorderSide(color: GacomColors.border), bottom: const BorderSide(color: GacomColors.border)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _chip(sev.toUpperCase(), _sevColor(sev)),
            const SizedBox(width: 6),
            _chip(status.toUpperCase(), status == 'open' ? GacomColors.warning : status == 'resolved' ? GacomColors.success : GacomColors.textSecondary),
            const Spacer(),
            Text(_when(e['created_at']), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Text(_pretty('${e['kind']}'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
          const SizedBox(height: 2),
          Text('${who != null ? 'User: $who  |  ' : ''}Source: ${e['source']}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)),
      );

  void _openDetail(Map<String, dynamic> e) {
    final note = TextEditingController(text: '${e['note'] ?? ''}');
    bool busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.elevatedCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        Future<void> apply(String status) async {
          setM(() => busy = true);
          try {
            await SecurityService.setStatus('${e['id']}', status, note: note.text.trim().isEmpty ? null : note.text.trim());
            if (ctx.mounted) Navigator.pop(ctx);
            _load(silent: true);
          } catch (_) {
            if (ctx.mounted) setM(() => busy = false);
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not update this alert.')));
          }
        }

        final json = const JsonEncoder.withIndent('  ').convert(e['details'] ?? {});
        final status = '${e['status']}';
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _chip('${e['severity']}'.toUpperCase(), _sevColor('${e['severity']}')),
                const SizedBox(width: 8),
                Expanded(child: Text(_pretty('${e['kind']}'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary))),
              ]),
              const SizedBox(height: 8),
              _kv('Raised', _when(e['created_at'])),
              _kv('Source', '${e['source']}'),
              if (e['actor_name'] != null) _kv('Actor', '${e['actor_name']}'),
              if (e['subject_name'] != null) _kv('Subject', '${e['subject_name']}'),
              if (e['ip_hash'] != null) _kv('Network hash', '${e['ip_hash']}'),
              _kv('Status', status.toUpperCase()),
              if (e['handled_by_name'] != null) _kv('Handled by', '${e['handled_by_name']} (${_when(e['handled_at'])})'),
              const SizedBox(height: 10),
              const Text('DETAILS (SCRUBBED)', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: GacomColors.obsidian, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(json, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                maxLength: 1000,
                style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Note', hintText: 'What did you check or do?'),
              ),
              Row(children: [
                if (status != 'acknowledged')
                  Expanded(child: OutlinedButton(onPressed: busy ? null : () => apply('acknowledged'), child: const Text('ACKNOWLEDGE'))),
                if (status != 'acknowledged' && status != 'resolved') const SizedBox(width: 10),
                if (status != 'resolved')
                  Expanded(child: ElevatedButton(onPressed: busy ? null : () => apply('resolved'), child: const Text('RESOLVE'))),
                if (status == 'resolved')
                  Expanded(child: OutlinedButton(onPressed: busy ? null : () => apply('open'), child: const Text('REOPEN'))),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(k, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))),
          Expanded(child: Text(v, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12))),
        ]),
      );

  // ------------------------------------------------------------ audit trail
  List<Widget> _auditTab() {
    final items = _list(_audit['items']);
    final tables = ['all', ...((_audit['tables'] as List?) ?? []).map((e) => '$e')];
    if (!tables.contains(_fTable)) tables.add(_fTable);
    return [
      _dropdown('Table', _fTable, tables, (v) => _setFilter(() => _fTable = v)),
      const SizedBox(height: 12),
      if (items.isEmpty)
        _card(const Text('No audited changes yet.', style: TextStyle(color: GacomColors.textMuted)))
      else
        for (final a in items)
          GestureDetector(
            onTap: () => _openDetail({...a, 'source': 'audit'}),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _sevColor('${a['severity']}'), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_pretty('${a['kind']}'), style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('${a['table_name'] ?? '-'}  |  by ${a['actor_name'] ?? 'system'}${a['subject_name'] != null ? '  |  on ${a['subject_name']}' : ''}',
                        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
                  ]),
                ),
                Text(_when(a['created_at']), style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
              ]),
            ),
          ),
    ];
  }

  // ----------------------------------------------------------- admin logins
  List<Widget> _loginsTab() {
    final items = _list(_logins['items']);
    return [
      _card(Text(
        _logins['source'] == 'auth'
            ? 'Sign-in times come from the authentication service.'
            : 'Sign-in history is not available here. Showing last activity recorded by the app.',
        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12),
      )),
      const SizedBox(height: 10),
      for (final a in items)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, color: GacomColors.accentCyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['name']}', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700)),
                Text('${_pretty('${a['role']}')}${a['email'] != null ? '  |  ${a['email']}' : ''}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(a['last_sign_in_at'] != null ? _when(a['last_sign_in_at']) : '-', style: const TextStyle(color: GacomColors.textPrimary, fontSize: 11)),
              Text('Seen ${_when(a['last_seen'])}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
            ]),
          ]),
        ),
      if (items.isEmpty) _card(const Text('No admin accounts found.', style: TextStyle(color: GacomColors.textMuted))),
    ];
  }

  // -------------------------------------------------------------- checklist
  static const _owner = [
    ('Enable multi-factor sign-in for every admin', 'Authentication > Providers in the Supabase dashboard. Require it for all admin and super admin accounts.'),
    ('Rotate API keys and service role secrets', 'Rotate after any staff change and at least every 90 days. Update edge function secrets and CI at the same time.'),
    ('Confirm daily backups and test a restore', 'Check point-in-time recovery is on and restore into a scratch project once a quarter.'),
    ('Set authentication rate limits', 'Authentication > Rate limits: sign-in, OTP and password reset. Enable CAPTCHA on sign-up.'),
    ('Review who holds admin access', 'Remove any admin who has not signed in for 30 days (see Admin Logins).'),
    ('Restrict dashboard access', 'Use single sign-on or hardware keys for the Supabase and store developer accounts.'),
  ];

  List<Widget> _checklistTab() {
    final checks = _list(_posture['checks']);
    return [
      _sectionLabel('LIVE DATABASE CHECKS'),
      for (final c in checks)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (c['ok'] == true ? GacomColors.success : GacomColors.warning).withOpacity(0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(c['ok'] == true ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 18, color: c['ok'] == true ? GacomColors.success : GacomColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text('${c['label']}', style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
              Text('${c['value']}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
            ]),
            if (c['ok'] != true && c['detail'] is List && (c['detail'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 28),
                child: Text((c['detail'] as List).join(', '), style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
              ),
          ]),
        ),
      const SizedBox(height: 12),
      _sectionLabel('OWNER CHECKLIST'),
      for (final o in _owner)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: GacomColors.accentCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.$1, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(o.$2, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
              ]),
            ),
          ]),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('These items live outside the database, so they cannot be verified here. Review them on a schedule.',
            style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      ),
    ];
  }

  // ---------------------------------------------------------------- helpers
  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
        child: child,
      );

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: GacomColors.textMuted)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    final track = Paint()..style = PaintingStyle.stroke..strokeWidth = 10..color = GacomColors.borderBright;
    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round..color = color;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.fraction != fraction || o.color != color;
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.days);
  final List<Map<String, dynamic>> days;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final maxV = days.map((d) => (d['total'] as num?)?.toDouble() ?? 0).fold<double>(1, math.max);
    final slot = size.width / days.length;
    final barW = math.min(slot * 0.55, 34.0);
    final base = Paint()..color = GacomColors.border;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), base);
    for (var i = 0; i < days.length; i++) {
      final total = (days[i]['total'] as num?)?.toDouble() ?? 0;
      final urgent = (days[i]['urgent'] as num?)?.toDouble() ?? 0;
      final x = i * slot + (slot - barW) / 2;
      final h = total / maxV * (chartH - 14);
      final hu = urgent / maxV * (chartH - 14);
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, chartH - h, barW, h), const Radius.circular(4)),
          Paint()..color = GacomColors.accentCyan.withOpacity(0.6),
        );
      }
      if (hu > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, chartH - hu, barW, hu), const Radius.circular(4)),
          Paint()..color = GacomColors.deepOrange,
        );
      }
      _text(canvas, '${total.toInt()}', Offset(x + barW / 2, chartH - h - 12), GacomColors.textSecondary, 9);
      final dt = DateTime.tryParse('${days[i]['day']}');
      _text(canvas, dt == null ? '' : DateFormat('E').format(dt), Offset(x + barW / 2, chartH + 3), GacomColors.textMuted, 9);
    }
  }

  void _text(Canvas canvas, String s, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_TrendPainter o) => o.days != days;
}
