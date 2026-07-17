import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../services/arena_service.dart';
import 'games/tictactoe_game.dart';
import 'games/rps_game.dart';
import 'games/trivia_game.dart';
import 'games/reaction_game.dart';
import 'games/chess_game.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  const MatchScreen({super.key, required this.matchId});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Map<String, dynamic>? _match;
  bool _loading = true;
  bool _voiceEnabled = false;
  bool _micMuted = false;
  bool _opponentSpeaking = false;
  StreamSubscription? _matchSub;
  Timer? _timer;
  int _elapsed = 0;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = SupabaseService.currentUserId;
    _loadMatch();
    _subscribeMatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _elapsed++); });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadMatch() async {
    try {
      final data = await SupabaseService.client.from('arena_matches')
          .select('*, creator:profiles!creator_id(id, username, display_name, avatar_url), opponent:profiles!opponent_id(id, username, display_name, avatar_url)')
          .eq('id', widget.matchId).single();
      if (mounted) setState(() { _match = data; _loading = false; });
      if (data['status'] == 'waiting') _waitForOpponent();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _subscribeMatch() {
    _matchSub = SupabaseService.client.from('arena_matches').stream(primaryKey: ['id']).eq('id', widget.matchId).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        setState(() => _match = {...?_match, ...rows.first});
        if (rows.first['status'] == 'completed') _handleMatchEnd();
      }
    });
  }

  void _waitForOpponent() {
    // Poll for opponent joining
    Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted) { t.cancel(); return; }
      final data = await SupabaseService.client.from('arena_matches').select('status, opponent_id').eq('id', widget.matchId).single();
      if (data['status'] == 'active') { t.cancel(); if (mounted) _loadMatch(); }
    });
  }

  void _handleMatchEnd() {
    final match = _match;
    if (match == null) return;
    final isWinner = match['winner_id'] == _uid;
    final payout = match['winner_payout'] as int? ?? 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Text(isWinner ? '🏆' : '😔', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Text(isWinner ? 'YOU WON!' : 'YOU LOST', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: isWinner ? GacomColors.success : GacomColors.error)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isWinner) ...[
            Text('₦${payout.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 36, color: GacomColors.success)),
            const Text('credited to your wallet', style: TextStyle(color: GacomColors.textSecondary)),
          ] else
            const Text('Better luck next time! Keep practicing your skills.', style: TextStyle(color: GacomColors.textSecondary, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); context.go('/arena'); }, child: const Text('Back to Arena', style: TextStyle(color: GacomColors.textMuted))),
          if (isWinner) ElevatedButton(
            onPressed: () { Navigator.pop(context); context.go('/arena'); },
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('PLAY AGAIN', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          ) else ElevatedButton(
            onPressed: () { Navigator.pop(context); context.go('/arena'); },
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('TRY AGAIN', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _onWinner(String winnerId) async {
    HapticFeedback.heavyImpact();
    await ArenaService.declareWinner(widget.matchId, winnerId);
  }

  Future<void> _raiseDispute() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Raise Dispute', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Describe the issue. An admin will review it.', style: TextStyle(color: GacomColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3, style: const TextStyle(color: GacomColors.textPrimary), decoration: InputDecoration(hintText: 'e.g. connection dropped, opponent disconnected...', hintStyle: const TextStyle(color: GacomColors.textMuted), filled: true, fillColor: GacomColors.surfaceDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: GacomColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('SUBMIT', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ArenaService.raiseDispute(widget.matchId, ctrl.text.trim());
      if (mounted) context.go('/arena');
    }
  }

  String get _timeStr {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_match == null) return Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Text('Match not found', style: TextStyle(color: GacomColors.txtMuted(context)))));

    final match = _match!;
    final status = match['status'] as String;
    final creator = match['creator'] as Map? ?? {};
    final opponent = match['opponent'] as Map?;
    final isCreator = _uid == match['creator_id'];
    final myProfile = isCreator ? creator : (opponent ?? {});
    final opponentProfile = isCreator ? (opponent ?? {}) : creator;
    final myName = myProfile['username'] ?? myProfile['display_name'] ?? 'You';
    final opponentName = opponent != null ? (opponentProfile['username'] ?? opponentProfile['display_name'] ?? 'Opponent') : 'Waiting...';
    final gameType = match['game_type'] as String;
    final stakeAmount = match['stake_amount'] as int;
    final settings = {'platform_fee_percent': 15};
    final fee = (stakeAmount * 2 * ((settings['platform_fee_percent'] as int) / 100)).round();
    final pot = stakeAmount * 2 - fee;

    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(
        title: Text(gameType.toUpperCase()),
        actions: [
          if (status == 'active') ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.error.withOpacity(0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: GacomColors.error, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('LIVE · $_timeStr', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.error)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.flag_outlined, color: GacomColors.warning), onPressed: _raiseDispute, tooltip: 'Raise dispute'),
          ],
        ],
      ),
      body: Column(children: [
        // Pot bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _PotItem('POT', '₦$pot', GacomColors.deepOrange),
            _PotItem('TIME', _timeStr, GacomColors.txtSecondary(context)),
            _PotItem('STATUS', status.toUpperCase(), status == 'active' ? GacomColors.success : GacomColors.warning),
          ]),
        ),

        // Players bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: _PlayerChip(name: myName, isYou: true, isTurn: match['current_turn'] == _uid)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textMuted))),
            Expanded(child: _PlayerChip(name: opponentName, isYou: false, isTurn: match['current_turn'] != _uid && match['current_turn'] != null)),
          ]),
        ),

        // Waiting state
        if (status == 'waiting') Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: GacomColors.deepOrange),
          const SizedBox(height: 20),
          Text('Waiting for opponent...', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.txtPrimary(context))),
          const SizedBox(height: 8),
          Text('Your stake: ₦$stakeAmount locked', style: TextStyle(color: GacomColors.txtMuted(context), fontSize: 13)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () async { await ArenaService.cancelMatch(widget.matchId); if (mounted) context.go('/arena'); },
            child: const Text('Cancel & Refund', style: TextStyle(color: GacomColors.error)),
          ),
        ]))),

        // Game area
        if (status == 'active' || status == 'completed') ...[
          Expanded(child: _buildGame(gameType, match)),

          // Voice chat bar
          _VoiceBar(
            matchId: widget.matchId,
            voiceChannel: match['voice_channel'] as String? ?? '',
            enabled: _voiceEnabled,
            muted: _micMuted,
            opponentSpeaking: _opponentSpeaking,
            opponentName: opponentName,
            onToggle: () => setState(() => _voiceEnabled = !_voiceEnabled),
            onMute: () => setState(() => _micMuted = !_micMuted),
          ),
        ],
      ]),
    );
  }

  Widget _buildGame(String type, Map<String, dynamic> match) {
    switch (type) {
      case 'tictactoe': return TicTacToeGame(match: match, myId: _uid!, onWinner: _onWinner);
      case 'rps': return RpsGame(match: match, myId: _uid!, onWinner: _onWinner);
      case 'trivia': return TriviaGame(match: match, myId: _uid!, onWinner: _onWinner);
      case 'reaction': return ReactionGame(match: match, myId: _uid!, onWinner: _onWinner);
      case 'chess': return ChessGame(match: match, myId: _uid!, onWinner: _onWinner);
      default: return Center(child: Text('Unknown game: $type', style: const TextStyle(color: GacomColors.textMuted)));
    }
  }
}

