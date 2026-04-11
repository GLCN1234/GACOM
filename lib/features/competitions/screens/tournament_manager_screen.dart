import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class TournamentManagerScreen extends ConsumerStatefulWidget {
  final String competitionId;
  final bool isAdmin;
  const TournamentManagerScreen({super.key, required this.competitionId, this.isAdmin = false});

  @override
  ConsumerState<TournamentManagerScreen> createState() => _TournamentManagerScreenState();
}

class _TournamentManagerScreenState extends ConsumerState<TournamentManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _competition;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _teamRegistrations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.isAdmin ? 4 : 3;
    _tab = TabController(length: tabCount, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final comp = await SupabaseService.client
          .from('competitions').select('*').eq('id', widget.competitionId).single();

      final matches = await SupabaseService.client
          .from('tournament_matches')
          .select('*, player1:profiles!player1_id(id, username, display_name, avatar_url), player2:profiles!player2_id(id, username, display_name, avatar_url), team1:gaming_teams!team1_id(name, tag), team2:gaming_teams!team2_id(name, tag), winner:profiles!winner_id(display_name)')
          .eq('competition_id', widget.competitionId)
          .order('match_number');

      final rooms = await SupabaseService.client
          .from('game_rooms').select('*').eq('competition_id', widget.competitionId);

      final parts = await SupabaseService.client
          .from('competition_participants')
          .select('*, user:profiles!user_id(id, username, display_name, avatar_url, gamer_tag)')
          .eq('competition_id', widget.competitionId);

      final teamRegs = await SupabaseService.client
          .from('competition_team_registrations')
          .select('*, team:gaming_teams(name, tag, members_count, captain:profiles!captain_id(display_name))')
          .eq('competition_id', widget.competitionId);

      if (mounted) setState(() {
        _competition = comp;
        _matches = List<Map<String, dynamic>>.from(matches);
        _rooms = List<Map<String, dynamic>>.from(rooms);
        _participants = List<Map<String, dynamic>>.from(parts);
        _teamRegistrations = List<Map<String, dynamic>>.from(teamRegs);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateBracket() async {
    if (_participants.isEmpty) {
      GacomSnackbar.show(context, 'No participants registered yet', isError: true);
      return;
    }
    showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(
      backgroundColor: GacomColors.cardDark,
      content: Row(children: [
        CircularProgressIndicator(color: GacomColors.deepOrange),
        SizedBox(width: 16),
        Text('Generating bracket...', style: TextStyle(color: GacomColors.textPrimary)),
      ]),
    ));

    try {
      final playerIds = _participants.map((p) => p['user_id'] as String).toList()..shuffle();
      int bracketSize = 1;
      while (bracketSize < playerIds.length) bracketSize *= 2;

      // Delete old brackets/matches for this competition
      await SupabaseService.client.from('tournament_matches').delete().eq('competition_id', widget.competitionId);
      await SupabaseService.client.from('tournament_brackets').delete().eq('competition_id', widget.competitionId);

      final bracket = await SupabaseService.client.from('tournament_brackets').insert({
        'competition_id': widget.competitionId,
        'round_number': 1,
        'round_name': _roundName(bracketSize),
        'status': 'active',
      }).select().single();

      final matchInserts = <Map<String, dynamic>>[];
      for (int i = 0; i < bracketSize; i += 2) {
        final p1 = i < playerIds.length ? playerIds[i] : null;
        final p2 = (i + 1) < playerIds.length ? playerIds[i + 1] : null;
        final isBye = p2 == null;
        matchInserts.add({
          'competition_id': widget.competitionId,
          'bracket_id': bracket['id'],
          'match_number': (i ~/ 2) + 1,
          'player1_id': p1,
          'player2_id': p2,
          'match_type': 'solo',
          'is_bye': isBye,
          'status': isBye ? 'completed' : 'scheduled',
        });
      }

      await SupabaseService.client.from('tournament_matches').insert(matchInserts);
      await SupabaseService.client.from('competitions').update({'bracket_generated': true}).eq('id', widget.competitionId);

      if (mounted) {
        Navigator.pop(context);
        GacomSnackbar.show(context, 'Bracket generated! ${matchInserts.length} matches created.', isSuccess: true);
        _load();
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); GacomSnackbar.show(context, 'Failed: $e', isError: true); }
    }
  }

  String _roundName(int size) {
    if (size == 2) return 'Final';
    if (size == 4) return 'Semi Final';
    if (size == 8) return 'Quarter Final';
    return 'Round of $size';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'BRACKET'),
      const Tab(text: 'REGISTER'),
      const Tab(text: 'MY MATCH'),
      if (widget.isAdmin) const Tab(text: 'ADMIN'),
    ];

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(_competition?['title'] ?? 'TOURNAMENT'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
          isScrollable: true,
          tabs: tabs,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : TabBarView(controller: _tab, children: [
              _BracketTab(matches: _matches, competition: _competition),
              _RegisterTab(competition: _competition, participants: _participants, teamRegistrations: _teamRegistrations, onRefresh: _load),
              _MyMatchTab(matches: _matches, rooms: _rooms, onRefresh: _load),
              if (widget.isAdmin) _AdminTab(competitionId: widget.competitionId, rooms: _rooms, matches: _matches, participants: _participants, onRefresh: _load, onGenerateBracket: _generateBracket),
            ]),
    );
  }
}

