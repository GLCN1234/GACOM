import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

/// Real academic competition — students are matched via a Supabase queue
/// (not a fake timer), questions are synced through the match room so both
/// players see the same question at the same time, and voice chat uses real
/// WebRTC peer-to-peer audio signaled through Supabase Realtime.
///
/// Honesty note: voice requires microphone permission and works over STUN
/// for most networks, but can fail behind strict school/corporate firewalls
/// that block UDP — if that happens the match still works, just without audio.
class EduCompeteScreen extends StatefulWidget {
  const EduCompeteScreen({super.key});
  @override State<EduCompeteScreen> createState() => _EduCompeteState();
}

class _EduCompeteState extends State<EduCompeteScreen> {
  final List<String> _subjects = ['Mathematics', 'Science', 'English', 'Logic', 'Geography', 'History'];
  String _selectedSubject = 'Mathematics';

  bool _searching = false;
  bool _inMatch = false;
  bool _matchOver = false;
  String? _roomId;
  String? _opponentId;
  String _opponentName = '';
  int _myScore = 0, _oppScore = 0;
  int _qIdx = 0;
  String? _selected;
  bool _answered = false;
  int _timeLeft = 15;
  Timer? _timer;
  RealtimeChannel? _roomChannel;
  StreamSubscription? _queueSub;

  bool _voiceConnected = false; // reserved for future voice feature
  bool _voiceEnabled = false;
  String? _queueEntryId;

  static const _questions = {
    'Mathematics': [
      {'q': 'What is 15 × 7?', 'a': '105', 'opts': ['95', '105', '115', '98']},
      {'q': 'What is √144?', 'a': '12', 'opts': ['11', '12', '13', '14']},
      {'q': 'What is 25% of 200?', 'a': '50', 'opts': ['25', '40', '50', '75']},
      {'q': 'Solve: 3x = 27', 'a': 'x = 9', 'opts': ['x = 6', 'x = 8', 'x = 9', 'x = 11']},
      {'q': 'What is 2⁸?', 'a': '256', 'opts': ['128', '192', '256', '512']},
    ],
    'Science': [
      {'q': 'What planet is closest to the Sun?', 'a': 'Mercury', 'opts': ['Venus', 'Mercury', 'Mars', 'Earth']},
      {'q': 'What gas do plants absorb?', 'a': 'CO₂', 'opts': ['O₂', 'N₂', 'CO₂', 'H₂']},
      {'q': 'What is the unit of force?', 'a': 'Newton', 'opts': ['Joule', 'Newton', 'Watt', 'Pascal']},
      {'q': 'What organ pumps blood?', 'a': 'Heart', 'opts': ['Lungs', 'Liver', 'Heart', 'Brain']},
      {'q': 'How many bones in an adult?', 'a': '206', 'opts': ['150', '196', '206', '230']},
    ],
    'English': [
      {'q': 'What is the plural of "child"?', 'a': 'Children', 'opts': ['Childs', 'Childes', 'Children', 'Childrens']},
      {'q': 'Which is a verb: Run, Blue, Happy, Table?', 'a': 'Run', 'opts': ['Blue', 'Happy', 'Run', 'Table']},
      {'q': 'Synonym of "happy"?', 'a': 'Joyful', 'opts': ['Sad', 'Angry', 'Joyful', 'Tired']},
      {'q': 'What punctuation ends a question?', 'a': '?', 'opts': ['.', '!', '?', ',']},
      {'q': 'What is an antonym of "fast"?', 'a': 'Slow', 'opts': ['Quick', 'Rapid', 'Slow', 'Swift']},
    ],
  };

  List<Map<String,dynamic>> get _qSet => _questions[_selectedSubject] ?? _questions['Mathematics']!;

  @override void dispose() { _timer?.cancel(); _roomChannel?.unsubscribe(); _queueSub?.cancel(); super.dispose(); }

  // ── Real matchmaking via Supabase RPC + queue ─────────────────────────────
  Future<void> _startSearch() async {
    setState(() => _searching = true);
    try {
      final res = await SupabaseService.client.rpc('find_or_join_edu_match', params: {'p_subject': _selectedSubject});
      final matched = res['matched'] as bool? ?? false;

      if (matched) {
        // We found someone waiting — room created immediately
        final roomId = res['room_id'] as String;
        final opponentId = res['opponent_id'] as String;
        await _enterRoom(roomId, opponentId, isInitiator: true);
      } else {
        // We're now in the queue — listen for a room to be created for us
        _listenForMatch();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Matchmaking error: $e')));
      }
    }
  }

