import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../edu/edu_subscription_service.dart';
import '../../../shared/widgets/cosmetic_visuals.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/rarity.dart';

const Map<String, String> _lockerTabs = {
  'hero_outfit': 'Outfits',
  'avatar_frame': 'Frames',
  'profile_banner': 'Banners',
  'trail': 'Trails',
  'title': 'Titles',
  'badge': 'Badges',
  'name_color': 'Name colours',
};

/// Everything the player owns: collection progress, sets, and a grid to
/// equip or take off items, shown on the same character stage as the shop.
class LockerScreen extends StatefulWidget {
  const LockerScreen({super.key});
  @override
  State<LockerScreen> createState() => _LockerScreenState();
}

class _LockerScreenState extends State<LockerScreen> {
  bool _loading = true;
  bool _signedIn = true;
  bool _isPro = false;
  List<Map<String, dynamic>> _items = [];
  Set<String> _owned = {};
  Map<String, dynamic>? _equipped;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _sets = [];
  final Map<String, Map<String, dynamic>> _sel = {};
  String _tab = 'hero_outfit';
  String? _busyId;
  String _displayName = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      if (mounted) setState(() { _signedIn = false; _loading = false; });
      return;
    }
    if (mounted) setState(() { _loading = true; _signedIn = true; });
    bool pro = false;
    try { pro = await EduSubscriptionService.isPro(); } catch (_) {}
    final results = await Future.wait<dynamic>([
      CosmeticsService.catalog(),
      CosmeticsService.ownedIds(),
      CosmeticsService.equipped(uid),
      _loadProfile(uid),
      CosmeticsService.collectionStats(),
      CosmeticsService.mySets(),
    ]);
    if (!mounted) return;
    final prof = results[3] as Map<String, dynamic>?;
    setState(() {
      _isPro = pro;
      _items = results[0] as List<Map<String, dynamic>>;
      _owned = results[1] as Set<String>;
      _equipped = results[2] as Map<String, dynamic>?;
      _stats = results[4] as Map<String, dynamic>?;
      _sets = results[5] as List<Map<String, dynamic>>;
      _displayName = (prof?['display_name'] as String?) ?? '';
      _avatarUrl = prof?['avatar_url'] as String?;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    try {
      return await SupabaseService.client.from('profiles').select('display_name, avatar_url').eq('id', uid).maybeSingle();
    } catch (_) { return null; }
  }

  /// Re-reads ownership, progress and the loadout after a claim.
  Future<void> _refresh() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    final r = await Future.wait<dynamic>([
      CosmeticsService.ownedIds(),
      CosmeticsService.collectionStats(),
      CosmeticsService.mySets(),
      CosmeticsService.equipped(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _owned = r[0] as Set<String>;
      _stats = r[1] as Map<String, dynamic>?;
      _sets = r[2] as List<Map<String, dynamic>>;
      _equipped = (r[3] as Map<String, dynamic>?) ?? _equipped;
      _busyId = null;
    });
  }

  // ---- helpers ----

  List<Map<String, dynamic>> _list(dynamic v) {
    if (v is! List) return <Map<String, dynamic>>[];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _source(Map<String, dynamic> it) => (it['source'] ?? 'shop').toString();
  bool _isOwned(Map<String, dynamic> it) => CosmeticsService.isOwned(it, _owned, _isPro);
  bool _isEquipped(Map<String, dynamic> it) => _equipped?['equipped_${it['category']}'] == it['id'];

  Map<String, dynamic> get _previewMap {
    final m = <String, dynamic>{};
    for (final c in CosmeticsService.categories) {
      final v = _sel[c] ?? _equipped?[c];
      if (v != null) m[c] = v;
    }
    return m;
  }

  List<Map<String, dynamic>> _tabItems() {
    final list = _items.where((e) {
      if (e['category'] != _tab) return false;
      if ((e['name']?.toString() ?? '') == 'None') return false;
      final until = Tac.time(e['available_until']);
      if (until != null && until.isBefore(DateTime.now()) && !_isOwned(e)) return false;
      return true;
    }).toList();
    int rank(Map<String, dynamic> e) => _isEquipped(e) ? 0 : (_isOwned(e) ? 1 : 2);
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return Rarity.parse(b['rarity']?.toString()).index.compareTo(Rarity.parse(a['rarity']?.toString()).index);
    });
    return list;
  }

  String _lockedText(Map<String, dynamic> it) {
    final src = _source(it);
    if (src == 'earned') return (it['earn_hint'] as String?) ?? 'Earn this in GACOM';
    if (src == 'licence') return 'Issued by GACOM';
    final price = (it['price'] as num?)?.toInt() ?? 0;
    if (src == 'premium' || it['requires_premium'] == true) return price > 0 ? 'Premium or ${Tac.naira(price)}' : 'Premium members';
    return price > 0 ? Tac.naira(price) : 'Free';
  }

  // ---- actions ----

  Future<void> _equip(Map<String, dynamic>? it, {String? category}) async {
    final cat = category ?? it?['category'] as String?;
    if (cat == null || _busyId != null) return;
    setState(() => _busyId = (it?['id'] as String?) ?? 'off_$cat');
    final res = await CosmeticsService.equip(itemId: it?['id'] as String?, category: it == null ? cat : null);
    Map<String, dynamic>? fresh;
    final uid = SupabaseService.currentUserId;
    if (res.success && uid != null) fresh = await CosmeticsService.equipped(uid);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (res.success) {
        if (fresh != null) _equipped = fresh;
        _sel.remove(cat);
      }
    });
    if (res.success) {
      GacomSnackbar.show(context, it == null ? 'Taken off' : '${it['name']} equipped', isSuccess: true);
    } else {
      GacomSnackbar.show(context, res.error ?? 'Could not update your look', isError: true);
    }
  }

  void _onTapItem(Map<String, dynamic> it) {
    if (_busyId != null) return;
    if (_isOwned(it)) {
      if (_isEquipped(it)) {
        _equip(null, category: it['category'] as String?);
      } else {
        _equip(it);
      }
      return;
    }
    // Not owned: show it on the stage and say how to get it.
    setState(() => _sel[it['category'] as String] = it);
    GacomSnackbar.show(context, _lockedText(it));
  }

  Future<void> _saveLook() async {
    if (_busyId != null) return;
    setState(() => _busyId = 'save');
    await CosmeticsService.refreshLoadout();
    final uid = SupabaseService.currentUserId;
    Map<String, dynamic>? fresh;
    if (uid != null) fresh = await CosmeticsService.equipped(uid);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (fresh != null) _equipped = fresh;
      _sel.clear();
    });
    GacomSnackbar.show(context, 'Look saved', isSuccess: true);
  }

  Future<void> _claim(int percent) async {
    if (_busyId != null) return;
    setState(() => _busyId = 'ms_$percent');
    final res = await CosmeticsService.claimMilestone(percent);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _busyId = null);
      GacomSnackbar.show(context, res.error ?? 'Could not claim this reward', isError: true);
      return;
    }
    GacomSnackbar.show(context, 'Reward claimed. Check your locker.', isSuccess: true);
    await _refresh();
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tac.bg,
      appBar: AppBar(
        backgroundColor: Tac.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('LOCKER', style: Tac.display(size: 18, weight: FontWeight.w800, letter: 2)),
        actions: [
          IconButton(
            tooltip: 'Shop',
            icon: const Icon(Icons.storefront_rounded, color: Tac.gold),
            onPressed: () => context.push('/customization').then((_) { if (mounted) _load(); }),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Tac.gold));
    if (!_signedIn) {
      return _message(Icons.lock_outline_rounded, 'Sign in to open your locker');
    }
    if (_items.isEmpty) {
      return _message(Icons.inventory_2_outlined, 'Your locker could not be loaded right now.', retry: _load);
    }
    final tabItems = _tabItems();
    return LayoutBuilder(builder: (context, c) {
      final int cols = (c.maxWidth / 150).floor().clamp(2, 6).toInt();
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(child: LoadoutStage(items: _previewMap, name: _displayName, avatarUrl: _avatarUrl)),
        SliverToBoxAdapter(child: _actionRow()),
        SliverToBoxAdapter(child: _collectionPanel()),
        if (_sets.isNotEmpty) SliverToBoxAdapter(child: _setsSection()),
        SliverToBoxAdapter(child: _tabBar()),
        if (tabItems.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32), child: Text('Nothing in this category yet.', textAlign: TextAlign.center, style: Tac.body(size: 15, color: Tac.textDim))))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 172),
              delegate: SliverChildBuilderDelegate((ctx, i) => _tile(tabItems[i]), childCount: tabItems.length),
            ),
          ),
      ]);
    });
  }

  Widget _message(IconData icon, String text, {Future<void> Function()? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: Tac.textDim),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: Tac.body(size: 15, color: Tac.textDim, height: 1.4)),
          if (retry != null) ...[
            const SizedBox(height: 16),
            SizedBox(width: 160, child: TacButton(label: 'TRY AGAIN', filled: false, onPressed: retry)),
          ],
        ]),
      ),
    );
  }

  Widget _actionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        Expanded(child: TacButton(label: 'SAVE LOOK', icon: Icons.check_circle_rounded, loading: _busyId == 'save', onPressed: _busyId != null ? null : _saveLook)),
        const SizedBox(width: 8),
        Expanded(
          child: TacButton(
            label: 'CLEAR PREVIEW',
            filled: false,
            color: Tac.cyan,
            onPressed: _sel.isEmpty ? null : () => setState(() => _sel.clear()),
          ),
        ),
      ]),
    );
  }

  // ---- collection ----

  Widget _label(String text) {
    return Row(children: [
      Container(width: 3, height: 14, color: Tac.gold),
      const SizedBox(width: 8),
      Text(text, style: Tac.display(size: 12, weight: FontWeight.w800, letter: 1.6)),
    ]);
  }

  Widget _collectionPanel() {
    final st = _stats;
    if (st == null) return const SizedBox.shrink();
    final owned = Tac.intOf(st['owned']);
    final total = Tac.intOf(st['total']);
    final pct = Tac.intOf(st['percent']);
    final ms = _list(st['milestones']);
    final frac = (pct / 100.0).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TacticalPanel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _label('COLLECTION')),
            Text('$owned of $total', style: Tac.body(size: 14, color: Tac.textDim)),
            const SizedBox(width: 10),
            Text('$pct%', style: Tac.display(size: 18, weight: FontWeight.w800, color: Tac.gold, letter: 0.2)),
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final double w = box.maxWidth;
            return SizedBox(
              height: 10,
              child: Stack(children: [
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: Tac.panel2, border: Border.all(color: Tac.keyline)))),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: w * frac,
                  child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Tac.gold, Tac.cyan]))),
                ),
                for (final m in ms)
                  Positioned(
                    left: (w * (Tac.intOf(m['percent']) / 100.0).clamp(0.0, 1.0).toDouble() - 1).clamp(0.0, w).toDouble(),
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: const ColoredBox(color: Tac.bg),
                  ),
              ]),
            );
          }),
          if (ms.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final double tw = (box.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [for (final m in ms) SizedBox(width: tw, child: _milestoneTile(m))]);
            }),
          ],
        ]),
      ),
    );
  }

  Widget _milestoneTile(Map<String, dynamic> m) {
    final pct = Tac.intOf(m['percent']);
    final reached = m['reached'] == true;
    final claimed = m['claimed'] == true;
    final item = m['item'];
    final name = item is Map ? (item['name']?.toString() ?? '') : (m['label']?.toString() ?? '');
    final rarity = Rarity.parse(item is Map ? item['rarity']?.toString() : null);
    final Color line = claimed ? Tac.ok : (reached ? Tac.gold : Tac.keyline);
    Widget status;
    if (claimed) {
      status = Text('CLAIMED', style: Tac.display(size: 10, weight: FontWeight.w800, color: Tac.ok, letter: 0.8));
    } else if (reached) {
      status = TacButton(label: 'CLAIM', height: 26, loading: _busyId == 'ms_$pct', onPressed: _busyId != null ? null : () => _claim(pct));
    } else {
      status = Text('LOCKED', style: Tac.display(size: 10, weight: FontWeight.w800, color: Tac.textDim, letter: 0.8));
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Tac.panel2,
        shape: ChamferedBorder(cut: 8, side: BorderSide(color: line.withValues(alpha: reached || claimed ? 0.9 : 0.8))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$pct%', style: Tac.display(size: 16, weight: FontWeight.w800, color: reached || claimed ? Tac.gold : Tac.textDim, letter: 0.2)),
            const SizedBox(width: 6),
            Expanded(child: Align(alignment: Alignment.centerRight, child: RarityChip(rarity, compact: true))),
          ]),
          const SizedBox(height: 2),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.body(size: 13, color: Tac.text)),
          const SizedBox(height: 6),
          SizedBox(height: 26, child: Align(alignment: Alignment.centerLeft, child: status)),
        ]),
      ),
    );
  }

  // ---- sets ----

  String _word(int n) {
    const words = {2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven', 8: 'eight'};
    return words[n] ?? '$n';
  }

  Widget _setsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _label('SETS')),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _setCard(_sets[i]),
          ),
        ),
      ]),
    );
  }

  Widget _setCard(Map<String, dynamic> s) {
    final pieces = _list(s['items']);
    final have = pieces.where((p) => p['owned'] == true).length;
    final n = pieces.length;
    final bonus = s['bonus'] is Map ? Map<String, dynamic>.from(s['bonus'] as Map) : null;
    final bonusRarity = Rarity.parse(bonus?['rarity']?.toString());
    final complete = n > 0 && have >= n;
    final bonusName = bonus?['name']?.toString();
    return SizedBox(
      width: 250,
      child: TacticalPanel(
        padding: const EdgeInsets.all(12),
        keyline: complete ? Tac.ok : (bonus != null ? bonusRarity.color.withValues(alpha: 0.7) : Tac.keyline),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s['name']?.toString() ?? 'Set', maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 14, weight: FontWeight.w800, letter: 0.3))),
            const SizedBox(width: 6),
            Text('$have of $n', style: Tac.display(size: 12, weight: FontWeight.w800, color: complete ? Tac.ok : Tac.gold, letter: 0.4)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (final p in pieces) ...[
              _pieceDot(p),
              const SizedBox(width: 6),
            ],
          ]),
          const Spacer(),
          if (bonusName != null)
            Text(
              complete ? 'Bonus unlocked: $bonusName' : 'Own all ${_word(n)}: $bonusName',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Tac.body(size: 13, color: complete ? Tac.ok : Tac.textDim, height: 1.15),
            )
          else
            Text((s['description'] as String?) ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.body(size: 13, color: Tac.textDim, height: 1.15)),
        ]),
      ),
    );
  }

  Widget _pieceDot(Map<String, dynamic> p) {
    final r = Rarity.parse(p['rarity']?.toString());
    final own = p['owned'] == true;
    return Tooltip(
      message: p['name']?.toString() ?? '',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: own ? r.color.withValues(alpha: 0.85) : Colors.transparent,
          shape: ChamferedBorder(cut: 5, side: BorderSide(color: r.color.withValues(alpha: own ? 1 : 0.5))),
        ),
        child: SizedBox(
          width: 26,
          height: 26,
          child: own ? const Icon(Icons.check_rounded, size: 14, color: Tac.bg) : const Icon(Icons.lock_rounded, size: 12, color: Tac.textDim),
        ),
      ),
    );
  }

  // ---- items ----

  Widget _tabBar() {
    final keys = _lockerTabs.keys.toList();
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: keys.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final k = keys[i];
            final sel = _tab == k;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = k),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: sel ? Tac.gold : Tac.panel,
                  shape: ChamferedBorder(cut: 7, side: BorderSide(color: sel ? Tac.gold : Tac.keyline)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: Text(_lockerTabs[k]!.toUpperCase(), style: Tac.display(size: 11, weight: FontWeight.w800, color: sel ? Tac.bg : Tac.textDim, letter: 0.9))),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> it) {
    final rarity = Rarity.parse(it['rarity']?.toString());
    final owned = _isOwned(it);
    final equipped = _isEquipped(it);
    final previewing = _sel[it['category']]?['id'] == it['id'];
    final busy = _busyId == it['id'];
    final Widget thumb = it['category'] == 'profile_banner'
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: CosmeticItemVisual(item: it))
        : FittedBox(fit: BoxFit.scaleDown, child: CosmeticItemVisual(item: it));
    return RarityCard(
      rarity: rarity,
      dimmed: !owned,
      selected: equipped || previewing,
      padding: const EdgeInsets.all(8),
      onTap: () => _onTapItem(it),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: rarity.color.withValues(alpha: owned ? 0.07 : 0.03)),
                child: ClipRect(child: Center(child: Opacity(opacity: owned ? 1.0 : 0.4, child: thumb))),
              ),
            ),
            if (!owned) const Positioned(right: 4, top: 4, child: Icon(Icons.lock_rounded, size: 14, color: Tac.textDim)),
            if (equipped) const Positioned(right: 4, top: 4, child: Icon(Icons.check_circle_rounded, size: 16, color: Tac.ok)),
            Positioned(left: 2, top: 2, child: RarityChip(rarity, compact: true)),
          ]),
        ),
        const SizedBox(height: 6),
        Text(it['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 12, weight: FontWeight.w700, color: owned ? Tac.text : Tac.textDim, letter: 0.2)),
        const SizedBox(height: 2),
        SizedBox(
          height: 30,
          child: busy
              ? const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Tac.gold)))
              : Text(
                  equipped ? 'EQUIPPED. TAP TO TAKE OFF' : (owned ? 'TAP TO EQUIP' : _lockedText(it)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: owned
                      ? Tac.display(size: 9, weight: FontWeight.w800, color: equipped ? Tac.ok : Tac.cyan, letter: 0.5)
                      : Tac.body(size: 12, color: Tac.textDim, height: 1.1),
                ),
        ),
      ]),
    );
  }
}