// ── BRACKET TAB ───────────────────────────────────────────────────────────────
class _BracketTab extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic>? competition;
  const _BracketTab({required this.matches, this.competition});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.account_tree_outlined, size: 64, color: GacomColors.border),
        const SizedBox(height: 16),
        const Text('Bracket not generated yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
        const SizedBox(height: 8),
        Text('${competition?['current_participants'] ?? 0} participants registered', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      ]));
    }

    final scheduled = matches.where((m) => m['status'] != 'completed' && m['is_bye'] != true).toList();
    final completed = matches.where((m) => m['status'] == 'completed' && m['is_bye'] != true).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (scheduled.isNotEmpty) ...[
        const Text('UPCOMING MATCHES', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 10),
        ...scheduled.map((m) => _MatchCard(match: m).animate().fadeIn()),
        const SizedBox(height: 20),
      ],
      if (completed.isNotEmpty) ...[
        const Text('COMPLETED', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 10),
        ...completed.map((m) => _MatchCard(match: m, dimmed: true)),
      ],
    ]);
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool dimmed;
  const _MatchCard({required this.match, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final p1 = match['player1'] as Map<String, dynamic>?;
    final p2 = match['player2'] as Map<String, dynamic>?;
    final t1 = match['team1'] as Map<String, dynamic>?;
    final t2 = match['team2'] as Map<String, dynamic>?;
    final winner = match['winner'] as Map<String, dynamic>?;
    final status = match['status'] as String? ?? 'scheduled';
    final isTeam = match['match_type'] == 'team';

    Color statusColor;
    switch (status) {
      case 'live': statusColor = GacomColors.error; break;
      case 'completed': statusColor = GacomColors.success; break;
      case 'disputed': statusColor = GacomColors.warning; break;
      default: statusColor = GacomColors.textMuted;
    }

    return Opacity(
      opacity: dimmed ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: status == 'live' ? GacomColors.error.withOpacity(0.5) : GacomColors.border, width: status == 'live' ? 1.5 : 0.5),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(child: _PlayerSlot(name: isTeam ? (t1?['name'] ?? 'TBD') : (p1?['display_name'] ?? 'TBD'), tag: isTeam ? t1?['tag'] : null, isWinner: winner != null && winner['id'] == p1?['id'])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
              child: Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: statusColor, fontSize: 13)),
            ),
            Expanded(child: _PlayerSlot(name: isTeam ? (t2?['name'] ?? 'TBD') : (p2?['display_name'] ?? 'TBD'), tag: isTeam ? t2?['tag'] : null, isRight: true, isWinner: winner != null && winner['id'] == p2?['id'])),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Match #${match['match_number']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontFamily: 'Rajdhani')),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
            ]),
            if (match['room_id_assigned'] != null)
              Text('Room: ${match['room_id_assigned']}', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani')),
          ]),
        ]),
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final String name;
  final String? tag;
  final bool isRight;
  final bool isWinner;
  const _PlayerSlot({required this.name, this.tag, this.isRight = false, this.isWinner = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (tag != null) Text(tag!, style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
        Text(name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: isWinner ? GacomColors.success : GacomColors.textPrimary), textAlign: isRight ? TextAlign.end : TextAlign.start, overflow: TextOverflow.ellipsis),
        if (isWinner) const Text('WINNER', style: TextStyle(color: GacomColors.success, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── REGISTER TAB ──────────────────────────────────────────────────────────────
class _RegisterTab extends ConsumerWidget {
  final Map<String, dynamic>? competition;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> teamRegistrations;
  final Future<void> Function() onRefresh;
  const _RegisterTab({required this.competition, required this.participants, required this.teamRegistrations, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowsSolo = competition?['allows_solo_registration'] == true;
    final allowsTeam = competition?['allows_team_registration'] == true;
    final isPaid = competition?['competition_type'] == 'paid';
    final entryFee = (competition?['entry_fee'] as num?)?.toDouble() ?? 0;

    return ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REGISTRATION INFO', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 14),
          _InfoRow(label: 'Entry', value: isPaid ? '₦${entryFee.toStringAsFixed(0)}' : 'FREE'),
          _InfoRow(label: 'Solo Registration', value: allowsSolo ? 'YES' : 'NO'),
          _InfoRow(label: 'Team Registration', value: allowsTeam ? 'YES' : 'NO'),
          _InfoRow(label: 'Format', value: competition?['tournament_format'] ?? 'single_elimination'),
          _InfoRow(label: 'Total Registered', value: '${participants.length} solo · ${teamRegistrations.length} teams'),
        ]),
      ),
      const SizedBox(height: 20),
      if (allowsSolo) ...[
        GacomButton(label: 'REGISTER AS SOLO PLAYER', onPressed: () async {
          final userId = SupabaseService.currentUserId;
          if (userId == null) return;
          try {
            final exists = await SupabaseService.client.from('competition_participants').select('id').eq('competition_id', competition!['id']).eq('user_id', userId).maybeSingle();
            if (exists != null) { GacomSnackbar.show(context, 'Already registered!', isError: true); return; }
            await SupabaseService.client.from('competition_participants').insert({'competition_id': competition!['id'], 'user_id': userId, 'payment_status': isPaid ? 'pending' : 'free'});
            GacomSnackbar.show(context, 'Registered as solo player!', isSuccess: true);
            onRefresh();
          } catch (e) { GacomSnackbar.show(context, 'Error: $e', isError: true); }
        }),
        const SizedBox(height: 12),
      ],
      if (allowsTeam) ...[
        GacomButton(
          label: 'REGISTER YOUR TEAM',
          isOutlined: true,
          onPressed: () => _registerTeam(context),
        ),
        const SizedBox(height: 20),
      ],
      if (teamRegistrations.isNotEmpty) ...[
        const Text('REGISTERED TEAMS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...teamRegistrations.map((r) {
          final team = r['team'] as Map<String, dynamic>? ?? {};
          return Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(team['tag'] ?? '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(team['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                Text('${team['members_count'] ?? 0} members', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
                child: Text(r['payment_status']?.toString().toUpperCase() ?? 'PENDING', style: const TextStyle(color: GacomColors.success, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }),
      ],
    ]);
  }

  void _registerTeam(BuildContext context) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final mem = await SupabaseService.client.from('team_members').select('team_id').eq('user_id', userId).maybeSingle();
      if (mem == null) { GacomSnackbar.show(context, 'You need to be in a team first!', isError: true); return; }
      final teamId = mem['team_id'] as String;
      final exists = await SupabaseService.client.from('competition_team_registrations').select('id').eq('competition_id', competition!['id']).eq('team_id', teamId).maybeSingle();
      if (exists != null) { GacomSnackbar.show(context, 'Your team is already registered!', isError: true); return; }
      await SupabaseService.client.from('competition_team_registrations').insert({'competition_id': competition!['id'], 'team_id': teamId, 'registered_by': userId, 'payment_status': 'free'});
      GacomSnackbar.show(context, 'Team registered for competition!', isSuccess: true);
      onRefresh();
    } catch (e) { GacomSnackbar.show(context, 'Error: $e', isError: true); }
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
      Text(value, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Rajdhani')),
    ]),
  );
}

