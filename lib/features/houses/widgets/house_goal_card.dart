import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../house_service.dart';
import 'house_visuals.dart';

/// "Ends in 3d 4h" style countdown, or null when there is no end time.
String? houseGoalCountdown(DateTime? endsAt) {
  if (endsAt == null) return null;
  final left = endsAt.difference(DateTime.now());
  if (left.isNegative) return 'Ending now';
  if (left.inDays >= 1) return 'Ends in ${left.inDays}d ${left.inHours % 24}h';
  if (left.inHours >= 1) return 'Ends in ${left.inHours}h ${left.inMinutes % 60}m';
  return 'Ends in ${left.inMinutes < 1 ? 1 : left.inMinutes}m';
}

/// The weekly House goal: progress, reward points, countdown and Titan Aura fragments.
class HouseGoalCard extends StatelessWidget {
  final HouseGoal goal;
  final Color color;
  const HouseGoalCard({super.key, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final countdown = houseGoalCountdown(goal.endsAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: goal.achieved ? GacomColors.success : GacomColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text('HOUSE GOAL', style: houseHeading(size: 13, color: GacomColors.textSecondary)),
          const Spacer(),
          if (goal.active && countdown != null) Text(countdown, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        if (!goal.active)
          const Text('No house goal is running this week.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13))
        else ...[
          Text(goal.title, style: houseHeading(size: 17)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.ratio,
              minHeight: 8,
              backgroundColor: GacomColors.elevatedCard,
              valueColor: AlwaysStoppedAnimation<Color>(goal.achieved ? GacomColors.success : color),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${formatPoints(goal.progress)} / ${formatPoints(goal.target)} ${goal.metricLabel}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Text(
              goal.achieved ? 'Goal reached' : '+${formatPoints(goal.rewardPoints)} points',
              style: TextStyle(color: goal.achieved ? GacomColors.success : GacomColors.gold, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          for (var k = 0; k < goal.fragmentsNeeded; k++)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(Icons.diamond_rounded, size: 16, color: (goal.unlocked || k < goal.fragments) ? GacomColors.accentCyan : GacomColors.elevatedCard),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              goal.unlocked
                  ? '${goal.rewardName} unlocked'
                  : '${goal.fragments} of ${goal.fragmentsNeeded} fragments toward ${goal.rewardName}',
              style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12),
            ),
          ),
        ]),
        if (!goal.unlocked && goal.active)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Reach the goal each week to earn a fragment.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          ),
      ]),
    );
  }
}