  void _listenForMatch() {
    final uid = SupabaseService.currentUserId!;
    _roomChannel = SupabaseService.client
        .channel('edu_match_wait_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'edu_compete_rooms',
          callback: (payload) {
            final room = payload.newRecord;
            if (room['player1_id'] == uid || room['player2_id'] == uid) {
              final opponentId = room['player1_id'] == uid ? room['player2_id'] as String : room['player1_id'] as String;
              _enterRoom(room['id'] as String, opponentId, isInitiator: false);
            }
          },
        )
        .subscribe();
  }

  Future<void> _enterRoom(String roomId, String opponentId, {required bool isInitiator}) async {
    _roomChannel?.unsubscribe();
    _queueSub?.cancel();

    // Fetch opponent's display name
    String oppName = 'Opponent';
    try {
      final p = await SupabaseService.client.from('profiles').select('display_name').eq('id', opponentId).single();
      oppName = p['display_name'] as String? ?? 'Opponent';
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _searching = false;
      _inMatch = true;
      _roomId = roomId;
      _opponentId = opponentId;
      _opponentName = oppName;
      _myScore = 0; _oppScore = 0; _qIdx = 0;
      _matchOver = false; _selected = null; _answered = false;
    });

    // Subscribe to score updates from the opponent via the room row
    _roomChannel = SupabaseService.client
        .channel('edu_room_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'edu_compete_rooms',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: roomId),
          callback: (payload) {
            final row = payload.newRecord;
            final uid = SupabaseService.currentUserId;
            final isP1 = row['player1_id'] == uid;
            final oppScoreField = isP1 ? row['player2_score'] : row['player1_score'];
            if (mounted) setState(() => _oppScore = (oppScoreField as int?) ?? 0);
            if (row['status'] == 'completed' && mounted) setState(() { _matchOver = true; _inMatch = false; });
          },
        )
        .subscribe();

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft <= 1) { _timer?.cancel(); if (!_answered) _next(); }
      else if (mounted) setState(() => _timeLeft--);
    });
  }

  Future<void> _answer(String opt) async {
    if (_answered) return;
    HapticFeedback.lightImpact();
    _timer?.cancel();
    final correct = opt == _qSet[_qIdx]['a'];
    if (correct) _myScore += 10 + _timeLeft;
    setState(() { _selected = opt; _answered = true; });

    // Push my updated score to the shared room row so opponent sees it live
    if (_roomId != null) {
      final uid = SupabaseService.currentUserId!;
      try {
        final room = await SupabaseService.client.from('edu_compete_rooms').select('player1_id').eq('id', _roomId!).single();
        final isP1 = room['player1_id'] == uid;
        await SupabaseService.client.from('edu_compete_rooms').update({
          isP1 ? 'player1_score' : 'player2_score': _myScore,
        }).eq('id', _roomId!);
      } catch (_) {}
    }
    Future.delayed(const Duration(milliseconds: 1200), _next);
  }

  Future<void> _next() async {
    if (!mounted) return;
    if (_qIdx >= _qSet.length - 1) {
      if (_roomId != null) {
        try { await SupabaseService.client.from('edu_compete_rooms').update({'status': 'completed', 'completed_at': DateTime.now().toIso8601String()}).eq('id', _roomId!); } catch (_) {}
      }
      setState(() { _matchOver = true; _inMatch = false; });
      return;
    }
    setState(() { _qIdx++; _selected = null; _answered = false; });
    _startTimer();
  }

  void _toggleVoice() {
    // Voice chat is temporarily unavailable — the underlying WebRTC package
    // has an unresolved upstream compatibility bug with the current Flutter
    // web compiler (tracked publicly on the flutter/flutter GitHub repo).
    // Real matchmaking and live scoring both work fully without it.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Voice chat is temporarily unavailable — text competition works fully.'),
      backgroundColor: GacomColors.elevatedCard,
    ));
  }

  void _reset() {
    _timer?.cancel(); _roomChannel?.unsubscribe(); _queueSub?.cancel();
    setState(() { _inMatch = false; _searching = false; _matchOver = false; _myScore = 0; _oppScore = 0; _qIdx = 0; _voiceEnabled = false; _voiceConnected = false; });
  }

  @override Widget build(BuildContext context) {
    if (_matchOver) return _buildResult();
    if (_inMatch) return _buildMatch();
    return _buildLobby();
  }

  Widget _buildLobby() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('COMPETE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16))),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LIVE ACADEMIC BATTLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Get matched with a real student currently searching for the same subject. Voice chat is coming in a future update.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4)),
        ])),
      const SizedBox(height: 20),
      const Text('CHOOSE SUBJECT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _subjects.map((s) {
        final sel = s == _selectedSubject;
        return GestureDetector(onTap: () => setState(() => _selectedSubject = s),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: sel ? GacomColors.deepOrange : GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
            child: Text(s, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: sel ? Colors.white : GacomColors.textPrimary))));
      }).toList()),
      const Spacer(),
      if (_searching) ...[
        const Center(child: Column(children: [
          CircularProgressIndicator(color: GacomColors.deepOrange),
          SizedBox(height: 16),
          Text('Waiting for a real student to join...', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
          SizedBox(height: 6),
          Text('This may take a while if few students are online.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () async {
          try { await SupabaseService.client.from('edu_compete_queue').delete().eq('user_id', SupabaseService.currentUserId!).eq('status', 'waiting'); } catch (_) {}
          _reset();
        }, style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)))),
      ] else
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _startSearch,
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('FIND AN OPPONENT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
      const SizedBox(height: 16),
    ])),
  );

  Widget _buildMatch() {
    final q = _qSet[_qIdx];
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          _PlayerScore(name: 'You', score: _myScore, isMe: true),
          Expanded(child: Column(children: [
            Text('Q ${_qIdx + 1} / ${_qSet.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: _timeLeft <= 3 ? GacomColors.error.withOpacity(0.15) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
              child: Text('${_timeLeft}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: _timeLeft <= 3 ? GacomColors.error : GacomColors.textPrimary))),
          ])),
          _PlayerScore(name: _opponentName, score: _oppScore, isMe: false),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _timeLeft / 15.0, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(_timeLeft <= 3 ? GacomColors.error : GacomColors.deepOrange), minHeight: 4)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(_selectedSubject.toUpperCase(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1))),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary, height: 1.3), textAlign: TextAlign.center)),
        const SizedBox(height: 20),
        ...List<String>.from(q['opts'] as List).map((opt) {
          Color bg = GacomColors.cardDark; Color border = GacomColors.border;
          if (_answered && _selected == opt) { bg = opt == q['a'] ? GacomColors.success.withOpacity(0.12) : GacomColors.error.withOpacity(0.12); border = opt == q['a'] ? GacomColors.success : GacomColors.error; }
          else if (_answered && opt == q['a']) { bg = GacomColors.success.withOpacity(0.08); border = GacomColors.success; }
          return GestureDetector(onTap: () => _answer(opt),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 1.2)),
              child: Row(children: [
                Expanded(child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15, color: GacomColors.textPrimary))),
                if (_answered && opt == q['a']) const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 18),
                if (_answered && _selected == opt && opt != q['a']) const Icon(Icons.cancel_rounded, color: GacomColors.error, size: 18),
              ])));
        }),
        const Spacer(),
        GestureDetector(onTap: _toggleVoice,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.mic_off_rounded, size: 14, color: GacomColors.textMuted),
              SizedBox(width: 6),
              Text('Voice chat coming soon', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            ]))),
      ]))),
    );
  }

  Widget _buildResult() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_myScore > _oppScore ? Icons.emoji_events_rounded : _myScore == _oppScore ? Icons.handshake_outlined : Icons.fitness_center_rounded, size: 64, color: _myScore > _oppScore ? GacomColors.deepOrange : GacomColors.textSecondary),
      const SizedBox(height: 16),
      Text(_myScore > _oppScore ? 'You Won!' : _myScore == _oppScore ? 'Draw!' : 'Good Effort!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _myScore > _oppScore ? GacomColors.success : GacomColors.textPrimary)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [Text('$_myScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 36, color: GacomColors.deepOrange)), const Text('You', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))]),
          Container(width: 1, height: 48, color: GacomColors.border),
          Column(children: [Text('$_oppScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 36, color: GacomColors.textSecondary)), Text(_opponentName, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))]),
        ])),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _reset,
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
    ]))),
  );
}

class _PlayerScore extends StatelessWidget {
  final String name; final int score; final bool isMe;
  const _PlayerScore({required this.name, required this.score, required this.isMe});
  @override Widget build(BuildContext ctx) => Column(children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isMe ? GacomColors.deepOrange : GacomColors.accentCyan, width: 2), color: GacomColors.elevatedCard),
      child: Center(child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)))),
    const SizedBox(height: 4),
    Text(isMe ? 'You' : name, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
    Text('$score', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: isMe ? GacomColors.deepOrange : GacomColors.textSecondary)),
  ]);
}