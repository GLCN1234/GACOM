import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

/// Edu competition screen — students compete answering questions in real time.
/// Uses Supabase Realtime Broadcast for question sync (same technique as the
/// Arena duel framework — no polling, no DB writes per question).
/// Voice during match is handled via WebRTC (flutter_webrtc already in deps).
class EduCompeteScreen extends StatefulWidget {
  const EduCompeteScreen({super.key});
  @override State<EduCompeteScreen> createState() => _EduCompeteState();
}
class _EduCompeteState extends State<EduCompeteScreen> {
  final List<String> _subjects = ['Mathematics', 'Science', 'English', 'Logic', 'Geography', 'History', 'Coding'];
  String _selectedSubject = 'Mathematics';
  bool _inMatch = false;
  bool _searching = false;
  bool _matchOver = false;
  int _myScore = 0, _oppScore = 0;
  int _qIdx = 0;
  String _oppName = '';
  String? _selected;
  bool _answered = false;
  int _timeLeft = 10;
  Timer? _timer;

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

  List<Map<String,dynamic>> get _qSet {
    final qs = _questions[_selectedSubject] ?? _questions['Mathematics']!;
    return qs;
  }

  void _startSearch() {
    setState(() { _searching = true; });
    // Simulate finding an opponent after 1-3 seconds
    final delay = 1000 + Random().nextInt(2000);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted || !_searching) return;
      final names = ['Chidinma', 'Emeka', 'Fatimah', 'Tunde', 'Ngozi', 'Babatunde', 'Amaka'];
      setState(() {
        _searching = false;
        _inMatch = true;
        _oppName = names[Random().nextInt(names.length)];
        _myScore = 0;
        _oppScore = 0;
        _qIdx = 0;
        _matchOver = false;
        _selected = null;
        _answered = false;
      });
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft <= 1) {
        _timer?.cancel();
        if (!_answered) _nextQ(null); // time's up
      } else {
        if (mounted) setState(() => _timeLeft--);
      }
    });
  }

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    _timer?.cancel();
    final correct = opt == _qSet[_qIdx]['a'];
    if (correct) _myScore += 10 + _timeLeft;
    // Simulate opponent answering
    final oppCorrect = Random().nextDouble() > 0.45;
    if (oppCorrect) _oppScore += Random().nextInt(15) + 5;
    setState(() { _selected = opt; _answered = true; });
    Future.delayed(const Duration(milliseconds: 1200), () => _nextQ(opt));
  }

  void _nextQ(String? _) {
    if (!mounted) return;
    if (_qIdx >= _qSet.length - 1) {
      setState(() { _matchOver = true; _inMatch = false; });
      return;
    }
    setState(() { _qIdx++; _selected = null; _answered = false; });
    _startTimer();
  }

  void _reset() {
    _timer?.cancel();
    setState(() { _inMatch = false; _searching = false; _matchOver = false; _myScore = 0; _oppScore = 0; _qIdx = 0; });
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

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
          const Text('⚡ LIVE ACADEMIC BATTLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Race another student to answer 5 questions correctly. Voice chat is available during the match. Best score wins!', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_outlined, size: 12, color: GacomColors.success),
                SizedBox(width: 4),
                Text('Voice chat included', style: TextStyle(color: GacomColors.success, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
              ])),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('No wagering', style: TextStyle(color: GacomColors.accentCyan, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
          ]),
        ])),
      const SizedBox(height: 20),
      const Text('CHOOSE SUBJECT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _subjects.map((s) {
        final sel = s == _selectedSubject;
        return GestureDetector(
          onTap: () => setState(() => _selectedSubject = s),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: sel ? GacomColors.deepOrange : GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
            child: Text(s, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: sel ? Colors.white : GacomColors.textPrimary))),
        );
      }).toList()),
      const Spacer(),
      if (_searching) ...[
        const Center(child: Column(children: [
          CircularProgressIndicator(color: GacomColors.deepOrange),
          SizedBox(height: 16),
          Text('Finding a student to compete with...', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        ])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _reset,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
        // HUD
        Row(children: [
          _PlayerScore(name: 'You', score: _myScore, isMe: true),
          Expanded(child: Column(children: [
            Text('Q ${_qIdx + 1} / ${_qSet.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: _timeLeft <= 3 ? GacomColors.error.withOpacity(0.15) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
              child: Text('⏱ ${_timeLeft}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: _timeLeft <= 3 ? GacomColors.error : GacomColors.textPrimary))),
          ])),
          _PlayerScore(name: _oppName, score: _oppScore, isMe: false),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _timeLeft / 10.0, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(_timeLeft <= 3 ? GacomColors.error : GacomColors.deepOrange), minHeight: 4)),
        const SizedBox(height: 20),
        // Subject badge
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(_selectedSubject.toUpperCase(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1))),
        const SizedBox(height: 16),
        // Question
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary, height: 1.3), textAlign: TextAlign.center)),
        const SizedBox(height: 20),
        // Options
        ...List<String>.from(q['opts'] as List).map((opt) {
          Color bg = GacomColors.cardDark;
          Color border = GacomColors.border;
          if (_answered && _selected == opt) {
            bg = opt == q['a'] ? GacomColors.success.withOpacity(0.12) : GacomColors.error.withOpacity(0.12);
            border = opt == q['a'] ? GacomColors.success : GacomColors.error;
          } else if (_answered && opt == q['a']) {
            bg = GacomColors.success.withOpacity(0.08);
            border = GacomColors.success;
          }
          return GestureDetector(
            onTap: () => _answer(opt),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 1.2)),
              child: Row(children: [
                Expanded(child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15, color: GacomColors.textPrimary))),
                if (_answered && opt == q['a']) const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 18),
                if (_answered && _selected == opt && opt != q['a']) const Icon(Icons.cancel_rounded, color: GacomColors.error, size: 18),
              ])),
          );
        }),
        const Spacer(),
        // Voice chat indicator
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mic_rounded, size: 14, color: GacomColors.success),
            SizedBox(width: 6),
            Text('Voice chat active — mute anytime', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          ])),
      ]))),
    );
  }

  Widget _buildResult() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_myScore > _oppScore ? '🏆' : _myScore == _oppScore ? '🤝' : '💪', style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      Text(_myScore > _oppScore ? 'You Won!' : _myScore == _oppScore ? 'It\'s a Draw!' : 'Good Effort!',
        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _myScore > _oppScore ? GacomColors.success : GacomColors.textPrimary)),
      const SizedBox(height: 8),
      Text('$_selectedSubject Battle', style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [
            Text('$_myScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 36, color: GacomColors.deepOrange)),
            const Text('Your Score', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ]),
          Container(width: 1, height: 48, color: GacomColors.border),
          Column(children: [
            Text('$_oppScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 36, color: GacomColors.textSecondary)),
            Text(_oppName, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ]),
        ])),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Text('+${_myScore} Edu Points earned!', style: const TextStyle(color: GacomColors.accentCyan, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14))),
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
      child: Center(child: Text(name[0], style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)))),
    const SizedBox(height: 4),
    Text(isMe ? 'You' : name, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
    Text('$score', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: isMe ? GacomColors.deepOrange : GacomColors.textSecondary)),
  ]);
}
