import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_button.dart';

// ── Demo products shown when Supabase table is empty / has no data ─────────────
final _demoProducts = [
  {
    'id': 'd1', 'name': 'Gaming Headset Pro X', 'price': 45000.0,
    'condition': 'new', 'category': 'accessories', 'images': [],
    'is_active': true,
    'seller': {'display_name': 'TechVault NG', 'verification_status': 'verified'},
  },
  {
    'id': 'd2', 'name': 'GACOM Limited Hoodie', 'price': 18500.0,
    'condition': 'new', 'category': 'apparel', 'images': [],
    'is_active': true,
    'seller': {'display_name': 'GACOM Official', 'verification_status': 'verified'},
  },
  {
    'id': 'd3', 'name': 'FC 25 (PS5) — Nigerian Edition', 'price': 32000.0,
    'condition': 'new', 'category': 'games', 'images': [],
    'is_active': true,
    'seller': {'display_name': 'GameZone Lagos', 'verification_status': 'unverified'},
  },
  {
    'id': 'd4', 'name': 'RGB Mechanical Keyboard', 'price': 28000.0,
    'condition': 'used', 'category': 'accessories', 'images': [],
    'is_active': true,
    'seller': {'display_name': 'GadgetHub', 'verification_status': 'verified'},
  },
  {
    'id': 'd5', 'name': 'PUBG Mobile Figurine', 'price': 12000.0,
    'condition': 'new', 'category': 'collectibles', 'images': [],
    'is_active': true,
    'seller': {'display_name': 'CollectorsNG', 'verification_status': 'unverified'},
  },
  {
    'id': 'd6', 'name': 'Gaming Chair — Black/Orange', 'price': 95000.0,
    'condition': 'new', 'category': 'accessories', 'images': [],
    'is_active': true,
    'seller': {'display_name': 'ComfortGear', 'verification_status': 'verified'},
  },
];

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  bool _isAdmin = false;
  String _search = '';
  String _selectedCategory = 'all';

  final _categories = [
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

  /// Check if the logged-in user has admin/super_admin role
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
      if (mounted) setState(() => _isAdmin = ['admin', 'super_admin'].contains(role));
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // Simple query without the foreign key join that was causing 400 errors
      var q = SupabaseService.client
          .from('products')
          .select('*')
          .eq('is_active', true);

      if (_selectedCategory != 'all') {
        q = q.eq('category', _selectedCategory) as dynamic;
      }
      if (_search.isNotEmpty) {
        q = q.ilike('name', '%$_search%') as dynamic;
      }

      final data = await (q as dynamic)
          .order('created_at', ascending: false)
          .limit(40);

      final rows = List<Map<String, dynamic>>.from(data);

      // Fetch seller display names separately to avoid FK join errors
      List<Map<String, dynamic>> enriched = [];
      for (final row in rows) {
        final sellerId = row['seller_id'] as String?;
        Map<String, dynamic> seller = {};
        if (sellerId != null) {
          try {
            final sp = await SupabaseService.client
                .from('profiles')
                .select('display_name, verification_status')
                .eq('id', sellerId)
                .maybeSingle();
            if (sp != null) seller = sp;
          } catch (_) {}
        }
        enriched.add({...row, 'seller': seller});
      }

      if (mounted) {
        setState(() {
          _products = enriched.isNotEmpty ? enriched : List<Map<String, dynamic>>.from(_demoProducts);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(_demoProducts);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('MARKETPLACE'),
        actions: [
          // ✅ ADMIN ONLY — regular users never see this button
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: GacomColors.deepOrange),
              tooltip: 'Add Product (Admin)',
              onPressed: () => _showAddProductSheet(context),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          tabs: const [Tab(text: 'BROWSE'), Tab(text: 'MY ORDERS')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BrowseTab(
            products: _products,
            loading: _loading,
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategoryChange: (c) {
              setState(() { _selectedCategory = c; });
              _load();
            },
            onSearch: (s) {
              setState(() { _search = s; });
              _load();
            },
          ),
          _OrdersTab(),
        ],
      ),
    );
  }

  /// Admin-only: add product to the store
  void _showAddProductSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String condition = 'new';
    String category = 'accessories';

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
              // Header
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
              GacomTextField(controller: descCtrl, label: 'Description', hint: 'Describe the product...', prefixIcon: Icons.description_rounded, maxLines: 3),
              const SizedBox(height: 12),
              GacomTextField(controller: priceCtrl, label: 'Price (₦)', hint: '0', prefixIcon: Icons.attach_money_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 12),

              // Category
              const Text('Category', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani', letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final cat in ['accessories', 'apparel', 'games', 'collectibles'])
                  GestureDetector(
                    onTap: () => setModal(() => category = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: category == cat ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: category == cat ? GacomColors.deepOrange : GacomColors.border)),
                      child: Text(cat[0].toUpperCase() + cat.substring(1),
                          style: TextStyle(color: category == cat ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),

              // Condition
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
                            border: Border.all(color: condition == c ? GacomColors.deepOrange : GacomColors.border)),
                        child: Text(c[0].toUpperCase() + c.substring(1),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: condition == c ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 28),

              // ✅ Button wrapped in SizedBox so it's always full-width and visible
              SizedBox(
                width: double.infinity,
                child: GacomButton(
                  label: 'ADD TO STORE',
                  height: 54,
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.isEmpty) {
                      GacomSnackbar.show(ctx, 'Name and price required', isError: true);
                      return;
                    }
                    try {
                      await SupabaseService.client.from('products').insert({
                        'seller_id': SupabaseService.currentUserId,
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'price': double.tryParse(priceCtrl.text) ?? 0,
                        'condition': condition,
                        'category': category,
                        'is_active': true,
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        GacomSnackbar.show(context, 'Product added to store! 🛍️', isSuccess: true);
                        await _load();
                      }
                    } catch (e) {
                      GacomSnackbar.show(ctx, 'Failed to add product. Check DB permissions.', isError: true);
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

// ── Browse tab ─────────────────────────────────────────────────────────────────

class _BrowseTab extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool loading;
  final List<(String, String, IconData)> categories;
  final String selectedCategory;
  final void Function(String) onCategoryChange;
  final void Function(String) onSearch;

  const _BrowseTab({
    required this.products,
    required this.loading,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChange,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          onChanged: onSearch,
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
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final c = categories[i];
            final sel = selectedCategory == c.$1;
            return GestureDetector(
              onTap: () => onCategoryChange(c.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border, width: 0.8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(c.$3, size: 13, color: sel ? GacomColors.deepOrange : GacomColors.textMuted),
                  const SizedBox(width: 6),
                  Text(c.$2, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            );
          },
        ),
      ),
      // Grid
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : products.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.storefront_rounded, size: 64, color: GacomColors.border),
                    SizedBox(height: 16),
                    Text('No items found', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
                  ]))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
                    itemCount: products.length,
                    itemBuilder: (_, i) => _ProductCard(product: products[i])
                        .animate(delay: (i * 40).ms)
                        .fadeIn(),
                  ),
      ),
    ]);
  }
}

