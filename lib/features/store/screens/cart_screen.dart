import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _placingOrder = false;

  // Delivery
  String _selectedState = '';
  double? _deliveryFee;
  String _deliveryDays = '';
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadZones();
  }

  Future<void> _loadCart() async {
    setState(() => _loading = true);
    final uid = SupabaseService.currentUserId;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final data = await SupabaseService.client
          .from('cart_items')
          .select('id, quantity, product:products(id, name, price, images, stock, condition, seller_id)')
          .eq('user_id', uid);
      if (mounted) setState(() { _items = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadZones() async {
    try {
      final data = await SupabaseService.client
          .from('delivery_zones')
          .select('state_name, fee, estimated_days')
          .eq('is_active', true)
          .order('state_name');
      final zones = List<Map<String, dynamic>>.from(data);
      if (!mounted) return;
      setState(() => _zones = zones);

      // Auto-select state from user profile
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        try {
          final profile = await SupabaseService.client
              .from('profiles').select('location').eq('id', uid).single();
          final loc = profile['location'] as String? ?? '';
          final segments = loc.split(',').map((s) => s.trim()).toList();
          final hint = segments.last;
          final match = zones.firstWhere(
            (z) => (z['state_name'] as String).toLowerCase().contains(hint.toLowerCase())
                || hint.toLowerCase().contains((z['state_name'] as String).toLowerCase()),
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
  }

  Future<void> _updateQty(String cartItemId, String productId, int newQty) async {
    if (newQty < 1) { await _removeItem(cartItemId); return; }
    try {
      await SupabaseService.client.from('cart_items')
          .update({'quantity': newQty}).eq('id', cartItemId);
      await _loadCart();
    } catch (_) {}
  }

  Future<void> _removeItem(String cartItemId) async {
    try {
      await SupabaseService.client.from('cart_items').delete().eq('id', cartItemId);
      await _loadCart();
    } catch (_) {}
  }

  Future<void> _clearCart() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    await SupabaseService.client.from('cart_items').delete().eq('user_id', uid);
  }

  void _showDeliveryPicker() {
    if (_zones.isEmpty) {
      GacomSnackbar.show(context, 'No delivery zones set up yet');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Row(children: [
                Icon(Icons.local_shipping_rounded, color: GacomColors.info, size: 20),
                SizedBox(width: 10),
                Text('Select Delivery State', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
              ]),
            ]),
          ),
          const Divider(color: GacomColors.border, height: 1),
          Expanded(child: ListView.builder(
            controller: scroll,
            itemCount: _zones.length,
            itemBuilder: (_, i) {
              final z = _zones[i];
              final state = z['state_name'] as String;
              final fee = (z['fee'] as num).toDouble();
              final days = z['estimated_days'] as String? ?? '';
              final sel = _selectedState == state;
              return ListTile(
                onTap: () {
                  setState(() { _selectedState = state; _deliveryFee = fee; _deliveryDays = days; });
                  Navigator.pop(context);
                },
                leading: Icon(Icons.location_on_rounded,
                    color: sel ? GacomColors.deepOrange : GacomColors.textMuted, size: 18),
                title: Text(state, style: TextStyle(
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14,
                    color: sel ? GacomColors.deepOrange : GacomColors.textPrimary)),
                subtitle: Text(days, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('₦${fee.toStringAsFixed(0)}',
                      style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800,
                          fontSize: 15, color: sel ? GacomColors.deepOrange : GacomColors.textSecondary)),
                  if (sel) ...[const SizedBox(width: 6), const Icon(Icons.check_circle_rounded, color: GacomColors.deepOrange, size: 16)],
                ]),
              );
            },
          )),
        ]),
      ),
    );
  }

  double get _subtotal => _items.fold(0.0, (sum, item) {
    final product = item['product'] as Map<String, dynamic>? ?? {};
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final qty = item['quantity'] as int? ?? 1;
    return sum + price * qty;
  });

  double get _total => _subtotal + (_deliveryFee ?? 0);

  Future<void> _checkout() async {
    if (_items.isEmpty) return;
    if (_selectedState.isEmpty || _deliveryFee == null) {
      GacomSnackbar.show(context, 'Please select your delivery state', isError: true);
      return;
    }

    setState(() => _placingOrder = true);
    final uid = SupabaseService.currentUserId;
    final email = SupabaseService.currentUser?.email ?? '';
    if (uid == null) { setState(() => _placingOrder = false); return; }

    try {
      final reference = 'GACOM_${const Uuid().v4().substring(0, 10).toUpperCase()}';
      final totalKobo = (_total * 100).toInt();

      // 1 — Create order record in DB
      final orderItems = _items.map((item) {
        final p = item['product'] as Map<String, dynamic>? ?? {};
        final price = (p['price'] as num?)?.toDouble() ?? 0;
        final qty = item['quantity'] as int? ?? 1;
        return {
          'product_id': p['id'],
          'quantity': qty,
          'unit_price': price,
          'total_price': price * qty,
        };
      }).toList();

      await SupabaseService.client.from('orders').insert({
        'user_id': uid,
        'reference': reference,
        'status': 'pending',
        'subtotal': _subtotal,
        'delivery_fee': _deliveryFee,
        'total': _total,
        'delivery_state': _selectedState,
        'delivery_days': _deliveryDays,
        'items': orderItems,
      });

      // 2 — Launch Paystack hosted checkout
      final paystackUrl = Uri.parse(
        'https://paystack.com/pay/${AppConstants.paystackPublicKey}'
        '?email=${Uri.encodeComponent(email)}'
        '&amount=$totalKobo'
        '&reference=$reference'
        '&callback_url=https://gacom.netlify.app/store',
      );

      if (await canLaunchUrl(paystackUrl)) {
        await launchUrl(paystackUrl, mode: LaunchMode.externalApplication);
        // 3 — Clear cart after launching payment
        await _clearCart();
        if (mounted) {
          GacomSnackbar.show(context, 'Complete payment in Paystack. Your order is saved!', isSuccess: true);
          await _loadCart();
        }
      } else {
        GacomSnackbar.show(context, 'Could not open Paystack. Try again.', isError: true);
      }
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Order failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('MY CART'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: GacomColors.cardDark,
                    title: const Text('Clear Cart?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                    content: const Text('Remove all items from cart?', style: TextStyle(color: GacomColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLEAR', style: TextStyle(color: GacomColors.error, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
                if (ok == true) { await _clearCart(); await _loadCart(); }
              },
              child: const Text('CLEAR', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _items.isEmpty
              ? _buildEmptyCart()
              : Column(children: [
                  Expanded(child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _CartItem(
                      item: _items[i],
                      onQtyChanged: (newQty) => _updateQty(
                        _items[i]['id'] as String,
                        (_items[i]['product'] as Map)['id'] as String,
                        newQty,
                      ),
                      onRemove: () => _removeItem(_items[i]['id'] as String),
                    ),
                  )),
                  _buildCheckoutPanel(),
                ]),
    );
  }

  Widget _buildEmptyCart() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.shopping_cart_outlined, size: 72, color: GacomColors.border),
      const SizedBox(height: 16),
      const Text('Your cart is empty', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Browse the marketplace and add items', style: TextStyle(color: GacomColors.textMuted, fontSize: 14)),
      const SizedBox(height: 28),
      GacomButton(label: 'SHOP NOW', onPressed: () => context.go(AppConstants.storeRoute)),
    ]),
  );

  Widget _buildCheckoutPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: GacomColors.cardDark,
        border: Border(top: BorderSide(color: GacomColors.border, width: 0.7)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Delivery state picker
        GestureDetector(
          onTap: _showDeliveryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: GacomColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selectedState.isEmpty ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border),
            ),
            child: Row(children: [
              Icon(Icons.local_shipping_rounded,
                  color: _selectedState.isEmpty ? GacomColors.deepOrange : GacomColors.info, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DELIVERY TO', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, letterSpacing: 1)),
                Text(
                  _selectedState.isEmpty ? 'Tap to select your state →' : _selectedState,
                  style: TextStyle(
                    fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14,
                    color: _selectedState.isEmpty ? GacomColors.deepOrange : GacomColors.textPrimary,
                  ),
                ),
                if (_deliveryDays.isNotEmpty)
                  Text('Est. $_deliveryDays', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ])),
              if (_deliveryFee != null)
                Text('₦${_deliveryFee!.toStringAsFixed(0)}',
                    style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.info))
              else
                const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
            ]),
          ),
        ),

        // Pricing breakdown
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Subtotal', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          Text('₦${_subtotal.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Delivery', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          Text(
            _deliveryFee != null ? '₦${_deliveryFee!.toStringAsFixed(0)}' : '— select state',
            style: TextStyle(color: _deliveryFee != null ? GacomColors.info : GacomColors.textMuted, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600),
          ),
        ]),
        const Divider(color: GacomColors.border, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
          Text('₦${_total.toStringAsFixed(0)}',
              style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22)),
        ]),
        const SizedBox(height: 16),

        // Pay button
        GacomButton(
          label: 'PAY WITH PAYSTACK  ₦${_total.toStringAsFixed(0)}',
          isLoading: _placingOrder,
          onPressed: _checkout,
          icon: const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 8),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.verified_user_rounded, size: 12, color: GacomColors.success),
          SizedBox(width: 5),
          Text('Secured by Paystack', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ── Single cart item row ───────────────────────────────────────────────────────
class _CartItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(int) onQtyChanged;
  final VoidCallback onRemove;
  const _CartItem({required this.item, required this.onQtyChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final product = item['product'] as Map<String, dynamic>? ?? {};
    final name = product['name'] as String? ?? 'Unknown Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final qty = item['quantity'] as int? ?? 1;
    final images = (product['images'] as List?)?.cast<String>() ?? [];
    final imageUrl = images.isNotEmpty ? images.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GacomColors.border, width: 0.5),
      ),
      child: Row(children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 70, height: 70,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: GacomColors.surfaceDark,
                        child: const Center(child: SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange)))),
                    errorWidget: (_, __, ___) => Container(color: GacomColors.surfaceDark,
                        child: const Icon(Icons.inventory_2_rounded, color: GacomColors.textMuted)),
                  )
                : Container(color: GacomColors.surfaceDark,
                    child: const Icon(Icons.inventory_2_rounded, color: GacomColors.textMuted)),
          ),
        ),
        const SizedBox(width: 12),

        // Details
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('₦${price.toStringAsFixed(0)}',
              style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          // Qty stepper
          Row(children: [
            _QtyBtn(icon: Icons.remove_rounded, onTap: () => onQtyChanged(qty - 1)),
            const SizedBox(width: 10),
            Text('$qty', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 10),
            _QtyBtn(icon: Icons.add_rounded, onTap: () => onQtyChanged(qty + 1)),
          ]),
        ])),

        // Line total + remove
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₦${(price * qty).toStringAsFixed(0)}',
              style: const TextStyle(color: GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: GacomColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GacomColors.error.withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 16, color: GacomColors.error),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: GacomColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GacomColors.border),
      ),
      child: Icon(icon, size: 16, color: GacomColors.textPrimary),
    ),
  );
}
