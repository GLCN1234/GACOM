import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import 'level_map_screen.dart';

/// Arena Gauntlet — pick a weapon (and, from level 9+, a shield). Correct
/// answers strike your opponent; build a combo streak for a damage
/// multiplier, and answer fast for a bonus. Wrong answers hurt — unless
/// you've got a shield charge left to block. One persistent 3D viewer for
/// the whole match, so nothing gets torn down mid-fight.
class ArenaGauntletScreen extends StatefulWidget {
  const ArenaGauntletScreen({super.key, this.subject = 'logic'});
  final String subject;

  @override
  State<ArenaGauntletScreen> createState() => _ArenaGauntletScreenState();
}

class _Weapon {
  final String id, name, glb, emoji;
  final int minDamage, maxDamage;
  const _Weapon(this.id, this.name, this.glb, this.emoji, this.minDamage, this.maxDamage);
}

class _Shield {
  final String id, name, glb, emoji;
  const _Shield(this.id, this.name, this.glb, this.emoji);
}

const _weapons = [
  _Weapon('hammer', 'War Hammer', 'hammer/hammer_hammer_1.glb', '🔨', 12, 20),
  _Weapon('dagger', 'Swift Dagger', 'dagger/dagger_dagger_1.glb', '🗡️', 8, 14),
];
const _shields = [
  _Shield('shield', 'Guard Shield', 'shield/shield_shield_1.glb', '🛡️'),
];

const _easyQ = [
  {'q': 'What is 9 + 6?', 'a': '15', 'opts': ['13', '14', '15', '16']},
  {'q': 'What is the past tense of "run"?', 'a': 'Ran', 'opts': ['Runned', 'Ran', 'Running', 'Runs']},
  {'q': 'Which gas do humans exhale?', 'a': 'Carbon Dioxide', 'opts': ['Oxygen', 'Carbon Dioxide', 'Nitrogen', 'Hydrogen']},
  {'q': 'What is 6 × 5?', 'a': '30', 'opts': ['25', '28', '30', '35']},
  {'q': 'How many continents are there?', 'a': '7', 'opts': ['5', '6', '7', '8']},
  {'q': 'What is the freezing point of water in Celsius?', 'a': '0°C', 'opts': ['-10°C', '0°C', '10°C', '32°C']},
  {'q': 'What is 30 - 12?', 'a': '18', 'opts': ['16', '17', '18', '20']},
  {'q': 'Who wrote Romeo and Juliet?', 'a': 'William Shakespeare', 'opts': ['Charles Dickens', 'William Shakespeare', 'Jane Austen', 'Mark Twain']},
];
const _mediumQ = [
  {'q': 'What is 8 × 7?', 'a': '56', 'opts': ['54', '56', '58', '64']},
  {'q': 'What is the chemical symbol for gold?', 'a': 'Au', 'opts': ['Ag', 'Au', 'Gd', 'Go']},
  {'q': 'Who was the first president of Nigeria?', 'a': 'Nnamdi Azikiwe', 'opts': ['Nnamdi Azikiwe', 'Tafawa Balewa', 'Yakubu Gowon', 'Obafemi Awolowo']},
  {'q': 'What is 25% of 80?', 'a': '20', 'opts': ['15', '20', '25', '30']},
  {'q': 'What is the longest river in Africa?', 'a': 'Nile', 'opts': ['Congo', 'Niger', 'Nile', 'Zambezi']},
  {'q': 'What does HTML stand for?', 'a': 'HyperText Markup Language', 'opts': ['HyperText Markup Language', 'High Tech Modern Language', 'HyperText Modern Links', 'Home Tool Markup Language']},
  {'q': 'What is 144 ÷ 12?', 'a': '12', 'opts': ['10', '11', '12', '14']},
  {'q': 'How many bones are in the human body?', 'a': '206', 'opts': ['186', '196', '206', '216']},
];
const _hardQ = [
  {'q': 'What is the derivative of x²?', 'a': '2x', 'opts': ['x', '2x', 'x²', '2x²']},
  {'q': 'Who developed the theory of relativity?', 'a': 'Albert Einstein', 'opts': ['Isaac Newton', 'Albert Einstein', 'Niels Bohr', 'Galileo Galilei']},
  {'q': 'What is the SI unit of electric current?', 'a': 'Ampere', 'opts': ['Volt', 'Watt', 'Ampere', 'Ohm']},
  {'q': 'What is 17 × 13?', 'a': '221', 'opts': ['211', '221', '231', '241']},
  {'q': 'Which African country was formerly called Abyssinia?', 'a': 'Ethiopia', 'opts': ['Kenya', 'Ethiopia', 'Sudan', 'Somalia']},
  {'q': 'What is the value of π to 2 decimal places?', 'a': '3.14', 'opts': ['3.12', '3.14', '3.16', '3.18']},
  {'q': 'What is 19 × 21?', 'a': '399', 'opts': ['389', '399', '409', '419']},
  {'q': 'Who was the first Secretary-General of the United Nations?', 'a': 'Trygve Lie', 'opts': ['Kofi Annan', 'Trygve Lie', 'U Thant', 'Dag Hammarskjöld']},
];

