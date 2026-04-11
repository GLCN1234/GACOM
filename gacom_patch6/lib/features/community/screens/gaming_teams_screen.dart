import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class GamingTeamsScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String? gameName;
  const GamingTeamsScreen({super.key, required this.communityId, this.gameName});

  @override
  ConsumerState<GamingTeamsScreen> createState() => _GamingTeamsScreenState();
}

class _GamingTeamsScreenState extends ConsumerState<GamingTeamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _allTeams = [];
  String? _myTeamId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUserId;
    try {
      final teams = await SupabaseService.client
          .from('gaming_teams')
          .select('*, captain:profiles!captain_id(username, display_name, avatar_url), members:team_members(role, user:profiles!user_id(id, username, display_name, avatar_url))')
          .eq('community_id', widget.communityId)
          .order('wins', ascending: false);

      String? myTeamId;
      if (userId != null) {
        final mem = await SupabaseService.client
            .from('team_members')
            .select('team_id')
            .eq('user_id', userId)
            .maybeSingle();
        myTeamId = mem?['team_id'] as String?;
      }

      if (mounted) setState(() {
        _allTeams = List<Map<String, dynamic>>.from(teams);
        _myTeamId = myTeamId;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinTeam(String teamId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (_myTeamId != null) {
      GacomSnackbar.show(context, 'Leave your current team first.', isError: true);
      return;
    }
    try {
      await SupabaseService.client.from('team_members').insert({'team_id': teamId, 'user_id': userId, 'role': 'member'});
      GacomSnackbar.show(context, 'Joined team! 🎮', isSuccess: true);
      _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Failed to join team', isError: true);
    }
  }

  void _showCreateTeamSheet() {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create Your Team', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('You will become the team captain.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          GacomTextField(controller: nameCtrl, label: 'Team Name *', hint: 'e.g. Shadow Wolves', prefixIcon: Icons.groups_rounded),
          const SizedBox(height: 12),
          GacomTextField(controller: tagCtrl, label: 'Team Tag * (max 5 chars)', hint: 'e.g. WOLF', prefixIcon: Icons.tag_rounded, maxLength: 5),
          const SizedBox(height: 12),
          GacomTextField(controller: descCtrl, label: 'Description', hint: 'Tell others about your team...', maxLines: 2),
          const SizedBox(height: 24),
          GacomButton(label: 'CREATE TEAM', onPressed: () async {
            final name = nameCtrl.text.trim();
            final tag = tagCtrl.text.trim().toUpperCase();
            if (name.isEmpty || tag.isEmpty) {
              GacomSnackbar.show(ctx, 'Name and tag are required', isError: true);
              return;
            }
            if (_myTeamId != null) {
              GacomSnackbar.show(ctx, 'Leave your current team first', isError: true);
              return;
            }
            final userId = SupabaseService.currentUserId;
            if (userId == null) return;
            try {
              final team = await SupabaseService.client.from('gaming_teams').insert({
                'name': name, 'tag': tag,
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'community_id': widget.communityId,
                'captain_id': userId,
                'game_name': widget.gameName,
              }).select().single();
              await SupabaseService.client.from('team_members').insert({
                'team_id': team['id'], 'user_id': userId, 'role': 'captain',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              GacomSnackbar.show(context, 'Team "$name" created! 🔥', isSuccess: true);
              _load();
            } catch (e) {
              GacomSnackbar.show(ctx, 'Error: $e', isError: true);
            }
          }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('GAMING TEAMS'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: 'ALL TEAMS'), Tab(text: 'MY TEAM')],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _buildAllTeams(),
        _MyTeamTab(myTeamId: _myTeamId, onRefresh: _load),
      ]),
    );
  }

  Widget _buildAllTeams() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_myTeamId == null)
          GacomButton(label: '+ CREATE YOUR TEAM', isOutlined: true, height: 48, onPressed: _showCreateTeamSheet),
        const SizedBox(height: 16),
        if (_allTeams.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('No teams yet. Create the first one!', style: TextStyle(color: GacomColors.textMuted), textAlign: TextAlign.center),
          ))
        else
          ..._allTeams.asMap().entries.map((e) =>
            _TeamCard(team: e.value, myTeamId: _myTeamId, onJoin: () => _joinTeam(e.value['id']))
                .animate(delay: (e.key * 60).ms).fadeIn().slideY(begin: 0.2, end: 0)),
      ]),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final String? myTeamId;
  final VoidCallback onJoin;
  const _TeamCard({required this.team, required this.myTeamId, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final captain = team['captain'] as Map<String, dynamic>? ?? {};
    final members = team['members'] as List? ?? [];
    final maxMembers = team['max_members'] ?? 5;
    final isMyTeam = myTeamId == team['id'];
    final isRecruiting = team['is_recruiting'] == true;
    final wins = team['wins'] ?? 0;
    final losses = team['losses'] ?? 0;
    final isFull = members.length >= maxMembers;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isMyTeam ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border, width: isMyTeam ? 1.5 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(team['tag'] ?? '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(team['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.textPrimary), overflow: TextOverflow.ellipsis)),
              if (isMyTeam) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(50)), child: const Text('MY TEAM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani'))),
              ],
            ]),
            Text('Captain: ${captain['display_name'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$wins W - $losses L', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.deepOrange, fontSize: 13)),
            Text('${members.length}/$maxMembers', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          ]),
        ]),
        if (team['description'] != null) ...[
          const SizedBox(height: 8),
          Text(team['description'], style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 12),
        Row(children: [
          ...members.take(5).map((m) {
            final u = m['user'] as Map<String, dynamic>? ?? {};
            return Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.obsidian, width: 2)),
              child: CircleAvatar(radius: 14, backgroundColor: GacomColors.border,
                backgroundImage: u['avatar_url'] != null ? CachedNetworkImageProvider(u['avatar_url']) : null,
                child: u['avatar_url'] == null ? Text((u['display_name'] ?? 'G')[0], style: const TextStyle(fontSize: 10, color: GacomColors.textPrimary)) : null),
            );
          }),
          const Spacer(),
          if (!isMyTeam && isRecruiting && myTeamId == null && !isFull)
            SizedBox(height: 34, child: ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              child: const Text('JOIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1)),
            ))
          else if (isFull || !isRecruiting)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(50)), child: const Text('FULL', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}

