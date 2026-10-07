import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

/// One line in a controls guide: the keys and what they do.
class PcKeyHelp {
  final String keys;
  final String action;
  const PcKeyHelp(this.keys, this.action);
}

class PcControlsGuide {
  final String title;
  final List<PcKeyHelp> keys;
  final String mouse;
  const PcControlsGuide({required this.title, required this.keys, required this.mouse});
}

/// Keyboard guides, keyed by game key. A game only appears here when it
/// really has keyboard controls.
class PcControlsGuides {
  static const Map<String, PcControlsGuide> all = <String, PcControlsGuide>{
    'odyssey': PcControlsGuide(
      title: 'Odyssey',
      keys: <PcKeyHelp>[
        PcKeyHelp('W A S D or arrow keys', 'Move around the world'),
        PcKeyHelp('Space or Left Shift', 'Dash'),
        PcKeyHelp('Esc or P', 'Pause'),
      ],
      mouse: 'Click and drag anywhere to steer with the on-screen joystick. Click answers to choose them.',
    ),
    'biome': PcControlsGuide(
      title: 'Biome',
      keys: <PcKeyHelp>[
        PcKeyHelp('W A S D or arrow keys', 'Move through the wild'),
        PcKeyHelp('Esc or P', 'Pause'),
      ],
      mouse: 'Click and drag to steer. Click to choose answers and battle moves.',
    ),
    'windward': PcControlsGuide(
      title: 'Windward',
      keys: <PcKeyHelp>[
        PcKeyHelp('W A S D or arrow keys', 'Steer the ship'),
        PcKeyHelp('Space', 'Trim the sails'),
        PcKeyHelp('E', 'Drop anchor'),
        PcKeyHelp('Esc or P', 'Pause'),
      ],
      mouse: 'Click and drag to steer. Click the TRIM and ANCHOR buttons.',
    ),
    'delve': PcControlsGuide(
      title: 'Delve',
      keys: <PcKeyHelp>[
        PcKeyHelp('W A S D or arrow keys', 'Move through the dungeon'),
        PcKeyHelp('Space', 'Sprint'),
        PcKeyHelp('Esc or P', 'Pause'),
      ],
      mouse: 'Click and drag to steer. Click the SPRINT button.',
    ),
    'casefiles': PcControlsGuide(
      title: 'Case Files',
      keys: <PcKeyHelp>[
        PcKeyHelp('W A S D or arrow keys', 'Walk the scene'),
        PcKeyHelp('Space', 'Inspect what is nearby'),
        PcKeyHelp('Esc or P', 'Pause'),
      ],
      mouse: 'Click and drag to walk. Click INSPECT and the suspects.',
    ),
    'starblaster': PcControlsGuide(
      title: 'Star Blaster',
      keys: <PcKeyHelp>[
        PcKeyHelp('A D or Left Right', 'Fly left and right'),
        PcKeyHelp('W S or Up Down', 'Fly up and down'),
      ],
      mouse: 'Click and drag the ship.',
    ),
    'dashrunner': PcControlsGuide(
      title: 'Dash Runner',
      keys: <PcKeyHelp>[
        PcKeyHelp('Space or Up', 'Jump'),
        PcKeyHelp('Down', 'Slide'),
      ],
      mouse: 'Click or tap to jump.',
    ),
    'skyhopper': PcControlsGuide(
      title: 'Sky Hopper',
      keys: <PcKeyHelp>[
        PcKeyHelp('Space or Up', 'Hop'),
      ],
      mouse: 'Click or tap to hop.',
    ),
    'blockdrop': PcControlsGuide(
      title: 'Block Drop',
      keys: <PcKeyHelp>[
        PcKeyHelp('Left Right', 'Move the piece'),
        PcKeyHelp('Down', 'Soft drop'),
        PcKeyHelp('Up or X', 'Rotate clockwise'),
        PcKeyHelp('Z', 'Rotate counter-clockwise'),
        PcKeyHelp('Space', 'Hard drop'),
        PcKeyHelp('C or Left Shift', 'Hold piece'),
        PcKeyHelp('P', 'Pause'),
      ],
      mouse: 'Use the on-screen buttons and swipes.',
    ),
  };
}

/// Reads whether the player chose keyboard control for the current game.
class PcControls extends InheritedWidget {
  final bool keyboard;
  const PcControls({super.key, required this.keyboard, required super.child});

  static bool keyboardOn(BuildContext context) {
    final PcControls? p = context.dependOnInheritedWidgetOfExactType<PcControls>();
    return p?.keyboard ?? true;
  }

  @override
  bool updateShouldNotify(PcControls old) => old.keyboard != keyboard;
}

