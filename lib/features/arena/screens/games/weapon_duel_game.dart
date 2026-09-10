import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';

/// Weapon Duel — pick your weapon, answer correctly to strike your
/// opponent, get it wrong and take a hit back. Your live, rotating 3D
/// weapon sits front and centre the whole match.
class WeaponDuelScreen extends StatefulWidget {
  const WeaponDuelScreen({super.key, this.subject = 'logic', this.questions});
  final String subject;
  final List<Map<String, dynamic>>? questions;

  @override
  State<WeaponDuelScreen> createState() => _WeaponDuelScreenState();
}

class _Weapon {
  final String id, name, glb, emoji;
  final int minDamage, maxDamage;
  const _Weapon(this.id, this.name, this.glb, this.emoji, this.minDamage, this.maxDamage);
}

const _weapons = [
  _Weapon('hammer', 'War Hammer', 'hammer/hammer_hammer_1.glb', '🔨', 12, 20),
  _Weapon('dagger', 'Swift Dagger', 'dagger/dagger_dagger_1.glb', '🗡️', 8, 14),
];

const _fallbackQuestions = [
  {'q': 'What is 8 × 7?', 'a': '56', 'opts': ['54', '56', '58', '64']},
  {'q': 'What is the chemical symbol for gold?', 'a': 'Au', 'opts': ['Ag', 'Au', 'Gd', 'Go']},
  {'q': 'Who was the first president of Nigeria?', 'a': 'Nnamdi Azikiwe', 'opts': ['Nnamdi Azikiwe', 'Tafawa Balewa', 'Yakubu Gowon', 'Obafemi Awolowo']},
  {'q': 'What is the past tense of "run"?', 'a': 'Ran', 'opts': ['Runned', 'Ran', 'Running', 'Runs']},
  {'q': 'How many bones are in the human body?', 'a': '206', 'opts': ['186', '196', '206', '216']},
  {'q': 'What is the freezing point of water in Celsius?', 'a': '0°C', 'opts': ['-10°C', '0°C', '10°C', '32°C']},
  {'q': 'What is 25% of 80?', 'a': '20', 'opts': ['15', '20', '25', '30']},
  {'q': 'Which gas do humans exhale?', 'a': 'Carbon Dioxide', 'opts': ['Oxygen', 'Carbon Dioxide', 'Nitrogen', 'Hydrogen']},
  {'q': 'What is the longest river in Africa?', 'a': 'Nile', 'opts': ['Congo', 'Niger', 'Nile', 'Zambezi']},
  {'q': 'What does HTML stand for?', 'a': 'HyperText Markup Language', 'opts': ['HyperText Markup Language', 'High Tech Modern Language', 'HyperText Modern Links', 'Home Tool Markup Language']},
  {'q': 'What is 144 ÷ 12?', 'a': '12', 'opts': ['10', '11', '12', '14']},
  {'q': 'Who wrote Romeo and Juliet?', 'a': 'William Shakespeare', 'opts': ['Charles Dickens', 'William Shakespeare', 'Jane Austen', 'Mark Twain']},
];

