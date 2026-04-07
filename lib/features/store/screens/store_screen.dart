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
    _load();
  }

  Future<void> _load() async {
    try {
      var q = SupabaseService.client
          .from('products')
          .select(
              '*, seller:profiles!seller_id(display_name, avatar_url, verification_status)')
          .eq('is_available', true);
      if (_selectedCategory != 'all') {
        q = q.eq('category', _selectedCategory) as dynamic;
      }
      if (_search.isNotEmpty) {
        q = q.ilike('name', '%$_search%') as dynamic;
      }
      final data = await (q as dynamic)
          .order('created_at', ascending: false)
          .limit(40);
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('MARKETPLACE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: GacomColors.deepOrange),
            tooltip: 'List Item',
            onPressed: () => _showListItemSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'BROWSE'), Tab(text: 'MY LISTINGS')],
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
            search: _search,
            onCategoryChange: (c) {
              setState(() {
                _selectedCategory = c;
                _loading = true;
              });
              _load();
            },
            onSearch: (s) {
              setState(() {
                _search = s;
                _loading = true;
              });
              _load();
            },
          ),
          _MyListingsTab(onRefresh: _load),
        ],
      ),
    );
  }

  void _showListItemSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
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
          initialChildSize: 0.85,
          builder: (_, scroll) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: ListView(controller: scroll, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: GacomColors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.storefront_rounded,
                      color: GacomColors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Text('List an Item',
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GacomColors.textPrimary)),
              ]),
              const SizedBox(height: 20),
              GacomTextField(
                  controller: nameCtrl,
                  label: 'Item Name',
                  hint: 'e.g. Gaming Headset',
                  prefixIcon: Icons.inventory_2_rounded),
              const SizedBox(height: 12),
              GacomTextField(
                  controller: descCtrl,
                  label: 'Description',
                  hint: 'Describe your item...',
                  prefixIcon: Icons.description_rounded,
                  maxLines: 3),
              const SizedBox(height: 12),
              GacomTextField(
                  controller: priceCtrl,
                  label: 'Price (₦)',
                  hint: '0',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              const Text('Condition',
                  style: TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                for (final c in ['new', 'used', 'refurbished'])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => condition = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: condition == c
                                ? GacomColors.deepOrange.withOpacity(0.15)
                                : GacomColors.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: condition == c
                                    ? GacomColors.deepOrange
                                    : GacomColors.border)),
                        child: Text(
                            c[0].toUpperCase() + c.substring(1),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: condition == c
                                    ? GacomColors.deepOrange
                                    : GacomColors.textMuted,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 24),
              GacomButton(
                label: 'LIST ITEM',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      priceCtrl.text.isEmpty) {
                    GacomSnackbar.show(ctx, 'Name and price required',
                        isError: true);
                    return;
                  }
                  try {
                    await SupabaseService.client.from('products').insert({
                      'seller_id': SupabaseService.currentUserId,
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'price': double.tryParse(priceCtrl.text) ?? 0,
                      'condition': condition,
                      'is_available': true,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      GacomSnackbar.show(
                          context, 'Item listed! 🛍️',
                          isSuccess: true);
                      setState(() => _loading = true);
                      await _load();
                    }
                  } catch (_) {
                    GacomSnackbar.show(ctx, 'Failed to list item',
                        isError: true);
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BrowseTab extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool loading;
  final List<(String, String, IconData)> categories;
  final String selectedCategory;
  final String search;
  final void Function(String) onCategoryChange;
  final void Function(String) onSearch;

  const _BrowseTab({
    required this.products,
    required this.loading,
    required this.categories,
    required this.selectedCategory,
    required this.search,
    required this.onCategoryChange,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          onChanged: onSearch,
          style: const TextStyle(color: GacomColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search marketplace...',
            hintStyle:
                const TextStyle(color: GacomColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded,
                color: GacomColors.textMuted),
            filled: true,
            fillColor: GacomColors.cardDark,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: GacomColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: GacomColors.border)),
          ),
        ),
      ),
      // Category filter
      SizedBox(
        height: 56,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final c = categories[i];
            final isSel = selectedCategory == c.$1;
            return GestureDetector(
              onTap: () => onCategoryChange(c.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: isSel
                        ? GacomColors.deepOrange.withOpacity(0.15)
                        : GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                        color: isSel
                            ? GacomColors.deepOrange
                            : GacomColors.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(c.$3,
                      size: 14,
                      color: isSel
                          ? GacomColors.deepOrange
                          : GacomColors.textMuted),
                  const SizedBox(width: 6),
                  Text(c.$2,
                      style: TextStyle(
                          color: isSel
                              ? GacomColors.deepOrange
                              : GacomColors.textMuted,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
              ),
            );
          },
        ),
      ),
      Expanded(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: GacomColors.deepOrange))
            : products.isEmpty
                ? const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.storefront_rounded,
                          size: 64, color: GacomColors.border),
                      SizedBox(height: 16),
                      Text('No items found',
                          style: TextStyle(
                              color: GacomColors.textMuted,
                              fontSize: 16)),
                    ]))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72),
                    itemCount: products.length,
                    itemBuilder: (_, i) =>
                        _ProductCard(product: products[i])
                            .animate(delay: (i * 40).ms)
                            .fadeIn(),
                  ),
      ),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final condition = product['condition'] as String? ?? 'new';
    final seller = product['seller'] as Map? ?? {};
    final isVerified =
        seller['verification_status'] == 'verified';

    return GestureDetector(
      onTap: () => context.push('/store/product/${product['id']}'),
      child: Container(
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 1,
              child: images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: images.first,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _ProductPlaceholder(condition: condition))
                  : _ProductPlaceholder(condition: condition),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(product['name'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₦${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: GacomColors.deepOrange,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: (condition == 'new'
                              ? GacomColors.success
                              : GacomColors.warning)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(
                      condition[0].toUpperCase() +
                          condition.substring(1),
                      style: TextStyle(
                          color: condition == 'new'
                              ? GacomColors.success
                              : GacomColors.warning,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.storefront_rounded,
                    size: 11, color: GacomColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(
                        seller['display_name'] ?? 'Seller',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: GacomColors.textMuted,
                            fontSize: 11))),
                if (isVerified)
                  const Icon(Icons.verified_rounded,
                      size: 11, color: GacomColors.deepOrange),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  final String condition;
  const _ProductPlaceholder({required this.condition});
  @override
  Widget build(BuildContext context) => Container(
        color: GacomColors.surfaceDark,
        child: const Icon(Icons.inventory_2_rounded,
            color: GacomColors.border, size: 48),
      );
}

class _MyListingsTab extends ConsumerStatefulWidget {
  final VoidCallback onRefresh;
  const _MyListingsTab({required this.onRefresh});
  @override
  ConsumerState<_MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends ConsumerState<_MyListingsTab> {
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final data = await SupabaseService.client
          .from('products')
          .select('*')
          .eq('seller_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _listings = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child:
              CircularProgressIndicator(color: GacomColors.deepOrange));
    }
    if (_listings.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.inventory_2_rounded,
                size: 64, color: GacomColors.border),
            const SizedBox(height: 16),
            const Text('No listings yet',
                style: TextStyle(
                    color: GacomColors.textMuted, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Tap + to list your first item',
                style: TextStyle(
                    color: GacomColors.textMuted, fontSize: 13)),
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _listings.length,
      itemBuilder: (_, i) {
        final p = _listings[i];
        final available = p['is_available'] as bool? ?? true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text(p['name'] ?? '',
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              Text('₦${p['price']}',
                  style: const TextStyle(
                      color: GacomColors.deepOrange,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700)),
            ])),
            Switch(
              value: available,
              activeColor: GacomColors.deepOrange,
              onChanged: (v) async {
                await SupabaseService.client
                    .from('products')
                    .update({'is_available': v}).eq('id', p['id']);
                await _load();
              },
            ),
          ]),
        );
      },
    );
  }
}