class _MyTeamTab extends ConsumerStatefulWidget {
  final String? myTeamId;
  final Future<void> Function() onRefresh;
  const _MyTeamTab({required this.myTeamId, required this.onRefresh});

  @override
  ConsumerState<_MyTeamTab> createState() => _MyTeamTabState();
}

class _MyTeamTabState extends ConsumerState<_MyTeamTab> {
  Map<String, dynamic>? _team;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_MyTeamTab old) {
    super.didUpdateWidget(old);
    if (old.myTeamId != widget.myTeamId) _load();
  }

  Future<void> _load() async {
    if (widget.myTeamId == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final team = await SupabaseService.client
          .from('gaming_teams')
          .select('*, captain:profiles!captain_id(id, username, display_name, avatar_url), members:team_members(role, user:profiles!user_id(id, username, display_name, avatar_url, gamer_tag))')
          .eq('id', widget.myTeamId!)
          .single();
      if (mounted) setState(() { _team = team; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_team == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.group_add_rounded, size: 64, color: GacomColors.border),
        const SizedBox(height: 16),
        const Text('You\'re not in a team yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Join or create one from All Teams tab', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      ]));
    }

    final team = _team!;
    final members = team['members'] as List? ?? [];
    final userId = SupabaseService.currentUserId;
    final isCaptain = team['captain_id'] == userId;

    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Center(child: Text(team['tag'] ?? '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 28, color: Colors.white))),
            ),
            const SizedBox(height: 12),
            Text(team['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('${team['wins'] ?? 0}W  ${team['losses'] ?? 0}L  ₦${(team['total_earnings'] ?? 0).toStringAsFixed(0)} earned', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 24),

        const Text('ROSTER', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...members.map((m) {
          final u = m['user'] as Map<String, dynamic>? ?? {};
          final role = m['role'] as String? ?? 'member';
          return Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: GacomColors.border,
                backgroundImage: u['avatar_url'] != null ? CachedNetworkImageProvider(u['avatar_url']) : null,
                child: u['avatar_url'] == null ? Text((u['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary)) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 15)),
                if (u['gamer_tag'] != null) Text(u['gamer_tag'], style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'captain' ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(role.toUpperCase(), style: TextStyle(color: role == 'captain' ? GacomColors.deepOrange : GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')),
              ),
            ]),
          );
        }),

        if (isCaptain) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Open Recruitment', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, color: GacomColors.textPrimary, fontSize: 15)),
                const Text('Allow others to join your team', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              Switch(
                value: team['is_recruiting'] == true,
                activeColor: GacomColors.deepOrange,
                onChanged: (v) async {
                  await SupabaseService.client.from('gaming_teams').update({'is_recruiting': v}).eq('id', team['id']);
                  _load();
                },
              ),
            ]),
          ),
        ],

        const SizedBox(height: 20),
        GacomButton(
          label: isCaptain ? 'DISBAND TEAM' : 'LEAVE TEAM',
          isOutlined: true,
          onPressed: () async {
            if (userId == null) return;
            if (isCaptain) {
              await SupabaseService.client.from('gaming_teams').delete().eq('id', team['id']);
            } else {
              await SupabaseService.client.from('team_members').delete().eq('team_id', team['id']).eq('user_id', userId);
            }
            widget.onRefresh();
            if (mounted) GacomSnackbar.show(context, isCaptain ? 'Team disbanded.' : 'Left team.', isSuccess: true);
          },
        ),
      ]),
    );
  }
}