// ── MY MATCH TAB ──────────────────────────────────────────────────────────────
class _MyMatchTab extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> rooms;
  final Future<void> Function() onRefresh;
  const _MyMatchTab({required this.matches, required this.rooms, required this.onRefresh});

  @override
  ConsumerState<_MyMatchTab> createState() => _MyMatchTabState();
}

class _MyMatchTabState extends ConsumerState<_MyMatchTab> {
  final _evidenceCtrl = TextEditingController();

  Map<String, dynamic>? get _myMatch {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;
    for (final m in widget.matches) {
      if ((m['player1'] as Map?)?['id'] == userId || (m['player2'] as Map?)?['id'] == userId) {
        if (m['status'] != 'completed') return m;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final match = _myMatch;
    if (match == null) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.sports_esports_rounded, size: 64, color: GacomColors.border),
        SizedBox(height: 16),
        Text('No active match assigned', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
        SizedBox(height: 8),
        Text('You\'ll be notified when a match is ready', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      ]));
    }

    final p1 = match['player1'] as Map<String, dynamic>?;
    final p2 = match['player2'] as Map<String, dynamic>?;
    final roomId = match['room_id_assigned'];
    final roomPass = match['room_password_assigned'];
    final status = match['status'] as String? ?? 'scheduled';

