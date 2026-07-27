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
    {'id': 'chess', 'name': 'Chess', 'icon': '♟️', 'meta': 'Pure strategy', 'tag': 'HOT', 'bg': GacomColors.deepOrange.withOpacity(0.14)},
    {'id': 'tictactoe', 'name': 'Tic-Tac-Toe', 'icon': '✖️', 'meta': '3 min avg', 'tag': 'LIVE', 'bg': GacomColors.accentCyan.withOpacity(0.14)},
    {'id': 'rps', 'name': 'RPS Battle', 'icon': '🪨', 'meta': 'Best of 5', 'tag': '', 'bg': GacomColors.deepOrange.withOpacity(0.14)},
    {'id': 'trivia', 'name': 'Trivia', 'icon': '🧠', 'meta': '10 questions', 'tag': 'NEW', 'bg': GacomColors.accentCyan.withOpacity(0.14)},
    {'id': 'reaction', 'name': 'Reaction', 'icon': '⚡', 'meta': 'Tap fastest', 'tag': '', 'bg': GacomColors.deepOrange.withOpacity(0.14)},
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
    final result = await ArenaService.createMatch(gameType: _selectedGame, stakeAmount: _selectedStake);
    if (mounted) setState(() => _creating = false);
    if (result['match'] != null && mounted) {
      context.push('/arena/match/${result['match']['id']}');
    } else if (mounted) {
      final refunded = result['refunded'] as bool?;
      final suffix = refunded == false
          ? '\n\n⚠️ Your stake could NOT be refunded automatically — contact support with this error.'
          : (refunded == true ? '\n\nYour stake has been refunded.' : '');
      _showError('${result['error'] ?? 'Could not create match.'}$suffix');
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
    // Use the global provider so Arena toggle and Home toggle are the same feature
    // Read (not watch) — watching causes rebuild loops when mode changes
    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(
        title: const Text('GACOM ARENA'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () async {
                final accepted = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _EduModeArenaDialog(),
                );
                if (accepted == true && context.mounted) {
                  context.go('/edu/home');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.school_outlined, size: 14, color: GacomColors.textMuted),
                  SizedBox(width: 5),
                  Text('Edu', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted)),
                ]),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.storefront_outlined), tooltip: 'Game Store', onPressed: () => context.push('/arena/store')),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: (_loading
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
                ])),
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
          decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, size: 13, color: GacomColors.success),
            SizedBox(width: 6),
            Text('100% Skill Competition — No Gambling', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GacomColors.success)),
          ]),
        ),
        const SizedBox(height: 20),

        // Game selector
        _SectionLabel('Choose a game'),
        SizedBox(
          height: 124,
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
                  width: 96,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: GacomColors.elevatedCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? GacomColors.deepOrange : Colors.white.withOpacity(0.08), width: sel ? 1.5 : 1),
                  ),
                  child: Stack(children: [
                    if ((g['tag'] as String).isNotEmpty)
                      Positioned(top: 6, left: 6, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
                        child: Text(g['tag'] as String, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: GacomColors.deepOrange)))),
                    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(g['icon'] as String, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(g['name'] as String, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: sel ? GacomColors.deepOrange : GacomColors.txtPrimary(context))),
                      Text(gEnabled ? g['meta'] as String : 'Disabled', style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
                    ])),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? GacomColors.deepOrange : GacomColors.elevatedCard,
                  borderRadius: BorderRadius.circular(20),
                  border: sel ? null : Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                ),
                child: Text('₦${s.toStringAsFixed(0)}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: sel ? Colors.white : GacomColors.txtPrimary(context))),
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

        if (_selectedGame == 'tictactoe') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/arena/practice/tictactoe'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.info), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.smart_toy_outlined, color: GacomColors.info, size: 18),
              label: const Text('PRACTICE VS RYAN (FREE)', style: TextStyle(color: GacomColors.info, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 1)),
    child: Row(children: [
      const Icon(Icons.account_balance_wallet_rounded, color: GacomColors.deepOrange, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ARENA WALLET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 1)),
        Text('₦${balance.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.txtPrimary(context))),
      ])),
      TextButton(onPressed: () => GoRouter.of(context).push('/wallet'), style: TextButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)), child: const Text('TOP UP', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13))),
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