/// On a computer, asks the player how they want to play a game that has
/// keyboard controls, shows the keys, and remembers the answer. A small KEYS
/// button re-opens the guide. On phones and tablets it does nothing.
class PcControlsGate extends StatefulWidget {
  final String gameKey;
  final Widget child;
  const PcControlsGate({super.key, required this.gameKey, required this.child});

  /// True on desktop operating systems, and on the web when a mouse is
  /// connected and the device is not a phone or tablet.
  static bool get isComputer {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  State<PcControlsGate> createState() => _PcControlsGateState();
}

class _PcControlsGateState extends State<PcControlsGate> {
  bool _keyboard = true;
  bool _asked = false;

  PcControlsGuide? get _guide => PcControlsGuides.all[widget.gameKey];
  String get _prefKey => 'pc_controls_${widget.gameKey}';

  bool get _active {
    if (_guide == null) return false;
    if (PcControlsGate.isComputer) return true;
    if (kIsWeb) {
      try {
        return RendererBinding.instance.mouseTracker.mouseIsConnected;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || !_active) return;
    String? saved;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      saved = p.getString(_prefKey);
    } catch (_) {}
    if (!mounted) return;
    if (saved == 'keyboard' || saved == 'mouse') {
      setState(() => _keyboard = saved == 'keyboard');
      return;
    }
    await _ask(first: true);
  }

  Future<void> _ask({required bool first}) async {
    final PcControlsGuide? g = _guide;
    if (g == null || !mounted || _asked && first) return;
    _asked = true;
    final _Choice? c = await showDialog<_Choice>(
      context: context,
      barrierDismissible: !first,
      builder: (BuildContext ctx) => _ControlsDialog(guide: g, current: _keyboard, first: first),
    );
    if (!mounted || c == null) return;
    setState(() => _keyboard = c.keyboard);
    if (c.remember) {
      try {
        final SharedPreferences p = await SharedPreferences.getInstance();
        await p.setString(_prefKey, c.keyboard ? 'keyboard' : 'mouse');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    return PcControls(
      keyboard: _keyboard,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ExcludeFocus(excluding: !_keyboard, child: widget.child),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _ask(first: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      Icon(_keyboard ? Icons.keyboard_rounded : Icons.mouse_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 5),
                      const Text('CONTROLS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white70, letterSpacing: 1)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice {
  final bool keyboard;
  final bool remember;
  const _Choice(this.keyboard, this.remember);
}

class _ControlsDialog extends StatefulWidget {
  final PcControlsGuide guide;
  final bool current;
  final bool first;
  const _ControlsDialog({required this.guide, required this.current, required this.first});

  @override
  State<_ControlsDialog> createState() => _ControlsDialogState();
}

class _ControlsDialogState extends State<_ControlsDialog> {
  late bool _keyboard = widget.current;
  bool _remember = true;

  Widget _option(IconData icon, String title, String sub, bool value) {
    final bool sel = _keyboard == value;
    return InkWell(
      onTap: () => setState(() => _keyboard = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? GacomColors.deepOrange.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? GacomColors.deepOrange : Colors.white24, width: sel ? 1.6 : 1),
        ),
        child: Row(children: <Widget>[
          Icon(icon, color: sel ? GacomColors.deepOrange : Colors.white60, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.3)),
            ]),
          ),
          Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? GacomColors.deepOrange : Colors.white38, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PcControlsGuide g = widget.guide;
    return Dialog(
      backgroundColor: GacomColors.cardDark,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('PLAYING ${g.title.toUpperCase()} ON A COMPUTER', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            const Text('How do you want to control the game?', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            _option(Icons.keyboard_rounded, 'Keyboard', 'Use the keys below. The mouse still works too.', true),
            const SizedBox(height: 8),
            _option(Icons.mouse_rounded, 'Mouse or touch only', g.mouse, false),
            const SizedBox(height: 14),
            if (_keyboard) ...<Widget>[
              const Text('KEYS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.deepOrange, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              for (final PcKeyHelp k in g.keys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Container(
                      constraints: const BoxConstraints(minWidth: 130),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)),
                      child: Text(k.keys, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(k.action, style: const TextStyle(color: Colors.white70, fontSize: 13)))),
                  ]),
                ),
              const SizedBox(height: 6),
            ],
            InkWell(
              onTap: () => setState(() => _remember = !_remember),
              child: Row(children: <Widget>[
                Checkbox(value: _remember, activeColor: GacomColors.deepOrange, onChanged: (bool? v) => setState(() => _remember = v ?? true)),
                const Expanded(child: Text('Remember my choice for this game', style: TextStyle(color: Colors.white70, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context, _Choice(_keyboard, _remember)),
                child: Text(widget.first ? 'START PLAYING' : 'SAVE', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
