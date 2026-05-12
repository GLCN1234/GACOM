import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../services/arena_service.dart';

import 'match_screen.dart';

class ArenaScreen extends ConsumerStatefulWidget {
  const ArenaScreen({super.key});
  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic> _settings = {};
  double _walletBalance = 0;
  List<Map<String, dynamic>> _openMatches = [];
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;
  String _selectedGame = 'chess';
  int _selectedStake = 1000;
  bool _creating = false;

  final _games = [
    {'id': 'chess', 'name': 'Chess', 'icon': '♟️', 'meta': 'Pure strategy', 'tag': 'HOT', 'bg': const Color(0xFFFAECE7)},
    {'id': 'tictactoe', 'name': 'Tic-Tac-Toe', 'icon': '✖️', 'meta': '3 min avg', 'tag': 'LIVE', 'bg': const Color(0xFFE1F5EE)},
    {'id': 'rps', 'name': 'RPS Battle', 'icon': '🪨', 'meta': 'Best of 5', 'tag': '', 'bg': const Color(0xFFE6F1FB)},
    {'id': 'trivia', 'name': 'Trivia', 'icon': '🧠', 'meta': '10 questions', 'tag': 'NEW', 'bg': const Color(0xFFEEEDFE)},
    {'id': 'reaction', 'name': 'Reaction', 'icon': '⚡', 'meta': 'Tap fastest', 'tag': '', 'bg': const Color(0xFFEAF3DE)},
  ];

