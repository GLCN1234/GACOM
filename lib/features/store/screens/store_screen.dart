import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

final _demoProducts = <Map<String, dynamic>>[
  {'id': 'demo_1', 'name': 'Gaming Headset Pro X', 'price': 45000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Professional gaming headset with 7.1 surround sound.', 'brand': 'SteelSound', 'seller_name': 'TechVault NG', 'seller_verified': true},
  {'id': 'demo_2', 'name': 'GACOM Limited Hoodie', 'price': 18500.0, 'condition': 'new', 'category': 'apparel', 'images': <String>[], 'is_active': true, 'description': 'Official GACOM branded hoodie. Premium cotton blend.', 'brand': 'GACOM', 'seller_name': 'GACOM Official', 'seller_verified': true},
  {'id': 'demo_3', 'name': 'FC 25 (PS5)', 'price': 32000.0, 'condition': 'new', 'category': 'games', 'images': <String>[], 'is_active': true, 'description': 'FIFA 25 for PlayStation 5. Brand new sealed copy.', 'brand': 'EA Sports', 'seller_name': 'GameZone Lagos', 'seller_verified': false},
  {'id': 'demo_4', 'name': 'RGB Mechanical Keyboard', 'price': 28000.0, 'condition': 'used', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Used but excellent condition. TKL layout, Cherry MX Red switches.', 'brand': 'Corsair', 'seller_name': 'GadgetHub', 'seller_verified': true},
  {'id': 'demo_5', 'name': 'PS5 DualSense Controller', 'price': 52000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Original Sony DualSense wireless controller.', 'brand': 'Sony', 'seller_name': 'PlayHouse NG', 'seller_verified': true},
  {'id': 'demo_6', 'name': 'Gaming Chair — Black/Orange', 'price': 95000.0, 'condition': 'new', 'category': 'accessories', 'images': <String>[], 'is_active': true, 'description': 'Ergonomic gaming chair with lumbar support.', 'brand': 'GamerSeat', 'seller_name': 'ComfortGear', 'seller_verified': true},
];

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> with SingleTickerProviderStateMixin {
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
    // Run sequentially so _isAdmin is set before the first meaningful paint
    _checkAdmin().then((_) => _load());
  }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _checkAdmin() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    // Run both checks in parallel so neither can block the other
    try {
      final results = await Future.wait([
        // Check 1: Is user admin/super_admin in profiles?
        SupabaseService.client
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .single()
            .then((p) {
              final role = p['role'] as String? ?? 'user';
              return ['admin', 'super_admin'].contains(role);
            })
            .catchError((_) => false),

        // Check 2: Is user an inventory_manager in exco_assignments?
        // This works regardless of what role is set in profiles,
        // so even if the profile role update lagged, this still grants access.
        SupabaseService.client
            .from('exco_assignments')
            .select('id')
            .eq('exco_id', uid)
            .eq('exco_role', 'inventory_manager')
            .limit(1)
            .then((rows) => (rows as List).isNotEmpty)
            .catchError((_) => false),
      ]);

      final isAdminRole = results[0] as bool;
      final isInventoryManager = results[1] as bool;

      if (mounted) setState(() => _isAdmin = isAdminRole || isInventoryManager);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client.from('products')
          .select('id, name, description, price, condition, brand, images, tags, is_active, is_featured, rating, stock, category, location, seller:profiles!seller_id(display_name, avatar_url, verification_status)')
          .eq('is_active', true).order('created_at', ascending: false).limit(60);
      final rows = List<Map<String, dynamic>>.from(data);
      if (mounted) setState(() { _allProducts = rows.isNotEmpty ? rows : List.from(_demoProducts); _loading = false; });
    } catch (_) { if (mounted) setState(() { _allProducts = List.from(_demoProducts); _loading = false; }); }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _allProducts;
    if (_selectedCategory != 'all') list = list.where((p) => (p['category'] as String? ?? '') == _selectedCategory).toList();
    if (_search.isNotEmpty) list = list.where((p) => (p['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())).toList();
    return list;
  }

  void _showProductSheet(Map<String, dynamic> product) {
    final isDemo = (product['id'] as String).startsWith('demo_');
    final images = (product['images'] as List?)?.cast<String>() ?? [];
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final condition = product['condition'] as String? ?? 'new';
    final sellerName = product['seller_name'] as String? ?? ((product['seller'] as Map?)?['display_name'] as String?) ?? 'GACOM Store';
    final sellerVerified = product['seller_verified'] as bool? ?? ((product['seller'] as Map?)?['verification_status'] == 'verified');
    final location = product['location'] as String?;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
        builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: AspectRatio(aspectRatio: 16/9,
            child: images.isNotEmpty ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover)
              : Container(color: GacomColors.surfaceDark, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_catIcon(product['category'] as String? ?? ''), color: GacomColors.deepOrange, size: 56), const SizedBox(height: 8),
                  Text(product['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13))])))),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(product['name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 22))),
            const SizedBox(width: 8),
            Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _CondBadge(condition), const SizedBox(width: 10),
            const Icon(Icons.storefront_rounded, size: 13, color: GacomColors.textMuted), const SizedBox(width: 4),
            Expanded(child: Text(sellerName, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13))),
            if (sellerVerified) const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange),
          ]),
          if (location != null) ...[const SizedBox(height: 6), Row(children: [const Icon(Icons.location_on_rounded, size: 13, color: GacomColors.textMuted), const SizedBox(width: 4), Text(location, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))])],
          const SizedBox(height: 16), const Divider(color: GacomColors.border),
          if ((product['brand'] as String?) != null) ...[const SizedBox(height: 8), Row(children: [const Icon(Icons.local_offer_rounded, size: 13, color: GacomColors.textMuted), const SizedBox(width: 6), Text('Brand: ${product['brand']}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))])],
          const SizedBox(height: 12),
          const Text('Description', style: TextStyle(color: GacomColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(product['description'] as String? ?? 'No description available.', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.65)),
          const SizedBox(height: 28),
          if (!isDemo)
            GacomButton(label: 'MESSAGE SELLER', onPressed: () { Navigator.pop(ctx); context.go('/chat'); })
          else
            GacomButton(label: 'COMING SOON — Demo Item', onPressed: () { Navigator.pop(ctx); GacomSnackbar.show(context, 'This is a demo listing!'); }),
        ])));
  }


  void _showDeliveryZonesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _DeliveryZonesSheet(),
    );
  }

  void _showAddProductSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '1');
    String condition = 'new';
    String category = 'accessories';
    List<String> uploadedImageUrls = [];
    bool uploadingImage = false;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => DraggableScrollableSheet(expand: false, initialChildSize: 0.95,
        builder: (_, scroll) => Padding(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: ListView(controller: scroll, children: [
            const Text('Add Product', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
            const SizedBox(height: 20),

            // Image upload
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (file == null) return;
                setModal(() => uploadingImage = true);
                try {
                  final bytes = await file.readAsBytes();
                  final ext = file.name.split('.').last;
                  final path = 'products/${DateTime.now().millisecondsSinceEpoch}.$ext';
                  final url = await SupabaseService.uploadFile(bucket: AppConstants.productImageBucket, path: path, bytes: bytes, contentType: 'image/jpeg');
                  setModal(() { uploadedImageUrls.add(url); uploadingImage = false; });
                } catch (e) { setModal(() => uploadingImage = false); GacomSnackbar.show(ctx, 'Image upload failed', isError: true); }
              },
              child: Container(height: 120, decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, style: BorderStyle.solid)),
                child: uploadingImage ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                  : uploadedImageUrls.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: uploadedImageUrls.first, fit: BoxFit.cover, width: double.infinity))
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, color: GacomColors.deepOrange, size: 32), SizedBox(height: 8), Text('Tap to add product image', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani'))])),
            ),
            const SizedBox(height: 16),

            GacomTextField(controller: nameCtrl, label: 'Product Name *', hint: 'e.g. Gaming Headset Pro', prefixIcon: Icons.inventory_2_rounded),
            const SizedBox(height: 12),
            GacomTextField(controller: brandCtrl, label: 'Brand', hint: 'e.g. Sony, Corsair', prefixIcon: Icons.local_offer_rounded),
            const SizedBox(height: 12),
            GacomTextField(controller: descCtrl, label: 'Description *', hint: 'Describe the product in detail...', prefixIcon: Icons.description_rounded, maxLines: 3),
            const SizedBox(height: 12),
            GacomTextField(controller: priceCtrl, label: 'Price (₦) *', hint: '0', prefixIcon: Icons.attach_money_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            GacomTextField(controller: stockCtrl, label: 'Stock Quantity', hint: '1', prefixIcon: Icons.numbers_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            GacomTextField(controller: locationCtrl, label: 'Location', hint: 'e.g. Lagos, Abuja', prefixIcon: Icons.location_on_rounded),
            const SizedBox(height: 12),
            const SizedBox(height: 4),

            // Category
            const Text('Category', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani', letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: ['accessories', 'apparel', 'games', 'collectibles'].map((c) => GestureDetector(
              onTap: () => setModal(() => category = c),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: category == c ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: category == c ? GacomColors.deepOrange : GacomColors.border)),
                child: Text(c[0].toUpperCase() + c.substring(1), style: TextStyle(color: category == c ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13))))).toList()),
            const SizedBox(height: 14),

            // Condition
            const Text('Condition', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani', letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(children: ['new', 'used', 'refurbished'].map((c) => Expanded(child: GestureDetector(
              onTap: () => setModal(() => condition = c),
              child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: condition == c ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: condition == c ? GacomColors.deepOrange : GacomColors.border)),
                child: Text(c[0].toUpperCase() + c.substring(1), textAlign: TextAlign.center, style: TextStyle(color: condition == c ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)))))).toList()),
            const SizedBox(height: 28),

            SizedBox(width: double.infinity, child: GacomButton(label: 'ADD TO STORE', onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.isEmpty || descCtrl.text.trim().isEmpty) { GacomSnackbar.show(ctx, 'Name, description and price required', isError: true); return; }
              try {
                final uid = SupabaseService.currentUserId;
                final slug = nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-') + '-${DateTime.now().millisecondsSinceEpoch}';
                await SupabaseService.client.from('products').insert({
                  'name': nameCtrl.text.trim(), 'slug': slug,
                  'description': descCtrl.text.trim(),
                  'brand': brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
                  'price': double.tryParse(priceCtrl.text) ?? 0,
                  'condition': condition, 'category': category,
                  'stock': int.tryParse(stockCtrl.text) ?? 1,
                  'is_active': true, 'images': uploadedImageUrls,
                  'seller_id': uid,
                  'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                });
                if (ctx.mounted) { Navigator.pop(ctx); GacomSnackbar.show(context, 'Product added to store! 🛍️', isSuccess: true); await _load(); }
              } catch (e) { if (ctx.mounted) GacomSnackbar.show(ctx, 'Failed: ${e.toString()}', isError: true); }
            })),
          ])))));
  }

  IconData _catIcon(String cat) { switch (cat) { case 'accessories': return Icons.headset_rounded; case 'apparel': return Icons.checkroom_rounded; case 'games': return Icons.sports_esports_rounded; case 'collectibles': return Icons.stars_rounded; default: return Icons.inventory_2_rounded; } }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      // ✅ FIX: Show sell button as a visible FAB for inventory managers + admins
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddProductSheet(context),
              backgroundColor: GacomColors.deepOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Sell Item',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(title: const Text('MARKETPLACE'), actions: [
        if (_isAdmin) ...[
          IconButton(icon: const Icon(Icons.local_shipping_rounded, color: GacomColors.info), tooltip: 'Delivery Zones', onPressed: () => _showDeliveryZonesSheet(context)),
          IconButton(icon: const Icon(Icons.add_circle_rounded, color: GacomColors.deepOrange), tooltip: 'Add Product', onPressed: () => _showAddProductSheet(context)),
        ],
      ], bottom: TabBar(controller: _tab, indicatorColor: GacomColors.deepOrange, labelColor: GacomColors.deepOrange, unselectedLabelColor: GacomColors.textMuted, labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13), tabs: const [Tab(text: 'BROWSE'), Tab(text: 'MY LISTINGS')])),
      body: TabBarView(controller: _tab, children: [
        Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: TextField(onChanged: (v) => setState(() => _search = v), style: const TextStyle(color: GacomColors.textPrimary),
            decoration: InputDecoration(hintText: 'Search marketplace...', hintStyle: const TextStyle(color: GacomColors.textMuted), prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted), filled: true, fillColor: GacomColors.cardDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border))))),
          SizedBox(height: 52, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), itemCount: _categories.length, itemBuilder: (_, i) {
            final (val, label, icon) = _categories[i]; final sel = _selectedCategory == val;
            return GestureDetector(onTap: () => setState(() => _selectedCategory = val), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.cardDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
              child: Row(children: [Icon(icon, size: 14, color: sel ? GacomColors.deepOrange : GacomColors.textMuted), const SizedBox(width: 6), Text(label, style: TextStyle(color: sel ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))])));
          })),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : _filtered.isEmpty ? const Center(child: Text('No products found', style: TextStyle(color: GacomColors.textMuted)))
            : GridView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.7),
                itemCount: _filtered.length, itemBuilder: (_, i) => _ProductCard(product: _filtered[i], onTap: () => _showProductSheet(_filtered[i])))),
        ]),
        _MyListingsTab(isAdmin: _isAdmin, onAddProduct: () => _showAddProductSheet(context)),
      ]),
    );
  }
}

