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
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _checkAdmin(); _load(); }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _checkAdmin() async {
    final uid = SupabaseService.currentUserId; if (uid == null) return;
    try {
      final p = await SupabaseService.client.from('profiles').select('role').eq('id', uid).single();
      if (mounted) setState(() => _isAdmin = ['admin', 'super_admin'].contains(p['role'] as String? ?? ''));
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client.from('products')
          .select('id, name, description, price, condition, brand, images, tags, is_active, is_featured, rating, stock, category, whatsapp_contact, location, seller:profiles!seller_id(display_name, avatar_url, verification_status)')
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
    final whatsapp = product['whatsapp_contact'] as String?;
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
          if (!isDemo && whatsapp != null)
            GacomButton(label: '📱 CONTACT VIA WHATSAPP', onPressed: () { Navigator.pop(ctx); GacomSnackbar.show(context, 'Opening WhatsApp...'); })
          else if (!isDemo)
            GacomButton(label: 'MESSAGE SELLER', onPressed: () { Navigator.pop(ctx); context.go('/chat'); })
          else
            GacomButton(label: 'COMING SOON — Demo Item', onPressed: () { Navigator.pop(ctx); GacomSnackbar.show(context, 'This is a demo listing!'); }),
        ])));
  }

  void _showAddProductSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final whatsappCtrl = TextEditingController();
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
            GacomTextField(controller: whatsappCtrl, label: 'WhatsApp Number', hint: '+234 800 000 0000', prefixIcon: Icons.phone_rounded, keyboardType: TextInputType.phone),
            const SizedBox(height: 14),

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
                  'whatsapp_contact': whatsappCtrl.text.trim().isEmpty ? null : whatsappCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('MARKETPLACE'), actions: [
        if (_isAdmin) IconButton(icon: const Icon(Icons.add_circle_rounded, color: GacomColors.deepOrange), tooltip: 'Add Product', onPressed: () => _showAddProductSheet(context)),
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
