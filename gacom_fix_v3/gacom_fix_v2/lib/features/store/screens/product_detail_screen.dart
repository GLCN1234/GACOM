import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  bool _loading = true;
  int _quantity = 1;
  bool _inCart = false;
  bool _addingToCart = false;
  int _selectedImage = 0;

  double? _deliveryFee;
  String _selectedState = '';
  String _deliveryDays = '';
  List<Map<String, dynamic>> _zones = [];
  bool _loadingZones = false;

  // Cart item count badge
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadZonesAndUserState();
    _loadCartCount();
  }

  Future<void> _loadCartCount() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final items = await SupabaseService.client
          .from('cart_items')
          .select('id')
          .eq('user_id', uid);
      if (mounted) setState(() => _cartCount = (items as List).length);
    } catch (_) {}
  }

  Future<void> _loadZonesAndUserState() async {
    setState(() => _loadingZones = true);
    try {
      final zones = await SupabaseService.client
          .from('delivery_zones')
          .select('state_name, fee, estimated_days')
          .eq('is_active', true)
          .order('state_name');
      _zones = List<Map<String, dynamic>>.from(zones);

      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('location')
              .eq('id', uid)
              .single();
          final loc = profile['location'] as String? ?? '';
          final segments = loc.split(',').map((s) => s.trim()).toList();
          final stateHint = segments.last;
          final match = _zones.firstWhere(
            (z) => (z['state_name'] as String).toLowerCase().contains(stateHint.toLowerCase())
                || stateHint.toLowerCase().contains((z['state_name'] as String).toLowerCase()),
            orElse: () => {},
          );
          if (match.isNotEmpty && mounted) {
            setState(() {
              _selectedState = match['state_name'] as String;
              _deliveryFee = (match['fee'] as num).toDouble();
              _deliveryDays = match['estimated_days'] as String? ?? '';
            });
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingZones = false);
  }

  Future<void> _load() async {
    try {
      final p = await SupabaseService.client
          .from('products')
          .select('*, reviews:product_reviews(rating, review, user:profiles!user_id(display_name, avatar_url))')
          .eq('id', widget.productId)
          .single();
      if (mounted) setState(() { _product = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDeliveryPicker() {
    if (_zones.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Column(children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Row(children: [
              Icon(Icons.local_shipping_rounded, color: GacomColors.info, size: 20),
              SizedBox(width: 10),
              Text('Select Delivery State', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
            ]),
            const SizedBox(height: 4),
            const Text('Delivery fee is calculated by your state', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ])),
          const Divider(color: GacomColors.border, height: 1),
          Expanded(child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _zones.length,
            itemBuilder: (_, i) {
              final z = _zones[i];
              final state = z['state_name'] as String;
              final fee = (z['fee'] as num).toDouble();
              final days = z['estimated_days'] as String? ?? '';
              final isSelected = _selectedState == state;
              return ListTile(
                onTap: () {
                  setState(() { _selectedState = state; _deliveryFee = fee; _deliveryDays = days; });
                  Navigator.pop(context);
                },
                leading: Icon(Icons.location_on_rounded,
                    color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted, size: 18),
                title: Text(state, style: TextStyle(
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14,
                    color: isSelected ? GacomColors.deepOrange : GacomColors.textPrimary)),
                subtitle: Text(days, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('₦${fee.toStringAsFixed(0)}',
                      style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15,
                          color: isSelected ? GacomColors.deepOrange : GacomColors.textSecondary)),
                  if (isSelected) ...[const SizedBox(width: 6), const Icon(Icons.check_circle_rounded, color: GacomColors.deepOrange, size: 16)],
                ]),
              );
            },
          )),
        ]),
      ),
    );
  }

  Future<void> _addToCart() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _addingToCart = true);
    try {
      await SupabaseService.client.from('cart_items').upsert({
        'user_id': userId,
        'product_id': widget.productId,
        'quantity': _quantity,
      });
      if (mounted) {
        setState(() { _inCart = true; _addingToCart = false; _cartCount++; });
        // ✅ Show snackbar with a "Go to Cart" action
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GacomColors.cardDark,
            content: const Text('Added to cart! 🛍️',
                style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
            action: SnackBarAction(
              label: 'VIEW CART',
              textColor: GacomColors.deepOrange,
              onPressed: () => context.push('/store/cart'),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) { setState(() => _addingToCart = false); GacomSnackbar.show(context, 'Failed to add', isError: true); }
    }
  }

  /// ✅ Fix: normalise Supabase storage URLs.
  /// Some versions of supabase-dart return URLs missing /public/ in the path.
  String _fixImageUrl(String url) {
    // Already a valid https URL — return as-is
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // It's a bare storage path — build the full public URL
    return SupabaseService.client.storage
        .from('product-images')
        .getPublicUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_product == null) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Text('Product not found.', style: TextStyle(color: GacomColors.textMuted))));

    final p = _product!;
    // ✅ Fix: normalise every image URL
    final rawImages = (p['images'] as List?)?.cast<String>() ?? [];
    final images = rawImages.map(_fixImageUrl).toList();
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final comparePrice = (p['compare_price'] as num?)?.toDouble();
    final stock = p['stock'] ?? 0;
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final reviews = p['reviews'] as List? ?? [];

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // ✅ Cart icon with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/store/cart'),
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                      color: GacomColors.deepOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$_cartCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            if (images.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: images[_selectedImage],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: GacomColors.surfaceDark,
                    child: const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange, strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: GacomColors.surfaceDark,
                    child: const Center(child: Icon(Icons.image_not_supported_rounded, color: GacomColors.textMuted, size: 48)),
                  ),
                ),
              ),
              if (images.length > 1) SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: images.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _selectedImage = i),
                    child: Container(
                      width: 56, height: 56, margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: i == _selectedImage ? GacomColors.deepOrange : GacomColors.border, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              // No images uploaded — show a themed placeholder
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: GacomColors.surfaceDark,
                  child: const Center(child: Icon(Icons.inventory_2_rounded, color: GacomColors.textMuted, size: 64)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p['brand'] != null) Text(p['brand'], style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(p['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    ...List.generate(5, (i) => Icon(i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded, color: GacomColors.warning, size: 16)),
                    const SizedBox(width: 6),
                    Text('${rating.toStringAsFixed(1)} (${reviews.length})', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 32, fontWeight: FontWeight.w700, color: GacomColors.deepOrange)),
                    if (comparePrice != null) ...[
                      const SizedBox(width: 10),
                      Text('₦${comparePrice.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 18, decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(stock > 0 ? 'In Stock ($stock available)' : 'Out of Stock',
                      style: TextStyle(color: stock > 0 ? GacomColors.success : GacomColors.error, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),

                  // Quantity
                  Row(children: [
                    const Text('Quantity:', style: TextStyle(color: GacomColors.textSecondary, fontSize: 15)),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.remove_rounded, size: 18), color: GacomColors.textPrimary,
                            onPressed: () { if (_quantity > 1) setState(() => _quantity--); }),
                        Text('$_quantity', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.add_rounded, size: 18), color: GacomColors.textPrimary,
                            onPressed: () { if (_quantity < stock) setState(() => _quantity++); }),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  if (p['description'] != null) ...[
                    const Text('Description', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(p['description'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Delivery fee card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GacomColors.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GacomColors.border, width: 0.5),
                    ),
                    child: _loadingZones
                        ? const SizedBox(height: 20, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange))))
                        : GestureDetector(
                            onTap: _zones.isEmpty ? null : _showDeliveryPicker,
                            child: Row(children: [
                              const Icon(Icons.local_shipping_rounded, color: GacomColors.info, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('DELIVERY', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, letterSpacing: 1)),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedState.isEmpty
                                      ? (_zones.isEmpty ? 'Not available' : 'Select your state →')
                                      : _selectedState,
                                  style: TextStyle(
                                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14,
                                    color: _selectedState.isEmpty ? GacomColors.textMuted : GacomColors.textPrimary,
                                  ),
                                ),
                                if (_deliveryDays.isNotEmpty)
                                  Text('Est. $_deliveryDays', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                              ])),
                              if (_deliveryFee != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: GacomColors.info.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: GacomColors.info.withOpacity(0.25)),
                                  ),
                                  child: Text('₦${_deliveryFee!.toStringAsFixed(0)}',
                                      style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.info)),
                                )
                              else if (_zones.isNotEmpty)
                                const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted, size: 18),
                            ]),
                          ),
                  ),

                  // Total
                  if (_deliveryFee != null) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Subtotal', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                      Text('₦${(price * _quantity).toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Delivery', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                      Text('₦${_deliveryFee!.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.info, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                    ]),
                    const Divider(color: GacomColors.border, height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
                      Text('₦${((price * _quantity) + _deliveryFee!).toStringAsFixed(0)}',
                          style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ✅ Two buttons: Add to Cart + Go to Cart
                  Row(children: [
                    Expanded(
                      child: GacomButton(
                        label: _inCart ? 'IN CART ✓' : 'ADD TO CART',
                        isLoading: _addingToCart,
                        isOutlined: _inCart,
                        onPressed: _inCart ? null : _addToCart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GacomButton(
                      label: '',
                      width: 56,
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 20),
                      onPressed: () => context.push('/store/cart'),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