// ── Product card ───────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final condition = product['condition'] as String? ?? 'new';
    final seller = product['seller'] as Map? ?? {};
    final isVerified = seller['verification_status'] == 'verified';
    final isDemo = product['id'].toString().startsWith('d');

    return GestureDetector(
      onTap: () {
        if (!isDemo) context.push('/store/product/${product['id']}');
      },
      child: Container(
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GacomColors.border, width: 0.6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
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
              Text(product['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₦${price.toStringAsFixed(0)}',
                    style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: (condition == 'new' ? GacomColors.success : GacomColors.warning).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(condition[0].toUpperCase() + condition.substring(1),
                      style: TextStyle(color: condition == 'new' ? GacomColors.success : GacomColors.warning, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.storefront_rounded, size: 11, color: GacomColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(seller['display_name'] ?? 'Seller', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))),
                if (isVerified) const Icon(Icons.verified_rounded, size: 11, color: GacomColors.deepOrange),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String condition;
  const _Placeholder({required this.condition});
  @override
  Widget build(BuildContext context) => Container(
        color: GacomColors.surfaceDark,
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_rounded, color: GacomColors.border, size: 40),
          const SizedBox(height: 6),
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: condition == 'new' ? GacomColors.success : GacomColors.warning,
            ),
          ),
        ])),
      );
}

// ── Orders tab (user's purchases) ─────────────────────────────────────────────

class _OrdersTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shopping_bag_outlined, size: 64, color: GacomColors.border),
        SizedBox(height: 16),
        Text('No orders yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 16, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('Browse the marketplace to find gear', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}