class _ArenaGauntletScreenState extends State<ArenaGauntletScreen> {
  int? _level;
  String _difficulty = 'Easy';
  String _phase = 'pick_weapon'; // pick_weapon | pick_shield | combat | over
  late List<Map<String, dynamic>> _questions;
  _Weapon? _weapon;
  _Shield? _shield;
  int _blockCharges = 3;
  int _qIdx = 0, _playerHp = 100, _opponentHp = 100, _combo = 0, _score = 0;
  String? _selected;
  bool _answered = false, _playerWon = false;
  String _log = '';
  final _rand = Random();
  Timer? _timer;
  int _timeLeft = 10;

  bool get _shieldUnlocked => (_level ?? 1) >= 9;

  double get _comboMultiplier => _combo >= 5 ? 2.0 : _combo >= 3 ? 1.5 : 1.0;

  void _startLevel(int level, String difficulty) {
    final bank = difficulty == 'Easy' ? _easyQ : difficulty == 'Medium' ? _mediumQ : _hardQ;
    setState(() {
      _level = level; _difficulty = difficulty;
      _questions = ([..._easyQ, ...bank, ...bank]..shuffle());
      _qIdx = 0; _playerHp = 100; _opponentHp = 100 + (level - 1) * 4; _combo = 0; _score = 0;
      _blockCharges = 3; _weapon = null; _shield = null;
      _phase = 'pick_weapon'; _selected = null; _answered = false;
    });
  }

  void _pickWeapon(_Weapon w) => setState(() {
    _weapon = w;
    _phase = _shieldUnlocked ? 'pick_shield' : 'combat';
    if (_phase == 'combat') _startTimer();
  });