class _WeaponDuelScreenState extends State<WeaponDuelScreen> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _questions;
  _Weapon? _chosenWeapon;
  int _idx = 0, _playerHp = 100, _opponentHp = 100, _score = 0;
  String? _selected;
  bool _answered = false, _matchOver = false, _playerWon = false;
  String _log = '';
  final _rand = Random();
  late AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _questions = (widget.questions != null && widget.questions!.isNotEmpty)
        ? (List<Map<String, dynamic>>.from(widget.questions!)..shuffle())
        : ([..._fallbackQuestions]..shuffle());
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void _pickWeapon(_Weapon w) => setState(() => _chosenWeapon = w);

  void _answer(String opt) {
    if (_answered || _chosenWeapon == null) return;
    HapticFeedback.mediumImpact();
    final correct = opt == _questions[_idx]['a'];
    setState(() { _selected = opt; _answered = true; });

    if (correct) {
      final dmg = _chosenWeapon!.minDamage + _rand.nextInt(_chosenWeapon!.maxDamage - _chosenWeapon!.minDamage + 1);
      _opponentHp = max(0, _opponentHp - dmg);
      _log = 'You struck for $dmg damage!';
    } else {
      final dmg = 8 + _rand.nextInt(10);
      _playerHp = max(0, _playerHp - dmg);
      _log = 'Opponent hit back for $dmg damage!';
    }
    _shakeCtrl.forward(from: 0);
    _score += correct ? 10 : 0;

    EduProgressRecorder.recordSession(
      subject: widget.subject, xpEarned: correct ? 10 : 0,
      questionsAnswered: 1, correctAnswers: correct ? 1 : 0,
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_opponentHp <= 0) { setState(() { _matchOver = true; _playerWon = true; }); return; }
      if (_playerHp <= 0) { setState(() { _matchOver = true; _playerWon = false; }); return; }
      _next();
    });
  }

  void _next() {
    if (_idx >= _questions.length - 1) { setState(() { _matchOver = true; _playerWon = _opponentHp < _playerHp; }); return; }
    setState(() { _idx++; _selected = null; _answered = false; });
  }

  void _reset() {
    setState(() {
      _questions = (widget.questions != null && widget.questions!.isNotEmpty)
          ? (List<Map<String, dynamic>>.from(widget.questions!)..shuffle())
          : ([..._fallbackQuestions]..shuffle());
      _chosenWeapon = null; _idx = 0; _playerHp = 100; _opponentHp = 100; _score = 0;
      _selected = null; _answered = false; _matchOver = false; _playerWon = false; _log = '';
    });
  }

  Widget _healthBar(String label, int hp, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
      Text('$hp/100', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: color)),
    ]),
    const SizedBox(height: 4),
    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: hp / 100, minHeight: 8, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color))),
  ]);

  @override
  Widget build(BuildContext context) {
    if (_matchOver) return Scaffold(backgroundColor: GacomColors.obsidian,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_playerWon ? '⚔️ Victory!' : '💀 Defeated', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _playerWon ? GacomColors.success : GacomColors.error)),
        const SizedBox(height: 8),
        Text('Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: GacomColors.deepOrange)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _reset, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('DUEL AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
      ])));

    if (_chosenWeapon == null) return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('CHOOSE YOUR WEAPON')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        const Text('Answer correctly to strike. Get it wrong, and you take the hit.',
          style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        Expanded(child: ListView(children: _weapons.map((w) => GestureDetector(
          onTap: () => _pickWeapon(w),
          child: Container(margin: const EdgeInsets.only(bottom: 12), height: 220,
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
            child: Column(children: [
              Expanded(child: ModelViewer(backgroundColor: GacomColors.obsidian,
                src: Uri.base.resolve('assets/assets/models_3d/${w.glb}').toString(),
                alt: w.name, ar: false, autoRotate: true, cameraControls: false, disableZoom: true)),
              Padding(padding: const EdgeInsets.all(12), child: Text('${w.emoji} ${w.name}  ·  ${w.minDamage}-${w.maxDamage} dmg',
                style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary))),
            ])))).toList())),
      ])));

    final q = _questions[_idx];
    final opts = List<String>.from(q['opts'] as List);

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('WEAPON DUEL'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Score: $_score',
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange)))),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _healthBar('YOU', _playerHp, GacomColors.success),
          const SizedBox(height: 10),
          _healthBar('OPPONENT', _opponentHp, GacomColors.error),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: ModelViewer(backgroundColor: GacomColors.cardDark,
            src: Uri.base.resolve('assets/assets/models_3d/${_chosenWeapon!.glb}').toString(),
            alt: _chosenWeapon!.name, ar: false, autoRotate: true, cameraControls: true, disableZoom: false)),
          if (_log.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_log, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic))),
          const SizedBox(height: 8),
          Text('Q ${_idx + 1}/${_questions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
            child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.textPrimary, height: 1.4))),
          const SizedBox(height: 16),
          ...opts.map((opt) {
            Color borderColor = GacomColors.border, bgColor = GacomColors.cardDark;
            if (_answered && _selected == opt) {
              borderColor = opt == q['a'] ? GacomColors.success : GacomColors.error;
              bgColor = opt == q['a'] ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1);
            } else if (_answered && opt == q['a']) {
              borderColor = GacomColors.success; bgColor = GacomColors.success.withOpacity(0.08);
            }
            return GestureDetector(onTap: () => _answer(opt),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.2)),
                child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15, color: GacomColors.textPrimary))));
          }),
        ]),
      ),
    );
  }
}
