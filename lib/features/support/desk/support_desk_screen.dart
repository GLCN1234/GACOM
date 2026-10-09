import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../support_service.dart';
import '../support_ui.dart';

/// Staff queue. The server decides who is on a team; an empty team list
/// means the person is not support staff.
class SupportDeskScreen extends StatefulWidget {
  const SupportDeskScreen({super.key});

  @override
  State<SupportDeskScreen> createState() => _SupportDeskScreenState();
}

class _SupportDeskScreenState extends State<SupportDeskScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    'Unassigned',
    'Mine',
    'All open',
    'Escalated',
    'Breaching SLA'
  ];

  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  Timer? _tick;
  List<SupportTeam> _teams = [];
  SupportTeam? _team;
  List<SupportTicket> _all = [];
  SupportTeamStats? _stats;
  bool _booting = true;
  bool _loading = false;
  String _query = '';
  String _priority = 'all';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _boot();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final teams = await SupportService.myTeams();
    if (!mounted) return;
    setState(() {
      _teams = teams;
      _team = teams.isEmpty ? null : teams.first;
      _booting = false;
    });
    if (_team != null) _load();
  }

  Future<void> _load() async {
    final team = _team;
    if (team == null) return;
    setState(() => _loading = true);
    final tab = _tabCtrl.index;
    final listF = SupportService.deskQueue(
      teamKey: team.key,
      status: tab == 3 ? 'escalated' : null,
      mineOnly: tab == 1,
      breachedOnly: tab == 4,
      limit: 100,
    );
    final statsF = SupportService.teamStats(team.key);
    final list = await listF;
    final stats = await statsF;
    if (!mounted) return;
    setState(() {
      _all = list;
      _stats = stats;
      _loading = false;
    });
  }

  int _rank(String p) {
    switch (p) {
      case 'urgent':
        return 0;
      case 'high':
        return 1;
      case 'normal':
        return 2;
      default:
        return 3;
    }
  }

  DateTime? _due(SupportTicket t) =>
      t.firstResponseAt == null ? t.firstResponseDue : t.resolutionDue;

  List<SupportTicket> get _visible {
    final tab = _tabCtrl.index;
    final q = _query.toLowerCase();
    final list = _all.where((t) {
      if (tab == 0 && (t.assigneeId != null || SupportUi.isDone(t.status))) {
        return false;
      }
      if (tab == 2 && SupportUi.isDone(t.status)) return false;
      if (_priority != 'all' && t.priority != _priority) return false;
      if (q.isNotEmpty) {
        final hay =
            '${t.userName} ${t.subject} ${t.id} ${t.lastPreview} ${t.category}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      final r = _rank(a.priority).compareTo(_rank(b.priority));
      if (r != 0) return r;
      final da = _due(a), db = _due(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppConstants.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text('SUPPORT DESK', style: SupportUi.heading(size: 20)),
        bottom: (_booting || _teams.isEmpty)
            ? null
            : TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: GacomColors.deepOrange,
                labelColor: GacomColors.deepOrange,
                unselectedLabelColor: GacomColors.textMuted,
                labelStyle: SupportUi.heading(size: 14),
                tabs: [for (final t in _tabs) Tab(text: t.toUpperCase())],
              ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_booting) return const SupportLoading();
    if (_teams.isEmpty) {
      return const SupportEmpty(
        icon: Icons.lock_outline_rounded,
        title: 'You are not on a support team',
        subtitle:
            'The support desk is for GACOM support staff. If you think you should have access, ask a team lead or an admin to add you.',
      );
    }
    return Column(children: [
      _toolbar(),
      if (_stats != null) _statsHeader(_stats!),
      Expanded(child: _queue()),
    ]);
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.groups_rounded,
              size: 18, color: GacomColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: _teams.length == 1
                ? Text(_team!.name, style: SupportUi.heading(size: 16))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: GacomColors.elevatedCard,
                      value: _team!.key,
                      style: SupportUi.heading(size: 16),
                      items: [
                        for (final t in _teams)
                          DropdownMenuItem(value: t.key, child: Text(t.name)),
                      ],
                      onChanged: (k) {
                        if (k == null) return;
                        setState(() {
                          _team = _teams.firstWhere((t) => t.key == k);
                        });
                        _load();
                      },
                    ),
                  ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name, subject or text',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter by priority',
            color: GacomColors.elevatedCard,
            icon: Icon(Icons.filter_list_rounded,
                color: _priority == 'all'
                    ? GacomColors.textSecondary
                    : GacomColors.deepOrange),
            onSelected: (v) => setState(() => _priority = v),
            itemBuilder: (_) => [
              for (final p in ['all', 'urgent', 'high', 'normal', 'low'])
                PopupMenuItem(
                    value: p,
                    child: Text(p == 'all' ? 'All priorities' : SupportUi.pretty(p))),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _statsHeader(SupportTeamStats s) {
    final avg = s.avgFirstResponseMin > 0
        ? SupportUi.duration(Duration(minutes: s.avgFirstResponseMin.round()))
        : '-';
    final csat = s.csatAvg > 0 ? '${s.csatAvg.toStringAsFixed(1)} / 5' : '-';
    Widget cell(String label, String value, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: SupportUi.card(border: c.withOpacity(0.25)),
            child: Column(children: [
              Text(value, style: SupportUi.heading(size: 18, color: c)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, color: GacomColors.textMuted)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 6),
      child: Row(children: [
        cell('Open', '${s.open}', GacomColors.info),
        cell('Breached', '${s.breached}',
            s.breached > 0 ? GacomColors.error : GacomColors.success),
        cell('Avg first reply', avg, GacomColors.warning),
        cell('CSAT', csat, GacomColors.gold),
      ]),
    );
  }

  Widget _queue() {
    final list = _visible;
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: _load,
      child: _loading && _all.isEmpty
          ? ListView(children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: const SupportLoading())
            ])
          : list.isEmpty
              ? ListView(children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const SupportEmpty(
                      icon: Icons.inbox_outlined,
                      title: 'Nothing here',
                      subtitle: 'No requests match this view right now.',
                    ),
                  ),
                ])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _tile(list[i]),
                ),
    );
  }

  Widget _sla(SupportTicket t) {
    if (SupportUi.isDone(t.status)) return const SizedBox.shrink();
    final due = _due(t);
    if (due == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final over = due.isBefore(now);
    final left = due.difference(now);
    Color c = GacomColors.success;
    String text = SupportUi.duration(left);
    if (over) {
      c = GacomColors.error;
      text = 'Overdue ${SupportUi.duration(left)}';
    } else if (t.breached) {
      c = GacomColors.error;
      text = 'Breached';
    } else if (left.inMinutes < 30) {
      c = GacomColors.warning;
    }
    return SupportChip(text, c, icon: Icons.schedule_rounded);
  }

  Widget _tile(SupportTicket t) {
    final pc = SupportUi.priorityColor(t.priority);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await context.push('/support/desk/ticket/${t.id}', extra: t);
        if (mounted) _load();
      },
      child: Container(
        decoration: SupportUi.card(),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: pc),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (t.unreadForStaff)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                                color: GacomColors.deepOrange,
                                shape: BoxShape.circle),
                          ),
                        Expanded(
                          child: Text(
                            t.subject.isEmpty ? 'Support request' : t.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SupportUi.heading(size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _sla(t),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                          '${t.userName.isEmpty ? 'User' : t.userName}  |  ${SupportUi.ago(t.updatedAt)}',
                          style: SupportUi.muted),
                      if (t.lastPreview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(t.lastPreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: GacomColors.textSecondary,
                                fontSize: 13)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        SupportChip(SupportUi.pretty(t.priority), pc),
                        SupportChip(
                            SupportUi.statusLabel(t.status, staff: true),
                            SupportUi.statusColor(t.status)),
                        SupportChip(SupportUi.pretty(t.category),
                            GacomColors.textSecondary),
                        SupportChip(
                            t.assigneeName ?? 'Unassigned',
                            t.assigneeId == null
                                ? GacomColors.warning
                                : GacomColors.success,
                            icon: Icons.person_outline_rounded),
                      ]),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
