import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

// Demo products — always shown when DB is empty. 'category' key is local-only.
final _demoProducts = <Map<String, dynamic>>[
  {'id': 'demo_1', 'name': 'Gaming Headset Pro X', 'price': 45000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Professional gaming headset with 7.1 surround sound, noise cancellation, and 40-hour battery life.', 'brand': 'SteelSound', 'seller_name': 'TechVault NG', 'seller_verified': true},
  {'id': 'demo_2', 'name': 'GACOM Limited Hoodie', 'price': 18500.0, 'condition': 'new', 'category': 'apparel', 'images': <String>[], 'is_active': true, 'description': 'Official GACOM branded hoodie. Premium cotton blend. Available in all sizes.', 'brand': 'GACOM', 'seller_name': 'GACOM Official', 'seller_verified': true},
  {'id': 'demo_3', 'name': 'FC 25 (PS5) — Nigerian Edition', 'price': 32000.0, 'condition': 'new', 'category': 'games', 'images': <String>[], 'is_active': true, 'description': 'FIFA 25 for PlayStation 5. Brand new sealed copy. Nigerian edition with AFCON content included.', 'brand': 'EA Sports', 'seller_name': 'GameZone Lagos', 'seller_verified': false},
  {'id': 'demo_4', 'name': 'RGB Mechanical Keyboard', 'price': 28000.0, 'condition': 'used', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Used but excellent condition. TKL layout, Cherry MX Red switches. Full RGB with software control.', 'brand': 'Corsair', 'seller_name': 'GadgetHub', 'seller_verified': true},
  {'id': 'demo_5', 'name': 'PUBG Mobile Figurine', 'price': 12000.0, 'condition': 'new', 'category': 'collectibles', 'images': <String>[], 'is_active': true, 'description': 'Official PUBG Mobile limited edition figurine. 15cm tall, comes in collector box.', 'brand': 'PUBG Corp', 'seller_name': 'CollectorsNG', 'seller_verified': false},
  {'id': 'demo_6', 'name': 'Gaming Chair — Black/Orange', 'price': 95000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Ergonomic gaming chair with lumbar support, recline up to 155°, adjustable armrests. Ships within Lagos.', 'brand': 'GamerSeat', 'seller_name': 'ComfortGear', 'seller_verified': true},
  {'id': 'demo_7', 'name': 'PS5 DualSense Controller', 'price': 52000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Original Sony DualSense wireless controller for PS5. Midnight Black edition. Includes USB-C cable.', 'brand': 'Sony', 'seller_name': 'PlayHouse NG', 'seller_verified': true},
  {'id': 'demo_8', 'name': 'Call of Duty Jersey', 'price': 9500.0, 'condition': 'new', 'category': 'apparel', 'images': <String>[], 'is_active': true, 'description': 'Official Call of Duty esports jersey. Breathable fabric, one-size-fits-most design.', 'brand': 'Activision', 'seller_name': 'GACOM Official', 'seller_verified': true},
];

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _allProducts = [];
  bool _loading = true;
  bool _isAdmin = false;
  String _search = '';
  String _selectedCategory = 'all';

  final _categories = const [
    ('all', 'All', Icons.grid_view_rounded),
    ('accessories', 'Accessories', Icons.headset_rounded),
    ('apparel', 'Apparel', Icons.checkroom_rounded),
    ('games', 'Games', Icons.sports_esports_rounded),
    ('collectibles', 'Collectibles', Icons.stars_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _checkAdminRole();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final p = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .single();
      final role = p['role'] as String? ?? 'user';
      if (mounted) {
        setState(() => _isAdmin = ['admin', 'super_admin'].contains(role));
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // FIX: products table has no seller_id, category, or is_available columns.
      // Correct columns: is_active, condition, brand, name, price, images, tags, specs
      // Category filtering must be done client-side (category_id is FK to product_categories)
      // so we just pull all active products and filter in Dart.
      final data = await SupabaseService.client
          .from('products')
          .select('id, name, description, price, condition, brand, images, tags, is_active, is_featured, rating, stock')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(60);

      final rows = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          // If DB has products use them, otherwise show demos
          _allProducts = rows.isNotEmpty ? rows : List.from(_demoProducts);
          _loading = false;
        });
      }
    } catch (_) {
      // Network error or table issue — always fall back to demos gracefully
      if (mounted) {
        setState(() {
          _allProducts = List.from(_demoProducts);
          _loading = false;
        });
      }
    }
  }

  // Client-side filtering — no extra DB calls when switching categories
  List<Map<String, dynamic>> get _filtered {
    return _allProducts.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final cat = (p['category'] as String? ?? '').toLowerCase();
      final tags = ((p['tags'] as List?) ?? []).join(' ').toLowerCase();
      final brand = (p['brand'] as String? ?? '').toLowerCase();

      final matchSearch = _search.isEmpty ||
          name.contains(_search.toLowerCase()) ||
          brand.contains(_search.toLowerCase()) ||
          tags.contains(_search.toLowerCase());

      final matchCat = _selectedCategory == 'all' ||
          cat == _selectedCategory ||
          tags.contains(_selectedCategory) ||
          brand.contains(_selectedCategory);

      return matchSearch && matchCat;
    }).toList();
  }

  void _openProduct(Map<String, dynamic> product) {
    final isDemo = (product['id'] as String).startsWith('demo_');
    if (!isDemo) {
      // Real product — navigate to detail page
      context.push('/store/product/${product['id']}');
      return;
    }
    // Demo product — show detail bottom sheet
    _showProductSheet(product);
  }

  void _showProductSheet(Map<String, dynamic> product) {
    final isDemo = (product['id'] as String).startsWith('demo_');
    final images = (product['images'] as List?)?.cast<String>() ?? [];
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final condition = product['condition'] as String? ?? 'new';
    final sellerName = product['seller_name'] as String? ??
        ((product['seller'] as Map?)?['display_name'] as String?) ?? 'GACOM Store';
    final sellerVerified = product['seller_verified'] as bool? ??
        ((product['seller'] as Map?)?['verification_status'] == 'verified');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // Handle
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: images.isNotEmpty
                    ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover)
                    : Container(
                        color: GacomColors.surfaceDark,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(
                            _categoryIcon(product['category'] as String? ?? ''),
                            color: GacomColors.deepOrange, size: 56,
                          ),
                          const SizedBox(height: 8),
                          Text(product['name'] ?? '', textAlign: TextAlign.center,
                              style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                        ]),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // Name + price
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(product['name'] ?? '',
                  style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 22))),
              const SizedBox(width: 8),
              Text('₦${price.toStringAsFixed(0)}',
                  style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22)),
            ]),
            const SizedBox(height: 10),
            // Condition + seller
            Row(children: [
              _ConditionBadge(condition: condition),
              const SizedBox(width: 10),
              const Icon(Icons.storefront_rounded, size: 13, color: GacomColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(sellerName,
                  style: const TextStyle(color: GacomColors.textMuted, fontSize: 13))),
              if (sellerVerified)
                const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange),
            ]),
            const SizedBox(height: 16),
            const Divider(color: GacomColors.border),
            const SizedBox(height: 12),
            if ((product['brand'] as String?) != null) ...[
              Row(children: [
                const Icon(Icons.local_offer_rounded, size: 13, color: GacomColors.textMuted),
                const SizedBox(width: 6),
                Text('Brand: ${product['brand']}',
                    style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
            ],
            const Text('Description',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(product['description'] as String? ?? 'No description available.',
                style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.65)),
            const SizedBox(height: 28),
            GacomButton(
              label: isDemo ? 'COMING SOON — Demo Item' : 'CONTACT SELLER',
              onPressed: () {
                Navigator.pop(ctx);
                if (!isDemo) {
                  context.push('/chat');
                } else {
                  GacomSnackbar.show(context, 'This is a demo listing. Real products coming soon! 🛍️');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'accessories': return Icons.headset_rounded;
      case 'apparel': return Icons.checkroom_rounded;
      case 'games': return Icons.sports_esports_rounded;
      case 'collectibles': return Icons.stars_rounded;
      default: return Icons.inventory_2_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('MARKETPLACE'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: GacomColors.deepOrange),
              tooltip: 'Add Product',
              onPressed: () => _showAddProductSheet(context),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelColor: GacomColors.deepOrange,
          unselectedLabelColor: GacomColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'BROWSE'), Tab(text: 'MY ORDERS')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Browse tab ──────────────────────────────────────
          Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: GacomColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search marketplace...',
                  hintStyle: const TextStyle(color: GacomColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted),
                  filled: true,
                  fillColor: GacomColors.cardDark,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border, width: 0.7)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
                ),
              ),
            ),
            // Category pills
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  final sel = _selectedCategory == c.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.cardDark,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border, width: 0.8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(c.$3, size: 13, color: sel ? GacomColors.deepOrange : GacomColors.textMuted),
                        const SizedBox(width: 6),
                        Text(c.$2, style: TextStyle(
                          color: sel ? GacomColors.deepOrange : GacomColors.textMuted,
                          fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13,
                        )),
                      ]),
                    ),
                  );
                },
              ),
            ),
            // Product grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                  : _filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.storefront_rounded, size: 64, color: GacomColors.border),
                          const SizedBox(height: 16),
                          Text(
                            _search.isNotEmpty ? 'No results for "$_search"' : 'No items in this category',
                            style: const TextStyle(color: GacomColors.textMuted, fontSize: 15),
                          ),
                        ]))
                      : RefreshIndicator(
                          color: GacomColors.deepOrange,
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _ProductCard(
                              product: _filtered[i],
                              onTap: () => _openProduct(_filtered[i]),
                            ).animate(delay: (i * 40).ms).fadeIn(),
                          ),
                        ),
            ),
          ]),

          // ── Orders tab ──────────────────────────────────────
          const _OrdersTab(),
        ],
      ),
    );
  }

  void _showAddProductSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    String condition = 'new';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          builder: (_, scroll) => Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: ListView(controller: scroll, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: GacomColors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: GacomColors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add Product', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
                  Text('Admin only', style: TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani')),
                ])),
              ]),
              const SizedBox(height: 20),
              GacomTextField(controller: nameCtrl, label: 'Product Name', hint: 'e.g. Gaming Headset Pro', prefixIcon: Icons.inventory_2_rounded),
              const SizedBox(height: 12),
              GacomTextField(controller: brandCtrl, label: 'Brand', hint: 'e.g. Sony, Corsair', prefixIcon: Icons.local_offer_rounded),
              const SizedBox(height: 12),
              GacomTextField(controller: descCtrl, label: 'Description', hint: 'Describe the product...', prefixIcon: Icons.description_rounded, maxLines: 3),
              const SizedBox(height: 12),
              GacomTextField(controller: priceCtrl, label: 'Price (₦)', hint: '0', prefixIcon: Icons.attach_money_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              const Text('Condition', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani', letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                for (final c in ['new', 'used', 'refurbished'])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => condition = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: condition == c ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: condition == c ? GacomColors.deepOrange : GacomColors.border),
                        ),
                        child: Text(c[0].toUpperCase() + c.substring(1),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: condition == c ? GacomColors.deepOrange : GacomColors.textMuted,
                              fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13,
                            )),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: GacomButton(
                  label: 'ADD TO STORE',
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.isEmpty) {
                      GacomSnackbar.show(ctx, 'Name and price required', isError: true);
                      return;
                    }
                    try {
                      // FIX: products table has no seller_id or category text column
                      // Use tags[] for categorisation, condition enum, brand text
                      final slug = nameCtrl.text.trim().toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9]'), '-') +
                          '-${DateTime.now().millisecondsSinceEpoch}';
                      await SupabaseService.client.from('products').insert({
                        'name': nameCtrl.text.trim(),
                        'slug': slug,
                        'description': descCtrl.text.trim(),
                        'brand': brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
                        'price': double.tryParse(priceCtrl.text) ?? 0,
                        'condition': condition,
                        'is_active': true,
                        'stock': 1,
                        'images': <String>[],
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        GacomSnackbar.show(context, 'Product added to store! 🛍️', isSuccess: true);
                        await _load();
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        GacomSnackbar.show(ctx, 'Failed: ${e.toString()}', isError: true);
                      }
                    }
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final images = (product['images'] as List?)?.cast<String>() ?? [];
    final condition = product['condition'] as String? ?? 'new';
    final sellerName = product['seller_name'] as String? ??
        ((product['seller'] as Map?)?['display_name'] as String?) ?? 'GACOM Store';
    final sellerVerified = product['seller_verified'] as bool? ??
        ((product['seller'] as Map?)?['verification_status'] == 'verified');

    return GestureDetector(
      onTap: onTap, // Always tappable — no more demo check blocking
      child: Container(
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GacomColors.border, width: 0.6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product image / placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 1,
              child: images.isNotEmpty
                  ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _Placeholder(condition: condition))
                  : _Placeholder(condition: condition),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product['name'] ?? '',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₦${price.toStringAsFixed(0)}',
                    style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                _ConditionBadge(condition: condition),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.storefront_rounded, size: 11, color: GacomColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(sellerName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))),
                if (sellerVerified)
                  const Icon(Icons.verified_rounded, size: 11, color: GacomColors.deepOrange),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: (condition == 'new' ? GacomColors.success : GacomColors.warning).withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      condition[0].toUpperCase() + condition.substring(1),
      style: TextStyle(
        color: condition == 'new' ? GacomColors.success : GacomColors.warning,
        fontSize: 9, fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Placeholder extends StatelessWidget {
  final String condition;
  const _Placeholder({required this.condition});
  @override
  Widget build(BuildContext context) => Container(
    color: GacomColors.surfaceDark,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.inventory_2_rounded, color: GacomColors.border, size: 40),
      const SizedBox(height: 6),
      Container(width: 6, height: 6, decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: condition == 'new' ? GacomColors.success : GacomColors.warning,
      )),
    ])),
  );
}

// ── Orders tab ────────────────────────────────────────────────────────────────

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: SupabaseService.currentUserId != null
          ? SupabaseService.client
              .from('orders')
              .select('id, status, total_amount, created_at')
              .eq('user_id', SupabaseService.currentUserId!)
              .order('created_at', ascending: false)
              .limit(20)
          : Future.value(<dynamic>[]),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
        }
        final orders = snap.data as List? ?? [];
        if (orders.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: GacomColors.border),
            SizedBox(height: 16),
            Text('No orders yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 16, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Browse the marketplace to find gear', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final o = orders[i] as Map<String, dynamic>;
            final status = o['status'] as String? ?? 'pending';
            final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
              child: Row(children: [
                const Icon(Icons.shopping_bag_rounded, color: GacomColors.deepOrange, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Order #${(o['id'] as String).substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('₦${amount.toStringAsFixed(0)}',
                      style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status.toUpperCase(), style: const TextStyle(color: GacomColors.info, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}