class _MyListingsTab extends ConsumerStatefulWidget {
  final bool isAdmin; final VoidCallback onAddProduct;
  const _MyListingsTab({required this.isAdmin, required this.onAddProduct});
  @override ConsumerState<_MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends ConsumerState<_MyListingsTab> {
  List<Map<String, dynamic>> _listings = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final uid = SupabaseService.currentUserId; if (uid == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final data = await SupabaseService.client.from('products').select('*').eq('seller_id', uid).order('created_at', ascending: false);
      if (mounted) setState(() { _listings = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_listings.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.store_outlined, size: 64, color: GacomColors.border), const SizedBox(height: 16),
      const Text('No listings yet', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: GacomColors.textPrimary, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
      const Text('Add products you want to sell', style: TextStyle(color: GacomColors.textMuted)), const SizedBox(height: 24),
      if (widget.isAdmin) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), icon: const Icon(Icons.add_rounded, color: Colors.white), label: const Text('ADD PRODUCT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)), onPressed: widget.onAddProduct),
    ]));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: _listings.length, itemBuilder: (_, i) {
      final p = _listings[i]; final images = (p['images'] as List?)?.cast<String>() ?? [];
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(width: 56, height: 56, color: GacomColors.surfaceDark, child: images.isNotEmpty ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover) : const Icon(Icons.inventory_2_rounded, color: GacomColors.textMuted))),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 14)), Text('₦${(p['price'] as num?)?.toStringAsFixed(0) ?? '0'} · ${p['condition'] ?? 'new'}', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))])),
          _CondBadge((p['is_active'] as bool? ?? true) ? 'active' : 'inactive'),
        ]));
    });
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product; final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final images = (product['images'] as List?)?.cast<String>() ?? [];
    final condition = product['condition'] as String? ?? 'new';
    final sellerName = product['seller_name'] as String? ?? ((product['seller'] as Map?)?['display_name'] as String?) ?? 'GACOM Store';
    return GestureDetector(onTap: onTap, child: Container(decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: GacomColors.border, width: 0.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: AspectRatio(aspectRatio: 1, child: images.isNotEmpty ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, errorWidget: (_, __, ___) => _PlaceholderImg(condition: condition)) : _PlaceholderImg(condition: condition))),
        Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Row(children: [Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)), const Spacer(), _CondBadge(condition)]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.storefront_rounded, size: 11, color: GacomColors.textMuted), const SizedBox(width: 4), Expanded(child: Text(sellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)))]),
        ])),
      ])));
  }
}

