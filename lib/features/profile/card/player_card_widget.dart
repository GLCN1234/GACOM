import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../../shared/widgets/cosmetic_art.dart';
import '../../../shared/widgets/cosmetic_avatar.dart';
import '../../../shared/widgets/rarity.dart';
import 'player_card_service.dart';

const List<Color> rankColors = <Color>[
  Color(0xFF8A96AD), // Rookie
  Color(0xFFCD7F32), // Bronze
  Color(0xFFC0C8D8), // Silver
  Color(0xFFF6B93B), // Gold
  Color(0xFF4FD6C8), // Platinum
  Color(0xFF5BB8FF), // Diamond
  Color(0xFFB060FF), // Master
  Color(0xFFFF4F66), // Legend
];

/// Logical size of the card. Captured at 3x for a 1080 x 1350 image.
const double playerCardW = 360;
const double playerCardH = 450;

class PlayerCardWidget extends StatelessWidget {
  final PlayerCardData d;
  /// Equipped cosmetics row (see CosmeticsService.equipped): frame, banner,
  /// spray. Optional; the card still works without it.
  final Map<String, dynamic>? look;
  const PlayerCardWidget({super.key, required this.d, this.look});

  @override
  Widget build(BuildContext context) {
    final Color rc = rankColors[d.rankIndex.clamp(0, rankColors.length - 1)];
    final Map<String, dynamic>? sprayArt = CosmeticsService.artOf(look, 'spray');
    return SizedBox(
      width: playerCardW,
      height: playerCardH,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color.lerp(const Color(0xFF0B1020), rc, 0.30)!, const Color(0xFF080C14), Color.lerp(const Color(0xFF080C14), rc, 0.16)!],
          ),
          border: Border.all(color: rc.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Stack(fit: StackFit.expand, children: <Widget>[
          if (sprayArt != null)
            Positioned(
              right: -12,
              bottom: 46,
              child: Opacity(opacity: 0.22, child: SprayArt(kind: sprayArt['kind']?.toString() ?? 'star', color: artColor(sprayArt), size: 230)),
            ),
          Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Row(children: <Widget>[
            Text('GACOM', style: Tac.display(size: 15, color: Tac.gold, letter: 3)),
            const Spacer(),
            if (d.passName != null) _chip('${d.passName!.toUpperCase()}  LV ${d.passLevel}', d.passPremium ? Tac.gold : Tac.textDim),
          ]),
          if (ProfileBanner.colorsFor(equipped: look) != null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ProfileBanner(equipped: look, height: 30, fallback: const SizedBox.shrink()),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: <Widget>[
            _avatar(rc),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 21, color: d.nameColor ?? Tac.text, letter: 0.3)),
                if (d.tag.isNotEmpty) Text(d.tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.body(size: 14, color: Tac.textDim)),
                if (d.title != null) Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(d.title!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 11, color: rc, letter: 1.2)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            SizedBox(width: 84, height: 96, child: CustomPaint(painter: RankEmblemPainter(d.rankIndex, rc))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(d.rank.toUpperCase(), style: Tac.display(size: 26, color: rc, letter: 2)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(value: d.rankProgress, minHeight: 7, color: rc, backgroundColor: Colors.white12),
                ),
                const SizedBox(height: 4),
                Text(
                  d.rankNext == null ? 'Top rank reached' : '${d.points}/${d.rankNextFloor} points to ${d.rankNext}',
                  style: Tac.body(size: 12, color: Tac.textDim),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            Expanded(child: _stat('${d.points}', 'POINTS', rc)),
            Expanded(child: _stat('${d.wins}', 'WINS', rc)),
            Expanded(child: _stat('${d.winRate}%', 'WIN RATE', rc)),
            Expanded(child: _stat('${d.games}', 'GAMES', rc)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(children: <Widget>[
              const Icon(Icons.location_city_rounded, color: Color(0xFFFF2E93), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('DARKOM CITY', style: Tac.display(size: 11, color: Tac.textDim, letter: 1.2))),
              Text('${d.missionsCleared}/120 missions   |   Chapter ${d.chapter > 5 ? 'Done' : d.chapter}', style: Tac.body(size: 13, color: Tac.text)),
            ]),
          ),
          const Spacer(),
          Row(children: <Widget>[
            if (d.badges.isEmpty)
              Text('No badges yet', style: Tac.body(size: 12, color: Tac.textDim))
            else
              for (final CardBadge b in d.badges)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Rarity.parse(b.rarity).color.withValues(alpha: 0.16),
                      border: Border.all(color: Rarity.parse(b.rarity).color, width: 1.3),
                    ),
                    child: Icon(b.icon, size: 18, color: Rarity.parse(b.rarity).color),
                  ),
                ),
            const Spacer(),
            if (d.houseName != null)
              Flexible(child: _chip(d.houseName!.toUpperCase(), d.houseColor ?? Tac.cyan)),
          ]),
          const SizedBox(height: 8),
          Row(children: <Widget>[
            Text('Player since ${d.joinedYear}', style: Tac.body(size: 11, color: Tac.textDim)),
            const Spacer(),
            Text('gamicom.net', style: Tac.display(size: 12, color: Tac.gold, letter: 1)),
          ]),
        ])),
        ]),
      ),
    );
  }

  Widget _avatar(Color rc) {
    if (look != null && look!['avatar_frame'] is Map) {
      return SizedBox(
        width: 66,
        height: 66,
        child: Center(child: CosmeticAvatar(radius: 28, avatarUrl: d.avatarUrl, name: d.name, equipped: look)),
      );
    }
    final String initial = d.name.isEmpty ? '?' : d.name.characters.first.toUpperCase();
    final Widget fallback = Container(
      color: const Color(0xFF1B2A44),
      alignment: Alignment.center,
      child: Text(initial, style: Tac.display(size: 26)),
    );
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rc, width: 2.5)),
      child: ClipOval(
        child: (d.avatarUrl == null || d.avatarUrl!.isEmpty)
            ? fallback
            : Image.network(d.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.7))),
        child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 10, color: c, letter: 0.8)),
      );

  Widget _stat(String v, String l, Color rc) => Column(children: <Widget>[
        Text(v, style: Tac.display(size: 19, color: Tac.text)),
        const SizedBox(height: 1),
        Text(l, style: Tac.display(size: 9, color: Tac.textDim, letter: 1)),
      ]);
}

