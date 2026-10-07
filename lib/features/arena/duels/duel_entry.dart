import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/duel_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/tutorial/how_to_gate.dart';
import '../../../shared/widgets/pc_controls_gate.dart';
import '../services/duel_service.dart';
import 'duel_registry.dart';

/// Wraps a game screen with a small "1v1" tab on the left edge. Tapping it
/// finds (or opens) a duel for that game. It never shows inside a duel.
class DuelEntry extends StatefulWidget {
  final String gameKey;
  final Widget child;
  const DuelEntry({super.key, required this.gameKey, required this.child});

  @override
  State<DuelEntry> createState() => _DuelEntryState();
}

class _DuelEntryState extends State<DuelEntry> {
  bool _busy = false;

  Future<void> _go() async {
    final DuelGame? g = DuelRegistry.byKey(widget.gameKey);
    if (g == null || _busy) return;
    setState(() => _busy = true);
    try {
      final DuelMatch m = await DuelService.quick(g);
      if (!mounted) return;
      setState(() => _busy = false);
      await context.push('/arena/duel/${m.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      GacomSnackbar.show(context, 'Could not start a 1v1 right now', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DuelSession.current != null || DuelRegistry.byKey(widget.gameKey) == null) {
      return HowToGate(gameKey: widget.gameKey, enabled: DuelSession.current == null, child: PcControlsGate(gameKey: widget.gameKey, child: widget.child));
    }
    return HowToGate(gameKey: widget.gameKey, child: PcControlsGate(gameKey: widget.gameKey, child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: MediaQuery.of(context).size.height * 0.42,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _go,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: GacomColors.deepOrange.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.sports_kabaddi_rounded, color: Colors.white, size: 20),
                        SizedBox(height: 2),
                        Text('1v1', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)),
                      ]),
              ),
            ),
          ),
        ),
      ],
    )));
  }
}
