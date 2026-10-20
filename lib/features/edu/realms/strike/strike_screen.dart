import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'strike_logic.dart';
import 'strike_painter.dart';
import 'strike_skins.dart';

/// Strike: an action arena where each question is a fight. Used for Sundial City,
/// Signal Ridge, Skyroot Frontier and Case Files, each with its own enemy behaviour.
class StrikeScreen extends StatelessWidget {
  const StrikeScreen({super.key, required this.skin, this.config = const RealmConfig()});
  final StrikeSkin skin;
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: skin.name,
      gameId: skin.gameId,
      title: skin.name,
      story: skin.story,
      howTo: skin.howTo,
      icon: skin.icon,
      accent: skin.accent,
      config: config,
      background: skin.floor,
      actions: const <RealmAction>[
        RealmAction(0, Icons.my_location_rounded, 'FIRE'),
        RealmAction(1, Icons.bolt_rounded, 'DASH'),
      ],
      create: (RealmContent content) => StrikeLogic(content, skin),
      painter: (RealmLogic logic, Listenable repaint) => StrikePainter(logic as StrikeLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final StrikeLogic g = logic as StrikeLogic;
        final q = g.q;
        if (q == null) return const SizedBox.shrink();
        final bool compact = MediaQuery.of(context).size.height < 440;
        const String letters = 'ABCDE';
        final double raw = g.roundT / StrikeLogic.roundLimit;
        final double frac = raw < 0 ? 0.0 : (raw > 1 ? 1.0 : raw);
        return Positioned(
          left: compact ? 110 : 12,
          right: compact ? 120 : 12,
          top: compact ? 44 : 92,
          child: Container(
            padding: EdgeInsets.fromLTRB(10, compact ? 6 : 10, 10, compact ? 6 : 10),
            decoration: BoxDecoration(
              color: const Color(0xCC000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: skin.accent.withOpacity(0.7)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(q.text, maxLines: compact ? 2 : 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 15, fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: <Widget>[
                for (int i = 0; i < q.options.length; i++)
                  GestureDetector(
                    onTap: () {
                      g.shootOption(i);
                      refresh();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 3 : 5),
                      decoration: BoxDecoration(
                        color: strikeColors[i % strikeColors.length].withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: strikeColors[i % strikeColors.length]),
                      ),
                      child: Text('${letters[i % letters.length]}  ${q.options[i]}', maxLines: 1, style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: frac, minHeight: 4, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(frac < 0.3 ? const Color(0xFFFF5252) : skin.accent)),
              ),
            ]),
          ),
        );
      },
    );
  }
}
