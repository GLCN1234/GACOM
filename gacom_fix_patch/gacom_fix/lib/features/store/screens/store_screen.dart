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

// Demo products — fully tappable (opens detail sheet)
final _demoProducts = [
  {'id': 'demo_1', 'name': 'Gaming Headset Pro X', 'price': 45000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Professional gaming headset with 7.1 surround sound, noise cancellation, and 40-hour battery life.', 'seller': {'display_name': 'TechVault NG', 'verification_status': 'verified'}},
  {'id': 'demo_2', 'name': 'GACOM Limited Hoodie', 'price': 18500.0, 'condition': 'new', 'category': 'apparel', 'images': <String>[], 'is_active': true, 'description': 'Official GACOM branded hoodie. Premium cotton blend. Available in all sizes.', 'seller': {'display_name': 'GACOM Official', 'verification_status': 'verified'}},
  {'id': 'demo_3', 'name': 'FC 25 (PS5) — Nigerian Edition', 'price': 32000.0, 'condition': 'new', 'category': 'games', 'images': <String>[], 'is_active': true, 'description': 'FIFA 25 for PlayStation 5. Brand new sealed copy. Nigerian edition with AFCON content included.', 'seller': {'display_name': 'GameZone Lagos', 'verification_status': 'unverified'}},
  {'id': 'demo_4', 'name': 'RGB Mechanical Keyboard', 'price': 28000.0, 'condition': 'used', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Used but excellent condition. TKL layout, Cherry MX Red switches. Full RGB with software control.', 'seller': {'display_name': 'GadgetHub', 'verification_status': 'verified'}},
  {'id': 'demo_5', 'name': 'PUBG Mobile Figurine', 'price': 12000.0, 'condition': 'new', 'category': 'collectibles', 'images': <String>[], 'is_active': true, 'description': 'Official PUBG Mobile limited edition figurine. 15cm tall, comes in collector box.', 'seller': {'display_name': 'CollectorsNG', 'verification_status': 'unverified'}},
  {'id': 'demo_6', 'name': 'Gaming Chair — Black/Orange', 'price': 95000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Ergonomic gaming chair with lumbar support, recline up to 155°, adjustable armrests. Ships within Lagos.', 'seller': {'display_name': 'ComfortGear', 'verification_status': 'verified'}},
];

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> with SingleTickerProviderStateMixin {
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
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _checkAdminRole() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final p = await SupabaseService.client.from('profiles').select('role').eq('id', uid).single();
      final role = p['role'] as String? ?? 'user';
      if (mounted) setState(() => _isAdmin = ['admin', 'super_admin', 'exco'].contains(role));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('products')
          .select('*, seller:profiles!seller_id(display_name, verification_status)')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(40);

      final products = List<Map<String, dynamic>>.from(data);
      if (mounted) setState(() {
        _products = products.isEmpty ? _demoProducts : products;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _products = _demoProducts; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _products.where((p) {
      final matchesSearch = _search.isEmpty ||
          (p['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase());
      final matchesCat = _selectedCategory == 'all' ||
          (p['category'] as String? ?? '') == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  // Show product detail in a bottom sheet — works for both real and demo products
  void _showProductDetail(BuildContext context, Map<String, dynamic> product) {
    final isDemo = (product['id'] as String).startsWith('demo_');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // Drag handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Image placeholder / actual image
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: (product['images'] as List?)?.isNotEmpty == true
                    ? CachedNetworkImage(imageUrl: (product['images'] as List).first, fit: BoxFit.cover)
                    : Container(
                        color: GacomColors.surfaceDark,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.inventory_2_rounded, color: GacomColors.border, size: 60),
                          const SizedBox(height: 8),
                          Text(product['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
                        ]),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Name + price
            Row(children: [
              Expanded(child: Text(product['name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 22))),
              Text('₦${(product['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22)),
            ]),
            const SizedBox(height: 8),

            // Condition + seller
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ((product['condition'] == 'new') ? GacomColors.success : GacomColors.warning).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (product['condition'] as String? ?? 'new').toUpperCase(),
                  style: TextStyle(
                    color: product['condition'] == 'new' ? GacomColors.success : GacomColors.warning,
                    fontSize: 10, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.storefront_rounded, size: 13, color: GacomColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(
                (product['seller'] as Map?)?['display_name'] ?? 'Seller',
                style: const TextStyle(color: GacomColors.textMuted, fontSize: 13),
              )),
              if ((product['seller'] as Map?)?['verification_status'] == 'verified')
                const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange),
            ]),

            const SizedBox(height: 16),
            const Divider(color: GacomColors.border),
            const SizedBox(height: 12),

            // Description
            const Text('Description', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(product['description'] as String? ?? 'No description available.',
                style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.6)),

            const SizedBox(height: 28),

            GacomButton(
              label: isDemo ? 'COMING SOON' : 'CONTACT SELLER',
              onPressed: () {
                Navigator.pop(ctx);
                if (isDemo) {
                  GacomSnackbar.show(context, 'This is a demo listing. Real products coming soon!');
                } else {
                  context.push('/chat');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            title: const Text('STORE'),
            floating: true,
            snap: true,
            backgroundColor: GacomColors.obsidian,
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: GacomColors.deepOrange),
                  onPressed: () => _showListProduct(context),
                  tooltip: 'List a product',
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
        ],
        body: TabBarView(controller: _tab, children: [
          // Browse tab
          Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: GacomColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search marketplace...',
                  hintStyle: const TextStyle(color: GacomColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted),
                  filled: true, fillColor: GacomColors.cardDark, contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border, width: 0.7)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
                ),
              ),
            ),
            // Category chips
            SizedBox(height: 56, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _selectedCategory == c.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c.$1),
                  child: Container(
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
                      Text(c.$2, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                );
              },
            )),
            // Grid
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                : _filtered.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.storefront_rounded, size: 64, color: GacomColors.border),
                        SizedBox(height: 16),
                        Text('No items found', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
                      ]))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _ProductCard(
                          product: _filtered[i],
                          onTap: () => _showProductDetail(context, _filtered[i]),
                        ).animate(delay: (i * 40).ms).fadeIn(),
                      )),
          ]),
          // Orders tab
          const _OrdersTab(),
        ]),
      ),
    );
  }

  void _showListProduct(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String condition = 'new';
    String category = 'accessories';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('List a Product', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 22, color: GacomColors.textPrimary)),
            const SizedBox(height: 16),
            GacomTextField(controller: nameCtrl, label: 'Product Name', hint: 'e.g. Gaming Mouse X7', prefixIcon: Icons.inventory_2_rounded),
            const SizedBox(height: 12),
            GacomTextField(controller: priceCtrl, label: 'Price ₦', hint: '5000', prefixIcon: Icons.attach_money_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            GacomTextField(controller: descCtrl, label: 'Description', hint: 'Describe the product...', prefixIcon: Icons.description_rounded, maxLines: 3),
            const SizedBox(height: 12),
            // Condition chips
            Row(children: ['new', 'used', 'refurbished'].map((c) => GestureDetector(
              onTap: () => setSt(() => condition = c),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: condition == c ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: condition == c ? GacomColors.deepOrange : GacomColors.border),
                ),
                child: Text(c, style: TextStyle(color: condition == c ? GacomColors.deepOrange : GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            )).toList()),
            const SizedBox(height: 20),
            GacomButton(label: 'LIST PRODUCT', onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                GacomSnackbar.show(ctx, 'Name and price required', isError: true);
                return;
              }
              try {
                await SupabaseService.client.from('products').insert({
                  'name': nameCtrl.text.trim(),
                  'price': double.tryParse(priceCtrl.text) ?? 0,
                  'description': descCtrl.text.trim(),
                  'condition': condition,
                  'category': category,
                  'seller_id': SupabaseService.currentUserId,
                  'is_active': true,
                  'images': [],
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  GacomSnackbar.show(context, 'Product listed! 🛍️', isSuccess: true);
                  setState(() => _loading = true);
                  await _load();
                }
              } catch (e) {
                if (ctx.mounted) GacomSnackbar.show(ctx, 'Failed: ${e.toString()}', isError: true);
              }
            }),
          ])),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final condition = product['condition'] as String? ?? 'new';
    final seller = product['seller'] as Map? ?? {};
    final isVerified = seller['verification_status'] == 'verified';

    return GestureDetector(
      onTap: onTap, // FIX: always tappable now
      child: Container(
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: GacomColors.border, width: 0.6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: (condition == 'new' ? GacomColors.success : GacomColors.warning).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(condition[0].toUpperCase() + condition.substring(1), style: TextStyle(color: condition == 'new' ? GacomColors.success : GacomColors.warning, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.storefront_rounded, size: 11, color: GacomColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(seller['display_name'] ?? 'Seller', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))),
              if (isVerified) const Icon(Icons.verified_rounded, size: 11, color: GacomColors.deepOrange),
            ]),
          ])),
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
      const Icon(Icons.inventory_2_rounded, color: GacomColors.border, size: 40),
      const SizedBox(height: 6),
      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: condition == 'new' ? GacomColors.success : GacomColors.warning)),
    ])),
  );
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: SupabaseService.client
          .from('orders')
          .select('*, items:order_items(*, product:products(name, images))')
          .eq('user_id', SupabaseService.currentUserId ?? '')
          .order('created_at', ascending: false)
          .limit(20),
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
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
              child: Row(children: [
                Expanded(child: Text('Order #${(o['id'] as String).substring(0, 8).toUpperCase()}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text((o['status'] as String? ?? '').toUpperCase(), style: const TextStyle(color: GacomColors.info, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}
