import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/gacom_snackbar.dart';
import 'house_service.dart';
import 'widgets/house_actions.dart';
import 'widgets/house_goal_card.dart';
import 'widgets/house_visuals.dart';

class HouseDetailScreen extends StatefulWidget {
  final String houseId;
  const HouseDetailScreen({super.key, required this.houseId});
  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  bool _loading = true;
  String? _error;
  HouseDetails? _d;
  bool _busy = false;
  HouseGoal? _goal;
  List<HouseSummary> _war = [];
  List<HouseMember> _top = [];
  bool _topWeek = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final d = await HouseService.details(widget.houseId);
      if (!mounted) return;
      setState(() { _d = d; _loading = false; _error = null; });
      if (d != null) _loadExtras();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = HouseService.friendlyError(e); });
    }
  }

  /// Goal, weekly war and top members. Each one is optional: failures just hide the section.
  Future<void> _loadExtras() async {
    final id = widget.houseId;
    HouseGoal? goal;
    var war = <HouseSummary>[];
    var top = <HouseMember>[];
    try {
      final r = await Future.wait<dynamic>([
        HouseService.goal(id),
        HouseService.leaderboard(week: true).catchError((_) => <HouseSummary>[]),
        HouseService.topMembers(id, week: _topWeek),
      ]);
      goal = r[0] as HouseGoal?;
      war = r[1] as List<HouseSummary>;
      top = r[2] as List<HouseMember>;
    } catch (_) {}
    if (!mounted) return;
    setState(() { _goal = goal; _war = war; _top = top; });
  }

  Future<void> _setTopScope(bool week) async {
    if (_topWeek == week) return;
    setState(() => _topWeek = week);
    final top = await HouseService.topMembers(widget.houseId, week: week);
    if (!mounted || _topWeek != week) return;
    setState(() => _top = top);
  }

  Future<void> _joinOrRequest(HouseDetails d) async {
    setState(() => _busy = true);
    final changed = await houseJoinFlow(context, houseId: d.id, houseName: d.name, isOpen: d.isOpen);
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) _load(silent: true);
  }

  Future<void> _leave(HouseDetails d) async {
    final lastOne = d.memberCount <= 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave ${d.name}?', style: houseHeading(size: 20)),
        content: Text(
          lastOne
              ? 'You are the last member. The house will be closed for good.'
              : d.isCaptain
                  ? 'Leadership will pass to the next officer or longest-serving member.'
                  : 'You can join again later if the house is open or accepts your request.',
          style: const TextStyle(color: GacomColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay', style: TextStyle(color: GacomColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: GacomColors.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final res = await HouseService.leaveHouse(d.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.success) {
      GacomSnackbar.show(context, res.message, isError: true);
      return;
    }
    if (res.houseClosed) {
      GacomSnackbar.show(context, 'The house has been closed', isSuccess: true);
      context.go('/houses');
      return;
    }
    GacomSnackbar.show(context, 'You left ${d.name}', isSuccess: true);
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text(d?.name.toUpperCase() ?? 'HOUSE')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _message(_error!, retry: true)
              : d == null
                  ? _message('This house no longer exists.')
                  : RefreshIndicator(onRefresh: () => _load(silent: true), child: _content(d)),
    );
  }

  Widget _message(String text, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: retry ? () => _load() : () => context.go('/houses'),
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
              child: Text(retry ? 'TRY AGAIN' : 'BACK TO HOUSES', style: houseHeading(size: 14, color: Colors.white)),
            ),
          ]),
        ),
      );

  Widget _content(HouseDetails d) {
    final color = houseColor(d.colorHex);
    final goal = _goal;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Banner + emblem header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: houseBannerGradient(d.banner, d.colorHex),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.8), width: 1.5),
          ),
          child: Column(children: [
            HouseEmblem(emblem: d.emblem, colorHex: d.colorHex, size: 76),
            const SizedBox(height: 12),
            Text(d.name, textAlign: TextAlign.center, style: houseHeading(size: 26, color: Colors.white)),
            if (d.motto != null && d.motto!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('"${d.motto}"', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              HouseChip(
                label: d.isOpen ? 'OPEN' : 'CLOSED',
                color: d.isOpen ? GacomColors.success : GacomColors.warning,
                icon: d.isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
              ),
              HouseChip(label: '${d.memberCount}/${d.memberLimit} MEMBERS', color: Colors.white, icon: Icons.groups_rounded),
              if (d.myRole != null) HouseRoleChip(role: d.myRole!),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        if (d.description != null && d.description!.isNotEmpty) ...[
          Text(d.description!, style: const TextStyle(color: GacomColors.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
        ],
        // Stats
        Row(children: [
          _stat('RANK', d.rank > 0 ? '#${d.rank}' : '-', color),
          const SizedBox(width: 8),
          _stat('WEEKLY RANK', d.weekRank > 0 ? '#${d.weekRank}' : '-', color),
          const SizedBox(width: 8),
          _stat('POINTS', formatPoints(d.points), color),
        ]),
        const SizedBox(height: 14),
        _levelCard(d, color),
        const SizedBox(height: 14),
        if (goal != null) ...[
          HouseGoalCard(goal: goal, color: color),
          const SizedBox(height: 14),
        ],
        _warTable(d, color),
        _topMembers(d, color),
        _trophies(d),
        _members(d),
        const SizedBox(height: 16),
        _actions(d, color),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
          child: Column(children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: houseHeading(size: 20, color: color))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _levelCard(HouseDetails d, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('LEVEL ${d.level}', style: houseHeading(size: 16)),
            const Spacer(),
            Text('${formatPoints(d.points)} / ${formatPoints(d.nextLevelPoints)}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: d.levelProgress,
              minHeight: 8,
              backgroundColor: GacomColors.elevatedCard,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatPoints((d.nextLevelPoints - d.points) < 0 ? 0 : (d.nextLevelPoints - d.points))} points to level ${d.level + 1}. Higher levels raise the member limit.',
            style: const TextStyle(color: GacomColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text('${formatPoints(d.weekPoints)} points this week', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
        ]),
      );

  Widget _warTable(HouseDetails d, Color color) {
    if (_war.isEmpty) return const SizedBox.shrink();
    final rows = _war.take(5).toList();
    if (d.isMember && !rows.any((h) => h.id == d.id)) {
      for (final h in _war) {
        if (h.id == d.id) { rows.add(h); break; }
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('WEEKLY WAR', style: houseHeading(size: 14, color: GacomColors.textSecondary)),
          const Spacer(),
          const Text('Week points, resets weekly', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ...rows.map((h) {
          final mine = d.isMember && h.id == d.id;
          final c = houseColor(h.colorHex);
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mine ? c.withOpacity(0.14) : GacomColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mine ? c : GacomColors.border, width: mine ? 1.5 : 1),
            ),
            child: Row(children: [
              SizedBox(width: 34, child: Text('#${h.rank}', style: houseHeading(size: 15, color: h.rank <= 3 ? GacomColors.gold : GacomColors.textMuted))),
              HouseEmblem(emblem: h.emblem, colorHex: h.colorHex, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: houseHeading(size: 15))),
              if (mine) ...[const HouseChip(label: 'YOUR HOUSE', color: GacomColors.deepOrange), const SizedBox(width: 8)],
              Text(formatPoints(h.weekPoints), style: houseHeading(size: 16, color: c)),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _scopeTab(String label, bool active, VoidCallback onTap, Color color) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : GacomColors.border),
          ),
          child: Text(label, style: houseHeading(size: 11, color: active ? color : GacomColors.textMuted)),
        ),
      );

  Widget _topMembers(HouseDetails d, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('TOP MEMBERS', style: houseHeading(size: 14, color: GacomColors.textSecondary)),
            const Spacer(),
            _scopeTab('THIS WEEK', _topWeek, () => _setTopScope(true), color),
            const SizedBox(width: 6),
            _scopeTab('ALL TIME', !_topWeek, () => _setTopScope(false), color),
          ]),
          const SizedBox(height: 8),
          if (_top.isEmpty)
            const Text('No points scored yet.', style: TextStyle(color: GacomColors.textMuted))
          else
            ...List<Widget>.generate(_top.length, (k) {
              final m = _top[k];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
                child: Row(children: [
                  SizedBox(width: 28, child: Text('${k + 1}', style: houseHeading(size: 15, color: k < 3 ? GacomColors.gold : GacomColors.textMuted))),
                  houseAvatar(m.avatarUrl, m.name, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600))),
                  Text(formatPoints(m.points), style: houseHeading(size: 15, color: GacomColors.textSecondary)),
                ]),
              );
            }),
        ]),
      );

  Widget _trophies(HouseDetails d) {
    if (d.trophies.isEmpty) return const SizedBox.shrink();
    Color medal(int r) => r == 1 ? GacomColors.gold : (r == 2 ? const Color(0xFFC0C7D0) : const Color(0xFFCD7F32));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TROPHIES', style: houseHeading(size: 14, color: GacomColors.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.trophies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = d.trophies[i];
              final c = medal(t.rank);
              return Container(
                width: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.5))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.emoji_events_rounded, color: c, size: 26),
                  Text('Week of ${formatWeekStart(t.weekStart)}', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 10)),
                  Text('#${t.rank}', style: houseHeading(size: 13, color: c)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _members(HouseDetails d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MEMBERS (${d.memberCount})', style: houseHeading(size: 14, color: GacomColors.textSecondary)),
        const SizedBox(height: 8),
        if (d.members.isEmpty)
          const Text('No members yet.', style: TextStyle(color: GacomColors.textMuted))
        else
          ...d.members.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
                child: Row(children: [
                  houseAvatar(m.avatarUrl, m.name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      HouseRoleChip(role: m.role),
                    ]),
                  ),
                  Text(formatPoints(m.points), style: houseHeading(size: 15, color: GacomColors.textSecondary)),
                ]),
              )),
      ]);

  Widget _actions(HouseDetails d, Color color) {
    if (!d.isMember) {
      if (d.myRequestPending) {
        return _bigButton('REQUEST PENDING', Icons.hourglass_top_rounded, null, GacomColors.elevatedCard);
      }
      if (d.isFull && d.isOpen) {
        return _bigButton('HOUSE IS FULL', Icons.groups_rounded, null, GacomColors.elevatedCard);
      }
      return _bigButton(
        d.isOpen ? 'JOIN HOUSE' : 'REQUEST TO JOIN',
        d.isOpen ? Icons.person_add_rounded : Icons.lock_rounded,
        _busy ? null : () => _joinOrRequest(d),
        color,
      );
    }
    return Column(children: [
      _bigButton(
        'OPEN HOUSE CHAT',
        Icons.chat_bubble_outline_rounded,
        () => context.push('/houses/chat', extra: {'houseId': d.id, 'houseName': d.name}),
        color,
      ),
      if (d.canManage) ...[
        const SizedBox(height: 10),
        _bigButton(
          d.isCaptain ? 'MANAGE HOUSE' : 'MANAGE REQUESTS AND MEMBERS',
          Icons.settings_rounded,
          () => context.push('/houses/${d.id}/manage').then((_) { if (mounted) _load(silent: true); }),
          GacomColors.elevatedCard,
        ),
      ],
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _leave(d),
          icon: const Icon(Icons.logout_rounded, color: GacomColors.error, size: 18),
          label: Text('LEAVE HOUSE', style: houseHeading(size: 14, color: GacomColors.error)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.error), padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ),
    ]);
  }

  Widget _bigButton(String label, IconData icon, VoidCallback? onTap, Color bg) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 18),
          label: Text(label, style: houseHeading(size: 15, color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      );
}
