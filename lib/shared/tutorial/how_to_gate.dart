import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/pc_controls_gate.dart';
import 'how_to_demo.dart';
import 'how_to_model.dart';
import 'how_to_registry.dart';

/// Remembers which tutorials a player has already seen.
class HowToStore {
  static const String _skipAll = 'howto_skip_all';
  static String _k(String key) => 'howto_seen_$key';

  static Future<bool> shouldShow(String key) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      if (p.getBool(_skipAll) ?? false) return false;
      return !(p.getBool(_k(key)) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen(String key, {bool skipAll = false}) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool(_k(key), true);
      if (skipAll) await p.setBool(_skipAll, true);
    } catch (_) {}
  }

  /// Lets a player switch tutorials back on.
  static Future<void> resetAll() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      for (final String k in p.getKeys().toList()) {
        if (k.startsWith('howto_')) await p.remove(k);
      }
    } catch (_) {}
  }
}

/// Wraps a game. The first time a player opens it, a short guided tutorial runs
/// first and the game only starts after it ends. A small ? button afterwards
/// replays it. Games without a tutorial are returned unchanged.
class HowToGate extends StatefulWidget {
  final String gameKey;
  final Widget child;

  /// When false (for example inside a timed duel) the tutorial is skipped.
  final bool enabled;
  const HowToGate({super.key, required this.gameKey, required this.child, this.enabled = true});

  @override
  State<HowToGate> createState() => _HowToGateState();
}

class _HowToGateState extends State<HowToGate> {
  bool _checked = false;
  bool _showFirst = false;

  GameHowTo? get _howTo => HowToRegistry.byKey(widget.gameKey);

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    if (!widget.enabled || _howTo == null) {
      _checked = true;
      return;
    }
    final bool show = await HowToStore.shouldShow(widget.gameKey);
    if (!mounted) return;
    setState(() {
      _showFirst = show;
      _checked = true;
    });
  }

  void _firstDone() {
    if (!mounted) return;
    setState(() => _showFirst = false);
  }

  Future<void> _replay() async {
    final GameHowTo? h = _howTo;
    if (h == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext c) => HowToScreen(gameKey: widget.gameKey, howTo: h, first: false, onDone: () => Navigator.of(c).pop()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final GameHowTo? h = _howTo;
    if (!widget.enabled || h == null) return widget.child;
    if (!_checked) return const ColoredBox(color: Colors.black);
    if (_showFirst) {
      return HowToScreen(gameKey: widget.gameKey, howTo: h, first: true, onDone: _firstDone);
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        Positioned(
          right: 6,
          top: MediaQuery.of(context).size.height * 0.42,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _replay,
              customBorder: const CircleBorder(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The tutorial itself: a few steps, each with an animated demo and a line from Ryan.
class HowToScreen extends StatefulWidget {
  final String gameKey;
  final GameHowTo howTo;
  final bool first;
  final VoidCallback onDone;
  const HowToScreen({super.key, required this.gameKey, required this.howTo, required this.first, required this.onDone});

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  int _i = 0;
  bool _skipAll = false;

  late final List<TutorialStep> _steps = widget.howTo.steps.where((TutorialStep s) => !s.pcOnly || PcControlsGate.isComputer).toList();

  Future<void> _finish() async {
    if (widget.first) await HowToStore.markSeen(widget.gameKey, skipAll: _skipAll);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final GameHowTo g = widget.howTo;
    if (_steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return const ColoredBox(color: Colors.black);
    }
    final bool intro = _i == 0;
    final TutorialStep s = _steps[_i];
    final bool last = _i == _steps.length - 1;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                Row(children: <Widget>[
                  Icon(g.icon, color: g.color, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.first ? 'HOW TO PLAY ${g.name.toUpperCase()}' : g.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: 1),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(widget.first ? 'SKIP' : 'CLOSE', style: const TextStyle(color: GacomColors.textSecondary, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 6),
                if (intro)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: g.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: <Widget>[
                      Icon(Icons.flag_rounded, color: g.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(g.goal, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35))),
                    ]),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                      HowToDemo(key: ValueKey<int>(_i), step: s, color: g.color),
                      const SizedBox(height: 14),
                      Text('STEP ${_i + 1} OF ${_steps.length}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4, color: g.color)),
                      const SizedBox(height: 2),
                      Text(s.title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
                      const SizedBox(height: 10),
                      RyanBubble(text: s.text),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  for (int k = 0; k < _steps.length; k++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: k == _i ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: k == _i ? g.color : Colors.white24, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: <Widget>[
                  if (_i > 0)
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                        onPressed: () => setState(() => _i--),
                        child: const Text('BACK', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ),
                    ),
                  if (_i > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                      onPressed: last ? _finish : () => setState(() => _i++),
                      child: Text(last ? (widget.first ? 'GOT IT, PLAY' : 'DONE') : 'NEXT', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                    ),
                  ),
                ]),
                if (widget.first)
                  InkWell(
                    onTap: () => setState(() => _skipAll = !_skipAll),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Checkbox(value: _skipAll, activeColor: GacomColors.deepOrange, visualDensity: VisualDensity.compact, onChanged: (bool? v) => setState(() => _skipAll = v ?? false)),
                        ),
                        const Text('I know how games work, skip all tutorials', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
