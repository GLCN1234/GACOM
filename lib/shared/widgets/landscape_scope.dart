import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps an open-world game in landscape while it is on screen.
///
/// On Android and iOS the phone is turned sideways and the system bars are
/// hidden; everything is put back when the game closes. A browser often cannot
/// force a rotation (rotation lock, or the page is not installed), so when the
/// window is still tall and narrow the game is turned a quarter turn by the app
/// itself and fills the screen. Touches follow the turn. As soon as the device
/// really is sideways the window is wide and nothing is turned.
class LandscapeScope extends StatefulWidget {
  final Widget child;
  const LandscapeScope({super.key, required this.child});

  @override
  State<LandscapeScope> createState() => _LandscapeScopeState();
}

class _LandscapeScopeState extends State<LandscapeScope> {
  bool _manualPortrait = false;

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
      // some platforms ignore this; the quarter turn below covers a tall window
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
      // Games are laid out to fixed sizes: a phone set to a large font or display
      // size must not blow up their buttons and captions.
      final MediaQueryData base = MediaQuery.of(context);
      final MediaQueryData calm = base.copyWith(textScaler: base.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.1));
      final bool turn = tall && !_manualPortrait;
      if (!turn) {
        return Stack(children: <Widget>[
          Positioned.fill(child: MediaQuery(data: calm, child: widget.child)),
          if (tall)
            Positioned(
              left: 8,
              bottom: 8,
              child: _chip(Icons.screen_rotation_rounded, 'Landscape', () => setState(() => _manualPortrait = false)),
            ),
        ]);
      }
      final MediaQueryData mq = calm;
      final MediaQueryData swapped = mq.copyWith(
        size: Size(mq.size.height, mq.size.width),
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      );
      return Stack(children: <Widget>[
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: RotatedBox(
              quarterTurns: 1,
              child: MediaQuery(data: swapped, child: widget.child),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _chip(Icons.stay_current_portrait_rounded, 'Portrait', () => setState(() => _manualPortrait = true)),
        ),
      ]);
    });
  }

  Widget _chip(IconData icon, String label, VoidCallback tap) => Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: const Color(0x88000000), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ));
}
