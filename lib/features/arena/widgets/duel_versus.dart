import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../../core/services/duel_live.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cosmetic_art.dart';
import '../../../shared/widgets/cosmetic_avatar.dart';

/// One player of a duel as the other sees them: banner behind, frame around
/// the picture, title under the name. These are the things a player buys, so a
/// rival's gear is visible before, during and after every match.
class DuelPlayerChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Map<String, dynamic>? loadout;
  final int? score;
  final bool highlight;
  final double width;
  final double height;
  final bool alignRight;

  const DuelPlayerChip({
    super.key,
    required this.name,
    this.avatarUrl,
    this.loadout,
    this.score,
    this.highlight = false,
    this.width = 150,
    this.height = 62,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final String? title = cosmeticTitleFor(loadout);
    final Color? nameColor = CosmeticsService.nameColorFor(loadout);
    final Widget avatar = CosmeticAvatar(avatarUrl: avatarUrl, name: name, radius: 18, equipped: loadout);
    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: nameColor ?? Colors.white)),
        if (title != null) Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
        if (score != null) Text('$score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
      ],
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? GacomColors.success : Colors.white24, width: highlight ? 1.6 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(fit: StackFit.expand, children: <Widget>[
          ProfileBanner(equipped: loadout, height: height, fallback: Container(color: GacomColors.cardDark)),
          Container(color: Colors.black.withValues(alpha: 0.28)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
              children: <Widget>[avatar, const SizedBox(width: 8), Flexible(child: text)],
            ),
          ),
        ]),
      ),
    );
  }
}

/// The two players side by side for the first seconds of a duel. It never
/// takes a touch, so play is not held up.
class DuelVersusIntro extends StatelessWidget {
  final String myName;
  final String? myAvatar;
  final Map<String, dynamic>? myLoadout;
  final String rivalName;
  final String? rivalAvatar;
  final Map<String, dynamic>? rivalLoadout;

  const DuelVersusIntro({
    super.key,
    required this.myName,
    this.myAvatar,
    this.myLoadout,
    required this.rivalName,
    this.rivalAvatar,
    this.rivalLoadout,
  });

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double chip = ((w - 70) / 2).clamp(110.0, 190.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, -24 * (1 - t)), child: child),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        DuelPlayerChip(name: myName, avatarUrl: myAvatar, loadout: myLoadout, width: chip),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 22, color: GacomColors.deepOrange, shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 6)])),
        ),
        DuelPlayerChip(name: rivalName, avatarUrl: rivalAvatar, loadout: rivalLoadout, width: chip, alignRight: true),
      ]),
    );
  }
}

/// Live standing during a duel: both scores, a tug-of-war bar and, when the
/// game has a shared objective, how many of its targets each player has.
class DuelRivalBar extends StatefulWidget {
  final DuelLive live;
  final String rivalName;
  const DuelRivalBar({super.key, required this.live, required this.rivalName});

  @override
  State<DuelRivalBar> createState() => _DuelRivalBarState();
}

class _DuelRivalBarState extends State<DuelRivalBar> {
  int _lastRelics = 0;
  String _flash = '';
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    widget.live.rival.addListener(_onRival);
  }

  @override
  void dispose() {
    widget.live.rival.removeListener(_onRival);
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onRival() {
    final RivalLive? r = widget.live.rival.value;
    if (r == null || !mounted) return;
    if (r.relics > _lastRelics) {
      _lastRelics = r.relics;
      _flashTimer?.cancel();
      setState(() => _flash = '${widget.rivalName} took relic ${r.relics}');
      _flashTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _flash = '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DuelLive live = widget.live;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[live.rival, live.mineScore, live.mineRelics]),
        builder: (BuildContext context, Widget? _) {
          final RivalLive? r = live.rival.value;
          final int mine = live.mineScore.value;
          final int theirs = r?.score ?? 0;
          final int total = mine + theirs;
          final double share = total <= 0 ? 0.5 : (mine / total).clamp(0.06, 0.94);
          final int diff = mine - theirs;
          final bool ahead = diff >= 0;
          final int goal = live.goal > 0 ? live.goal : (r?.goal ?? 0);
          String line;
          Color lineColor;
          if (_flash.isNotEmpty) {
            line = _flash;
            lineColor = const Color(0xFFFF8A80);
          } else if (r == null) {
            line = 'Waiting for ${widget.rivalName}...';
            lineColor = Colors.white60;
          } else if (diff == 0) {
            line = 'Level scores';
            lineColor = Colors.white70;
          } else {
            line = ahead ? 'You lead by ${diff.abs()}' : '${widget.rivalName} leads by ${diff.abs()}';
            lineColor = ahead ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80);
          }
          return Container(
            width: 250,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
            decoration: BoxDecoration(color: const Color(0xCC0B0B0F), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Row(children: <Widget>[
                Text('YOU $mine', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                Flexible(child: Text('${widget.rivalName.toUpperCase()} ${r == null ? '-' : theirs}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF40C4FF), fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13))),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: Row(children: <Widget>[
                    Expanded(flex: (share * 1000).round(), child: Container(color: GacomColors.deepOrange)),
                    Expanded(flex: 1000 - (share * 1000).round(), child: Container(color: const Color(0xFF40C4FF))),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: lineColor, fontSize: 11, fontWeight: FontWeight.w700)),
              if (goal > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Relics  ${live.mineRelics.value}/$goal  vs  ${r?.relics ?? 0}/$goal', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Plays the winner's equipped finisher once over the results, so the loser
/// sees what the winner owns. Nothing is shown when no finisher is equipped.
class DuelFinisherStage extends StatefulWidget {
  final Map<String, dynamic>? winnerLoadout;
  const DuelFinisherStage({super.key, required this.winnerLoadout});

  @override
  State<DuelFinisherStage> createState() => _DuelFinisherStageState();
}

class _DuelFinisherStageState extends State<DuelFinisherStage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? art = CosmeticsService.artOf(widget.winnerLoadout, 'finisher');
    if (art == null || _done) return const SizedBox.shrink();
    return Positioned.fill(
      child: FinisherOverlay(
        kind: art['kind']?.toString() ?? 'shockwave',
        color: artColor(art),
        color2: artColor2(art, Colors.white),
        onDone: () {
          if (mounted) setState(() => _done = true);
        },
      ),
    );
  }
}