  final _stakes = [200, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ArenaService.getSettings(),
      ArenaService.getWalletBalance(),
      _fetchOpenMatches(),
      ArenaService.getLeaderboard(),
    ]);
    if (mounted) setState(() {
      _settings = results[0] as Map<String, dynamic>;
      _walletBalance = results[1] as double;
      _openMatches = results[2] as List<Map<String, dynamic>>;
      _leaderboard = results[3] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchOpenMatches() async {
    try {
      final data = await SupabaseService.client.from('arena_matches')
          .select('*, creator:profiles!creator_id(username, display_name, avatar_url)')
          .eq('status', 'waiting')
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) { return []; }
  }

  Future<void> _createMatch() async {
    if (_creating) return;
    final banned = await ArenaService.isUserBanned(SupabaseService.currentUserId!);
    if (banned && mounted) { _showBanned(); return; }
    if (_walletBalance < _selectedStake && mounted) {
      _showInsufficientFunds(); return;
    }
    setState(() => _creating = true);
    final match = await ArenaService.createMatch(gameType: _selectedGame, stakeAmount: _selectedStake);
    if (mounted) setState(() => _creating = false);
    if (match != null && mounted) {
      context.push('/arena/match/${match['id']}');
    } else if (mounted) {
      _showError('Could not create match. Please try again.');
    }
  }

  Future<void> _joinMatch(Map<String, dynamic> match) async {
    final banned = await ArenaService.isUserBanned(SupabaseService.currentUserId!);
    if (banned && mounted) { _showBanned(); return; }
    if (_walletBalance < (match['stake_amount'] as int) && mounted) {
      _showInsufficientFunds(); return;
    }
    final joined = await ArenaService.joinMatch(match['id'] as String);
    if (joined != null && mounted) {
      context.push('/arena/match/${match['id']}');
    } else if (mounted) {
      _showError('Could not join match. It may have been taken.');
    }
  }

  void _showInsufficientFunds() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Insufficient Balance', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary, fontSize: 18)),
      content: Text('You need ₦${_selectedStake.toStringAsFixed(0)} in your arena wallet. Top up to continue.', style: const TextStyle(color: GacomColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(onPressed: () { Navigator.pop(context); context.go('/wallet'); }, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('TOP UP', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800))),
      ],
    ),
  );

  void _showBanned() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      title: const Text('Arena Access Restricted', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.error, fontSize: 18)),
      content: const Text('Your arena access has been restricted by an admin.', style: TextStyle(color: GacomColors.textSecondary)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  void _showError(String msg) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      title: const Text('Error', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
      content: Text(msg, style: const TextStyle(color: GacomColors.textSecondary)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  int get _fee => ((_selectedStake * 2) * (_settings['platform_fee_percent'] ?? 15) / 100).round();
  int get _winnerPayout => (_selectedStake * 2) - _fee;

  @override
  Widget build(BuildContext context) {
    final arenaEnabled = _settings['arena_enabled'] as bool? ?? true;
    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(
        title: const Text('GACOM ARENA'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(icon: const Icon(Icons.history_rounded), onPressed: () => _tab.animateTo(3)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : !arenaEnabled
              ? _ArenaDisabled()
              : Column(children: [
                  _WalletBar(balance: _walletBalance),
                  TabBar(
                    controller: _tab,
                    indicatorColor: GacomColors.deepOrange,
                    labelColor: GacomColors.deepOrange,
                    unselectedLabelColor: GacomColors.txtMuted(context),
                    labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12),
                    tabs: const [Tab(text: 'BROWSE'), Tab(text: 'LIVE'), Tab(text: 'TOP PLAYERS'), Tab(text: 'HISTORY')],
                  ),
                  Expanded(child: TabBarView(controller: _tab, children: [
                    _buildBrowse(),
                    _buildLive(),
                    _buildLeaderboard(),
                    _buildHistory(),
                  ])),
                ]),
    );
  }

  Widget _buildBrowse() => RefreshIndicator(
    color: GacomColors.deepOrange,
    onRefresh: _load,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Skill badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, size: 13, color: Color(0xFF085041)),
            SizedBox(width: 6),
            Text('100% Skill Competition — No Gambling', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF085041))),
          ]),
        ),
        const SizedBox(height: 20),

        // Game selector
        _SectionLabel('Choose a game'),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _games.length,
            itemBuilder: (_, i) {
              final g = _games[i];
              final sel = _selectedGame == g['id'];
              final gEnabled = _settings['${g['id']}_enabled'] as bool? ?? true;
              return GestureDetector(
                onTap: gEnabled ? () { setState(() => _selectedGame = g['id'] as String); HapticFeedback.selectionClick(); } : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GacomColors.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.borderColor(context), width: sel ? 1.5 : 0.5),
                    boxShadow: sel ? [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.15), blurRadius: 12)] : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((g['tag'] as String).isNotEmpty) ...[
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(g['tag'] as String, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: GacomColors.deepOrange))),
                      const SizedBox(height: 4),
                    ],
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: g['bg'] as Color, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(g['icon'] as String, style: const TextStyle(fontSize: 18)))),
                    const SizedBox(height: 8),
                    Text(g['name'] as String, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: sel ? GacomColors.deepOrange : GacomColors.txtPrimary(context))),
                    Text(g['meta'] as String, style: TextStyle(fontSize: 10, color: GacomColors.txtMuted(context))),
                    if (!gEnabled) Text('Disabled', style: const TextStyle(fontSize: 9, color: GacomColors.textMuted)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Stake selector
        _SectionLabel('Set your stake'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _stakes.map((s) {
            final sel = _selectedStake == s;
            return GestureDetector(
              onTap: () { setState(() => _selectedStake = s); HapticFeedback.selectionClick(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? GacomColors.deepOrange.withOpacity(0.1) : GacomColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.borderColor(context), width: sel ? 1.5 : 0.5),
                ),
                child: Text('₦${s.toStringAsFixed(0)}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: sel ? GacomColors.deepOrange : GacomColors.txtPrimary(context))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Fee breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
          child: Column(children: [
            _FeeRow('Your stake', '₦${_selectedStake.toStringAsFixed(0)}'),
            _FeeRow('Opponent stake', '₦${_selectedStake.toStringAsFixed(0)}'),
            _FeeRow('Total pot', '₦${(_selectedStake * 2).toStringAsFixed(0)}'),
            _FeeRow('GACOM fee (${_settings['platform_fee_percent'] ?? 15}%)', '−₦${_fee.toStringAsFixed(0)}', color: GacomColors.error),
            const Divider(height: 16),
            _FeeRow('Winner takes home', '₦${_winnerPayout.toStringAsFixed(0)}', color: GacomColors.success, bold: true),
          ]),
        ),
        const SizedBox(height: 14),

        // Voice note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
          child: Row(children: [
            const Icon(Icons.mic_rounded, color: GacomColors.success, size: 16),
            const SizedBox(width: 8),
            Text('Live voice chat active during match · Mute anytime', style: TextStyle(fontSize: 12, color: GacomColors.txtSecondary(context))),
          ]),
        ),
        const SizedBox(height: 16),

        // Find opponent button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _creating ? null : _createMatch,
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _creating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('FIND OPPONENT & START MATCH', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 30),
      ]),
    ),
  );

  Widget _buildLive() => RefreshIndicator(
    color: GacomColors.deepOrange,
    onRefresh: () async { final m = await _fetchOpenMatches(); if (mounted) setState(() => _openMatches = m); },
    child: _openMatches.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.sports_esports_outlined, size: 64, color: GacomColors.borderColor(context)),
            const SizedBox(height: 16),
            Text('No open matches right now', style: TextStyle(color: GacomColors.txtMuted(context), fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Create one in Browse tab', style: TextStyle(color: GacomColors.txtMuted(context), fontSize: 13)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _openMatches.length,
            itemBuilder: (_, i) {
              final m = _openMatches[i];
              final creator = m['creator'] as Map?;
              final name = creator?['username'] ?? creator?['display_name'] ?? 'Player';
              final gameId = m['game_type'] as String;
              final game = _games.firstWhere((g) => g['id'] == gameId, orElse: () => _games[0]);
              final isOwn = m['creator_id'] == SupabaseService.currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
                child: Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: game['bg'] as Color, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(game['icon'] as String, style: const TextStyle(fontSize: 22)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.txtPrimary(context))),
                    Text('${game['name']} · Waiting for opponent', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₦${(m['stake_amount'] as int).toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.deepOrange)),
                    const SizedBox(height: 4),
                    if (!isOwn) GestureDetector(
                      onTap: () => _joinMatch(m),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(20)), child: const Text('JOIN', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12))),
                    ) else Text('Your match', style: TextStyle(fontSize: 10, color: GacomColors.txtMuted(context))),
                  ]),
                ]),
              );
            }),
  );

  Widget _buildLeaderboard() => RefreshIndicator(
    color: GacomColors.deepOrange,
    onRefresh: () async { final lb = await ArenaService.getLeaderboard(); if (mounted) setState(() => _leaderboard = lb); },
    child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 16), child: _SectionLabel('Top earners all time'));
        final entry = _leaderboard[i - 1];
        final profile = entry['profile'] as Map? ?? {};
        final name = profile['username'] ?? profile['display_name'] ?? 'Player';
        final rank = i;
        final rankColor = rank == 1 ? const Color(0xFFBA7517) : rank == 2 ? const Color(0xFF888780) : rank == 3 ? const Color(0xFF993C1D) : GacomColors.textMuted;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: rank <= 3 ? GacomColors.deepOrange.withOpacity(0.05) : GacomColors.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: rank <= 3 ? GacomColors.deepOrange.withOpacity(0.2) : GacomColors.borderColor(context), width: 0.5)),
          child: Row(children: [
            SizedBox(width: 28, child: Text('$rank', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: rankColor))),
            CircleAvatar(backgroundColor: GacomColors.deepOrange.withOpacity(0.15), radius: 18, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.txtPrimary(context))),
              Text('${entry['wins']} wins', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
            ])),
            Text('+₦${(entry['total_earnings'] as int).toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.success)),
          ]),
        );
      },
    ),
  );

  Widget _buildHistory() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return const SizedBox();
    return FutureBuilder(
      future: SupabaseService.client.from('arena_matches').select('*, creator:profiles!creator_id(username), opponent:profiles!opponent_id(username)').or('creator_id.eq.$uid,opponent_id.eq.$uid').order('created_at', ascending: false).limit(30),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
        final matches = List<Map<String, dynamic>>.from(snap.data as List);
        if (matches.isEmpty) return Center(child: Text('No matches yet', style: TextStyle(color: GacomColors.txtMuted(context), fontFamily: 'Rajdhani', fontSize: 18)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (_, i) {
            final m = matches[i];
            final isWinner = m['winner_id'] == uid;
            final status = m['status'] as String;
            final statusColor = status == 'completed' ? (isWinner ? GacomColors.success : GacomColors.error) : status == 'active' ? GacomColors.warning : GacomColors.textMuted;
            final statusText = status == 'completed' ? (isWinner ? 'WON' : 'LOST') : status.toUpperCase();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m['game_type'].toString().toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.txtPrimary(context))),
                  Text('Stake: ₦${(m['stake_amount'] as int).toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.4))), child: Text(statusText, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: statusColor))),
                if (status == 'completed' && isWinner) ...[
                  const SizedBox(width: 8),
                  Text('+₦${(m['winner_payout'] as int? ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.success)),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _WalletBar extends StatelessWidget {
  final double balance;
  const _WalletBar({required this.balance});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
    child: Row(children: [
      const Icon(Icons.account_balance_wallet_rounded, color: GacomColors.deepOrange, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ARENA WALLET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GacomColors.txtMuted(context), letterSpacing: 1)),
        Text('₦${balance.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.txtPrimary(context))),
      ])),
      TextButton(onPressed: () => GoRouter.of(context).push('/wallet'), style: TextButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)), child: const Text('TOP UP', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12))),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: GacomColors.txtMuted(context), letterSpacing: 1.2)),
  );
}

class _FeeRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool bold;
  const _FeeRow(this.label, this.value, {this.color, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: color ?? GacomColors.txtSecondary(context), fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 15 : 12, color: color ?? GacomColors.txtPrimary(context))),
    ]),
  );
}

class _ArenaDisabled extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.sports_esports_outlined, size: 72, color: GacomColors.borderColor(context)),
    const SizedBox(height: 16),
    Text('Arena is currently offline', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.txtPrimary(context))),
    const SizedBox(height: 8),
    Text('Check back soon!', style: TextStyle(color: GacomColors.txtMuted(context))),
  ]));
}
