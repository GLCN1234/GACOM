import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../../shared/widgets/cosmetic_visuals.dart';
import '../../../shared/widgets/rarity.dart';

List<Map<String, dynamic>> _maps(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

Widget _miniThumb(Map<String, dynamic> it) {
  final Rarity r = Rarity.parse(it['rarity']?.toString());
  return Container(
    width: 62,
    height: 62,
    decoration: BoxDecoration(color: r.color.withValues(alpha: 0.10), border: Border.all(color: r.color.withValues(alpha: 0.6))),
    child: ClipRect(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: CosmeticItemVisual(item: it, scale: 0.6)))),
  );
}

/// One-time starter pack offer at the top of the shop.
class StarterPackCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final bool busy;
  final VoidCallback onBuy;
  const StarterPackCard({super.key, required this.offer, required this.busy, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = _maps(offer['items']);
    final int full = Tac.intOf(offer['full_price']);
    final int price = Tac.intOf(offer['price']);
    final int disc = Tac.intOf(offer['discount']);
    return TacticalPanel(
      keyline: Tac.gold,
      cut: 16,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text('STARTER PACK', style: Tac.display(size: 17, weight: FontWeight.w800, letter: 1.6, color: Tac.gold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: Tac.gold,
            child: Text('-$disc%', style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.bg)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(offer['description']?.toString() ?? '', style: Tac.body(size: 13, color: Tac.textDim, height: 1.25)),
        const SizedBox(height: 10),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, int i) => _miniThumb(items[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: <Widget>[
          Text(Tac.naira(full), style: Tac.body(size: 14, color: Tac.textDim).copyWith(decoration: TextDecoration.lineThrough)),
          const SizedBox(width: 8),
          Text(Tac.naira(price), style: Tac.display(size: 20, weight: FontWeight.w800, color: Tac.gold)),
          const Spacer(),
          CountdownText(until: Tac.time(offer['ends_at']), prefix: 'Ends in ', doneText: 'Ended'),
        ]),
        const SizedBox(height: 10),
        TacButton(label: 'GET STARTER PACK', loading: busy, onPressed: busy ? null : onBuy),
      ]),
    );
  }
}

/// Shown until the first purchase is made, then disappears.
class FirstPurchaseBanner extends StatelessWidget {
  final Map<String, dynamic> state;
  const FirstPurchaseBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = _maps(state['items']);
    return TacticalPanel(
      keyline: Tac.cyan.withValues(alpha: 0.7),
      cut: 14,
      padding: const EdgeInsets.all(12),
      child: Row(children: <Widget>[
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('FIRST PURCHASE BONUS', style: Tac.display(size: 13, weight: FontWeight.w800, letter: 1.4, color: Tac.cyan)),
            const SizedBox(height: 3),
            Text('Buy anything and get an exclusive title, emote and spray free.', style: Tac.body(size: 13, color: Tac.textDim, height: 1.25)),
          ]),
        ),
        const SizedBox(width: 10),
        for (final Map<String, dynamic> it in items.take(3)) Padding(padding: const EdgeInsets.only(left: 4), child: SizedBox(width: 40, height: 40, child: FittedBox(child: _miniThumb(it)))),
      ]),
    );
  }
}

/// Asks who to gift, with an optional note. Returns the result of the gift,
/// or null when cancelled. The caller refreshes balances afterwards.
Future<CosmeticResult?> showGiftDialog(BuildContext context, {required Map<String, dynamic> item, required int price, required double balance}) {
  return showDialog<CosmeticResult>(context: context, builder: (BuildContext ctx) => _GiftDialog(item: item, price: price, balance: balance));
}

