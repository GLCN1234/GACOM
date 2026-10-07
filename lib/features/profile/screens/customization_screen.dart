import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../edu/edu_subscription_service.dart';
import '../../edu/realms/realm_kit.dart' show RealmDraw;
import '../../../shared/widgets/cosmetic_avatar.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

const Map<String, String> _tabLabels = {
  'name_color': 'Name Colour',
  'badge': 'Badge',
  'avatar_frame': 'Avatar Frame',
  'hero_outfit': 'Hero Outfit',
  'trail': 'Trail',
  'profile_banner': 'Banner',
};

Color _rarityColor(String? rarity) {
  switch (rarity) {
    case 'rare': return const Color(0xFF4FC3F7);
    case 'epic': return const Color(0xFFB388FF);
    case 'legendary': return GacomColors.gold;
    default: return const Color(0xFF9A9AA6);
  }
}

String _naira(num amount) {
  final s = amount.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '₦$buf';
}

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});
  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  bool _signedIn = true;
  bool _isPro = false;
  List<Map<String, dynamic>> _items = [];
  Set<String> _owned = {};
  Map<String, dynamic>? _equipped;
  final Map<String, Map<String, dynamic>> _sel = {}; // previewed but not equipped
  String? _busyId;
  double? _balance;
  String _displayName = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: CosmeticsService.categories.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    ]);
    if (!mounted) return;
    final prof = results[3] as Map<String, dynamic>?;
    setState(() {
      _isPro = pro;
      _items = results[0] as List<Map<String, dynamic>>;
      _owned = results[1] as Set<String>;
      _equipped = results[2] as Map<String, dynamic>?;
      _balance = (prof?['wallet_balance'] as num?)?.toDouble();
      _displayName = (prof?['display_name'] as String?) ?? '';
      _avatarUrl = prof?['avatar_url'] as String?;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    try {
      return await SupabaseService.client.from('profiles').select('display_name, avatar_url, wallet_balance').eq('id', uid).maybeSingle();
    } catch (_) { return null; }
  }

  // ---- item state ----

  int _price(Map<String, dynamic> it) => (it['price'] as num?)?.toInt() ?? 0;
  bool _premium(Map<String, dynamic> it) => it['requires_premium'] == true;

  bool _isOwned(Map<String, dynamic> it) {
    final id = it['id'] as String;
    if (_owned.contains(id)) return true;
    if (_price(it) <= 0 && !_premium(it)) return true;
    if (_premium(it) && _isPro) return true;
    return false;
  }

  bool _isEquipped(Map<String, dynamic> it) => _equipped?['equipped_${it['category']}'] == it['id'];

  Map<String, dynamic> get _previewMap {
    final m = <String, dynamic>{};
    for (final c in CosmeticsService.categories) {
      final v = _sel[c] ?? _equipped?[c];
      if (v != null) m[c] = v;
    }
    return m;
  }

  // ---- actions ----

  void _select(Map<String, dynamic> it) {
    setState(() => _sel[it['category'] as String] = it);
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

  Future<void> _buy(Map<String, dynamic> it) async {
    final price = _price(it);
    setState(() => _busyId = it['id'] as String?);
    final fresh = await CosmeticsService.walletBalance();
    if (!mounted) return;
    setState(() { _busyId = null; if (fresh != null) _balance = fresh; });
    final double balance = fresh ?? _balance ?? 0.0;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => _PurchaseDialog(item: it, price: price, balance: balance),
    );
    if (!mounted || choice == null) return;
    if (choice == 'wallet') {
      context.push(AppConstants.walletRoute);
      return;
    }
    setState(() => _busyId = it['id'] as String?);
    final res = await CosmeticsService.purchase(it['id'] as String);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _busyId = null);
      GacomSnackbar.show(context, res.error ?? 'Purchase failed', isError: true);
      return;
    }
    setState(() {
      _owned = {..._owned, it['id'] as String};
      if (res.balance != null) _balance = res.balance;
      _busyId = null;
    });
    GacomSnackbar.show(context, '${it['name']} is yours', isSuccess: true);
    await _equip(it);
  }

  void _onPrimary(Map<String, dynamic> it) {
    if (_busyId != null) return;
    if (_isEquipped(it)) return;
    if (_isOwned(it)) { _equip(it); return; }
    if (_premium(it) && _price(it) <= 0) {
      GacomSnackbar.show(context, 'Included with a Premium membership', isError: true);
      return;
    }
    _buy(it);
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('SHOP'),
        actions: [
          if (_balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () => context.push(AppConstants.walletRoute),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: GacomColors.deepOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GacomColors.borderOrange),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: GacomColors.deepOrange),
                      const SizedBox(width: 6),
                      Text(_naira(_balance!), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange)),
                    ]),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return _message(Icons.lock_outline_rounded, 'Sign in to use the shop', null);
    }
    if (_items.isEmpty) {
      return _message(Icons.storefront_rounded, 'The shop could not be loaded or is empty right now.', _load);
    }
    return Column(children: [
      _Preview(items: _previewMap, name: _displayName, avatarUrl: _avatarUrl),
      Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GacomColors.border))),
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: GacomColors.deepOrange,
          labelColor: GacomColors.deepOrange,
          unselectedLabelColor: GacomColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14),
          tabs: [for (final c in CosmeticsService.categories) Tab(text: _tabLabels[c] ?? c)],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [for (final c in CosmeticsService.categories) _grid(c)],
        ),
      ),
    ]);
  }

  Widget _message(IconData icon, String text, Future<void> Function()? retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: GacomColors.textMuted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.4)),
          if (retry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: retry, child: const Text('Try again')),
          ],
        ]),
      ),
    );
  }

  Widget _grid(String category) {
    final list = _items.where((e) => e['category'] == category).toList();
    if (list.isEmpty) {
      return _message(Icons.inventory_2_outlined, 'Nothing here yet. New items land often.', null);
    }
    final equippedId = _equipped?['equipped_$category'];
    return LayoutBuilder(builder: (context, c) {
      final int cols = (c.maxWidth / 170).floor().clamp(2, 6).toInt();
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              const Expanded(
                child: Text('Purely cosmetic. Nothing here changes scoring.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ),
              if (equippedId != null)
                TextButton(
                  onPressed: _busyId != null ? null : () => _equip(null, category: category),
                  child: const Text('Take off'),
                ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 196),
            delegate: SliverChildBuilderDelegate((ctx, i) => _card(list[i]), childCount: list.length),
          ),
        ),
      ]);
    });
  }

  Widget _card(Map<String, dynamic> it) {
    final rarity = it['rarity'] as String?;
    final rc = _rarityColor(rarity);
    final equipped = _isEquipped(it);
    final owned = _isOwned(it);
    final price = _price(it);
    final previewing = _sel[it['category']]?['id'] == it['id'];
    final busy = _busyId == it['id'];
    final locked = !owned && _premium(it) && price <= 0;
    final paidOwned = _owned.contains(it['id']) && price > 0;

    String label;
    Color fg;
    Color bg;
    Color border;
    if (equipped) {
      label = 'EQUIPPED'; fg = GacomColors.success; bg = Colors.transparent; border = GacomColors.success;
    } else if (owned) {
      label = 'EQUIP'; fg = GacomColors.deepOrange; bg = Colors.transparent; border = GacomColors.deepOrange;
    } else if (locked) {
      label = 'PREMIUM'; fg = GacomColors.textMuted; bg = Colors.transparent; border = GacomColors.border;
    } else {
      label = _naira(price); fg = Colors.white; bg = GacomColors.deepOrange; border = GacomColors.deepOrange;
    }

    return GestureDetector(
      onTap: () => _select(it),
      child: Container(
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: equipped ? GacomColors.success : (previewing ? rc : rc.withValues(alpha: 0.35)), width: (equipped || previewing) ? 1.6 : 1),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: rc.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Center(child: _visual(it, rc))),
            ),
          ),
          const SizedBox(height: 8),
          Text(it['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
          Row(children: [
            Text((rarity ?? 'common').toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6, color: rc)),
            if (paidOwned) const Padding(padding: EdgeInsets.only(left: 6), child: Text('OWNED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6, color: GacomColors.textMuted))),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: Material(
              color: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: (equipped || _busyId != null) ? null : () => _onPrimary(it),
                child: Center(
                  child: busy
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (locked) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock_rounded, size: 12, color: GacomColors.textMuted)),
                          Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
                        ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _visual(Map<String, dynamic> it, Color rc) {
    final cat = it['category'] as String?;
    final asset = it['asset'] is Map ? Map<String, dynamic>.from(it['asset'] as Map) : <String, dynamic>{};
    switch (cat) {
      case 'name_color': {
        final col = CosmeticsService.parseColor(it['value'] as String?) ?? GacomColors.textPrimary;
        return Text('Aa', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 34, color: col));
      }
      case 'badge':
        return Icon(CosmeticsService.iconForBadge(it['value'] as String?) ?? Icons.star_outline_rounded, size: 38, color: rc);
      case 'avatar_frame':
        return CosmeticAvatar(radius: 24, name: 'G', frameItem: it);
      case 'hero_outfit':
        return SizedBox(width: 70, height: 80, child: CustomPaint(painter: _FigurePainter(outfit: asset, trail: const {}, scale: 1.5, phase: 0, moving: false)));
      case 'trail':
        return SizedBox(width: 110, height: 70, child: CustomPaint(painter: _FigurePainter(outfit: const {}, trail: asset, scale: 1.1, phase: 6.0, moving: true, dx: 0.7)));
      case 'profile_banner':
        return ProfileBanner(
          bannerItem: it,
          height: 56,
          fallback: const Center(child: Icon(Icons.block_rounded, size: 24, color: GacomColors.textMuted)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------

class _PurchaseDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final int price;
  final double balance;
  const _PurchaseDialog({required this.item, required this.price, required this.balance});

  @override
  Widget build(BuildContext context) {
    final enough = balance >= price;
    final short = price - balance;
    final rc = _rarityColor(item['rarity'] as String?);
    return AlertDialog(
      backgroundColor: GacomColors.elevatedCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Buy ${item['name']}?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(((item['rarity'] as String?) ?? 'common').toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8, color: rc)),
        if ((item['description'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(item['description'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        ],
        const SizedBox(height: 14),
        _row('Price', _naira(price), GacomColors.textPrimary),
        _row('Wallet balance', _naira(balance), enough ? GacomColors.textPrimary : GacomColors.error),
        if (enough) _row('After purchase', _naira(balance - price), GacomColors.textSecondary),
        if (!enough) ...[
          const SizedBox(height: 10),
          Text('You need ${_naira(short)} more to buy this.', style: const TextStyle(color: GacomColors.error, fontSize: 13)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        if (enough)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GacomColors.deepOrange),
            onPressed: () => Navigator.of(context).pop('buy'),
            child: Text('Buy for ${_naira(price)}'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GacomColors.deepOrange),
            onPressed: () => Navigator.of(context).pop('wallet'),
            child: const Text('Add funds'),
          ),
      ],
    );
  }

  Widget _row(String l, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13))),
          Text(v, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: c)),
        ]),
      );
}

// ---------------------------------------------------------------------------

/// Live preview: banner, framed avatar, coloured name with badge, and an
/// animated hero wearing the outfit and trail.
class _Preview extends StatefulWidget {
  final Map<String, dynamic> items;
  final String name;
  final String? avatarUrl;
  const _Preview({required this.items, required this.name, this.avatarUrl});
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asset(String key) {
    final a = widget.items[key]?['asset'];
    return a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final nameColor = CosmeticsService.nameColorFor(widget.items) ?? GacomColors.textPrimary;
    final badge = CosmeticsService.badgeFor(widget.items);
    final shown = widget.name.isEmpty ? 'You' : widget.name;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      height: 150,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: GacomColors.borderBright)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          ProfileBanner(
            equipped: widget.items,
            fallback: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [GacomColors.deepOrange.withValues(alpha: 0.2), GacomColors.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CosmeticAvatar(radius: 32, avatarUrl: widget.avatarUrl, name: shown, equipped: widget.items),
              const SizedBox(width: 12),
              Expanded(
                child: Row(children: [
                  if (badge != null) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(badge, size: 18, color: GacomColors.deepOrange)),
                  Flexible(
                    child: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: nameColor)),
                  ),
                ]),
              ),
              SizedBox(
                width: 130,
                height: 120,
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (_, __) => CustomPaint(
                    painter: _FigurePainter(outfit: _asset('hero_outfit'), trail: _asset('trail'), scale: 1.7, phase: _ctl.value * 6.283185307 * 14, moving: true, dx: 0.72),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Draws the hero with a given outfit and trail (asset json), independent of
/// what is currently equipped.
class _FigurePainter extends CustomPainter {
  final Map<String, dynamic> outfit;
  final Map<String, dynamic> trail;
  final double scale;
  final double phase;
  final bool moving;
  final double dx; // horizontal position as a fraction of the width

  const _FigurePainter({required this.outfit, required this.trail, required this.scale, required this.phase, required this.moving, this.dx = 0.5});

  Color _c(Map<String, dynamic> m, String k, Color d) => CosmeticsService.parseColor(m[k]?.toString()) ?? d;

  @override
  void paint(Canvas canvas, Size size) {
    final double x = size.width * dx;
    final double y = size.height / 2 - 4;
    final String kind = trail['kind']?.toString() ?? 'none';
    if (moving && kind != 'none') {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale, scale);
      RealmDraw.heroTrail(canvas, kind, _c(trail, 'color', const Color(0xFFFFF176)), phase, 1.0);
      canvas.restore();
    }
    RealmDraw.person(
      canvas, x, y,
      phase: phase,
      moving: moving,
      facing: 1,
      shirt: _c(outfit, 'shirt', const Color(0xFFFF6A00)),
      pants: _c(outfit, 'pants', const Color(0xFF2A3A63)),
      skin: _c(outfit, 'skin', const Color(0xFFF2B785)),
      hair: _c(outfit, 'hair', const Color(0xFF2B1B12)),
      scale: scale,
    );
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) =>
      old.phase != phase || old.outfit != outfit || old.trail != trail || old.scale != scale || old.moving != moving;
}
