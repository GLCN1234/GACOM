import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../edu/edu_subscription_service.dart';
import '../../shared/widgets/gacom_snackbar.dart';

class HousesScreen extends StatefulWidget {
  const HousesScreen({super.key});
  @override State<HousesScreen> createState() => _HousesScreenState();
}

class _HousesScreenState extends State<HousesScreen> {
  bool _loading = true;
  bool _isPro = false;
  List<Map<String, dynamic>> _houses = [];
  String? _myHouseId;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = SupabaseService.currentUserId;
    final isPro = await EduSubscriptionService.isPro();
    try {
      final houses = await SupabaseService.client.from('houses').select('*, member_count:house_members(count)').order('created_at', ascending: false);
      String? myHouseId;
      if (uid != null) {
        final mine = await SupabaseService.client.from('house_members').select('house_id').eq('user_id', uid).maybeSingle();
        myHouseId = mine?['house_id'] as String?;
      }
      final housesList = List<Map<String, dynamic>>.from(houses);
      // Fetch each house's live points — small list, fine to do in parallel.
      await Future.wait(housesList.map((h) async {
        try {
          final pts = await SupabaseService.client.rpc('get_house_points', params: {'p_house_id': h['id']});
          h['points'] = (pts as num?)?.toInt() ?? 0;
        } catch (_) { h['points'] = 0; }
      }));
      housesList.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
      if (mounted) setState(() { _houses = housesList; _isPro = isPro; _myHouseId = myHouseId; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _join(String houseId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    if (_myHouseId != null) {
      GacomSnackbar.show(context, 'Leave your current house before joining another', isError: true);
      return;
    }
    try {
      await SupabaseService.client.from('house_members').insert({'house_id': houseId, 'user_id': uid});
      _load();
    } catch (e) { GacomSnackbar.show(context, 'Could not join: $e', isError: true); }
  }

  Future<void> _leave(String houseId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('house_members').delete().eq('house_id', houseId).eq('user_id', uid);
      _load();
    } catch (e) { GacomSnackbar.show(context, 'Could not leave: $e', isError: true); }
  }

  void _createDialog() {
    if (!_isPro) {
      GacomSnackbar.show(context, 'Founding a house is a premium feature', isError: true);
      return;
    }
    final nameCtrl = TextEditingController();
    String color = '#E84B00';
    const colors = ['#E84B00', '#00E5FF', '#8B5CF6', '#34D399', '#FFD700', '#E85B8A'];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Found a House', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(labelText: 'House name', labelStyle: TextStyle(color: GacomColors.textMuted))),
        const SizedBox(height: 14),
        Wrap(spacing: 10, children: colors.map((c) => GestureDetector(
          onTap: () => setDlg(() => color = c),
          child: Container(width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
              border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2)),
          ),
        )).toList()),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(
          onPressed: () async {
            final uid = SupabaseService.currentUserId;
            if (uid == null || nameCtrl.text.trim().isEmpty) return;
            try {
              final house = await SupabaseService.client.from('houses').insert({
                'name': nameCtrl.text.trim(), 'banner_color': color, 'captain_id': uid,
              }).select().single();
              await SupabaseService.client.from('house_members').insert({'house_id': house['id'], 'user_id': uid});
              if (mounted) { Navigator.pop(ctx); _load(); }
            } catch (e) {
              if (mounted) GacomSnackbar.show(ctx, 'Could not create house: $e', isError: true);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
          child: const Text('FOUND HOUSE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
        ),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('HOUSES')),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _createDialog,
            icon: Icon(_isPro ? Icons.add_rounded : Icons.lock_rounded, color: Colors.white, size: 18),
            label: Text(_isPro ? 'FOUND A HOUSE' : 'FOUND A HOUSE (PREMIUM)', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: _isPro ? GacomColors.deepOrange : GacomColors.elevatedCard, padding: const EdgeInsets.symmetric(vertical: 14)),
          ))),
          Expanded(child: _houses.isEmpty
            ? const Center(child: Text('No houses yet — be the first to found one.', style: TextStyle(color: GacomColors.textMuted)))
            : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), itemCount: _houses.length, itemBuilder: (_, i) {
                final h = _houses[i];
                final color = Color(int.tryParse((h['banner_color'] as String? ?? '#E84B00').replaceFirst('#', '0xFF')) ?? 0xFFE84B00);
                final isMine = h['id'] == _myHouseId;
                final memberCount = (h['member_count'] as List?)?.isNotEmpty == true ? (h['member_count'] as List).first['count'] : 0;
                return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: isMine ? color : GacomColors.border, width: isMine ? 1.5 : 1)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(Icons.shield_rounded, color: color, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h['name'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
                        Text('$memberCount member${memberCount == 1 ? '' : 's'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      ])),
                      Text('${h['points']}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 18, color: color)),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: isMine
                      ? OutlinedButton(onPressed: () => _leave(h['id']), style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.error)),
                          child: const Text('LEAVE HOUSE', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))
                      : ElevatedButton(onPressed: () => _join(h['id']), style: ElevatedButton.styleFrom(backgroundColor: color),
                          child: const Text('JOIN HOUSE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
                  ]));
              })),
        ]),
  );
}