    return ListView(padding: const EdgeInsets.all(20), children: [
      // Match info
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text('MATCH #${match['match_number']}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white70, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Text(p1?['display_name'] ?? 'TBD', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
            const Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white70)),
            Text(p2?['display_name'] ?? 'TBD', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
            child: Text(status.toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12, letterSpacing: 1)),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // Room credentials
      if (roomId != null) ...[
        const Text('ROOM CREDENTIALS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
          child: Column(children: [
            _CredRow(label: 'Room ID', value: roomId),
            if (roomPass != null) _CredRow(label: 'Password', value: roomPass),
            const SizedBox(height: 8),
            const Text('⚠️ Do not share these credentials', style: TextStyle(color: GacomColors.warning, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 20),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: const Row(children: [
            Icon(Icons.schedule_rounded, color: GacomColors.textMuted, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Room credentials will appear here when your match is ready. You\'ll be notified.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 20),
      ],

      // Submit result
      if (status == 'room_assigned' || status == 'live') ...[
        const Text('SUBMIT RESULT', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 12),
        _SubmitResultCard(match: match, onRefresh: widget.onRefresh),
        const SizedBox(height: 20),
      ],

      // Report dispute
      GacomButton(
        label: 'REPORT ISSUE / DISPUTE',
        isOutlined: true,
        onPressed: () => _showDisputeSheet(context, match['id']),
      ),
    ]);
  }

  void _showDisputeSheet(BuildContext context, String matchId) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Report Dispute', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
          const SizedBox(height: 16),
          GacomTextField(controller: reasonCtrl, label: 'Describe the issue', hint: 'What happened?', maxLines: 4),
          const SizedBox(height: 20),
          GacomButton(label: 'SUBMIT REPORT', onPressed: () async {
            final userId = SupabaseService.currentUserId;
            if (userId == null || reasonCtrl.text.trim().isEmpty) return;
            await SupabaseService.client.from('match_disputes').insert({'match_id': matchId, 'reported_by': userId, 'reason': reasonCtrl.text.trim()});
            if (ctx.mounted) Navigator.pop(ctx);
            GacomSnackbar.show(context, 'Dispute filed. Admins will review it.', isSuccess: true);
          }),
        ]),
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label, value;
  const _CredRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
      SelectableText(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.deepOrange, fontSize: 16)),
    ]),
  );
}

class _SubmitResultCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> match;
  final Future<void> Function() onRefresh;
  const _SubmitResultCard({required this.match, required this.onRefresh});

  @override
  ConsumerState<_SubmitResultCard> createState() => _SubmitResultCardState();
}

