import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/duel_session.dart';
import '../duels/duel_registry.dart';
import '../services/duel_service.dart';
import '../../../shared/widgets/pc_controls_gate.dart';
import '../widgets/game_logo.dart';

/// One head-to-head duel: wait for an opponent, play the same game with the
/// same seed, then see who won. The server decides the result.
class DuelScreen extends StatefulWidget {
  final String duelId;
  const DuelScreen({super.key, required this.duelId});
  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  final String? _uid = SupabaseService.currentUserId;

  DuelMatch? _m;
  DuelGame? _game;
  Widget? _gameWidget;
  DuelSession? _session;
  Map<String, Map<String, dynamic>> _profiles = <String, Map<String, dynamic>>{};

  bool _loading = true;
  bool _started = false;
  bool _submitted = false;
  bool _submitting = false;
  String? _error;
  DateTime? _startedAt;

  int _best = 0;
  int _total = 0;
  int _limitLeft = 0;

  StreamSubscription? _sub;
  Timer? _poll;
  Timer? _tick;
  Timer? _limit;

  @override
  void initState() {
    super.initState();
    _load();
    try {
      _sub = SupabaseService.client
          .from('duel_matches')
          .stream(primaryKey: <String>['id'])
          .eq('id', widget.duelId)
          .listen((rows) {
        if (rows.isNotEmpty && mounted) _apply(DuelMatch.fromRow(Map<String, dynamic>.from(rows.first)));
      }, onError: (_) {});
    } catch (_) {}
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final DuelMatch? fresh = await DuelService.fetch(widget.duelId);
      if (fresh != null && mounted) _apply(fresh);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    _tick?.cancel();
    _limit?.cancel();
    _session?.stop();
    final DuelMatch? m = _m;
    if (m != null && m.isPlayer(_uid)) {
      final bool playing = m.status == 'active' && !_submitted;
      final bool waiting = m.status == 'waiting' && m.creatorId == _uid;
      if (playing || waiting) {
        DuelService.forfeit(m.id).catchError((_) => m);
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    final DuelMatch? m = await DuelService.fetch(widget.duelId);
    if (!mounted) return;
    if (m == null) {
      setState(() { _loading = false; _error = 'This duel no longer exists.'; });
      return;
    }
    setState(() => _loading = false);
    _apply(m);
  }

  Future<void> _apply(DuelMatch m) async {
    if (!mounted) return;
    final DuelMatch? old = _m;
    // Never move backwards (a stale poll can arrive after a newer stream row).
    if (old != null && _rank(m.status) < _rank(old.status)) return;
    final bool needProfiles = _profiles[m.creatorId] == null || (m.opponentId != null && _profiles[m.opponentId!] == null);
    if (m.status == 'active' && !_started && m.isPlayer(_uid)) {
      _beginPlay(m);
    }
    setState(() => _m = m);
    if (m.status == 'completed' || m.status == 'cancelled') {
      _limit?.cancel();
      _session?.stop();
    }
    if (needProfiles) {
      final Map<String, Map<String, dynamic>> p = await DuelService.profiles(<String>[m.creatorId, if (m.opponentId != null) m.opponentId!]);
      if (mounted) setState(() => _profiles = <String, Map<String, dynamic>>{..._profiles, ...p});
    }
  }

  int _rank(String s) => s == 'waiting' ? 0 : (s == 'active' ? 1 : 2);

  void _beginPlay(DuelMatch m) {
    final DuelGame? g = DuelRegistry.byKey(m.gameKey);
    if (g == null) {
      setState(() => _error = 'This game is not available in your app version.');
      return;
    }
    _started = true;
    _game = g;
    _startedAt = DateTime.now();
    final DuelSession s = DuelSession(seed: m.seed, onScore: _onScore);
    _session = s;
    s.start();
    _gameWidget = PcControlsGate(gameKey: g.key, child: g.build());
    if (g.scoring != DuelScoring.firstResult && g.seconds > 0) {
      _limitLeft = g.seconds;
      _limit = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        _limitLeft--;
        if (_limitLeft <= 0) {
          t.cancel();
          _finish(g.scoring == DuelScoring.totalInTime ? _total : _best);
        }
      });
    }
  }

  void _onScore(int score, bool? won) {
    if (_submitted || _game == null) return;
    switch (_game!.scoring) {
      case DuelScoring.firstResult:
        _finish(score);
        break;
      case DuelScoring.bestInTime:
        if (score > _best) _best = score;
        break;
      case DuelScoring.totalInTime:
        _total += score;
        break;
    }
  }