class _PotItem extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _PotItem(this.label, this.value, this.valueColor);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GacomColors.txtMuted(context), letterSpacing: 1)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: valueColor)),
  ]);
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final bool isYou, isTurn;
  const _PlayerChip({required this.name, required this.isYou, required this.isTurn});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isTurn ? GacomColors.deepOrange.withOpacity(0.1) : GacomColors.surface(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isTurn ? GacomColors.deepOrange : GacomColors.borderColor(context), width: isTurn ? 1.5 : 0.5),
    ),
    child: Row(children: [
      CircleAvatar(radius: 14, backgroundColor: isYou ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.info.withOpacity(0.15), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isYou ? GacomColors.deepOrange : GacomColors.info))),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isYou ? 'You' : name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.txtPrimary(context))),
        if (isTurn) const Text('Your turn', style: TextStyle(fontSize: 10, color: GacomColors.deepOrange, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );
}

class _VoiceBar extends StatelessWidget {
  final String matchId, voiceChannel, opponentName;
  final bool enabled, muted, opponentSpeaking;
  final VoidCallback onToggle, onMute;
  const _VoiceBar({required this.matchId, required this.voiceChannel, required this.enabled, required this.muted, required this.opponentSpeaking, required this.opponentName, required this.onToggle, required this.onMute});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: GacomColors.surface(context), border: Border(top: BorderSide(color: GacomColors.borderColor(context), width: 0.5))),
    child: Row(children: [
      GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFE1F5EE) : GacomColors.elevated(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: enabled ? const Color(0xFF1D9E75) : GacomColors.borderColor(context)),
          ),
          child: Row(children: [
            Icon(enabled ? Icons.mic_rounded : Icons.mic_off_rounded, size: 16, color: enabled ? GacomColors.success : GacomColors.txtMuted(context)),
            const SizedBox(width: 6),
            Text(enabled ? 'Voice ON' : 'Join Voice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: enabled ? GacomColors.success : GacomColors.txtMuted(context))),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      if (enabled) ...[
        if (opponentSpeaking) Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: GacomColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$opponentName is speaking...', style: const TextStyle(fontSize: 11, color: GacomColors.success)),
        ]) else Text('Voice connected', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
        const Spacer(),
        GestureDetector(
          onTap: onMute,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: muted ? GacomColors.error.withOpacity(0.1) : GacomColors.elevated(context), border: Border.all(color: muted ? GacomColors.error.withOpacity(0.4) : GacomColors.borderColor(context))),
            child: Icon(muted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 16, color: muted ? GacomColors.error : GacomColors.txtSecondary(context)),
          ),
        ),
      ] else ...[
        const Spacer(),
        Text('Tap to talk to opponent', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
      ],
    ]),
  );
}
