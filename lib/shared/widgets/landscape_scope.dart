import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps an open-world game in landscape while it is on screen.
///
/// On Android and iOS the phone is turned sideways and the system bars are
/// hidden; everything is put back when the game closes. In a browser the page
/// cannot always force a rotation, so when the window is still tall and narrow
/// a prompt asks the player to turn the device, with a way to play anyway.
class LandscapeScope extends StatefulWidget {
  final Widget child;
  const LandscapeScope({super.key, required this.child});

  @override
  State<LandscapeScope> createState() => _LandscapeScopeState();
}

class _LandscapeScopeState extends State<LandscapeScope> {
  bool _playAnyway = false;

  @override
  void initState() {
    super.initState();
    _lock();
  }

  Future<void> _lock() async {
    try {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // some platforms ignore this; the prompt below covers a tall window
    }
  }

  @override
  void dispose() {
    try {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints bc) {
      final bool tall = bc.maxHeight > bc.maxWidth * 1.05;
      return Stack(children: <Widget>[
        Positioned.fill(child: widget.child),
        if (tall && !_playAnyway)
          Positioned.fill(
            child: Material(
              color: const Color(0xF2080B14),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      const Icon(Icons.screen_rotation_rounded, color: Color(0xFFFFD54F), size: 64),
                      const SizedBox(height: 16),
                      const Text('TURN YOUR PHONE SIDEWAYS',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Text('This game plays best in landscape. Rotate your device and it will fill the screen.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => setState(() => _playAnyway = true),
                        child: const Text('Play anyway', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}
