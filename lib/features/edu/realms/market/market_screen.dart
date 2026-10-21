import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_kits.dart';
import '../realm_shell.dart';
import 'market_logic.dart';
import 'market_painter.dart';
import 'market_skins.dart';

const String marketStory =
    'One trading day, one basket and six thousand naira. Nobody is going to ask you a question: the money is the question. '
    'Buy where it is cheap, sell at your counter, and count the change right.';

const String marketHowTo =
    'DRAG anywhere to walk. Stand at a stall and press TRADE to buy: every board shows what the stall charges and what customers pay today, so buy when the stall price is under the selling price. '
    'Customers come to your counter on their own. Stand there, press TRADE, then TAP notes to make their change. The screen shows what you have handed over, not what you owe, so work the subtraction out yourself. '
    'Right change and the sale is yours. Wrong change and the customer still leaves with the correct money, so the mistake comes out of your profit. '
    'The market closes after about three minutes, and your profit is your score.';

/// Market Run: a trading day where the arithmetic is the gameplay.
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    GameKit.ensureLoaded();
    final MarketSkin skin = MarketSkin.equipped();
    return RealmShell(
      gameName: 'Market Run',
      gameId: 'market',
      title: 'Market Run',
      story: marketStory,
      howTo: marketHowTo,
      icon: Icons.storefront_rounded,
      accent: skin.accent,
      background: const Color(0xFF0D0B09),
      config: config,
      actions: const <RealmAction>[
        RealmAction(0, Icons.swap_horiz_rounded, 'TRADE'),
      ],
      create: (RealmContent content) => MarketLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => MarketPainter(logic as MarketLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final MarketLogic g = logic as MarketLogic;
        // The hud builder must hand the shell a Positioned, because the shell
        // drops it straight into its Stack.
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MarketHud(g: g, skin: skin, refresh: refresh),
        );
      },
    );
  }
}

class _MarketHud extends StatelessWidget {
  const _MarketHud({required this.g, required this.skin, required this.refresh});
  final MarketLogic g;
  final MarketSkin skin;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (g.noteT > 0 && g.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: skin.accent.withValues(alpha: 0.85)),
              ),
              child: Text(
                g.note,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
      if (g.panel == mkBuy) _buyPanel(context),
      if (g.panel == mkSell) _sellPanel(context),
    ]);
  }

  BoxDecoration get _panelDeco => BoxDecoration(
        color: const Color(0xF20E1014),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: skin.accent.withValues(alpha: 0.9), width: 1.6)),
      );

  Widget _label(String t, {Color color = Colors.white54, double size = 10.5}) => Text(
        t.toUpperCase(),
        style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, letterSpacing: 1.1),
      );

  Widget _pill(String t, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      );

  Widget _button(String label, VoidCallback? onTap, {Color? color, bool wide = true}) {
    final Color c = color ?? skin.accent;
    return SizedBox(
      width: wide ? double.infinity : null,
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap == null ? Colors.white12 : c,
          disabledBackgroundColor: Colors.white12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: onTap == null ? Colors.white38 : const Color(0xFF14101A),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ buy

  Widget _buyPanel(BuildContext context) {
    if (g.panelStall < 0 || g.panelStall >= g.stalls.length) return const SizedBox.shrink();
    final MkStall s = g.stalls[g.panelStall];
    final MkGood good = mkGoods[s.goodIndex];
    final int total = g.buyTotal;
    final int sells = g.market[s.goodIndex];
    final int perUnit = sells - s.price;
    final bool canBuy = total <= g.cash && g.buyQty >= 1 && g.buyQty <= s.stock && g.basketCount + g.buyQty <= MarketLogic.basketCap;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _panelDeco,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: _label('Buying ${good.name}', color: skin.accent, size: 13)),
          GestureDetector(
            onTap: () {
              g.close();
              refresh();
            },
            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: <Widget>[
          _pill('Stall ₦${s.price}', g.stallIsCheap ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80)),
          _pill('Sells at ₦$sells', Colors.white38),
          _pill(perUnit >= 0 ? '+₦$perUnit each' : '-₦${-perUnit} each', perUnit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80)),
          _pill('${s.stock} in stock', Colors.white24),
        ]),
        const SizedBox(height: 12),
        Row(children: <Widget>[
          _step(Icons.remove_rounded, () {
            g.setQty(g.buyQty - 1);
            refresh();
          }),
          Expanded(
            child: Column(children: <Widget>[
              Text('${g.buyQty}', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30)),
              _label('${g.buyQty} x ₦${s.price} = ₦$total'),
            ]),
          ),
          _step(Icons.add_rounded, () {
            g.setQty(g.buyQty + 1);
            refresh();
          }),
        ]),
        const SizedBox(height: 10),
        Row(children: <Widget>[
          Expanded(child: _label('You have ₦${g.cash}  |  basket ${g.basketCount}/${MarketLogic.basketCap}')),
        ]),
        const SizedBox(height: 10),
        _button(
          canBuy ? 'BUY FOR ₦$total' : 'CANNOT AFFORD OR CARRY',
          canBuy
              ? () {
                  g.confirmBuy();
                  refresh();
                }
              : null,
        ),
      ]),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );

  // ----------------------------------------------------------------- sell

  Widget _sellPanel(BuildContext context) {
    final MkCustomer? c = g.customer;
    if (c == null) return const SizedBox.shrink();
    final MkGood good = mkGoods[c.goodIndex];
    final int given = g.handedTotal;
    final bool enough = g.basket[c.goodIndex] >= c.units;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _panelDeco,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: _label('Serving a customer', color: skin.accent, size: 13)),
          GestureDetector(
            onTap: () {
              g.close();
              refresh();
            },
            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          '${c.units} ${good.name} at ₦${g.market[c.goodIndex]} each',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: <Widget>[
          _pill('Bill ₦${c.total}', Colors.white38),
          _pill('Paid ₦${c.paid}', skin.accent),
          _pill('You handed ₦$given', given == 0 ? Colors.white24 : const Color(0xFF4FC3F7)),
        ]),
        const SizedBox(height: 4),
        _label('Work out the change yourself, then tap the notes'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final int n in mkNotes)
              GestureDetector(
                onTap: () {
                  g.hand(n);
                  refresh();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14341F),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    '₦$n',
                    style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: <Widget>[
          SizedBox(
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: g.handedTotal == 0
                  ? null
                  : () {
                      g.undoHand();
                      refresh();
                    },
              child: const Text('UNDO', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _button(
              enough ? 'GIVE CHANGE' : 'NOT ENOUGH ${good.name.toUpperCase()}',
              enough
                  ? () {
                      g.confirmSale();
                      refresh();
                    }
                  : null,
            ),
          ),
        ]),
      ]),
    );
  }
}
