import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'ember_logic.dart';
import 'ember_painter.dart';
import 'ember_panels.dart';

const Color _emAccent = Color(0xFF2ED3E6);
const Color _emInk = Color(0xFF04202A);
const Color _emBad = Color(0xFFFF8A80);
const Color _emGood = Color(0xFF69F0AE);
const Color _emAmber = Color(0xFFFFB74D);

/// Ember Archipelago: plot routes on a night-sea coordinate chart, sail, then
/// do the harbour job to relight each beacon.
class EmberScreen extends StatelessWidget {
  const EmberScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Ember Archipelago',
      gameId: 'ember',
      title: 'Ember Archipelago',
      story: 'The five beacons of the archipelago have gone dark. Read the orders, plot a route on the chart with coordinates, spend your fuel wisely and sail to each island. At every harbour, solve the job to relight the beacon. When all five burn, the Night Tide rises.',
      howTo: 'Tap grid points on the chart to plot waypoints. The fuel cost shows as you plot. Press SAIL to go, or UNDO to remove the last waypoint. At a harbour, finish the job and press SUBMIT.',
      icon: Icons.local_fire_department_rounded,
      accent: _emAccent,
      config: config,
      create: (RealmContent c) => EmberLogic(c),
      painter: (RealmLogic l, Listenable repaint) => EmberPainter(l as EmberLogic, repaint: repaint),
      hud: _emberHud,
      actions: const <RealmAction>[
        RealmAction(0, Icons.sailing_rounded, 'SAIL'),
        RealmAction(1, Icons.undo_rounded, 'UNDO'),
      ],
      joystick: false,
      duelSeconds: 420,
      background: const Color(0xFF030813),
    );
  }
}

Widget _emberHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final EmberLogic g = logic as EmberLogic;
  final MediaQueryData mq = MediaQuery.of(context);
  // The shell wraps this HUD in a SafeArea, which zeroes `padding`; viewPadding keeps the real insets.
  g.safeTop = mq.viewPadding.top;
  g.safeBottom = mq.viewPadding.bottom;
  final List<Widget> kids = <Widget>[];
  if (!g.over && (g.phase == emPlot || g.phase == emSail)) {
    kids.add(Positioned(left: 10, right: 98, bottom: 20, child: _orderStrip(g, refresh)));
  }
  if (g.modal && !g.over) kids.add(emberPanels(g, refresh));
  return Positioned.fill(child: Stack(children: kids));
}

Widget _orderStrip(EmberLogic g, VoidCallback refresh) {
  final bool plotting = g.phase == emPlot;
  final double cost = g.routeCost;
  final bool fits = (cost * 10).round() / 10 <= g.fuel + 1e-9;
  final double frac = (g.fuelShown / EmberLogic.fuelCap).clamp(0.0, 1.0).toDouble();
  final double need = plotting ? (cost / EmberLogic.fuelCap).clamp(0.0, 1.0).toDouble() : 0.0;
  String line;
  Color lineColor = Colors.white70;
  if (plotting) {
    if (g.route.isEmpty) {
      line = 'No route yet. Tap a grid point.';
    } else if (g.firstBadLeg >= 0) {
      line = 'Leg ${g.firstBadLeg + 1} crosses a reef.';
      lineColor = _emBad;
    } else if (!fits) {
      line = 'Route costs ${cost.toStringAsFixed(1)}: more than the tank.';
      lineColor = _emBad;
    } else {
      line = 'Route: ${g.route.length} waypoints, cost ${cost.toStringAsFixed(1)} of ${g.fuel.toStringAsFixed(1)} fuel.';
      lineColor = _emGood;
    }
  } else {
    line = 'Sailing...';
  }
  final String msg = g.hasMessage ? g.message : line;
  final Color msgColor = g.hasMessage ? (g.messageBad ? _emBad : Colors.white) : lineColor;
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    decoration: BoxDecoration(
      color: const Color(0xE6081824),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _emAccent.withValues(alpha: 0.8), width: 1.3),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Icon(Icons.local_fire_department_rounded, color: _emAmber, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text('ORDER ${g.litCount + 1} OF ${EmberLogic.islandCount}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        ),
        if (plotting)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              g.toggleHint();
              refresh();
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: g.hintOn ? _emAccent : Colors.white12,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: g.hintOn ? _emAccent : Colors.white24),
              ),
              child: Text(g.hintOn ? 'HIDE RING' : 'SHOW ISLAND', style: TextStyle(color: g.hintOn ? _emInk : Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.6)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Text('${g.orderPrefix} ${g.orderCoords}', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, height: 1.15)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 10,
          child: Stack(children: <Widget>[
            Container(color: Colors.white12),
            FractionallySizedBox(widthFactor: frac, child: Container(color: _emAccent)),
            if (plotting && need > 0) FractionallySizedBox(widthFactor: need, child: Container(color: (fits ? Colors.white : _emBad).withValues(alpha: 0.45))),
          ]),
        ),
      ),
      const SizedBox(height: 5),
      Text(msg, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: msgColor, fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
    ]),
  );
}
