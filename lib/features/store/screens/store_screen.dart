import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _selectedCategory;
  int _cartCount = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final cats = await SupabaseService.client.from('product_categories').select('*').order('display_order');
      final prods = await SupabaseService.client.from('products').select('*, category:product_categories(name)').eq('is_active', true).order('is_featured', ascending: false).order('sales_count', ascending: false).limit(40);
      final userId = SupabaseService.currentUserId;
      int cartCount = 0;
      if (userId != null) {
        final cart = await SupabaseService.client.from('cart_items').select('id').eq('user_id', userId);
        cartCount = cart.length;
      }
      if (mounted) setState(() { _categories = List<Map<String, dynamic>>.from(cats); _products = List<Map<String, dynamic>>.from(prods); _cartCount = cartCount; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == null) return _products;
    return _products.where((p) => (p['category'] as Map?)?['name'] == _selectedCategory).toList();
  }

  Future<void> _addToCart(String productId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.client.from('cart_items').upsert({'user_id': userId, 'product_id': productId, 'quantity': 1});
      if (mounted) { setState(() => _cartCount++); GacomSnackbar.show(context, 'Added to cart!', isSuccess: true); }
    } catch (e) { if (mounted) GacomSnackbar.show(context, 'Failed to add to cart', isError: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('GACOM STORE'),
        actions: [
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.shopping_bag_outlined), onPressed: () {}),
              if (_cartCount > 0) Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: GacomColors.deepOrange, shape: BoxShape.circle), child: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : Column(
              children: [
                // Categories
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _categories.length + 1,
                    itemBuilder: (_, i) {
                      final isAll = i == 0;
                      final cat = isAll ? null : _categories[i - 1];
                      final isSelected = isAll ? _selectedCategory == null : _selectedCategory == cat?['name'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = isAll ? null : cat?['name']),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? GacomColors.deepOrange : GacomColors.cardDark,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: isSelected ? GacomColors.deepOrange : GacomColors.border),
                          ),
                          child: Text(isAll ? 'All' : cat?['name'] ?? '', style: TextStyle(color: isSelected ? Colors.white : GacomColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Rajdhani')),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _ProductCard(product: _filtered[i], onAddToCart: () => _addToCart(_filtered[i]['id'])).animate(delay: (i * 50).ms).fadeIn().scale(begin: const Offset(0.9, 0.9)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onAddToCart;
  const _ProductCard({required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final comparePrice = (product['compare_price'] as num?)?.toDouble();
    final images = product['images'] as List? ?? [];
    final isFeatured = product['is_featured'] == true;
    final rating = (product['rating'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () => context.go('/store/product/${product['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isFeatured ? GacomColors.deepOrange.withOpacity(0.4) : GacomColors.border, width: isFeatured ? 1.5 : 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: images.isNotEmpty
                        ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, width: double.infinity)
                        : Container(decoration: const BoxDecoration(color: GacomColors.surfaceDark), child: const Icon(Icons.image_outlined, color: GacomColors.border, size: 48)),
                  ),
                  if (isFeatured) Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(50)), child: const Text('HOT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')))),
                  if (comparePrice != null) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: GacomColors.error, borderRadius: BorderRadius.circular(50)), child: Text('${(((comparePrice - price) / comparePrice) * 100).toStringAsFixed(0)}% OFF', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (rating > 0) Row(children: [const Icon(Icons.star_rounded, color: GacomColors.warning, size: 12), const SizedBox(width: 2), Text(rating.toStringAsFixed(1), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))]),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, color: GacomColors.deepOrange)),
                        if (comparePrice != null) Text('₦${comparePrice.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, decoration: TextDecoration.lineThrough)),
                      ])),
                      GestureDetector(
                        onTap: onAddToCart,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(gradient: GacomColors.orangeGradient, shape: BoxShape.circle),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