class _SubmitResultCardState extends ConsumerState<_SubmitResultCard> {
  String? _selectedWinnerId;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final p1 = widget.match['player1'] as Map<String, dynamic>?;
    final p2 = widget.match['player2'] as Map<String, dynamic>?;
    final userId = SupabaseService.currentUserId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Who won?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, color: GacomColors.textPrimary, fontSize: 16)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _WinnerOption(name: p1?['display_name'] ?? 'Player 1', playerId: p1?['id'], selected: _selectedWinnerId == p1?['id'], onTap: () => setState(() => _selectedWinnerId = p1?['id']))),
          const SizedBox(width: 10),
          Expanded(child: _WinnerOption(name: p2?['display_name'] ?? 'Player 2', playerId: p2?['id'], selected: _selectedWinnerId == p2?['id'], onTap: () => setState(() => _selectedWinnerId = p2?['id']))),
        ]),
        const SizedBox(height: 12),
        GacomTextField(controller: _notesCtrl, label: 'Notes (optional)', hint: 'e.g. Final score 3-1', maxLines: 2),
        const SizedBox(height: 16),
        GacomButton(
          label: 'SUBMIT RESULT',
          isLoading: _submitting,
          onPressed: _selectedWinnerId == null ? null : () async {
            setState(() => _submitting = true);
            try {
              await SupabaseService.client.from('match_results').insert({
                'match_id': widget.match['id'],
                'submitted_by': userId,
                'claimed_winner_id': _selectedWinnerId,
                'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              });

              // Check if both players submitted and agree
              final results = await SupabaseService.client.from('match_results').select('claimed_winner_id').eq('match_id', widget.match['id']);
              if (results.length == 2) {
                final ids = (results as List).map((r) => r['claimed_winner_id']).toSet();
                if (ids.length == 1) {
                  // Both agree — mark match complete
                  await SupabaseService.client.from('tournament_matches').update({'status': 'completed', 'winner_id': ids.first}).eq('id', widget.match['id']);
                  if (mounted) GacomSnackbar.show(context, 'Result confirmed! Match complete.', isSuccess: true);
                } else {
                  // Disagreement — flag as disputed
                  await SupabaseService.client.from('tournament_matches').update({'status': 'disputed'}).eq('id', widget.match['id']);
                  if (mounted) GacomSnackbar.show(context, 'Results conflict. Admins will review.', isError: false);
                }
              } else {
                if (mounted) GacomSnackbar.show(context, 'Result submitted. Waiting for opponent.', isSuccess: true);
              }
              widget.onRefresh();
            } catch (e) {
              if (mounted) GacomSnackbar.show(context, 'Failed: $e', isError: true);
            } finally {
              if (mounted) setState(() => _submitting = false);
            }
          },
        ),
      ]),
    );
  }
}

