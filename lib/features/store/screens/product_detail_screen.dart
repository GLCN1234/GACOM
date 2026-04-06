import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final p = await SupabaseService.client.from('products').select('*, category:product_categories(name), reviews:product_reviews(rating, review, user:profiles!user_id(display_name, avatar_url))').eq('id', widget.productId).single();
      if (mounted) setState(() { _product = p; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _addToCart() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _addingToCart = true);
    try {
      await SupabaseService.client.from('cart_items').upsert({'user_id': userId, 'product_id': widget.productId, 'quantity': _quantity});
      if (mounted) { setState(() { _inCart = true; _addingToCart = false; }); GacomSnackbar.show(context, 'Added to cart!', isSuccess: true); }
    } catch (e) { if (mounted) { setState(() => _addingToCart = false); GacomSnackbar.show(context, 'Failed', isError: true); } }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_product == null) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Text('Product not found.', style: TextStyle(color: GacomColors.textMuted))));

    final p = _product!;
    final images = p['images'] as List? ?? [];
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final comparePrice = (p['compare_price'] as num?)?.toDouble();
    final stock = p['stock'] ?? 0;
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final reviews = p['reviews'] as List? ?? [];

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(p['name'] ?? ''),
        actions: [IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}), IconButton(icon: const Icon(Icons.bookmark_border_outlined), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            if (images.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(imageUrl: images[_selectedImage], fit: BoxFit.cover),
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
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: i == _selectedImage ? GacomColors.deepOrange : GacomColors.border, width: 2)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover)),
                    ),
                  ),
                ),
              ),
            ],

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
                    if (comparePrice != null) ...[const SizedBox(width: 10), Text('₦${comparePrice.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 18, decoration: TextDecoration.lineThrough))],
                  ]),
                  const SizedBox(height: 8),
                  Text(stock > 0 ? 'In Stock ($stock available)' : 'Out of Stock', style: TextStyle(color: stock > 0 ? GacomColors.success : GacomColors.error, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),

                  // Quantity
                  Row(children: [
                    const Text('Quantity:', style: TextStyle(color: GacomColors.textSecondary, fontSize: 15)),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.remove_rounded, size: 18), color: GacomColors.textPrimary, onPressed: () { if (_quantity > 1) setState(() => _quantity--); }),
                        Text('$_quantity', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.add_rounded, size: 18), color: GacomColors.textPrimary, onPressed: () { if (_quantity < stock) setState(() => _quantity++); }),
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

                  Row(children: [
                    Expanded(child: GacomButton(label: _inCart ? 'IN CART ✓' : 'ADD TO CART', isLoading: _addingToCart, isOutlined: _inCart, onPressed: _inCart ? () {} : _addToCart)),
                    const SizedBox(width: 12),
                    GacomButton(label: '', width: 56, icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20), onPressed: () {}),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