  void _pickShield(_Shield? s) => setState(() { _shield = s; _phase = 'combat'; _startTimer(); });

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_timeLeft <= 1) { setState(() { _answered = true; _combo = 0; }); _timer?.cancel(); _resolveWrong(); }
      else setState(() => _timeLeft--);
    });
  }

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    final correct = opt == _questions[_qIdx]['a'];
    setState(() { _selected = opt; _answered = true; });

    if (correct) {
      _combo++;
      final base = _weapon!.minDamage + _rand.nextInt(_weapon!.maxDamage - _weapon!.minDamage + 1);
      final speedBonus = _timeLeft >= 7 ? 5 : 0;
      final dmg = ((base + speedBonus) * _comboMultiplier).round();
      setState(() { _opponentHp = max(0, _opponentHp - dmg); _score += 10; _log = 'Hit for $dmg! Combo x${_comboMultiplier.toStringAsFixed(1)}'; });
    } else {
      _combo = 0;
      _resolveWrong();
    }

    EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: correct ? 10 : 0, questionsAnswered: 1, correctAnswers: correct ? 1 : 0);
    Future.delayed(const Duration(milliseconds: 900), _next);
  }

  void _resolveWrong() {
    if (_shield != null && _blockCharges > 0) {
      _blockCharges--;
      setState(() => _log = '🛡️ Blocked with $_blockCharges charge(s) left!');
    } else {
      final dmg = 8 + _rand.nextInt(10);
      setState(() { _playerHp = max(0, _playerHp - dmg); _log = 'Opponent hit you for $dmg!'; });
    }
  }

  void _next() {
    if (!mounted) return;
    if (_opponentHp <= 0) {
      LevelMapScreen.unlockNext('arena_gauntlet', _level!);
      setState(() { _phase = 'over'; _playerWon = true; });
      return;
    }
    if (_playerHp <= 0) { setState(() { _phase = 'over'; _playerWon = false; }); return; }
    if (_qIdx >= _questions.length - 1) { setState(() { _phase = 'over'; _playerWon = _opponentHp < _playerHp; }); return; }
    setState(() { _qIdx++; _selected = null; _answered = false; });
    _startTimer();
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String get _currentModelSrc {
    if (_phase == 'pick_shield' && _shield != null) return _shield!.glb;
    return _weapon?.glb ?? _weapons.first.glb;
  }

  @override
  Widget build(BuildContext context) {
    if (_level == null) return LevelMapScreen(gameKey: 'arena_gauntlet', title: 'Arena Gauntlet', onPlayLevel: _startLevel);

    if (_phase == 'over') return Scaffold(backgroundColor: GacomColors.obsidian,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_playerWon ? '⚔️ Victory!' : '💀 Defeated', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: _playerWon ? GacomColors.success : GacomColors.error)),
        const SizedBox(height: 8),
        Text('Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: GacomColors.deepOrange)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(onPressed: () => setState(() => _level = null), style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border)),
            child: const Text('LEVEL MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
          const SizedBox(width: 12),
          if (_playerWon) ElevatedButton(onPressed: () => _startLevel(_level! + 1 > 20 ? _level! : _level! + 1, LevelMapScreen.difficultyFor(_level! + 1 > 20 ? _level! : _level! + 1)),
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('NEXT LEVEL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)))
          else ElevatedButton(onPressed: () => _startLevel(_level!, _difficulty), style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('RETRY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
        ]),
      ])));

    // ONE persistent ModelViewer instance across pick_weapon → pick_shield →
    // combat, avoiding repeated iframe teardown/recreation — this is the
    // structural fix for the black-screen issue.
    final modelViewer = ModelViewer(
      key: const ValueKey('arena_model_viewer'),
      backgroundColor: GacomColors.cardDark,
      src: Uri.base.resolve('assets/assets/models_3d/$_currentModelSrc').toString(),
      alt: 'weapon or shield', ar: false, autoRotate: true,
      cameraControls: _phase == 'combat', disableZoom: _phase != 'combat',
    );

    if (_phase == 'pick_weapon') return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text('LEVEL $_level · $_difficulty — CHOOSE WEAPON')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        SizedBox(height: 220, child: modelViewer),
        const SizedBox(height: 16),
        Expanded(child: ListView(children: _weapons.map((w) => GestureDetector(onTap: () => _pickWeapon(w),
          child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
            child: Row(children: [
              Text(w.emoji, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12),
              Expanded(child: Text('${w.name} · ${w.minDamage}-${w.maxDamage} dmg', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary))),
              const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
            ])))).toList())),
      ])));

    if (_phase == 'pick_shield') return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('CHOOSE A SHIELD (or skip)')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        SizedBox(height: 220, child: modelViewer),
        const SizedBox(height: 16),
        const Text('A shield gives you 3 block charges — get an answer wrong and block the hit instead of taking damage.',
          style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        ..._shields.map((s) => GestureDetector(onTap: () => _pickShield(s),
          child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
            child: Row(children: [Text(s.emoji, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12),
              Expanded(child: Text(s.name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)))])))),
        TextButton(onPressed: () => _pickShield(null), child: const Text('Skip — fight without a shield', style: TextStyle(color: GacomColors.textMuted))),
      ])));

    // combat phase
    final q = _questions[_qIdx];
    final opts = List<String>.from(q['opts'] as List);

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text('LEVEL $_level'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange)))),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('YOU', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
          if (_shield != null) Text('🛡️ x$_blockCharges', style: const TextStyle(fontSize: 12, color: GacomColors.info)),
          Text('$_playerHp/100', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.success)),
        ]),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _playerHp / 100, minHeight: 8, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.success))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('OPPONENT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
          Text('$_opponentHp/${100 + (_level! - 1) * 4}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.error)),
        ]),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _opponentHp / (100 + (_level! - 1) * 4), minHeight: 8, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.error))),
        const SizedBox(height: 14),
        if (_combo >= 2) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text('🔥 COMBO x$_combo  →  ${_comboMultiplier.toStringAsFixed(1)}x damage', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange))),
        SizedBox(height: 170, child: modelViewer),
        if (_log.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_log, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic))),
        Row(children: [
          Text('Q ${_qIdx + 1}/${_questions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _timeLeft <= 3 ? GacomColors.error.withOpacity(0.15) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50)),
            child: Text('⏱ ${_timeLeft}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: _timeLeft <= 3 ? GacomColors.error : GacomColors.textPrimary))),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
          child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary, height: 1.4))),
        const SizedBox(height: 12),
        ...opts.map((opt) {
          Color borderColor = GacomColors.border, bgColor = GacomColors.cardDark;
          if (_answered && _selected == opt) {
            borderColor = opt == q['a'] ? GacomColors.success : GacomColors.error;
            bgColor = opt == q['a'] ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1);
          } else if (_answered && opt == q['a']) {
            borderColor = GacomColors.success; bgColor = GacomColors.success.withOpacity(0.08);
          }
          return GestureDetector(onTap: () => _answer(opt),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor, width: 1.2)),
              child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14, color: GacomColors.textPrimary))));
        }),
      ])),
    );
  }
}
