import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/hosting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/verified_tick.dart';

String _naira(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₦$b';
}

Color _hex(String? h, Color fallback) {
  final x = (h ?? '').replaceAll('#', '');
  final v = int.tryParse(x, radix: 16);
  return (v == null || x.length != 6) ? fallback : Color(0xFF000000 | v);
}

const _catNames = {
  'title': 'Title', 'emote': 'Emote', 'spray': 'Spray', 'finisher': 'Finisher',
  'avatar_frame': 'Frame', 'badge': 'Badge', 'name_color': 'Name colour',
};

/// Verification levels: what each costs and gives, ID check status, subscribe or switch.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  Map<String, dynamic> _o = {};
  bool _loading = true;
  bool _changed = false;
  String? _busyTier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await HostingService.overview();
    if (mounted) setState(() { _o = o; _loading = false; });
  }

  List<Map<String, dynamic>> get _tiers =>
      ((_o['tiers'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _choose(Map<String, dynamic> t) async {
    final code = '${t['code']}';
    final needsId = t['needs_id'] == true;
    final idOk = _o['id_status'] == 'approved';
    if (needsId && !idOk) {
      await context.push('/verification/id');
      _load();
      return;
    }
    final current = _o['tier'] as String?;
    final active = _o['active'] == true;
    final same = active && current == code;
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              backgroundColor: GacomColors.cardDark,
              title: Text(same ? 'Renew ${t['name']}?' : (active ? 'Switch to ${t['name']}?' : 'Get ${t['name']}?'), style: const TextStyle(color: GacomColors.textPrimary)),
              content: Text(
                  '${_naira(t['price'] as num)} for 30 days from your wallet.'
                  '${active && !same ? ' Unused days on your current level are credited against this price.' : ''}'
                  '${same ? ' Another 30 days are added to what you have left.' : ''}'
                  ' It does not renew by itself.',
                  style: const TextStyle(color: GacomColors.textMuted, height: 1.4)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Continue')),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => _busyTier = code);
    final r = await HostingService.subscribe(code, 1);
    if (!mounted) return;
    setState(() => _busyTier = null);
    if (!r.success) {
      if (r.data['needs_id'] == true) {
        await context.push('/verification/id');
        _load();
        return;
      }
      GacomSnackbar.show(context, r.error ?? 'Could not subscribe', isError: true);
      if ((r.error ?? '').toLowerCase().contains('balance')) context.go('/wallet');
      return;
    }
    _changed = true;
    GacomSnackbar.show(context, 'You are now ${t['name']}', isSuccess: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _o['active'] == true;
    final idStatus = (_o['id_status'] as String?) ?? 'none';
    final curColor = _hex(_o['tier_color'] as String?, GacomColors.deepOrange);
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(
          title: const Text('VERIFICATION'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop(_changed)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : RefreshIndicator(
                color: GacomColors.deepOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? curColor : GacomColors.border, width: active ? 1.2 : 0.5)),
                    child: Row(children: [
                      active ? VerifiedTick(tier: _o['tier'] as String?, size: 34) : const Icon(Icons.verified_outlined, color: GacomColors.textMuted, size: 34),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(active ? '${_o['tier_name']} member' : 'Not verified', style: TextStyle(color: active ? curColor : GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)),
                        Text(active ? '${_o['days_left']} days left' : 'Pick a level below to get your tick.', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _IdCard(status: idStatus, onTap: () async { await context.push('/verification/id'); _load(); }),
                  const SizedBox(height: 18),
                  for (final t in _tiers) _TierCard(
                    t: t,
                    current: active && _o['tier'] == t['code'],
                    busy: _busyTier == t['code'],
                    idOk: idStatus == 'approved',
                    higher: active && ((t['rank'] as num?) ?? 0) > ((_o['tier_rank'] as num?) ?? 0),
                    onTap: _busyTier != null ? null : () => _choose(t),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Paid from your GACOM wallet for 30 days at a time. When a level ends, the tick and the assets that came with it are removed, and hosting pauses until you renew. Competitions you already created keep running.',
                      style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.5)),
                ]),
              ),
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _IdCard({required this.status, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final map = {
      'approved': (Icons.badge_rounded, GacomColors.success, 'ID verified', 'Higher levels and paid competitions are open to you.'),
      'pending': (Icons.hourglass_top_rounded, GacomColors.warning, 'ID under review', 'We will tell you as soon as it is checked.'),
      'rejected': (Icons.error_outline_rounded, GacomColors.error, 'ID not accepted', 'Tap to try again with clearer photos.'),
      'none': (Icons.badge_outlined, GacomColors.textMuted, 'Verify your ID', 'Needed for Pro, Elite and Legend, and to host competitions with an entry fee.'),
    };
    final m = map[status] ?? map['none']!;
    return GestureDetector(
      onTap: status == 'approved' || status == 'pending' ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Row(children: [
          Icon(m.$1, color: m.$2),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.$3, style: TextStyle(color: m.$2 == GacomColors.textMuted ? GacomColors.textPrimary : m.$2, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(m.$4, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.4)),
          ])),
          if (status == 'none' || status == 'rejected') const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
        ]),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final bool current, busy, idOk, higher;
  final VoidCallback? onTap;
  const _TierCard({required this.t, required this.current, required this.busy, required this.idOk, required this.higher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _hex(t['color'] as String?, GacomColors.deepOrange);
    final needsId = t['needs_id'] == true;
    final assets = ((t['assets'] as List?) ?? []).whereType<Map>().toList();
    final discount = (t['ad_discount'] as num?)?.toInt() ?? 0;
    Widget bullet(String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_rounded, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(s, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12, height: 1.35))),
          ]),
        );
    String label;
    if (busy) {
      label = 'PLEASE WAIT...';
    } else if (needsId && !idOk) {
      label = 'ID CHECK REQUIRED';
    } else if (current) {
      label = 'RENEW';
    } else if (higher) {
      label = 'UPGRADE';
    } else {
      label = 'CHOOSE';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: current ? color : GacomColors.border, width: current ? 1.4 : 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          VerifiedTick(tier: '${t['code']}', size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text('${t['name']}', style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20))),
          if (current) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('YOUR LEVEL', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 2),
        Text('${t['tagline']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_naira(t['price'] as num), style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28)),
          const Padding(padding: EdgeInsets.only(bottom: 5, left: 4), child: Text('/ 30 days', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        bullet('Verified tick in ${(t['name'] as String).toLowerCase()} colour on your profile and posts'),
        bullet('Host ${t['max_active']} competition${(t['max_active'] as num) == 1 ? '' : 's'} at a time'),
        bullet('Prize pools up to ${_naira(t['max_prize'] as num)}, up to ${t['max_players']} players'),
        bullet('Platform fee on entry fees: ${t['fee_percent']}%'),
        if (discount > 0) bullet('$discount% off all ad prices'),
        if (needsId) bullet('Needs a verified ID'),
        if (assets.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('COMES WITH (while active)', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in assets)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
                child: Text('${_catNames['${a['category']}'] ?? a['category']}: ${a['name']}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
          if ((t['rank'] as num) > 1)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('Plus everything from the levels below.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11))),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(backgroundColor: needsId && !idOk ? GacomColors.surfaceDark : color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(label, style: TextStyle(color: needsId && !idOk ? GacomColors.textPrimary : Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }
}
