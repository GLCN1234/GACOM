import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../services/arena_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// A single, reusable "play online" entry point — lives inside each
/// supported game's own AppBar, not squeezed onto a store grid card.
/// Creates a genuinely free (zero-stake) match and drops the player
/// straight into the real multiplayer version of the same game.
class Play1v1Button extends StatefulWidget {
  final String gameTypeKey; // matches match_screen.dart's switch keys
  const Play1v1Button({super.key, required this.gameTypeKey});
  @override State<Play1v1Button> createState() => _Play1v1ButtonState();
}

class _Play1v1ButtonState extends State<Play1v1Button> {
  bool _loading = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    final result = await ArenaService.createMatch(gameType: widget.gameTypeKey, stakeAmount: 0);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result['match'] != null) {
      context.push('/arena/match/${result['match']['id']}');
    } else {
      GacomSnackbar.show(context, result['error'] ?? 'Could not find a match right now', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Center(child: _loading
      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.electricBlue))
      : TextButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.people_alt_rounded, size: 16, color: GacomColors.electricBlue),
          label: const Text('Play Online', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.electricBlue)),
        )),
  );
}
