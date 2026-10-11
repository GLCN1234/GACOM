import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/rarity.dart';
import 'season_pass_service.dart';

/// The season pass: a free and a premium reward at every level.
/// Route: '/pass'.
class SeasonPassScreen extends StatefulWidget {
  const SeasonPassScreen({super.key});

  @override
  State<SeasonPassScreen> createState() => _SeasonPassScreenState();
}

class _SeasonPassScreenState extends State<SeasonPassScreen> {
  PassState? _s;
  bool _loading = true;
  bool _busy = false;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(scrollToLevel: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool scrollToLevel = false}) async {
    final PassState? s = await PassService.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
    if (scrollToLevel && s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final double target = ((s.level - 1) * 112.0).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
        _scroll.jumpTo(target);
      });
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Tac.danger : const Color(0xFF1B2A44),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _claim(PassReward r) async {
    if (_busy) return;
    setState(() => _busy = true);
    final PassResult res = await PassService.claim(r.level, r.track);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(res.ok ? 'Claimed: ${res.message}' : res.message, error: !res.ok);
    await _load();
  }

  Future<void> _claimAll() async {
    final PassState? s = _s;
    if (s == null || _busy) return;
    setState(() => _busy = true);
    int ok = 0;
    String? err;
    for (final PassReward r in s.rewards) {
      if (r.claimed || r.level > s.level || (r.track == 'premium' && !s.premium)) continue;
      final PassResult res = await PassService.claim(r.level, r.track);
      if (res.ok) {
        ok++;
      } else {
        err = res.message;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(err ?? 'Claimed $ok reward${ok == 1 ? '' : 's'}', error: err != null);
    await _load();
  }

  Future<void> _buy() async {
    final PassState? s = _s;
    if (s == null || _busy) return;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Tac.panel,
        title: Text('Unlock the premium pass', style: Tac.display(size: 16)),
        content: Text(
          '${Tac.naira(s.price)} will be taken from your wallet (balance ${Tac.naira(s.balance)}). You keep the premium track for this whole season, and rewards from levels you have already reached can be claimed straight away.',
          style: Tac.body(size: 14, color: Tac.textDim),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tac.gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Pay ${Tac.naira(s.price)}'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final PassResult res = await PassService.buyPremium();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(res.message, error: !res.ok);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tac.bg,
      appBar: AppBar(
        backgroundColor: Tac.bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        title: Text('SEASON PASS', style: Tac.display(size: 16, letter: 1.4)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Tac.gold))
          : (_s == null ? _empty() : _body(_s!)),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Icons.event_busy_rounded, color: Tac.textDim, size: 40),
            const SizedBox(height: 12),
            Text('No season is running right now, or you are offline.', textAlign: TextAlign.center, style: Tac.body(size: 15, color: Tac.textDim)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Try again')),
          ]),
        ),
      );

  Widget _body(PassState s) {
    final int days = s.endsAt == null ? 0 : s.endsAt!.difference(DateTime.now()).inDays;
    final double frac = s.level >= s.maxLevel ? 1.0 : (s.xpIntoLevel / s.xpPerLevel).clamp(0.0, 1.0).toDouble();
    return ListView(padding: const EdgeInsets.only(bottom: 12), children: <Widget>[
      Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Tac.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Tac.keyline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(s.name.toUpperCase(), style: Tac.display(size: 20, color: Tac.gold, letter: 1.5)),
                if (s.tagline.isNotEmpty) Text(s.tagline, style: Tac.body(size: 13, color: Tac.textDim)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
              Text('LEVEL ${s.level}/${s.maxLevel}', style: Tac.display(size: 15)),
              Text(days <= 0 ? 'Ends today' : '$days days left', style: Tac.body(size: 12, color: Tac.textDim)),
            ]),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: frac, minHeight: 8, color: Tac.cyan, backgroundColor: Tac.panel2),
          ),
          const SizedBox(height: 6),
          Text(
            s.level >= s.maxLevel
                ? 'Maximum level reached'
                : '${s.xpIntoLevel}/${s.xpPerLevel} XP to level ${s.level + 1}   |   Earned today ${s.xpToday}/${s.dailyCap}',
            style: Tac.body(size: 12, color: Tac.textDim),
          ),
          const SizedBox(height: 4),
          Text('Earn XP by finishing Darkom City missions and story runs.', style: Tac.body(size: 12, color: Tac.textDim)),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            if (!s.premium)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Tac.gold, foregroundColor: Colors.black),
                  onPressed: _busy ? null : _buy,
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text('UNLOCK PREMIUM  ${Tac.naira(s.price)}'),
                ),
              )
            else
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Tac.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Tac.gold)),
                  child: Text('PREMIUM ACTIVE', style: Tac.display(size: 13, color: Tac.gold, letter: 1.2)),
                ),
              ),
            if (s.claimable > 0) ...<Widget>[
              const SizedBox(width: 10),
              OutlinedButton(onPressed: _busy ? null : _claimAll, child: Text('CLAIM ALL (${s.claimable})')),
            ],
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
        child: Row(children: <Widget>[
          Text('FREE', style: Tac.display(size: 12, color: Tac.textDim)),
          const Spacer(),
          Text('PREMIUM', style: Tac.display(size: 12, color: Tac.gold)),
        ]),
      ),
      SizedBox(height: 240, child: _track(s)),
    ]);
  }

  Widget _track(PassState s) {
    return ListView.builder(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      itemCount: s.maxLevel,
      itemBuilder: (BuildContext context, int i) {
        final int lvl = i + 1;
        final bool reached = lvl <= s.level;
        return Container(
          width: 104,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: reached ? Tac.panel : Tac.panel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: reached ? Tac.cyan.withValues(alpha: 0.5) : Tac.keyline),
          ),
          child: Column(children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('$lvl', style: Tac.display(size: 18, color: reached ? Tac.cyan : Tac.textDim)),
            ),
            Expanded(child: _tile(s, s.rewardAt(lvl, 'free'), reached, true)),
            const Divider(height: 1, color: Tac.keyline),
            Expanded(child: _tile(s, s.rewardAt(lvl, 'premium'), reached, s.premium)),
          ]),
        );
      },
    );
  }

  Widget _tile(PassState s, PassReward? r, bool reached, bool unlocked) {
    if (r == null) return const SizedBox.shrink();
    final bool canClaim = reached && unlocked && !r.claimed;
    final Color c = r.kind == 'cosmetic' ? Rarity.parse(r.rarity).color : Tac.textDim;
    final IconData icon = r.kind == 'points' ? Icons.stars_rounded : _iconFor(r.category);
    return InkWell(
      onTap: canClaim && !_busy ? () => _claim(r) : null,
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: canClaim ? c.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: canClaim ? c : Colors.transparent, width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Stack(alignment: Alignment.center, children: <Widget>[
            Icon(icon, color: r.claimed ? Tac.textDim.withValues(alpha: 0.5) : (unlocked ? c : Tac.textDim.withValues(alpha: 0.5)), size: 26),
            if (r.claimed) const Icon(Icons.check_circle_rounded, color: Tac.ok, size: 16),
            if (!unlocked && !r.claimed) Positioned(right: 0, bottom: 0, child: Icon(Icons.lock_rounded, color: Tac.textDim.withValues(alpha: 0.8), size: 13)),
          ]),
          const SizedBox(height: 4),
          Text(r.label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Tac.body(size: 11, color: r.claimed ? Tac.textDim : Tac.text, height: 1.1)),
          if (canClaim) Text('CLAIM', style: Tac.display(size: 10, color: c, letter: 1)),
        ]),
      ),
    );
  }

  IconData _iconFor(String? cat) {
    switch (cat) {
      case 'title':
        return Icons.military_tech_rounded;
      case 'name_color':
        return Icons.palette_rounded;
      case 'weapon_skin':
        return Icons.gavel_rounded;
      case 'hero_outfit':
        return Icons.checkroom_rounded;
      case 'badge':
        return Icons.shield_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }
}
