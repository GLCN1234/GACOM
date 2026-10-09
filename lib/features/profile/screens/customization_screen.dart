import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../edu/edu_subscription_service.dart';
import '../../../shared/widgets/cosmetic_visuals.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/rarity.dart';

/// Chip order of the shop. 'featured' and 'bundles' are sections; the rest
/// are cosmetic categories.
const Map<String, String> _chipLabels = {
  'featured': 'Featured',
  'hero_outfit': 'Outfits',
  'avatar_frame': 'Frames',
  'profile_banner': 'Banners',
  'trail': 'Trails',
  'weapon_skin': 'Weapons',
  'title': 'Titles',
  'badge': 'Badges',
  'name_color': 'Name colours',
  'bundles': 'Bundles',
};

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});
  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  bool _loading = true;
  bool _signedIn = true;
  bool _isPro = false;
  List<Map<String, dynamic>> _items = [];
  Set<String> _owned = {};
  Map<String, dynamic>? _equipped;
  Map<String, dynamic>? _shop; // get_shop_state
  final Map<String, Map<String, dynamic>> _sel = {}; // previewed but not equipped
  String? _busyId;
  double? _balance;
  String _displayName = '';
  String? _avatarUrl;
  String _tab = 'featured';

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
      CosmeticsService.shopState(),
    ]);
    if (!mounted) return;
    final prof = results[3] as Map<String, dynamic>?;
    setState(() {
      _isPro = pro;
      _items = results[0] as List<Map<String, dynamic>>;
      _owned = results[1] as Set<String>;
      _equipped = results[2] as Map<String, dynamic>?;
      _shop = results[4] as Map<String, dynamic>?;
      _balance = (prof?['wallet_balance'] as num?)?.toDouble();
      _displayName = (prof?['display_name'] as String?) ?? '';
      _avatarUrl = prof?['avatar_url'] as String?;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    try {
      final row = await SupabaseService.client.from('profiles').select('display_name, avatar_url').eq('id', uid).maybeSingle();
      if (row == null) return null;
      final out = Map<String, dynamic>.from(row);
      try {
        out['wallet_balance'] = (await SupabaseService.client.rpc('my_wallet') as Map)['wallet_balance'];
      } catch (_) {}
      return out;
    } catch (_) { return null; }
  }

  // ---- shop data helpers ----

  List<Map<String, dynamic>> _listOf(dynamic v) {
    if (v is! List) return <Map<String, dynamic>>[];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic>? get _featured {
    final f = _shop?['featured'];
    return f is Map ? Map<String, dynamic>.from(f) : null;
  }

  List<Map<String, dynamic>> get _deals => _listOf(_shop?['deals']);
  List<Map<String, dynamic>> get _bundles => _listOf(_shop?['bundles']);
  List<Map<String, dynamic>> get _earn => _listOf(_shop?['earn']);

  /// Sale prices of items that are in today's featured or deal slots.
  Map<String, int> get _saleById {
    final m = <String, int>{};
    final all = <Map<String, dynamic>>[..._deals];
    final f = _featured;
    if (f != null) all.add(f);
    for (final it in all) {
      final id = it['id']?.toString();
      final s = it['sale_price'];
      if (id != null && s is num) m[id] = s.toInt();
    }
    return m;
  }

  // ---- item state ----

  int _basePrice(Map<String, dynamic> it) => (it['price'] as num?)?.toInt() ?? 0;

  /// What the player pays today (sale_price, never the list price).
  int _pay(Map<String, dynamic> it) {
    final s = it['sale_price'];
    if (s is num) return s.toInt();
    final id = it['id']?.toString();
    final sale = id == null ? null : _saleById[id];
    return sale ?? _basePrice(it);
  }

  int _discount(Map<String, dynamic> it) {
    final base = _basePrice(it);
    final pay = _pay(it);
    if (base <= 0 || pay >= base) return 0;
    return ((base - pay) * 100 / base).round();
  }

  String _source(Map<String, dynamic> it) => (it['source'] ?? 'shop').toString();
  bool _premium(Map<String, dynamic> it) => it['requires_premium'] == true || _source(it) == 'premium';
  bool _isOwned(Map<String, dynamic> it) => CosmeticsService.isOwned(it, _owned, _isPro);
  bool _isEquipped(Map<String, dynamic> it) => _equipped?['equipped_${CosmeticsService.slotOf(it['category'].toString())}'] == it['id'];

  /// Why an unowned item can not be bought, or null when it can.
  String? _lockLabel(Map<String, dynamic> it) {
    final src = _source(it);
    if (src == 'earned') return 'EARN IT';
    if (src == 'licence') return 'GACOM';
    if (_premium(it) && _basePrice(it) <= 0) return 'PREMIUM';
    return null;
  }

  bool _shopVisible(Map<String, dynamic> it) {
    final src = _source(it);
    if (src != 'shop' && src != 'premium') return false;
    final until = Tac.time(it['available_until']);
    if (until != null && until.isBefore(DateTime.now()) && !_isOwned(it)) return false;
    return true;
  }

  Map<String, dynamic> get _previewMap {
    final m = <String, dynamic>{};
    for (final c in CosmeticsService.categories) {
      final slot = CosmeticsService.slotOf(c);
      final v = _sel[c] ?? _equipped?[slot];
      if (v != null) m[slot] = v;
    }
    return m;
  }

  // ---- actions ----

  void _select(Map<String, dynamic> it) {
    final cat = it['category']?.toString();
    if (cat == null) return;
    setState(() => _sel[cat] = it);
  }

  Future<void> _equip(Map<String, dynamic>? it, {String? category}) async {
    final cat = category ?? it?['category'] as String?;
    if (cat == null) return;
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
      GacomSnackbar.show(context, it == null ? 'Removed' : '${it['name']} equipped', isSuccess: true);
    } else {
      GacomSnackbar.show(context, res.error ?? 'Could not equip', isError: true);
    }
  }

  /// Refreshes the balance first, then shows the purchase dialog. Returns
  /// true only when the player chose to pay. Sends them to the wallet when
  /// they pick "Add funds".
  Future<bool> _confirmPurchase({required String title, required Rarity rarity, String? description, required int price, required String busyKey}) async {
    setState(() => _busyId = busyKey);
    final fresh = await CosmeticsService.walletBalance();
    if (!mounted) return false;
    setState(() { _busyId = null; if (fresh != null) _balance = fresh; });
    final double balance = fresh ?? _balance ?? 0.0;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => _PurchaseDialog(title: title, rarity: rarity, description: description, price: price, balance: balance),
    );
    if (!mounted || choice == null) return false;
    if (choice == 'wallet') {
      context.push(AppConstants.walletRoute);
      return false;
    }
    return true;
  }

  Future<void> _reloadOwnership() async {
    final r = await Future.wait<dynamic>([CosmeticsService.ownedIds(), CosmeticsService.shopState()]);
    if (!mounted) return;
    setState(() {
      _owned = r[0] as Set<String>;
      final s = r[1] as Map<String, dynamic>?;
      if (s != null) _shop = s;
    });
  }

  Future<void> _buy(Map<String, dynamic> it) async {
    final id = it['id'] as String;
    final ok = await _confirmPurchase(
      title: 'Buy ${it['name']}?',
      rarity: Rarity.parse(it['rarity']?.toString()),
      description: it['description'] as String?,
      price: _pay(it),
      busyKey: id,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = id);
    final res = await CosmeticsService.purchase(id);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _busyId = null);
      GacomSnackbar.show(context, res.error ?? 'Purchase failed', isError: true);
      return;
    }
    setState(() {
      _owned = {..._owned, id};
      if (res.balance != null) _balance = res.balance;
      _busyId = null;
    });
    GacomSnackbar.show(context, '${it['name']} is yours', isSuccess: true);
    await _reloadOwnership();
    if (!mounted) return;
    await _equip(it);
  }

  Future<void> _buyBundle(Map<String, dynamic> b) async {
    final id = b['id']?.toString();
    if (id == null) return;
    final ok = await _confirmPurchase(
      title: 'Buy ${b['name']}?',
      rarity: Rarity.legendary,
      description: b['description'] as String?,
      price: Tac.intOf(b['price']),
      busyKey: 'bundle_$id',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = 'bundle_$id');
    final res = await CosmeticsService.purchaseBundle(id);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _busyId = null);
      GacomSnackbar.show(context, res.error ?? 'Purchase failed', isError: true);
      return;
    }
    setState(() {
      if (res.balance != null) _balance = res.balance;
      _busyId = null;
    });
    GacomSnackbar.show(context, '${b['name']} unlocked', isSuccess: true);
    await _reloadOwnership();
  }

  void _onPrimary(Map<String, dynamic> it) {
    if (_busyId != null) return;
    if (_isEquipped(it)) return;
    if (_isOwned(it)) { _equip(it); return; }
    final lock = _lockLabel(it);
    if (lock != null) {
      final src = _source(it);
      final msg = src == 'earned'
          ? ((it['earn_hint'] as String?) ?? 'Earn this item in GACOM')
          : src == 'licence'
              ? 'Issued by GACOM'
              : 'Included with a Premium membership';
      GacomSnackbar.show(context, msg, isError: true);
      return;
    }
    _buy(it);
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
        title: Text('SHOP', style: Tac.display(size: 18, weight: FontWeight.w800, letter: 2)),
        actions: [
          if (_balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () => context.push(AppConstants.walletRoute),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Tac.gold.withValues(alpha: 0.1),
                      shape: ChamferedBorder(cut: 7, side: BorderSide(color: Tac.gold.withValues(alpha: 0.6))),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Tac.gold),
                        const SizedBox(width: 6),
                        Text(Tac.naira(_balance!), style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.gold, letter: 0.3)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Tac.gold));
    if (!_signedIn) {
      return _message(Icons.lock_outline_rounded, 'Sign in to use the shop', null);
    }
    if (_items.isEmpty && _shop == null) {
      return _message(Icons.storefront_rounded, 'The shop could not be loaded or is empty right now.', _load);
    }
    return Column(children: [
      LoadoutStage(items: _previewMap, name: _displayName, avatarUrl: _avatarUrl),
      _chipBar(),
      Expanded(child: _content()),
    ]);
  }

  Widget _message(IconData icon, String text, Future<void> Function()? retry) {
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

  Widget _chipBar() {
    final keys = _chipLabels.keys.toList();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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
                child: Center(child: Text(_chipLabels[k]!.toUpperCase(), style: Tac.display(size: 11, weight: FontWeight.w800, color: sel ? Tac.bg : Tac.textDim, letter: 0.9))),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content() {
    if (_tab == 'featured') return _featuredTab();
    if (_tab == 'bundles') return _bundlesTab();
    return _grid(_tab);
  }

  // ---- featured tab ----

  Widget _sectionHeader(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(children: [
        Container(width: 3, height: 14, color: Tac.gold),
        const SizedBox(width: 8),
        Text(label, style: Tac.display(size: 12, weight: FontWeight.w800, letter: 1.6)),
        const Spacer(),
        if (trailing != null) trailing,
      ]),
    );
  }

  Widget _featuredTab() {
    final feat = _featured;
    final deals = _deals;
    final bundles = _bundles;
    final earn = _earn;
    if (feat == null && deals.isEmpty && bundles.isEmpty && earn.isEmpty) {
      return _message(Icons.storefront_rounded, 'Today\'s picks are not available right now. Browse a category above.', _load);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (feat != null) ...[
          _sectionHeader('FEATURED'),
          _featuredCard(feat),
        ],
        if (deals.isNotEmpty) ...[
          _sectionHeader('DAILY DEALS', trailing: CountdownText(until: Tac.time(_shop?['deals_reset_at']), prefix: 'Resets in ', doneText: 'Refreshing')),
          _dealsRow(deals),
        ],
        if (bundles.isNotEmpty) ...[
          _sectionHeader('BUNDLES'),
          _bundleCard(bundles.first),
          if (bundles.length > 1) ...[
            const SizedBox(height: 10),
            TacButton(label: 'SEE ALL BUNDLES', filled: false, color: Tac.cyan, onPressed: () => setState(() => _tab = 'bundles')),
          ],
        ],
        if (earn.isNotEmpty) ...[
          _sectionHeader('EARN IT FREE'),
          _earnRow(earn),
        ],
      ],
    );
  }

  Widget _tag(String text, Color c) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: c, shape: const ChamferedBorder(cut: 4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(text, style: Tac.display(size: 10, weight: FontWeight.w800, color: Tac.bg, letter: 0.8)),
      ),
    );
  }

  Widget _featuredCard(Map<String, dynamic> it) {
    final rarity = Rarity.parse(it['rarity']?.toString());
    final previewing = _sel[it['category']]?['id'] == it['id'];
    final desc = it['description'] as String?;
    return RarityCard(
      rarity: rarity,
      cut: 18,
      padding: const EdgeInsets.all(14),
      selected: previewing,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 104,
            height: 112,
            child: DecoratedBox(
              decoration: BoxDecoration(color: rarity.color.withValues(alpha: 0.08)),
              child: ClipRect(child: Center(child: _thumb(it))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _tag('FEATURED', Tac.gold),
                const SizedBox(width: 6),
                RarityChip(rarity, compact: true),
              ]),
              const SizedBox(height: 6),
              Text(it['name'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.display(size: 17, weight: FontWeight.w800, letter: 0.2)),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.body(size: 13, color: Tac.textDim, height: 1.2)),
              ],
              const SizedBox(height: 6),
              CountdownText(until: Tac.time(it['ends_at']), prefix: 'Ends in ', doneText: 'Ended'),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _priceLine(it, size: 17),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TacButton(label: 'PREVIEW', filled: false, color: Tac.cyan, onPressed: () => _select(it))),
          const SizedBox(width: 8),
          Expanded(child: _primary(it)),
        ]),
      ]),
    );
  }

  Widget _dealsRow(List<Map<String, dynamic>> deals) {
    final shown = deals.take(3).toList();
    return SizedBox(
      height: 214,
      child: Row(children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: i < shown.length ? _card(shown[i], compact: true) : const SizedBox.shrink()),
        ],
      ]),
    );
  }

  Widget _earnRow(List<Map<String, dynamic>> earn) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: earn.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final it = earn[i];
          final rarity = Rarity.parse(it['rarity']?.toString());
          final owned = _isOwned(it);
          final hint = (it['earn_hint'] as String?) ?? 'Earn this in GACOM';
          return SizedBox(
            width: 152,
            child: RarityCard(
              rarity: rarity,
              padding: const EdgeInsets.all(8),
              dimmed: !owned && rarity != Rarity.mythic,
              selected: _sel[it['category']]?['id'] == it['id'],
              onTap: () => _select(it),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: rarity.color.withValues(alpha: 0.07)),
                    child: ClipRect(child: Center(child: _thumb(it))),
                  ),
                ),
                const SizedBox(height: 6),
                Text(it['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 12, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                owned
                    ? Text('EARNED', style: Tac.display(size: 10, weight: FontWeight.w800, color: Tac.ok, letter: 0.8))
                    : Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.body(size: 12, color: Tac.textDim, height: 1.1)),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ---- bundles ----

  Widget _bundlesTab() {
    final bundles = _bundles;
    if (bundles.isEmpty) {
      return _message(Icons.inventory_2_outlined, 'No bundles right now. New ones land often.', null);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: bundles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _bundleCard(bundles[i]),
    );
  }

  Widget _bundleCard(Map<String, dynamic> b) {
    final items = _listOf(b['items']);
    final full = Tac.intOf(b['full_price']);
    final price = Tac.intOf(b['price']);
    final disc = Tac.intOf(b['discount_percent']);
    final allOwned = b['all_owned'] == true;
    final id = b['id']?.toString() ?? '';
    final until = Tac.time(b['available_until']);
    final desc = b['description'] as String?;
    return TacticalPanel(
      keyline: Tac.gold.withValues(alpha: 0.6),
      cut: 16,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b['name'] as String? ?? 'Bundle', maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.display(size: 16, weight: FontWeight.w800, letter: 0.3)),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.body(size: 13, color: Tac.textDim, height: 1.2)),
              ],
            ]),
          ),
          if (disc > 0) ...[const SizedBox(width: 8), _tag('-$disc%', Tac.gold)],
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _miniItem(items[i]),
          ),
        ),
        const SizedBox(height: 10),
        if (until != null) CountdownText(until: until, prefix: 'Offer ends in ', doneText: 'Ended'),
        if (!allOwned) ...[
          const SizedBox(height: 4),
          Row(children: [
            if (full > price) ...[
              Text(Tac.naira(full), style: Tac.body(size: 14, weight: FontWeight.w700, color: Tac.textDim).copyWith(decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 8),
            ],
            Text(Tac.naira(price), style: Tac.display(size: 18, weight: FontWeight.w800, color: Tac.gold, letter: 0.2)),
            if (full > price) ...[
              const SizedBox(width: 8),
              Text('save ${Tac.naira(full - price)}', style: Tac.body(size: 13, color: Tac.ok)),
            ],
          ]),
        ],
        const SizedBox(height: 10),
        TacButton(
          label: allOwned ? 'ALL OWNED' : 'BUY BUNDLE',
          onPressed: (allOwned || _busyId != null || id.isEmpty) ? null : () => _buyBundle(b),
          loading: _busyId == 'bundle_$id',
        ),
      ]),
    );
  }

  Widget _miniItem(Map<String, dynamic> it) {
    final rarity = Rarity.parse(it['rarity']?.toString());
    final owned = _isOwned(it);
    return SizedBox(
      width: 78,
      child: RarityCard(
        rarity: rarity,
        cut: 8,
        padding: const EdgeInsets.all(5),
        selected: _sel[it['category']]?['id'] == it['id'],
        onTap: () => _select(it),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ClipRect(child: Center(child: _thumb(it, scale: 0.7)))),
          const SizedBox(height: 3),
          Text(it['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Tac.display(size: 9, weight: FontWeight.w700, letter: 0.2)),
          Text(owned ? 'OWNED' : ' ', textAlign: TextAlign.center, style: Tac.display(size: 8, weight: FontWeight.w800, color: Tac.ok, letter: 0.6)),
        ]),
      ),
    );
  }

  // ---- category grid ----

  Widget _grid(String category) {
    final list = _items.where((e) => e['category'] == category && _shopVisible(e)).toList();
    if (list.isEmpty) {
      return _message(Icons.inventory_2_outlined, 'Nothing here yet. New items land often.', null);
    }
    final equippedId = _equipped?['equipped_${CosmeticsService.slotOf(category)}'];
    return LayoutBuilder(builder: (context, c) {
      final int cols = (c.maxWidth / 170).floor().clamp(2, 6).toInt();
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              Expanded(
                child: Text('Purely cosmetic. Nothing here changes scoring.', style: Tac.body(size: 13, color: Tac.textDim)),
              ),
              if (equippedId != null)
                TextButton(
                  onPressed: _busyId != null ? null : () => _equip(null, category: category),
                  child: Text('TAKE OFF', style: Tac.display(size: 11, weight: FontWeight.w800, color: Tac.cyan, letter: 0.8)),
                ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 214),
            delegate: SliverChildBuilderDelegate((ctx, i) => _card(list[i]), childCount: list.length),
          ),
        ),
      ]);
    });
  }

  // ---- shared card pieces ----

  /// Item thumbnail that survives being scaled down. Banners are width
  /// hungry, so they are never put inside a FittedBox.
  Widget _thumb(Map<String, dynamic> it, {double scale = 1.0}) {
    final visual = CosmeticItemVisual(item: it, scale: scale);
    if (it['category'] == 'profile_banner') {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: visual);
    }
    return FittedBox(fit: BoxFit.scaleDown, child: visual);
  }

  Widget _discountBadge(int pct) {
    return DecoratedBox(
      decoration: const ShapeDecoration(color: Tac.gold, shape: ChamferedBorder(cut: 4, tl: false, tr: false, br: false, bl: true)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('-$pct%', style: Tac.display(size: 10, weight: FontWeight.w800, color: Tac.bg, letter: 0.4)),
      ),
    );
  }

  /// Struck list price and today's price, or the ownership / lock state.
  Widget _priceLine(Map<String, dynamic> it, {double size = 13}) {
    final owned = _isOwned(it);
    final lock = _lockLabel(it);
    final base = _basePrice(it);
    final pay = _pay(it);
    final List<Widget> kids = [];
    if (owned) {
      kids.add(Text('OWNED', style: Tac.display(size: size * 0.85, weight: FontWeight.w800, color: Tac.textDim, letter: 0.8)));
    } else if (lock != null) {
      kids.add(Text(_source(it) == 'earned' ? 'EARNED IN GAME' : lock, style: Tac.display(size: size * 0.8, weight: FontWeight.w800, color: Tac.textDim, letter: 0.6)));
    } else if (pay <= 0) {
      kids.add(Text('FREE', style: Tac.display(size: size, weight: FontWeight.w800, color: Tac.gold, letter: 0.4)));
    } else {
      if (pay < base) {
        kids.add(Text(Tac.naira(base), style: Tac.body(size: size * 0.82, weight: FontWeight.w700, color: Tac.textDim).copyWith(decoration: TextDecoration.lineThrough)));
        kids.add(const SizedBox(width: 6));
      }
      kids.add(Text(Tac.naira(pay), style: Tac.display(size: size, weight: FontWeight.w800, color: Tac.gold, letter: 0.2)));
    }
    return SizedBox(
      height: size + 5,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: kids)),
    );
  }

  /// The buy / equip / locked button for an item.
  Widget _primary(Map<String, dynamic> it, {double height = 38, bool compact = false}) {
    final equipped = _isEquipped(it);
    final owned = _isOwned(it);
    final lock = _lockLabel(it);
    final pay = _pay(it);
    final busy = _busyId == it['id'];
    if (equipped) {
      return SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(shape: ChamferedBorder(cut: 8, side: BorderSide(color: Tac.ok.withValues(alpha: 0.8), width: 1.2))),
          child: Center(child: Text('EQUIPPED', style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.ok, letter: 0.8))),
        ),
      );
    }
    String label;
    Color color;
    bool filled;
    IconData? icon;
    if (owned) {
      label = 'EQUIP'; color = Tac.cyan; filled = false;
    } else if (lock != null) {
      label = lock; color = Tac.textDim; filled = false; icon = compact ? null : Icons.lock_rounded;
    } else {
      label = pay <= 0 ? 'GET' : (compact ? Tac.naira(pay) : 'BUY ${Tac.naira(pay)}'); color = Tac.gold; filled = true;
    }
    return TacButton(
      label: label,
      color: color,
      filled: filled,
      icon: icon,
      height: height,
      loading: busy,
      onPressed: _busyId != null ? null : () => _onPrimary(it),
    );
  }

  Widget _card(Map<String, dynamic> it, {bool compact = false}) {
    final rarity = Rarity.parse(it['rarity']?.toString());
    final equipped = _isEquipped(it);
    final owned = _isOwned(it);
    final previewing = _sel[it['category']]?['id'] == it['id'];
    final disc = owned ? 0 : _discount(it);
    return RarityCard(
      rarity: rarity,
      selected: equipped || previewing,
      padding: EdgeInsets.all(compact ? 8 : 10),
      onTap: () => _select(it),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: rarity.color.withValues(alpha: 0.07)),
                child: ClipRect(child: Center(child: _thumb(it))),
              ),
            ),
            if (disc > 0) Positioned(top: 0, right: 0, child: _discountBadge(disc)),
            if (!compact) Positioned(left: 4, top: 4, child: RarityChip(rarity, compact: true)),
          ]),
        ),
        const SizedBox(height: 6),
        Text(it['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: compact ? 11 : 12.5, weight: FontWeight.w700, letter: 0.2)),
        const SizedBox(height: 2),
        _priceLine(it, size: compact ? 12 : 13),
        const SizedBox(height: 6),
        _primary(it, height: compact ? 30 : 32, compact: compact),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------

class _PurchaseDialog extends StatelessWidget {
  final String title;
  final Rarity rarity;
  final String? description;
  final int price;
  final double balance;
  const _PurchaseDialog({required this.title, required this.rarity, this.description, required this.price, required this.balance});

  @override
  Widget build(BuildContext context) {
    final enough = balance >= price;
    final short = price - balance;
    return AlertDialog(
      backgroundColor: Tac.panel,
      shape: const ChamferedBorder(cut: 16, side: BorderSide(color: Tac.keyline)),
      title: Text(title, style: Tac.display(size: 17, weight: FontWeight.w800, letter: 0.2)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.centerLeft, child: RarityChip(rarity)),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description!, style: Tac.body(size: 14, color: Tac.textDim)),
        ],
        const SizedBox(height: 14),
        _row('Price', Tac.naira(price), Tac.text),
        _row('Wallet balance', Tac.naira(balance), enough ? Tac.text : Tac.danger),
        if (enough) _row('After purchase', Tac.naira(balance - price), Tac.textDim),
        if (!enough) ...[
          const SizedBox(height: 10),
          Text('You need ${Tac.naira(short)} more to buy this.', style: Tac.body(size: 14, color: Tac.danger)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('CANCEL', style: Tac.display(size: 12, color: Tac.textDim, weight: FontWeight.w800))),
        if (enough)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tac.gold, foregroundColor: Tac.bg),
            onPressed: () => Navigator.of(context).pop('buy'),
            child: Text('Buy for ${Tac.naira(price)}', style: Tac.display(size: 12, color: Tac.bg, weight: FontWeight.w800)),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tac.gold, foregroundColor: Tac.bg),
            onPressed: () => Navigator.of(context).pop('wallet'),
            child: Text('Add funds', style: Tac.display(size: 12, color: Tac.bg, weight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _row(String l, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: Tac.body(size: 14, color: Tac.textDim))),
          Text(v, style: Tac.display(size: 14, weight: FontWeight.w800, color: c, letter: 0.2)),
        ]),
      );
}
