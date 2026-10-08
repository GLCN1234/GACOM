import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../missions_service.dart';
import 'mission_style.dart';

/// Compact home-screen card. Renders nothing until the season loads, and
/// nothing at all when no season is running.
class MissionEntryCard extends StatefulWidget {
  const MissionEntryCard({super.key});
  @override
  State<MissionEntryCard> createState() => _MissionEntryCardState();
}

class _MissionEntryCardState extends State<MissionEntryCard> {
  Map<String, dynamic>? _season;
  int _approved = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await MissionsService.myMissions();
    if (!mounted) return;
    final s = res['season'];
    if (res['error'] != null || s is! Map) {
      setState(() => _season = null);
      return;
    }
    final ms = res['missions'];
    setState(() {
      _season = Map<String, dynamic>.from(s);
      _approved = (res['approved_count'] as num?)?.toInt() ?? 0;
      _count = ms is List ? ms.length : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final season = _season;
    if (season == null) return const SizedBox.shrink();
    final total = (season['total_days'] as num?)?.toInt() ?? 0;
    final today = (season['today_day'] as num?)?.toInt() ?? 0;
    String dayText;
    if (today < 1) {
      dayText = 'Starting soon';
    } else if (today > total) {
      dayText = 'Season finished';
    } else {
      dayText = 'Day $today of $total';
    }
    final value = _count <= 0 ? 0.0 : (_approved / _count).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: () => context.push('/missions').then((_) { if (mounted) _load(); }),
        child: MPanel(
          cut: 12,
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: MTac.gold.withOpacity(0.14), border: Border.all(color: MTac.gold.withOpacity(0.6))),
              child: const Icon(Icons.flag_rounded, color: MTac.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AGON MISSIONS', style: mHead(size: 15, color: MTac.gold, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text('$dayText  -  $_approved of $_count done', style: mBody(size: 12, color: MTac.textDim)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: value, minHeight: 4, backgroundColor: MTac.panelAlt, valueColor: const AlwaysStoppedAnimation<Color>(MTac.cyan)),
              ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: MTac.textMuted),
          ]),
        ),
      ),
    );
  }
}
