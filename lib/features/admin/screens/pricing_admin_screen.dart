import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/pricing_admin_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// One place to change what GACOM charges: ad prices, ad rules and the verification levels.
class PricingAdminScreen extends StatefulWidget {
  const PricingAdminScreen({super.key});
  @override
  State<PricingAdminScreen> createState() => _PricingAdminScreenState();
}

class _PricingAdminScreenState extends State<PricingAdminScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await PricingAdmin.load();
    if (mounted) setState(() { _d = d; _loading = false; });
  }

  List<Map<String, dynamic>> _list(String k) =>
      ((_d?[k] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  void _toast(String? err, String ok) {
    if (!mounted) return;
    GacomSnackbar.show(context, err ?? ok, isError: err != null, isSuccess: err == null);
    if (err == null) _load();
  }

  Future<void> _editRate(Map<String, dynamic> r) async {
    final cpm = TextEditingController(text: '${r['cpm']}');
    final cpc = TextEditingController(text: '${r['cpc']}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              backgroundColor: GacomColors.cardDark,
              title: Text('${r['label']} prices', style: const TextStyle(color: GacomColors.textPrimary)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: cpm, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Naira per 1,000 views (awareness)')),
                TextField(controller: cpc, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Naira per click (traffic)')),
                const SizedBox(height: 8),
                const Text('Applies from now on to every campaign, including ones already running.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
              ],
            ));
    if (ok != true) return;
    final err = await PricingAdmin.setRate('${r['placement']}', int.tryParse(cpm.text.trim()) ?? 0, int.tryParse(cpc.text.trim()) ?? 0);
    _toast(err, 'Prices saved');
  }

  Future<void> _editSettings() async {
    final s = Map<String, dynamic>.from((_d?['settings'] as Map?) ?? {});
    bool review = s['review_first_campaign'] != false;
    final maxLive = TextEditingController(text: '${s['max_live_per_advertiser'] ?? 10}');
    final minD = TextEditingController(text: '${s['min_daily_budget'] ?? 1000}');
    final maxD = TextEditingController(text: '${s['max_daily_budget'] ?? 500000}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
              builder: (d, setD) => AlertDialog(
                backgroundColor: GacomColors.cardDark,
                title: const Text('Ad rules', style: TextStyle(color: GacomColors.textPrimary)),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: review,
                      activeColor: GacomColors.deepOrange,
                      onChanged: (v) => setD(() => review = v),
                      title: const Text('Review first campaigns', style: TextStyle(color: GacomColors.textPrimary, fontSize: 14)),
                      subtitle: const Text('On: a new advertiser\'s first campaign waits for approval. Off: clean ads go live at once. Ads with flagged wording are always reviewed.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    ),
                    TextField(controller: maxLive, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Most running campaigns per advertiser')),
                    TextField(controller: minD, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Smallest daily budget (naira)')),
                    TextField(controller: maxD, keyboardType: TextInputType.number, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Largest daily budget (naira)')),
                  ]),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
                ],
              ),
            ));
    if (ok != true) return;
    final err = await PricingAdmin.setSettings(
        reviewFirst: review,
        maxLive: int.tryParse(maxLive.text.trim()) ?? 10,
        minDaily: int.tryParse(minD.text.trim()) ?? 1000,
        maxDaily: int.tryParse(maxD.text.trim()) ?? 500000);
    _toast(err, 'Ad rules saved');
  }

  Future<void> _editTier(Map<String, dynamic> t) async {
    final c = {
      'name': TextEditingController(text: '${t['name']}'),
      'tagline': TextEditingController(text: '${t['tagline']}'),
      'price': TextEditingController(text: '${t['price']}'),
      'color': TextEditingController(text: '${t['color']}'),
      'max_active': TextEditingController(text: '${t['max_active']}'),
      'max_prize': TextEditingController(text: '${t['max_prize']}'),
      'max_players': TextEditingController(text: '${t['max_players']}'),
      'fee_percent': TextEditingController(text: '${t['fee_percent']}'),
      'ad_discount': TextEditingController(text: '${t['ad_discount']}'),
    };
    bool needsId = t['needs_id'] == true;
    bool active = t['active'] != false;
    final labels = {
      'name': 'Name', 'tagline': 'One-line pitch', 'price': 'Price per 30 days (naira)', 'color': 'Tick colour (hex, e.g. #3B82F6)',
      'max_active': 'Competitions at once', 'max_prize': 'Biggest prize pool (naira)', 'max_players': 'Most players (up to 1000)',
      'fee_percent': 'Platform fee on entry fees (%)', 'ad_discount': 'Ad discount (%)',
    };
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
              builder: (d, setD) => AlertDialog(
                backgroundColor: GacomColors.cardDark,
                title: Text('Edit ${t['name']}', style: const TextStyle(color: GacomColors.textPrimary)),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final e in c.entries)
                      TextField(
                        controller: e.value,
                        keyboardType: (e.key == 'name' || e.key == 'tagline' || e.key == 'color') ? TextInputType.text : TextInputType.number,
                        style: const TextStyle(color: GacomColors.textPrimary),
                        decoration: InputDecoration(labelText: labels[e.key]),
                      ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, value: needsId, activeColor: GacomColors.deepOrange, onChanged: (v) => setD(() => needsId = v), title: const Text('Needs a verified ID', style: TextStyle(color: GacomColors.textPrimary, fontSize: 14))),
                    SwitchListTile(contentPadding: EdgeInsets.zero, value: active, activeColor: GacomColors.deepOrange, onChanged: (v) => setD(() => active = v), title: const Text('Offered to members', style: TextStyle(color: GacomColors.textPrimary, fontSize: 14))),
                  ]),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
                ],
              ),
            ));
    if (ok != true) return;
    int? n(String k) => int.tryParse(c[k]!.text.trim());
    final err = await PricingAdmin.setTier('${t['code']}', {
      'name': c['name']!.text.trim(),
      'tagline': c['tagline']!.text.trim(),
      'price': n('price'),
      'color': c['color']!.text.trim(),
      'max_active': n('max_active'),
      'max_prize': n('max_prize'),
      'max_players': n('max_players'),
      'fee_percent': n('fee_percent'),
      'ad_discount': n('ad_discount'),
      'needs_id': needsId,
      'active': active,
    });
    _toast(err, 'Level saved');
  }

  String _n(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '₦$b';
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(t, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800)),
      );

  Widget _card({required Widget child, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = Map<String, dynamic>.from((_d?['settings'] as Map?) ?? {});
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('ADS AND PRICING')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _d == null
              ? const Center(child: Text('Could not load. Run the 20261105 migration first.', style: TextStyle(color: GacomColors.textMuted)))
              : RefreshIndicator(
                  color: GacomColors.deepOrange,
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                    _head('WAITING FOR YOU'),
                    _card(
                      onTap: () => context.push('/admin/ads'),
                      child: Row(children: [
                        const Icon(Icons.campaign_rounded, color: GacomColors.deepOrange),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${_d!['pending_ads']} ads to review', style: const TextStyle(color: GacomColors.textPrimary))),
                        const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
                      ]),
                    ),
                    _card(
                      onTap: () => context.push('/admin/ids'),
                      child: Row(children: [
                        const Icon(Icons.badge_rounded, color: GacomColors.deepOrange),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${_d!['pending_ids']} ID checks to review', style: const TextStyle(color: GacomColors.textPrimary))),
                        const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
                      ]),
                    ),
                    _head('AD PRICES (TAP TO CHANGE)'),
                    for (final r in _list('rates'))
                      _card(
                        onTap: () => _editRate(r),
                        child: Row(children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r['label']}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('${r['blurb']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${_n(r['cpm'] as num)} / 1,000 views', style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700, fontSize: 12)),
                            Text('${_n(r['cpc'] as num)} / click', style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700, fontSize: 12)),
                          ]),
                        ]),
                      ),
                    const Text('Small audiences are charged up to 1.6 times these prices, and verified members get their level\'s discount on top.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.4)),
                    _head('AD RULES'),
                    _card(
                      onTap: _editSettings,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: const Text('Review first campaigns', style: TextStyle(color: GacomColors.textPrimary))),
                          Text(s['review_first_campaign'] == false ? 'OFF' : 'ON', style: TextStyle(color: s['review_first_campaign'] == false ? GacomColors.warning : GacomColors.success, fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 6),
                        Text('Daily budget ${_n((s['min_daily_budget'] as num?) ?? 1000)} to ${_n((s['max_daily_budget'] as num?) ?? 500000)}  |  up to ${s['max_live_per_advertiser'] ?? 10} running per advertiser',
                            style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                      ]),
                    ),
                    _head('VERIFICATION LEVELS (TAP TO CHANGE)'),
                    for (final t in _list('tiers'))
                      _card(
                        onTap: () => _editTier(t),
                        child: Row(children: [
                          Container(width: 10, height: 44, decoration: BoxDecoration(color: _hex('${t['color']}'), borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${t['name']}${t['active'] == false ? '  (hidden)' : ''}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('${t['max_active']} at once | prize up to ${_n(t['max_prize'] as num)} | ${t['max_players']} players | fee ${t['fee_percent']}% | ads -${t['ad_discount']}%${t['needs_id'] == true ? ' | ID needed' : ''}',
                                style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                          ])),
                          Text(_n(t['price'] as num), style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                  ]),
                ),
    );
  }

  Color _hex(String h) {
    final x = h.replaceAll('#', '');
    final v = int.tryParse(x, radix: 16);
    return (v == null || x.length != 6) ? GacomColors.deepOrange : Color(0xFF000000 | v);
  }
}