class _WinnerOption extends StatelessWidget {
  final String name;
  final String? playerId;
  final bool selected;
  final VoidCallback onTap;
  const _WinnerOption({required this.name, this.playerId, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? GacomColors.deepOrange : GacomColors.border, width: selected ? 1.5 : 0.5),
      ),
      child: Column(children: [
        Icon(Icons.emoji_events_rounded, color: selected ? GacomColors.deepOrange : GacomColors.textMuted, size: 24),
        const SizedBox(height: 6),
        Text(name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: selected ? GacomColors.deepOrange : GacomColors.textPrimary, fontSize: 14), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ── ADMIN TAB ─────────────────────────────────────────────────────────────────
class _AdminTab extends ConsumerStatefulWidget {
  final String competitionId;
  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> participants;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onGenerateBracket;

  const _AdminTab({required this.competitionId, required this.rooms, required this.matches, required this.participants, required this.onRefresh, required this.onGenerateBracket});

  @override
  ConsumerState<_AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends ConsumerState<_AdminTab> {
  final _roomNameCtrl = TextEditingController();
  final _roomCodeCtrl = TextEditingController();
  final _roomPassCtrl = TextEditingController();

  void _showAddRoomSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Game Room', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Enter room credentials created in the game.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          GacomTextField(controller: _roomNameCtrl, label: 'Room Label', hint: 'e.g. Room A', prefixIcon: Icons.meeting_room_rounded),
          const SizedBox(height: 12),
          GacomTextField(controller: _roomCodeCtrl, label: 'Room ID / Code *', hint: 'The in-game room ID', prefixIcon: Icons.tag_rounded),
          const SizedBox(height: 12),
          GacomTextField(controller: _roomPassCtrl, label: 'Room Password', hint: 'Leave blank if no password', prefixIcon: Icons.lock_outline_rounded),
          const SizedBox(height: 20),
          GacomButton(label: 'ADD ROOM', onPressed: () async {
            if (_roomCodeCtrl.text.trim().isEmpty) { GacomSnackbar.show(ctx, 'Room code is required', isError: true); return; }
            await SupabaseService.client.from('game_rooms').insert({
              'competition_id': widget.competitionId,
              'room_name': _roomNameCtrl.text.trim().isEmpty ? 'Room' : _roomNameCtrl.text.trim(),
              'room_code': _roomCodeCtrl.text.trim(),
              'room_password': _roomPassCtrl.text.trim().isEmpty ? null : _roomPassCtrl.text.trim(),
              'created_by': SupabaseService.currentUserId,
            });
            _roomNameCtrl.clear(); _roomCodeCtrl.clear(); _roomPassCtrl.clear();
            if (ctx.mounted) Navigator.pop(ctx);
            GacomSnackbar.show(context, 'Room added!', isSuccess: true);
            widget.onRefresh();
          }),
        ]),
      ),
    );
  }

  Future<void> _assignRoomToMatch(String matchId, String roomCode, String? roomPass) async {
    await SupabaseService.client.from('tournament_matches').update({
      'room_id_assigned': roomCode,
      'room_password_assigned': roomPass,
      'room_assigned_at': DateTime.now().toIso8601String(),
      'status': 'room_assigned',
    }).eq('id', matchId);
    GacomSnackbar.show(context, 'Room assigned to match!', isSuccess: true);
    widget.onRefresh();
  }

  Future<void> _declareWinner(String matchId, String winnerId) async {
    await SupabaseService.client.from('tournament_matches').update({'winner_id': winnerId, 'status': 'completed'}).eq('id', matchId);
    GacomSnackbar.show(context, 'Winner declared!', isSuccess: true);
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final pendingMatches = widget.matches.where((m) => m['status'] == 'scheduled' || m['status'] == 'disputed').toList();
    final disputedMatches = widget.matches.where((m) => m['status'] == 'disputed').toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Actions
      Row(children: [
        Expanded(child: GacomButton(label: 'GENERATE BRACKET', height: 48, onPressed: widget.onGenerateBracket)),
        const SizedBox(width: 10),
        Expanded(child: GacomButton(label: '+ ADD ROOM', height: 48, isOutlined: true, onPressed: _showAddRoomSheet)),
      ]),
      const SizedBox(height: 20),

      // Stats
      Row(children: [
        _AdminStat(label: 'Participants', value: '${widget.participants.length}', icon: Icons.people_rounded),
        const SizedBox(width: 10),
        _AdminStat(label: 'Matches', value: '${widget.matches.length}', icon: Icons.sports_esports_rounded),
        const SizedBox(width: 10),
        _AdminStat(label: 'Rooms', value: '${widget.rooms.length}', icon: Icons.meeting_room_rounded),
      ]),
      const SizedBox(height: 20),

      // Disputed matches
      if (disputedMatches.isNotEmpty) ...[
        const Text('⚠️ DISPUTED MATCHES', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.warning, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...disputedMatches.map((m) {
          final p1 = m['player1'] as Map<String, dynamic>?;
          final p2 = m['player2'] as Map<String, dynamic>?;
          return Container(
            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.warning.withOpacity(0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Match #${m['match_number']}: ${p1?['display_name'] ?? 'TBD'} vs ${p2?['display_name'] ?? 'TBD'}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Declare winner:', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                if (p1 != null) Expanded(child: SizedBox(height: 36, child: ElevatedButton(
                  onPressed: () => _declareWinner(m['id'], p1['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text(p1['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
                ))),
                if (p1 != null && p2 != null) const SizedBox(width: 8),
                if (p2 != null) Expanded(child: SizedBox(height: 36, child: ElevatedButton(
                  onPressed: () => _declareWinner(m['id'], p2['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text(p2['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
                ))),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 10),
      ],

      // Game Rooms
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('GAME ROOMS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
        Text('${widget.rooms.length} rooms', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      ]),
      const SizedBox(height: 10),
      if (widget.rooms.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('No rooms added yet. Add rooms created in the game above.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13), textAlign: TextAlign.center))
      else
        ...widget.rooms.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Row(children: [
            const Icon(Icons.meeting_room_rounded, color: GacomColors.deepOrange, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['room_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
              Text('ID: ${r['room_code']}${r['room_password'] != null ? '  Pass: ${r['room_password']}' : ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            ])),
            // Assign to match dropdown
            if (pendingMatches.isNotEmpty) PopupMenuButton<String>(
              color: GacomColors.cardDark,
              onSelected: (matchId) => _assignRoomToMatch(matchId, r['room_code'], r['room_password']),
              itemBuilder: (_) => pendingMatches.map((m) {
                final p1 = m['player1'] as Map?;
                final p2 = m['player2'] as Map?;
                return PopupMenuItem(value: m['id'] as String, child: Text('Match #${m['match_number']}: ${p1?['display_name'] ?? 'TBD'} vs ${p2?['display_name'] ?? 'TBD'}', style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13)));
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
                child: const Text('ASSIGN', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ]),
        )),
    ]);
  }
}

class _AdminStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _AdminStat({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
      child: Column(children: [
        Icon(icon, color: GacomColors.deepOrange, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
        Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
      ]),
    ),
  );
}