// ── Edu Gaming Screen ─────────────────────────────────────────────────────────
class _EduGamingScreen extends StatelessWidget {
  static const _categories = [
    {'icon': '🧮', 'title': 'Mathematics', 'desc': 'Speed Math, Sudoku, Number Puzzles', 'color': 0xFFFF6A00, 'route': '/arena/practice/speedmath'},
    {'icon': '🔬', 'title': 'Science', 'desc': 'Physics, Chemistry, Biology quizzes', 'color': 0xFF00C2A8, 'route': '/arena/practice/trivia'},
    {'icon': '📖', 'title': 'English', 'desc': 'Word Scramble, Hangman, Vocabulary', 'color': 0xFF3D8BFF, 'route': '/arena/practice/wordscramble'},
    {'icon': '🌍', 'title': 'Geography', 'desc': 'World Map, Capitals, Countries', 'color': 0xFF8B5CF6, 'route': '/arena/practice/trivia'},
    {'icon': '📚', 'title': 'Literature', 'desc': 'Story Detective, Poetry, Novel Quest', 'color': 0xFFE85B8A, 'route': '/arena/practice/trivia'},
    {'icon': '🏛', 'title': 'History', 'desc': 'Timeline Builder, African History', 'color': 0xFFFF8A33, 'route': '/arena/practice/trivia'},
    {'icon': '💻', 'title': 'Computer Science', 'desc': 'Logic Puzzles, Algorithm Builder', 'color': 0xFF00E5FF, 'route': '/arena/practice/numberduel'},
    {'icon': '🧠', 'title': 'IQ & Logic', 'desc': 'Chess, Memory Match, Pattern Puzzles', 'color': 0xFFFF6A00, 'route': '/arena/practice/chess'},
    {'icon': '💰', 'title': 'Business & Finance', 'desc': 'Tycoon, Stock Market, Budgeting', 'color': 0xFF34D399, 'route': '/arena/practice/trivia'},
    {'icon': '🎨', 'title': 'Creative Skills', 'desc': 'Music, Art, Animation challenges', 'color': 0xFFE85B8A, 'route': '/arena/practice/simon'},
    {'icon': '🌐', 'title': 'Languages', 'desc': 'Yoruba, Hausa, Igbo, French & more', 'color': 0xFF8B5CF6, 'route': '/arena/practice/wordscramble'},
    {'icon': '⚙', 'title': 'Engineering', 'desc': 'Bridge Builder, Circuit Design', 'color': 0xFF3D8BFF, 'route': '/arena/practice/2048'},
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('🎓', style: TextStyle(fontSize: 24)), const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('EDU GAMING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.accentCyan, letterSpacing: 1)),
              const Text('Learn Through Play', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            ])]),
          const SizedBox(height: 8),
          const Text('Play educational games across 12 subjects. Build real academic skills while competing on leaderboards.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4)),
        ])),
      const SizedBox(height: 20),
      const Text('SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final c = _categories[i];
          final color = Color(c['color'] as int);
          return GestureDetector(
            onTap: () => context.push(c['route'] as String),
            child: Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['icon'] as String, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(c['title'] as String, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                const SizedBox(height: 2),
                Text(c['desc'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
          );
        }),
      const SizedBox(height: 20),
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🏆 DAILY CHALLENGES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Complete daily learning challenges to earn Gacom Coins and unlock exclusive badges.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          ...[['🧮 Daily Math Challenge', 'Speed'], ['📖 Daily Vocabulary', 'Words'], ['🧠 Daily Logic Puzzle', 'Logic']].map((d) =>
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              Text(d[0], style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(50)),
                child: Text(d[1], style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            ]))),
        ])),
    ]),
  );
}

// Minimal inline edu dialog for the Arena toggle — mirrors the one in feed_screen
class _EduModeArenaDialog extends StatefulWidget {
  @override State<_EduModeArenaDialog> createState() => _EduModeArenaDialogState();
}
class _EduModeArenaDialogState extends State<_EduModeArenaDialog> {
  bool _accepted = false;
  @override Widget build(BuildContext ctx) => Dialog(
    backgroundColor: GacomColors.cardDark,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎓', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Switch to Edu Gaming?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('Edu Gaming replaces the Arena with an educational learning environment — 12 subjects, skill tracking, student competitions, and parent reports. No real-money stakes in Edu mode.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      GestureDetector(onTap: () => setState(() => _accepted = !_accepted),
        child: Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 150), width: 22, height: 22,
            decoration: BoxDecoration(color: _accepted ? GacomColors.deepOrange : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: _accepted ? GacomColors.deepOrange : GacomColors.textMuted, width: 1.5)),
            child: _accepted ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
          const SizedBox(width: 10),
          const Expanded(child: Text('I understand and agree to the Edu Gaming terms.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12))),
        ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: _accepted ? () => Navigator.pop(ctx, true) : null,
          style: ElevatedButton.styleFrom(backgroundColor: _accepted ? GacomColors.deepOrange : GacomColors.elevatedCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Switch', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: _accepted ? Colors.white : GacomColors.textMuted)))),
      ]),
    ])),
  );
}