  Future<void> _finish(int score) async {
    if (_submitted) return;
    final DuelMatch? m = _m;
    if (m == null) return;
    _submitted = true;
    _limit?.cancel();
    _session?.stop();
    final int ms = _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inMilliseconds;
    if (mounted) setState(() { _submitting = true; _error = null; _mine = score; });
    try {
      final DuelMatch res = await DuelService.submit(m.id, score, ms);
      if (mounted) _apply(res);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send your score. Check your connection.');
    }
    if (mounted) setState(() => _submitting = false);
  }

  int _mine = 0;

  Future<void> _retrySend() async {
    _submitted = false;
    await _finish(_mine);
  }

  Future<void> _claim() async {
    final DuelMatch? m = _m;
    if (m == null) return;
    try {
      final DuelMatch res = await DuelService.claim(m.id);
      if (mounted) _apply(res);
    } catch (_) {}
  }

  Future<void> _rematch() async {
    final DuelGame? g = _game ?? (_m == null ? null : DuelRegistry.byKey(_m!.gameKey));
    if (g == null) return;
    try {
      final DuelMatch next = await DuelService.quick(g, stake: _m?.stake ?? 0);
      if (mounted) context.pushReplacement('/arena/duel/${next.id}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start a rematch.');
    }
  }

  bool get _midGame => _m?.status == 'active' && _started && !_submitted;