/// A shield with one chevron per rank step.
class RankEmblemPainter extends CustomPainter {
  final int index;
  final Color color;
  RankEmblemPainter(this.index, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Path shield = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.96, h * 0.14)
      ..lineTo(w * 0.96, h * 0.52)
      ..quadraticBezierTo(w * 0.96, h * 0.84, w * 0.5, h)
      ..quadraticBezierTo(w * 0.04, h * 0.84, w * 0.04, h * 0.52)
      ..lineTo(w * 0.04, h * 0.14)
      ..close();
    canvas.drawShadow(shield, color, 10, true);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.55)!],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(shield, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Color.lerp(color, Colors.white, 0.6)!);
    final Path inner = Path()
      ..moveTo(w * 0.5, h * 0.09)
      ..lineTo(w * 0.86, h * 0.2)
      ..lineTo(w * 0.86, h * 0.52)
      ..quadraticBezierTo(w * 0.86, h * 0.77, w * 0.5, h * 0.9)
      ..quadraticBezierTo(w * 0.14, h * 0.77, w * 0.14, h * 0.52)
      ..lineTo(w * 0.14, h * 0.2)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.black.withValues(alpha: 0.35));
    // chevrons: 1 for Rookie up to 8 for Legend, in two columns past 4
    final int n = min(8, index + 1);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.95);
    final int rows = min(4, n);
    final double top = h * 0.5 - rows * 6.5;
    for (int i = 0; i < rows; i++) {
      final double y = top + i * 13;
      final Path c = Path()
        ..moveTo(w * 0.32, y + 5)
        ..lineTo(w * 0.5, y - 3)
        ..lineTo(w * 0.68, y + 5);
      canvas.drawPath(c, p);
    }
    if (n > 4) {
      final Paint dot = Paint()..color = Colors.white;
      for (int i = 0; i < n - 4; i++) {
        canvas.drawCircle(Offset(w * 0.5 + (i - (n - 5) / 2) * 11, h * 0.2 + 2), 3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RankEmblemPainter old) => old.index != index || old.color != color;
}