class _PlaceholderImg extends StatelessWidget {
  final String condition; const _PlaceholderImg({required this.condition});
  @override Widget build(BuildContext context) => Container(color: GacomColors.surfaceDark, child: const Center(child: Icon(Icons.inventory_2_rounded, color: GacomColors.textMuted, size: 32)));
}

class _CondBadge extends StatelessWidget {
  final String condition; const _CondBadge(this.condition);
  Color get _color { if (condition == 'new' || condition == 'active') return GacomColors.success; if (condition == 'used' || condition == 'inactive') return GacomColors.warning; return GacomColors.info; }
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: _color.withOpacity(0.3))), child: Text(condition[0].toUpperCase() + condition.substring(1), style: TextStyle(color: _color, fontSize: 9, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)));
}


// ══════════════════════════════════════════════════════════════════════════════
// DELIVERY ZONES MANAGEMENT
// ══════════════════════════════════════════════════════════════════════════════

const List<String> _kNigerianStates = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
  'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu',
  'Abuja (FCT)', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina',
  'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo',
  'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
];

class _DeliveryZonesSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DeliveryZonesSheet> createState() => _DeliveryZonesSheetState();
}

class _DeliveryZonesSheetState extends ConsumerState<_DeliveryZonesSheet> {
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;
  bool _bulkSeeding = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('delivery_zones')
          .select('*')
          .order('state_name');
      if (mounted) {
        setState(() {
          _zones = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveZone(String id, double fee, String days) async {
    try {
      await SupabaseService.client.from('delivery_zones').update({
        'fee': fee,
        'estimated_days': days,
        'updated_by': SupabaseService.currentUserId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      GacomSnackbar.show(context, 'Saved ✅', isSuccess: true);
      await _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Failed: $e', isError: true);
    }
  }

  Future<void> _deleteZone(String id) async {
    try {
      await SupabaseService.client.from('delivery_zones').delete().eq('id', id);
      GacomSnackbar.show(context, 'Zone removed', isSuccess: true);
      await _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Failed: $e', isError: true);
    }
  }

  /// Adds a single new zone row
  void _showAddZoneDialog() {
    // States not yet added
    final existing = _zones.map((z) => z['state_name'] as String).toSet();
    final available = _kNigerianStates.where((s) => !existing.contains(s)).toList();

    String? selectedState = available.isNotEmpty ? available.first : null;
    final feeCtrl = TextEditingController(text: '2000');
    final daysCtrl = TextEditingController(text: '3-5 days');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: GacomColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Delivery Zone',
              style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800,
                  color: GacomColors.textPrimary, fontSize: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // State dropdown
            const Align(alignment: Alignment.centerLeft,
                child: Text('State', style: TextStyle(color: GacomColors.textMuted, fontSize: 11,
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                  color: GacomColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GacomColors.border)),
              child: available.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('All states already added',
                          style: TextStyle(color: GacomColors.textMuted, fontSize: 13)))
                  : DropdownButton<String>(
                      value: selectedState,
                      isExpanded: true,
                      dropdownColor: GacomColors.cardDark,
                      underline: const SizedBox(),
                      style: const TextStyle(color: GacomColors.textPrimary,
                          fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15),
                      items: available.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setDlg(() => selectedState = v),
                    ),
            ),
            const SizedBox(height: 14),
            // Fee field
            const Align(alignment: Alignment.centerLeft,
                child: Text('Delivery Fee (₦)', style: TextStyle(color: GacomColors.textMuted, fontSize: 11,
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: GacomColors.textPrimary,
                  fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: const TextStyle(color: GacomColors.deepOrange,
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
                filled: true, fillColor: GacomColors.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            // Days field
            const Align(alignment: Alignment.centerLeft,
                child: Text('Estimated Delivery Time', style: TextStyle(color: GacomColors.textMuted, fontSize: 11,
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            TextField(
              controller: daysCtrl,
              style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. 3-5 days',
                hintStyle: const TextStyle(color: GacomColors.textMuted),
                filled: true, fillColor: GacomColors.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: GacomColors.deepOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: available.isEmpty || selectedState == null ? null : () async {
                final fee = double.tryParse(feeCtrl.text) ?? 0;
                Navigator.pop(ctx);
                try {
                  await SupabaseService.client.from('delivery_zones').insert({
                    'state_name': selectedState,
                    'fee': fee,
                    'estimated_days': daysCtrl.text.trim().isEmpty ? '3-5 days' : daysCtrl.text.trim(),
                    'is_active': true,
                    'updated_by': SupabaseService.currentUserId,
                  });
                  GacomSnackbar.show(context, '$selectedState added ✅', isSuccess: true);
                  await _load();
                } catch (e) {
                  GacomSnackbar.show(context, 'Failed: $e', isError: true);
                }
              },
              child: const Text('ADD ZONE',
                  style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// Bulk seeds all 37 states that aren't already in the table
  Future<void> _bulkSeedAllStates() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Seed All States?', style: TextStyle(fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
        content: const Text(
          'This will add all 37 Nigerian states with a default fee of ₦2,000. '
          'States already added will be skipped. You can edit each fee individually after.',
          style: TextStyle(color: GacomColors.textSecondary, height: 1.5, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SEED ALL', style: TextStyle(color: Colors.white,
                fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _bulkSeeding = true);
    final existing = _zones.map((z) => z['state_name'] as String).toSet();
    final toInsert = _kNigerianStates.where((s) => !existing.contains(s)).toList();

    if (toInsert.isEmpty) {
      GacomSnackbar.show(context, 'All states already added!', isSuccess: true);
      setState(() => _bulkSeeding = false);
      return;
    }

    try {
      // Insert in batches of 10 to avoid payload limits
      for (int i = 0; i < toInsert.length; i += 10) {
        final batch = toInsert.sublist(i, i + 10 > toInsert.length ? toInsert.length : i + 10);
        await SupabaseService.client.from('delivery_zones').insert(
          batch.map((s) => {
            'state_name': s,
            'fee': 2000,
            'estimated_days': '3-5 days',
            'is_active': true,
            'updated_by': SupabaseService.currentUserId,
          }).toList(),
        );
      }
      GacomSnackbar.show(context, '${toInsert.length} states added ✅', isSuccess: true);
      await _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Seed failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _bulkSeeding = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _zones;
    return _zones
        .where((z) => (z['state_name'] as String)
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      builder: (_, scroll) => Column(children: [

        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: GacomColors.border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(children: [
              Container(padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_shipping_rounded, color: GacomColors.info, size: 22)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Delivery Zones', style: TextStyle(fontFamily: 'Rajdhani',
                    fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
                Text('Manually set fee per state', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              // Bulk seed button
              if (_bulkSeeding)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange))
              else
                TextButton.icon(
                  onPressed: _bulkSeedAllStates,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: GacomColors.warning),
                  label: const Text('Seed All', style: TextStyle(color: GacomColors.warning,
                      fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      backgroundColor: GacomColors.warning.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              const SizedBox(width: 8),
              // Add single zone button
              GestureDetector(
                onTap: _showAddZoneDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: GacomColors.orangeGradient,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Stats row
            if (_zones.isNotEmpty) Row(children: [
              _ZoneChip('${_zones.length} / 37 States', Icons.map_rounded, GacomColors.info),
              const SizedBox(width: 8),
              _ZoneChip(
                'Avg ₦${(_zones.map((z) => (z['fee'] as num).toDouble()).reduce((a, b) => a + b) / _zones.length).toStringAsFixed(0)}',
                Icons.payments_rounded, GacomColors.success,
              ),
            ]),
            if (_zones.isNotEmpty) const SizedBox(height: 10),

            // Search bar
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search state...',
                hintStyle: const TextStyle(color: GacomColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18),
                filled: true, fillColor: GacomColors.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GacomColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 4),
          ]),
        ),

        const Divider(color: GacomColors.border, height: 1),

        // ── Zone list or empty state ───────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
              : _zones.isEmpty
                  // ── Empty state — clearly prompt them to add zones ─────
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                              color: GacomColors.info.withOpacity(0.08), shape: BoxShape.circle,
                              border: Border.all(color: GacomColors.info.withOpacity(0.2))),
                          child: const Icon(Icons.local_shipping_rounded, size: 38, color: GacomColors.info),
                        ),
                        const SizedBox(height: 20),
                        const Text('No delivery zones yet',
                            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700,
                                fontSize: 18, color: GacomColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Add zones manually using the + button above,
or tap "Seed All" to auto-populate all 37 Nigerian states with a default ₦2,000 fee (you can change each one after).',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: GacomColors.textMuted, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 28),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          // Seed all button
                          ElevatedButton.icon(
                            onPressed: _bulkSeedAllStates,
                            icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                            label: const Text('Seed All 37 States',
                                style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: GacomColors.warning,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                          ),
                          const SizedBox(width: 12),
                          // Add single zone
                          OutlinedButton.icon(
                            onPressed: _showAddZoneDialog,
                            icon: const Icon(Icons.add_rounded, size: 16, color: GacomColors.deepOrange),
                            label: const Text('Add One',
                                style: TextStyle(color: GacomColors.deepOrange,
                                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: GacomColors.deepOrange),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                          ),
                        ]),
                      ]),
                    ))
                  : _filtered.isEmpty
                      ? const Center(child: Text('No match found',
                          style: TextStyle(color: GacomColors.textMuted)))
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ZoneTile(
                            zone: _filtered[i],
                            onSave: (fee, days) =>
                                _saveZone(_filtered[i]['id'] as String, fee, days),
                            onDelete: () =>
                                _deleteZone(_filtered[i]['id'] as String),
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ── Small stat chip ───────────────────────────────────────────────────────────
class _ZoneChip extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  const _ZoneChip(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(50), border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 11,
          fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Individual zone row ───────────────────────────────────────────────────────
class _ZoneTile extends StatefulWidget {
  final Map<String, dynamic> zone;
  final Future<void> Function(double fee, String days) onSave;
  final VoidCallback onDelete;
  const _ZoneTile({required this.zone, required this.onSave, required this.onDelete});
  @override State<_ZoneTile> createState() => _ZoneTileState();
}

class _ZoneTileState extends State<_ZoneTile> {
  bool _editing = false;
  late TextEditingController _feeCtrl;
  late TextEditingController _daysCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _feeCtrl = TextEditingController(
        text: (widget.zone['fee'] as num).toStringAsFixed(0));
    _daysCtrl = TextEditingController(
        text: widget.zone['estimated_days'] as String? ?? '3-5 days');
  }

  @override
  void dispose() { _feeCtrl.dispose(); _daysCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fee = (widget.zone['fee'] as num).toDouble();
    final state = widget.zone['state_name'] as String;
    final days = widget.zone['estimated_days'] as String? ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _editing ? GacomColors.deepOrange.withOpacity(0.04) : GacomColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _editing ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border,
            width: _editing ? 1.3 : 0.5),
      ),
      child: _editing
          // ── EDIT MODE ─────────────────────────────────────────────────────
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: GacomColors.deepOrange),
                const SizedBox(width: 6),
                Text(state, style: const TextStyle(fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _editing = false),
                  child: const Icon(Icons.close_rounded, color: GacomColors.textMuted, size: 18),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                // Fee input
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Delivery Fee (₦)', style: TextStyle(color: GacomColors.textMuted,
                      fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _feeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: GacomColors.textPrimary,
                        fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20),
                    decoration: InputDecoration(
                      prefixText: '₦ ',
                      prefixStyle: const TextStyle(color: GacomColors.deepOrange,
                          fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18),
                      filled: true, fillColor: GacomColors.surfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GacomColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GacomColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ])),
                const SizedBox(width: 12),
                // Delivery days input
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Est. Delivery', style: TextStyle(color: GacomColors.textMuted,
                      fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _daysCtrl,
                    style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '3-5 days',
                      hintStyle: const TextStyle(color: GacomColors.textMuted),
                      filled: true, fillColor: GacomColors.surfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GacomColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GacomColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                // Delete button
                GestureDetector(
                  onTap: () async {
                    setState(() => _editing = false);
                    widget.onDelete();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: GacomColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GacomColors.error.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.delete_outline_rounded, size: 16, color: GacomColors.error),
                      SizedBox(width: 6),
                      Text('Remove', style: TextStyle(color: GacomColors.error,
                          fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                ),
                const Spacer(),
                // Save button
                GestureDetector(
                  onTap: _saving ? null : () async {
                    final fee = double.tryParse(_feeCtrl.text);
                    if (fee == null) return;
                    setState(() => _saving = true);
                    await widget.onSave(fee, _daysCtrl.text.trim().isEmpty
                        ? '3-5 days' : _daysCtrl.text.trim());
                    if (mounted) setState(() { _saving = false; _editing = false; });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                        gradient: GacomColors.orangeGradient,
                        borderRadius: BorderRadius.circular(10)),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('SAVE', style: TextStyle(color: Colors.white,
                            fontFamily: 'Rajdhani', fontWeight: FontWeight.w800,
                            fontSize: 15, letterSpacing: 1)),
                  ),
                ),
              ]),
            ])

          // ── VIEW MODE ─────────────────────────────────────────────────────
          : GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Row(children: [
                Container(width: 42, height: 42,
                    decoration: BoxDecoration(color: GacomColors.surfaceDark,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Icon(Icons.location_on_rounded,
                        size: 20, color: GacomColors.textMuted))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(state, style: const TextStyle(fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
                  Text(days.isNotEmpty ? days : 'No estimate set',
                      style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ])),
                Text('₦${fee.toStringAsFixed(0)}',
                    style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800,
                        fontSize: 18, color: GacomColors.deepOrange)),
                const SizedBox(width: 6),
                const Icon(Icons.edit_rounded, color: GacomColors.textMuted, size: 15),
              ]),
            ),
    );
  }
}