  Future<bool> _confirmLeave() async {
    if (!_midGame) return true;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Leave this duel?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
        content: const Text('If you leave before finishing, your opponent wins.', style: TextStyle(color: GacomColors.textSecondary)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: GacomColors.error))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _leaveTapped() async {
    if (await _confirmLeave() && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/arena/duels');
      }
    }
  }

  String _name(String? id) => id == _uid ? 'You' : DuelService.nameOf(_profiles, id);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmLeave,
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: SafeArea(
          child: Column(children: <Widget>[
            _header(),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    final DuelMatch? m = _m;
    final String title = m?.gameName ?? 'Duel';
    final String? oppId = m == null || _uid == null ? null : m.otherId(_uid!);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      decoration: const BoxDecoration(color: GacomColors.surfaceDark, border: Border(bottom: BorderSide(color: GacomColors.border))),
      child: Row(children: <Widget>[
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: GacomColors.textPrimary), onPressed: _leaveTapped),
        SizedBox(width: 30, height: 30, child: GameLogo(name: title, radius: 8, fallback: const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
            Text(oppId == null ? 'Duel' : 'vs ${_name(oppId)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
          ]),
        ),
        if (_midGame && _limitLeft > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: GacomColors.deepOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.deepOrange)),
            child: Text('${_limitLeft ~/ 60}:${(_limitLeft % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.deepOrange)),
          ),
      ]),
    );
  }

  Widget _centered(List<Widget> children) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    final DuelMatch? m = _m;
    if (m == null) {
      return _centered(<Widget>[
        Text(_error ?? 'Duel not found.', style: const TextStyle(color: GacomColors.textSecondary)),
        const SizedBox(height: 16),
        _button('BACK', () => context.go('/arena/duels')),
      ]);
    }
    if (_error != null && !m.isPlayer(_uid) ) {
      return _centered(<Widget>[Text(_error!, style: const TextStyle(color: GacomColors.textSecondary))]);
    }
    if (m.status == 'cancelled') {
      return _centered(<Widget>[
        const Icon(Icons.cancel_outlined, color: GacomColors.textMuted, size: 48),
        const SizedBox(height: 12),
        const Text('This duel was cancelled.', style: TextStyle(color: GacomColors.textSecondary)),
        const SizedBox(height: 16),
        _button('BACK', () => context.go('/arena/duels')),
      ]);
    }
    if (m.status == 'waiting') return _waitingPanel(m);
    if (m.status == 'completed') return _resultPanel(m);
    // active
    if (!m.isPlayer(_uid)) {
      return _centered(<Widget>[const Text('Duel in progress.', style: TextStyle(color: GacomColors.textSecondary))]);
    }
    if (_error != null && !_submitted) {
      return _centered(<Widget>[Text(_error!, style: const TextStyle(color: GacomColors.error))]);
    }
    if (_submitted) return _waitingForOpponent(m);
    return _gameWidget ?? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
  }

  Widget _button(String label, VoidCallback onTap, {bool secondary = false}) => SizedBox(
        width: 220,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: secondary ? GacomColors.elevatedCard : GacomColors.deepOrange,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      );

  Widget _waitingPanel(DuelMatch m) {
    final bool mine = m.creatorId == _uid;
    return _centered(<Widget>[
      SizedBox(width: 84, height: 84, child: GameLogo(name: m.gameName, radius: 20, fallback: const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 54))),
      const SizedBox(height: 18),
      const CircularProgressIndicator(color: GacomColors.deepOrange),
      const SizedBox(height: 18),
      Text(mine ? 'Looking for an opponent...' : 'Joining...', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
      const SizedBox(height: 6),
      Text(m.stake > 0 ? 'Stake: ₦${m.stake}. Your stake is held until the duel ends.\nThe match starts the moment someone joins.' : 'The match starts the moment someone joins.\nYou both get the same seed.', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      const SizedBox(height: 22),
      if (mine)
        _button('CANCEL', () async {
          try { await DuelService.cancel(m.id); } catch (_) {}
          if (mounted) context.go('/arena/duels');
        }, secondary: true),
    ]);
  }

  Widget _waitingForOpponent(DuelMatch m) {
    final String opp = _name(m.otherId(_uid!));
    final bool timedOut = m.deadline != null && DateTime.now().isAfter(m.deadline!);
    final int? mineScore = m.scoreOf(_uid!) ?? _mine;
    final Duration? left = m.deadline?.difference(DateTime.now());
    return _centered(<Widget>[
      const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 52),
      const SizedBox(height: 12),
      const Text('YOUR RESULT IS IN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
      const SizedBox(height: 6),
      Text('$mineScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 44, color: GacomColors.deepOrange)),
      const SizedBox(height: 10),
      if (_error != null) ...<Widget>[
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.error, fontSize: 12)),
        const SizedBox(height: 12),
        _button('SEND AGAIN', _retrySend),
      ] else if (_submitting)
        const Text('Sending...', style: TextStyle(color: GacomColors.textMuted))
      else ...<Widget>[
        Text('Waiting for $opp to finish...', style: const TextStyle(color: GacomColors.textSecondary)),
        const SizedBox(height: 14),
        if (timedOut)
          _button('CLAIM THE WIN', _claim)
        else if (left != null)
          Text('You can claim the win if they do not finish in ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      ],
    ]);
  }

  Widget _resultPanel(DuelMatch m) {
    final String? uid = _uid;
    final bool isPlayer = m.isPlayer(uid);
    final bool won = isPlayer && m.winnerId == uid;
    final bool draw = m.isDraw;
    final String headline = !isPlayer ? 'DUEL FINISHED' : (draw ? 'DRAW' : (won ? 'YOU WON' : 'YOU LOST'));
    final Color color = draw ? GacomColors.warning : (won ? GacomColors.success : GacomColors.error);
    final String? oppId = isPlayer ? m.otherId(uid!) : null;
    String reason = '';
    if (m.endReason == 'forfeit') reason = won ? 'Your opponent left the duel.' : 'You left the duel.';
    if (m.endReason == 'timeout') reason = won ? 'Your opponent did not finish in time.' : 'You did not finish in time.';
    final int? mine = isPlayer ? m.scoreOf(uid!) : m.creatorScore;
    final int? theirs = isPlayer ? m.scoreOf(oppId ?? '') : m.opponentScore;
    return _centered(<Widget>[
      Icon(draw ? Icons.handshake_rounded : (won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded), color: draw ? GacomColors.warning : (won ? GacomColors.gold : GacomColors.textMuted), size: 62),
      const SizedBox(height: 12),
      Text(headline, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: color)),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        _scoreBox(isPlayer ? 'You' : _name(m.creatorId), mine, won),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textMuted))),
        _scoreBox(isPlayer ? _name(oppId) : _name(m.opponentId), theirs, isPlayer && !won && !draw),
      ]),
      if (reason.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        Text(reason, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      ],
      if (isPlayer && m.stake > 0) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          draw
              ? 'Draw. Your ₦${m.stake} stake was returned.'
              : (won ? 'You won ₦${m.payout ?? (m.stake * 2)} (stakes pooled, platform fee taken).' : 'You lost your ₦${m.stake} stake.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: draw ? GacomColors.warning : (won ? GacomColors.success : GacomColors.error), fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
      const SizedBox(height: 26),
      if (isPlayer) _button('REMATCH', _rematch),
      const SizedBox(height: 10),
      _button('BACK TO DUELS', () => context.go('/arena/duels'), secondary: true),
    ]);
  }

  Widget _scoreBox(String name, int? score, bool highlight) => Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlight ? GacomColors.success : GacomColors.borderBright, width: highlight ? 1.5 : 1),
        ),
        child: Column(children: <Widget>[
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(score == null ? '-' : '$score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.textPrimary)),
        ]),
      );
}
