import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// Three jobs: manage every product (edit price/details, delete, spot
/// low-confidence AI pricing), assign staff their specific permission,
/// and manage delivery fees per state — all three genuinely reachable
/// from here, not buried in a different screen.
class StoreAdminScreen extends StatefulWidget {
  const StoreAdminScreen({super.key});
  @override
  State<StoreAdminScreen> createState() => _StoreAdminScreenState();
}

class _StoreAdminScreenState extends State<StoreAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); _load(); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await SupabaseService.client.from('products')
          .select('id, name, description, price, source_price, source_url, category, price_confidence, is_active, created_at')
          .order('created_at', ascending: false);
      final staff = await SupabaseService.client.from('store_staff_roles')
          .select('user_id, can_add_products, can_manage_orders').order('created_at', ascending: false);
      final zones = await SupabaseService.client.from('delivery_zones').select('*').order('state_name');
      if (mounted) setState(() {
        _products = List<Map<String, dynamic>>.from(products);
        _staff = List<Map<String, dynamic>>.from(staff);
        _zones = List<Map<String, dynamic>>.from(zones);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _deleteProduct(String id) async {
    try {
      await SupabaseService.client.from('products').update({'is_active': false}).eq('id', id);
      if (mounted) GacomSnackbar.show(context, 'Product removed', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not remove: $e', isError: true);
    }
  }

  Future<void> _saveProductEdit(String id, {required String name, required int price, required String description}) async {
    try {
      await SupabaseService.client.from('products').update({
        'name': name, 'price': price, 'description': description, 'price_confidence': 'high',
      }).eq('id', id);
      if (mounted) { Navigator.pop(context); GacomSnackbar.show(context, 'Product updated', isSuccess: true); }
      _load();
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not save: $e', isError: true);
    }
  }

  void _openEditDialog(Map<String, dynamic> p) {
    final nameCtrl = TextEditingController(text: p['name'] as String? ?? '');
    final priceCtrl = TextEditingController(text: '${p['price'] ?? ''}');
    final descCtrl = TextEditingController(text: p['description'] as String? ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit product', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: GacomColors.textMuted))),
        const SizedBox(height: 10),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Price (₦)', labelStyle: TextStyle(color: GacomColors.textMuted))),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, maxLines: 3, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: GacomColors.textMuted))),
        if (p['source_price'] != null) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text('AI found source price: ₦${p['source_price']} — verify against the real site before trusting it.',
            style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(
          onPressed: () {
            final price = int.tryParse(priceCtrl.text.trim()) ?? (p['price'] as num?)?.toInt() ?? 0;
            _saveProductEdit(p['id'] as String, name: nameCtrl.text.trim(), price: price, description: descCtrl.text.trim());
          },
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
          child: const Text('SAVE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
        ),
      ],
    ));
  }

  Future<void> _addStaffByEmail(String email, {required bool canAdd, required bool canManage}) async {
    try {
      final res = await SupabaseService.client.rpc('get_user_id_by_email', params: {'p_email': email});
      final uid = res as String?;
      if (uid == null) {
        if (mounted) GacomSnackbar.show(context, 'No user found with that email', isError: true);
        return;
      }
      await SupabaseService.client.from('store_staff_roles').upsert({
        'user_id': uid, 'can_add_products': canAdd, 'can_manage_orders': canManage,
      });
      _load();
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Failed: $e', isError: true);
    }
  }

  Future<void> _saveZone(String state, int fee, int days, {String? existingId}) async {
    try {
      if (existingId != null) {
        await SupabaseService.client.from('delivery_zones').update({'fee': fee, 'estimated_days': days, 'updated_by': SupabaseService.currentUserId}).eq('id', existingId);
      } else {
        await SupabaseService.client.from('delivery_zones').insert({'state_name': state, 'fee': fee, 'estimated_days': days, 'updated_by': SupabaseService.currentUserId});
      }
      if (mounted) { Navigator.pop(context); GacomSnackbar.show(context, 'Delivery zone saved', isSuccess: true); }
      _load();
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not save zone: $e', isError: true);
    }
  }

  Future<void> _deleteZone(String id) async {
    try {
      await SupabaseService.client.from('delivery_zones').delete().eq('id', id);
      if (mounted) GacomSnackbar.show(context, 'Zone removed', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not remove zone: $e', isError: true);
    }
  }

  void _openZoneDialog({Map<String, dynamic>? existing}) {
    final stateCtrl = TextEditingController(text: existing?['state_name'] as String? ?? '');
    final feeCtrl = TextEditingController(text: existing != null ? '${existing['fee']}' : '');
    final daysCtrl = TextEditingController(text: existing != null ? '${existing['estimated_days']}' : '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(existing != null ? 'Edit delivery zone' : 'Add delivery zone', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: stateCtrl, enabled: existing == null, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'State', labelStyle: TextStyle(color: GacomColors.textMuted))),
        const SizedBox(height: 10),
        TextField(controller: feeCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Delivery fee (₦)', labelStyle: TextStyle(color: GacomColors.textMuted))),
        const SizedBox(height: 10),
        TextField(controller: daysCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Estimated days', labelStyle: TextStyle(color: GacomColors.textMuted))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(
          onPressed: () => _saveZone(stateCtrl.text.trim(), int.tryParse(feeCtrl.text.trim()) ?? 0, int.tryParse(daysCtrl.text.trim()) ?? 3, existingId: existing?['id'] as String?),
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
          child: const Text('SAVE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('STORE ADMIN'), bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [
      Tab(text: 'PRODUCTS'), Tab(text: 'DELIVERY ZONES'), Tab(text: 'STAFF ROLES'),
    ])),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : TabBarView(controller: _tab, children: [_productsTab(), _zonesTab(), _staffTab()]),
  );

  Widget _productsTab() {
    final active = _products.where((p) => p['is_active'] != false).toList();
    return active.isEmpty
      ? const Center(child: Text('No products yet.', style: TextStyle(color: GacomColors.textMuted)))
      : ListView.builder(padding: const EdgeInsets.all(16), itemCount: active.length, itemBuilder: (_, i) {
          final p = active[i];
          final lowConfidence = p['price_confidence'] == 'low';
          return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: lowConfidence ? GacomColors.error.withOpacity(0.5) : GacomColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(p['name'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary))),
                if (lowConfidence) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
                  child: const Text('CHECK PRICE', style: TextStyle(color: GacomColors.error, fontSize: 10, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              Text(p['description'] as String? ?? '', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text('Listed: ₦${p['price']}${p['source_price'] != null ? ' (source: ₦${p['source_price']})' : ''}', style: const TextStyle(color: GacomColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _openEditDialog(p),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.electricBlue)),
                  child: const Text('EDIT', style: TextStyle(color: GacomColors.electricBlue, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => _deleteProduct(p['id'] as String),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.error)),
                  child: const Text('REMOVE', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
              ]),
            ]));
        });
  }

  Widget _zonesTab() => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: () => _openZoneDialog(),
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('ADD DELIVERY ZONE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14)),
    ))),
    Expanded(child: _zones.isEmpty
      ? const Center(child: Text('No delivery zones set up yet.', style: TextStyle(color: GacomColors.textMuted)))
      : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _zones.length, itemBuilder: (_, i) {
          final z = _zones[i];
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(z['state_name'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
                Text('₦${z['fee']} — ${z['estimated_days']} days', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              IconButton(onPressed: () => _openZoneDialog(existing: z), icon: const Icon(Icons.edit_rounded, color: GacomColors.electricBlue, size: 18)),
              IconButton(onPressed: () => _deleteZone(z['id'] as String), icon: const Icon(Icons.delete_outline_rounded, color: GacomColors.error, size: 18)),
            ]));
        })),
  ]);

  Widget _staffTab() {
    final emailCtrl = TextEditingController();
    bool canAdd = false, canManage = false;
    return StatefulBuilder(builder: (context, setLocal) => ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ASSIGN STAFF ROLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 1)),
          const SizedBox(height: 10),
          TextField(controller: emailCtrl, style: const TextStyle(color: GacomColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Staff email', hintStyle: TextStyle(color: GacomColors.textMuted), border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, value: canAdd, onChanged: (v) => setLocal(() => canAdd = v),
            title: const Text('Can add products (incl. approve AI scouting)', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)), activeColor: GacomColors.deepOrange),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, value: canManage, onChanged: (v) => setLocal(() => canManage = v),
            title: const Text('Can receive and approve orders only', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)), activeColor: GacomColors.deepOrange),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => _addStaffByEmail(emailCtrl.text.trim(), canAdd: canAdd, canManage: canManage),
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
            child: const Text('SAVE ROLE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
        ])),
      const SizedBox(height: 20),
      const Text('CURRENT STAFF', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
      const SizedBox(height: 10),
      ..._staff.map((s) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Text(s['user_id'] as String, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
          if (s['can_add_products'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.add_box_rounded, color: GacomColors.accentCyan, size: 16)),
          if (s['can_manage_orders'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.local_shipping_rounded, color: GacomColors.success, size: 16)),
        ]))),
    ]));
  }
}
