import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Two jobs: approve/reject AI-scouted products before they go live, and
/// assign staff the specific permission they need — adding products,
/// managing orders, or both — rather than one blanket admin flag.
class StoreAdminScreen extends StatefulWidget {
  const StoreAdminScreen({super.key});
  @override
  State<StoreAdminScreen> createState() => _StoreAdminScreenState();
}

class _StoreAdminScreenState extends State<StoreAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await SupabaseService.client.from('products')
          .select('id, name, description, price, source_price, source_url, category, created_at')
          .eq('review_status', 'pending_review').order('created_at', ascending: false);
      final staff = await SupabaseService.client.from('store_staff_roles')
          .select('user_id, can_add_products, can_manage_orders').order('created_at', ascending: false);
      if (mounted) setState(() {
        _pending = List<Map<String, dynamic>>.from(pending);
        _staff = List<Map<String, dynamic>>.from(staff);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _reviewProduct(String id, bool approve) async {
    await SupabaseService.client.from('products')
        .update({'review_status': approve ? 'approved' : 'rejected'}).eq('id', id);
    _load();
  }

  Future<void> _addStaffByEmail(String email, {required bool canAdd, required bool canManage}) async {
    try {
      // Admin-only lookup — resolves an email to a user id via a lightweight
      // RPC rather than the full auth.admin API from the client.
      final res = await SupabaseService.client.rpc('get_user_id_by_email', params: {'p_email': email});
      final uid = res as String?;
      if (uid == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No user found with that email')));
        return;
      }
      await SupabaseService.client.from('store_staff_roles').upsert({
        'user_id': uid, 'can_add_products': canAdd, 'can_manage_orders': canManage,
      });
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('STORE ADMIN'), bottom: TabBar(controller: _tab, tabs: const [
      Tab(text: 'PENDING PRODUCTS'), Tab(text: 'STAFF ROLES'),
    ])),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : TabBarView(controller: _tab, children: [_pendingTab(), _staffTab()]),
  );

  Widget _pendingTab() => _pending.isEmpty
    ? const Center(child: Text('No products awaiting review.', style: TextStyle(color: GacomColors.textMuted)))
    : Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.error.withOpacity(0.4))),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: GacomColors.error, size: 18), SizedBox(width: 8),
            Expanded(child: Text('The AI has no live web search — verify the price and source link yourself before approving. Do not approve on trust alone.',
              style: TextStyle(color: GacomColors.error, fontSize: 12, fontWeight: FontWeight.w600))),
          ])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), itemCount: _pending.length, itemBuilder: (_, i) {
        final p = _pending[i];
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
            const SizedBox(height: 4),
            Text(p['description'] as String? ?? '', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('Source: ₦${p['source_price']} → Listed: ₦${p['price']} (20% markup)', style: const TextStyle(color: GacomColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
            if (p['source_url'] != null) Text(p['source_url'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _reviewProduct(p['id'] as String, false),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.error)),
                child: const Text('REJECT', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: () => _reviewProduct(p['id'] as String, true),
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.success),
                child: const Text('APPROVE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
            ]),
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
