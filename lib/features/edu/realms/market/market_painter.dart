import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'market_logic.dart';
import 'market_skins.dart';

/// Draws Market Run. The world is drawn into the top part of the screen only,
/// so a trade panel at the bottom can never cover the player or a stall.
class MarketPainter extends CustomPainter {
  final MarketLogic g;
  final Paint _p = Paint();

  MarketPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  /// How much of the screen height the market itself uses.
  static double worldH(Size s, bool panelOpen) => s.height * (panelOpen ? 0.52 : 0.70);

  @override
  void paint(Canvas canvas, Size size) {
    final MarketSkin skin = g.skin;
    final double wh = worldH(size, g.panel != mkNone);
    final double w = size.width;

    double sx(double wx) => wx * w;
    double sy(double wy) => wy * wh;

    _p.shader = null;
    _p.color = const Color(0xFF0D0B09);
    canvas.drawRect(Offset.zero & size, _p);

    // Ground, in bands so movement reads.
    _p.color = skin.ground;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, wh), _p);
    _p.color = skin.groundAlt;
    for (int i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, wh * i / 8, w, wh / 8), _p);
    }
    _dust(canvas, w, wh);

    // Your counter, then the stalls, then whoever is standing in front.
    _counter(canvas, sx(MarketLogic.counterX), sy(MarketLogic.counterY), w, skin);
    for (final MkStall s in g.stalls) {
      _stall(canvas, s, sx(s.x), sy(s.y), w, skin);
    }
    if (g.customer != null) {
      RealmDraw.person(
        canvas,
        sx(MarketLogic.counterX) + w * 0.09,
        sy(MarketLogic.counterY) - 6,
        facing: -1,
        shirt: const Color(0xFF42A5F5),
        pants: const Color(0xFF37474F),
        scale: 0.95,
      );
      RealmDraw.label(canvas, 'waiting', Offset(sx(MarketLogic.counterX) + w * 0.09, sy(MarketLogic.counterY) - 44), size: 10, maxWidth: 70);
    }
    _player(canvas, sx(g.x), sy(g.y));

    // A hard edge under the world, so the panel below reads as a separate shelf.
    _p.color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTWH(0, wh - 3, w, 3), _p);

    if (g.hitFlash > 0) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.20 * mkCl(g.hitFlash / 0.5, 0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, wh), _p);
    }
    if (g.goodFlash > 0) {
      _p.color = const Color(0xFF00E676).withValues(alpha: 0.13 * mkCl(g.goodFlash / 0.5, 0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, wh), _p);
    }
  }

  void _dust(Canvas canvas, double w, double wh) {
    _p.color = Colors.white.withValues(alpha: 0.03);
    for (int i = 0; i < 26; i++) {
      final double dx = realmUnit(i, 3, 11) * w;
      final double dy = ((realmUnit(i, 7, 5) + g.time * 0.03) % 1.0) * wh;
      canvas.drawCircle(Offset(dx, dy), 1.5 + realmUnit(i, 9, 2) * 2.5, _p);
    }
  }

  void _stall(Canvas canvas, MkStall s, double cx, double cy, double w, MarketSkin skin) {
    final MkGood good = mkGoods[s.goodIndex];
    final double sw = w * 0.21;
    final double sh = sw * 0.52;
    final bool here = g.atStall >= 0 && g.stalls[g.atStall] == s;
    final bool cheap = s.price < g.market[s.goodIndex];

    RealmDraw.shadow(canvas, cx, cy + sh * 0.6, sw * 0.9);
    // Table.
    _p.color = const Color(0xFF4E342E);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: sw, height: sh), const Radius.circular(4)), _p);
    // Goods on the table.
    _p.color = good.color;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(cx - sw * 0.33 + i * sw * 0.165, cy - sh * 0.12), sw * 0.055, _p);
    }
    // Canopy, striped or plain by the skin.
    final Rect top = Rect.fromLTWH(cx - sw * 0.6, cy - sh * 1.5, sw * 1.2, sh * 0.5);
    _p.color = skin.canopy;
    canvas.drawRect(top, _p);
    if (skin.cloth != 'plain') {
      _p.color = skin.canopyAlt;
      final int bands = skin.cloth == 'ankara' ? 7 : 4;
      for (int i = 0; i < bands; i += 2) {
        canvas.drawRect(Rect.fromLTWH(top.left + top.width * i / bands, top.top, top.width / bands, top.height), _p);
      }
    }
    _p.color = const Color(0xFF3E2723);
    canvas.drawRect(Rect.fromLTWH(top.left, top.bottom, 3, sh * 1.0), _p);
    canvas.drawRect(Rect.fromLTWH(top.right - 3, top.bottom, 3, sh * 1.0), _p);

    // The price board. This is the number the player is reading all game.
    final Rect board = Rect.fromCenter(center: Offset(cx, cy + sh * 0.95), width: sw * 1.05, height: sh * 0.62);
    _p.color = const Color(0xF20E1014);
    canvas.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(6)), _p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = here ? 2.4 : 1.2
        ..color = here ? skin.accent : (cheap ? const Color(0xFF69F0AE) : Colors.white24),
    );
    RealmDraw.text(
      canvas,
      '${good.name}  ₦${s.price}',
      board.center.translate(0, -board.height * 0.16),
      mkCl(board.height * 0.34, 9.0, 14.0),
      cheap ? const Color(0xFF69F0AE) : Colors.white,
      maxWidth: board.width - 6,
      maxLines: 1,
    );
    RealmDraw.text(
      canvas,
      'sells at ₦${g.market[s.goodIndex]}  |  ${s.stock} left',
      board.center.translate(0, board.height * 0.26),
      mkCl(board.height * 0.26, 7.5, 11.0),
      Colors.white60,
      maxWidth: board.width - 6,
      maxLines: 1,
    );
  }

  void _counter(Canvas canvas, double cx, double cy, double w, MarketSkin skin) {
    final double cw = w * 0.30;
    final double ch = cw * 0.30;
    final bool here = g.atCounter;
    RealmDraw.shadow(canvas, cx, cy + ch * 0.7, cw * 0.9);
    _p.color = skin.counter;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch), const Radius.circular(6)), _p);
    _p.color = realmLighten(skin.counter, 0.14);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy - ch * 0.34), width: cw, height: ch * 0.22), _p);
    RealmDraw.text(canvas, 'YOUR COUNTER', Offset(cx, cy), mkCl(ch * 0.34, 8.0, 12.0), Colors.white, maxWidth: cw - 8, maxLines: 1);
    if (here) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: cw + 6, height: ch + 6), const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = skin.accent,
      );
    }
    // Basket contents on the counter, so the player can see their stock.
    double bx = cx - cw * 0.40;
    for (int i = 0; i < g.basket.length; i++) {
      if (g.basket[i] <= 0) continue;
      _p.color = mkGoods[i].color;
      canvas.drawCircle(Offset(bx, cy - ch * 0.75), w * 0.016, _p);
      RealmDraw.text(canvas, '${g.basket[i]}', Offset(bx, cy - ch * 0.75), w * 0.019, const Color(0xFF14101A), maxWidth: 30, maxLines: 1);
      bx += w * 0.045;
    }
  }

  void _player(Canvas canvas, double px, double py) {
    RealmDraw.person(
      canvas,
      px,
      py,
      phase: g.walkPhase,
      moving: (g.inputX.abs() + g.inputY.abs()) > 0.02 && g.panel == mkNone,
      facing: g.facing,
      hero: true,
      scale: 1.05,
    );
    // The basket in hand.
    if (g.basketCount > 0) {
      _p.color = const Color(0xFF8D6E63);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(px + g.facing * 13, py + 6), width: 13, height: 9), const Radius.circular(3)),
        _p,
      );
    }
  }

  @override
  bool shouldRepaint(MarketPainter old) => true;
}
