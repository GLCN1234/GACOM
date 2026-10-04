import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class HowToPlayStep {
  final IconData icon;
  final String title;
  final String description;
  const HowToPlayStep({required this.icon, required this.title, required this.description});
}

/// A one-time "how to play" screen shown the first time someone opens
/// a given game, so new players aren't just dropped in lost. Wraps
/// the game's own screen content — shows the instructions first, then
/// reveals the actual game once dismissed. Persisted per game per
/// device, so returning players never see it again unless they clear
/// app data.
class HowToPlayOverlay extends StatefulWidget {
  final String gameKey;
  final String title;
  final List<HowToPlayStep> steps;
  final Widget child;
  const HowToPlayOverlay({super.key, required this.gameKey, required this.title, required this.steps, required this.child});

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  bool _loading = true;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('how_to_play_seen_${widget.gameKey}') ?? false;
      if (mounted) setState(() { _show = !seen; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('how_to_play_seen_${widget.gameKey}', true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.child;
    return Stack(children: [
      widget.child,
      if (_show) Container(
        color: Colors.black.withOpacity(0.88),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(28),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: GacomDecorations.glassCard(context, radius: 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 16),
              ...widget.steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(s.icon, color: GacomColors.accentCyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                    Text(s.description, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  ])),
                ]),
              )),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _dismiss,
                child: const Text('START', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
              )),
            ]),
          ),
        ),
      ),
    ]);
  }
}
