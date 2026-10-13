import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/boost_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/rarity.dart';

/// The Boosts tab of the shop. Casual boosts only: they speed up the Season
/// Pass and skin evolution, and never touch a score, a duel or a prize.
class BoostShelf extends StatefulWidget {
  const BoostShelf({super.key});

  @override
  State<BoostShelf> createState() => _BoostShelfState();
}

class _BoostShelfState extends State<BoostShelf> {
  BoostState? _s;
  bool _loading = true;
  String? _busy;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      final BoostState? s = _s;
      if (s?.active != null) {
        if (s!.active!.live) {
          setState(() {});
        } else {
          _load();
        }
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final BoostState? s = await BoostService.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
  }

  Future<void> _buy(BoostItem b) async {
    if (_busy != null) return;
    setState(() => _busy = 'buy_${b.id}');
    final BoostResult r = await BoostService.buy(b.id);
    if (!mounted) return;
    setState(() => _busy = null);
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Purchase failed', isError: true);
      return;
    }
    GacomSnackbar.show(context, '${b.name} added to your boosts', isSuccess: true);
    await _load();
  }

  Future<void> _use(BoostItem b) async {
    if (_busy != null) return;
    setState(() => _busy = 'use_${b.id}');
    final BoostResult r = await BoostService.activate(b.id);
    if (!mounted) return;
    setState(() => _busy = null);
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Could not switch it on', isError: true);
      return;
    }
    GacomSnackbar.show(context, '${b.name} is on', isSuccess: true);
    await _load();
  }

  String _clock(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Tac.gold));
    final BoostState? s = _s;
    if (s == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Icons.bolt_rounded, size: 44, color: Tac.textDim),
            const SizedBox(height: 12),
            Text('Boosts could not be loaded right now.', textAlign: TextAlign.center, style: Tac.body(size: 15, color: Tac.textDim)),
            const SizedBox(height: 16),
            SizedBox(width: 160, child: TacButton(label: 'TRY AGAIN', filled: false, onPressed: _load)),
          ]),
        ),
      );
    }
    final ActiveBoost? a = s.active;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        if (a != null) _activeCard(a),
        if (a == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(color: Tac.panel, shape: ChamferedBorder(cut: 8, side: const BorderSide(color: Tac.keyline))),
            child: Text('No boost is running. Buy one, then switch it on when you are about to play.', style: Tac.body(size: 13.5, color: Tac.textDim, height: 1.35)),
          ),
        const SizedBox(height: 10),
        Text('Switched on today: ${s.usedToday} of ${s.dailyCap}. One boost at a time, up to ${s.maxHeld} of each in your bag.', style: Tac.body(size: 12.5, color: Tac.textDim, height: 1.35)),
        const SizedBox(height: 4),
        Text('Boosts only speed up the Season Pass and skin evolution. They never change a score, a duel, a stake or a prize.', style: Tac.body(size: 12.5, color: Tac.textDim, height: 1.35)),
        if (s.balance != null) ...<Widget>[
          const SizedBox(height: 6),
          Text('Wallet: ${Tac.naira(s.balance!)}', style: Tac.display(size: 12, color: Tac.gold)),
        ],
        const SizedBox(height: 12),
        for (final BoostItem b in s.catalog) _boostCard(b, s),
      ],
    );
  }

  Widget _activeCard(ActiveBoost a) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(color: Tac.panel, shape: ChamferedBorder(cut: 8, side: const BorderSide(color: Tac.ok, width: 1.4))),
      child: Row(children: <Widget>[
        const Icon(Icons.bolt_rounded, color: Tac.ok, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('${a.name} is on', style: Tac.display(size: 13, color: Tac.ok)),
            const SizedBox(height: 2),
            Text('+${a.pct}% ${BoostService.kindLabel(a.kind)}', style: Tac.body(size: 13, color: Tac.text)),
          ]),
        ),
        Text(_clock(a.left), style: Tac.display(size: 18, color: Tac.text)),
      ]),
    );
  }

  Widget _boostCard(BoostItem b, BoostState s) {
    final bool running = s.active != null;
    final bool canUse = b.qty > 0 && !running && s.usedToday < s.dailyCap;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(color: Tac.panel, shape: ChamferedBorder(cut: 8, side: const BorderSide(color: Tac.keyline))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(b.name.toUpperCase(), style: Tac.display(size: 13, weight: FontWeight.w800))),
          Text('+${b.pct}%  ${b.minutes} min', style: Tac.display(size: 12, color: Tac.cyan)),
        ]),
        const SizedBox(height: 4),
        Text(b.description, style: Tac.body(size: 13, color: Tac.textDim, height: 1.3)),
        const SizedBox(height: 10),
        Row(children: <Widget>[
          Text('In your bag: ${b.qty}', style: Tac.body(size: 12.5, color: b.qty > 0 ? Tac.text : Tac.textDim)),
          const Spacer(),
          SizedBox(
            width: 112,
            child: TacButton(label: 'USE', color: Tac.ok, filled: false, loading: _busy == 'use_${b.id}', onPressed: canUse ? () => _use(b) : null),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 124,
            child: TacButton(label: 'BUY  ${Tac.naira(b.price)}', loading: _busy == 'buy_${b.id}', onPressed: b.qty >= s.maxHeld ? null : () => _buy(b)),
          ),
        ]),
      ]),
    );
  }
}
