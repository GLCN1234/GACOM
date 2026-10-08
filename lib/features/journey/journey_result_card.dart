import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/rarity.dart';
import 'journey_service.dart';
import 'journey_widgets.dart';

/// Shown on a run's end screen: stars gained, quests that moved, gates
/// cleared and zones opened. Renders nothing when the run changed nothing.
class JourneyResultCard extends StatelessWidget {
  final JourneyRunResult? result;
  const JourneyResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final JourneyRunResult? r = result;
    if (r == null || (r.changes.isEmpty && r.cleared.isEmpty && r.opened.isEmpty)) {
      return const SizedBox.shrink();
    }
    int gained = r.gained;
    if (gained <= 0) {
      for (final JourneyChange c in r.changes) {
        if (c.after > c.before) gained += c.after - c.before;
      }
    }
    return TacticalPanel(
      keyline: Tac.gold.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Text('JOURNEY', style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.textDim, letter: 1.4)),
          const Spacer(),
          if (gained > 0) ...<Widget>[
            const Icon(Icons.star_rounded, size: 18, color: Tac.gold),
            const SizedBox(width: 4),
            Text('+$gained', style: Tac.display(size: 18, weight: FontWeight.w800, color: Tac.gold)),
          ],
        ]),
        const SizedBox(height: 8),
        for (final JourneyChange c in r.changes) _changeRow(c),
        for (final int z in r.cleared) _line(Icons.flag_rounded, 'Gate cleared in zone $z', Tac.gold),
        for (final int z in r.opened) _line(Icons.lock_open_rounded, 'Zone $z opened', Tac.cyan),
        const SizedBox(height: 10),
        TacButton(
          label: 'OPEN JOURNEY',
          icon: Icons.map_rounded,
          color: Tac.gold,
          filled: false,
          height: 40,
          onPressed: () => context.push('/journey/${r.realmId}'),
        ),
      ]),
    );
  }

  Widget _line(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Tac.display(size: 13, weight: FontWeight.w800, color: color, letter: 0.4))),
      ]),
    );
  }

  Widget _changeRow(JourneyChange c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: <Widget>[
        Expanded(
          child: Text(
            c.isGate ? '${c.title} (mastery gate)' : c.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Tac.body(size: 13, weight: FontWeight.w700, color: Tac.text),
          ),
        ),
        const SizedBox(width: 8),
        JourneyStarRow(stars: c.before, size: 13),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 13, color: Tac.textDim)),
        JourneyStarRow(stars: c.after, size: 13),
      ]),
    );
  }
}
