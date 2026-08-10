import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ReactionSoloScreen extends StatefulWidget {
  const ReactionSoloScreen({super.key});
  @override State<ReactionSoloScreen> createState() => _ReactionSoloState();
}

class _ReactionSoloState extends State<ReactionSoloScreen> {
  static const _rounds = 5;
  List<int> _times = []; // ms
  Timer? _waitTimer;
  DateTime? _flashTime;
  bool _waiting = false, _flashing = false, _tooEarly = false, _done = false;

  void _start() {
    setState(() { _times = []; _done = false; _tooEarly = false; });
    _scheduleNext();
  }

  void _scheduleNext() {
    _waiting = true; _flashing = false;
    final delay = 1500 + Random().nextInt(3000);
    _waitTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() { _flashing = true; _flashTime = DateTime.now(); });
    });
    setState(() {});
  }

  void _tap() {
    if (!_waiting && !_flashing) return;
    _waitTimer?.cancel();
    if (!_flashing) {
      setState(() { _tooEarly = true; _waiting = false; });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() { _tooEarly = false; _scheduleNext(); });
      });
      return;
    }
    final ms = DateTime.now().difference(_flashTime!).inMilliseconds;
    _times.add(ms);
    _flashing = false; _waiting = false;
    if (_times.length >= _rounds) { setState(() => _done = true); }
    else { Future.delayed(const Duration(milliseconds: 600), _scheduleNext); setState(() {}); }
  }

  int get _avg => _times.isEmpty ? 0 : _times.reduce((a, b) => a + b) ~/ _times.length;
  String get _rating => _avg < 200 ? 'Lightning Fast' : _avg < 300 ? 'Very Fast' : _avg < 400 ? 'Good' : _avg < 500 ? 'Average' : 'Keep practising';

  @override void dispose() { _waitTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('REACTION TEST')),
    body: _done ? _buildResults() : _buildGame(),
  );

  Widget _buildGame() => GestureDetector(onTap: _tap, child: Container(color: Colors.transparent, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('Round ${_times.length + 1} / $_rounds', style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
    const SizedBox(height: 40),
    AnimatedContainer(duration: const Duration(milliseconds: 100),
      width: 200, height: 200,
      decoration: BoxDecoration(
        color: _tooEarly ? GacomColors.error : _flashing ? GacomColors.success : GacomColors.elevatedCard,
        shape: BoxShape.circle,
        boxShadow: _flashing ? [BoxShadow(color: GacomColors.success.withOpacity(0.4), blurRadius: 40, spreadRadius: 10)] : [],
      ),
      child: Center(child: Text(
        _tooEarly ? 'TOO EARLY!' : _flashing ? 'TAP!' : _waiting ? '...' : 'TAP TO START',
        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: _flashing ? 28 : 18,
          color: _flashing || _tooEarly ? Colors.white : GacomColors.textMuted),
        textAlign: TextAlign.center,
      ))),
    const SizedBox(height: 40),
    if (_times.isNotEmpty) ...[ Text('Last: ${_times.last}ms', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)) ],
    if (!_waiting && !_flashing && !_tooEarly && _times.isEmpty)
      const Text('Tap the circle when it turns GREEN', style: TextStyle(color: GacomColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
  ]))));

  Widget _buildResults() => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('Results', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
    const SizedBox(height: 24),
    Text('${_avg}ms average', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 40, color: GacomColors.deepOrange)),
    const SizedBox(height: 8),
    Text(_rating, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18, color: GacomColors.textSecondary)),
    const SizedBox(height: 24),
    ..._times.asMap().entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('Round ${e.key + 1}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const Spacer(),
        Text('${e.value}ms', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
      ]))),
    const SizedBox(height: 32),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start,
      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: const Text('TRY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
  ]));
}