class _GiftDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final int price;
  final double balance;
  const _GiftDialog({required this.item, required this.price, required this.balance});

  @override
  State<_GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<_GiftDialog> {
  final TextEditingController _q = TextEditingController();
  final TextEditingController _note = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _found = <Map<String, dynamic>>[];
  Map<String, dynamic>? _to;
  bool _searching = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (_to != null) setState(() => _to = null);
    if (v.trim().length < 2) {
      setState(() => _found = <Map<String, dynamic>>[]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      final List<Map<String, dynamic>> r = await CosmeticsService.searchGiftTargets(v.trim());
      if (!mounted) return;
      setState(() {
        _found = r;
        _searching = false;
      });
    });
  }

  Future<void> _send() async {
    final Map<String, dynamic>? to = _to;
    if (to == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final CosmeticResult res = await CosmeticsService.gift(itemId: widget.item['id'].toString(), toUser: to['id'].toString(), message: _note.text);
    if (!mounted) return;
    if (res.success) {
      Navigator.of(context).pop(res);
    } else {
      setState(() {
        _sending = false;
        _error = res.error ?? 'Could not send the gift';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Rarity r = Rarity.parse(widget.item['rarity']?.toString());
    final bool enough = widget.balance >= widget.price;
    return AlertDialog(
      backgroundColor: Tac.panel,
      shape: const ChamferedBorder(cut: 16, side: BorderSide(color: Tac.keyline)),
      title: Text('Gift ${widget.item['name']}', style: Tac.display(size: 17, weight: FontWeight.w800, letter: 0.2)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Align(alignment: Alignment.centerLeft, child: RarityChip(r)),
            const SizedBox(height: 10),
            TextField(
              controller: _q,
              onChanged: _onChanged,
              autocorrect: false,
              style: Tac.body(size: 15),
              decoration: InputDecoration(
                hintText: 'Search a username',
                hintStyle: Tac.body(size: 14, color: Tac.textDim),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Tac.gold))) : null,
              ),
            ),
            const SizedBox(height: 6),
            if (_to != null)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_giftcard_rounded, color: Tac.gold),
                title: Text(_name(_to!), style: Tac.display(size: 14, weight: FontWeight.w800)),
                subtitle: Text('@${_to!['username']}', style: Tac.body(size: 12, color: Tac.textDim)),
              )
            else
              for (final Map<String, dynamic> p in _found)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Tac.panel2,
                    backgroundImage: (p['avatar_url'] is String && (p['avatar_url'] as String).isNotEmpty) ? NetworkImage(p['avatar_url'] as String) : null,
                    child: (p['avatar_url'] is String && (p['avatar_url'] as String).isNotEmpty) ? null : Text(_name(p).isEmpty ? '?' : _name(p)[0].toUpperCase(), style: Tac.display(size: 13)),
                  ),
                  title: Text(_name(p), style: Tac.body(size: 14)),
                  subtitle: Text('@${p['username']}', style: Tac.body(size: 12, color: Tac.textDim)),
                  onTap: () => setState(() {
                    _to = p;
                    _q.text = p['username']?.toString() ?? '';
                  }),
                ),
            if (_to == null && _found.isEmpty && _q.text.trim().length >= 2 && !_searching)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('No players found.', style: Tac.body(size: 13, color: Tac.textDim))),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 140,
              style: Tac.body(size: 14),
              decoration: InputDecoration(hintText: 'Add a note (optional)', hintStyle: Tac.body(size: 14, color: Tac.textDim), counterStyle: Tac.body(size: 11, color: Tac.textDim)),
            ),
            const SizedBox(height: 6),
            Row(children: <Widget>[
              Expanded(child: Text('You pay', style: Tac.body(size: 14, color: Tac.textDim))),
              Text(Tac.naira(widget.price), style: Tac.display(size: 15, weight: FontWeight.w800, color: Tac.gold)),
            ]),
            Row(children: <Widget>[
              Expanded(child: Text('Wallet balance', style: Tac.body(size: 14, color: Tac.textDim))),
              Text(Tac.naira(widget.balance), style: Tac.display(size: 14, weight: FontWeight.w800, color: enough ? Tac.text : Tac.danger)),
            ]),
            if (!enough) Padding(padding: const EdgeInsets.only(top: 6), child: Text('You need ${Tac.naira(widget.price - widget.balance)} more.', style: Tac.body(size: 13, color: Tac.danger))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: Tac.body(size: 13, color: Tac.danger))),
          ]),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(), child: Text('CANCEL', style: Tac.display(size: 12, color: Tac.textDim, weight: FontWeight.w800))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tac.gold, foregroundColor: Tac.bg),
          onPressed: (_to == null || !enough || _sending) ? null : _send,
          child: Text(_sending ? 'Sending...' : 'Send gift', style: Tac.display(size: 12, color: Tac.bg, weight: FontWeight.w800)),
        ),
      ],
    );
  }

  String _name(Map<String, dynamic> p) {
    final String d = (p['display_name'] ?? '').toString().trim();
    return d.isNotEmpty ? d : (p['username'] ?? '').toString();
  }
}

/// Evolving skin progress for the locker.
class EvolutionPanel extends StatelessWidget {
  final List<Map<String, dynamic>> chains;
  const EvolutionPanel({super.key, required this.chains});

  @override
  Widget build(BuildContext context) {
    if (chains.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Container(width: 3, height: 14, color: Tac.gold),
          const SizedBox(width: 8),
          Text('EVOLVING SKINS', style: Tac.display(size: 12, weight: FontWeight.w800, letter: 1.6)),
        ]),
        const SizedBox(height: 4),
        Text('Wear one and earn Darkom points to unlock its next stage.', style: Tac.body(size: 12, color: Tac.textDim)),
        const SizedBox(height: 10),
        for (final Map<String, dynamic> c in chains) _chain(c),
      ]),
    );
  }

  Widget _chain(Map<String, dynamic> c) {
    final List<Map<String, dynamic>> stages = _maps(c['stages']);
    final int xp = Tac.intOf(c['xp']);
    int current = 0;
    for (int i = 0; i < stages.length; i++) {
      if (xp >= Tac.intOf(stages[i]['xp_needed'])) current = i;
    }
    final bool maxed = current >= stages.length - 1;
    final int from = Tac.intOf(stages[current]['xp_needed']);
    final int to = maxed ? from : Tac.intOf(stages[current + 1]['xp_needed']);
    final double frac = maxed || to <= from ? 1.0 : ((xp - from) / (to - from)).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TacticalPanel(
        keyline: Tac.keyline,
        cut: 12,
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Row(children: <Widget>[
            for (int i = 0; i < stages.length; i++) ...<Widget>[
              Opacity(
                opacity: i <= current ? 1.0 : 0.35,
                child: _miniThumb(Map<String, dynamic>.from(stages[i]['item'] as Map)),
              ),
              if (i < stages.length - 1) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right_rounded, color: Tac.textDim, size: 18)),
            ],
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: frac, minHeight: 6, color: Tac.gold, backgroundColor: Colors.white12),
          ),
          const SizedBox(height: 4),
          Text(
            maxed ? 'Final stage reached' : '$xp / $to points to ${(stages[current + 1]['item'] as Map)['name']}',
            style: Tac.body(size: 12, color: Tac.textDim),
          ),
        ]),
      ),
    );
  }
}
