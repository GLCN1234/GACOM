import 'package:flutter/material.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pick_upload.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import 'ads_screen.dart';

String _n(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Results and controls for one campaign.
class CampaignDetailScreen extends StatefulWidget {
  final Map<String, dynamic> campaign;
  const CampaignDetailScreen({super.key, required this.campaign});
  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  late Map<String, dynamic> _c;
  Map<String, dynamic>? _s;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c = Map<String, dynamic>.from(widget.campaign);
    _load();
  }

  Future<void> _load() async {
    final list = await AdsService.myCampaigns();
    final fresh = list.where((x) => x['id'] == _c['id']).toList();
    final s = await AdsService.stats('${_c['id']}');
    if (!mounted) return;
    setState(() {
      if (fresh.isNotEmpty) _c = fresh.first;
      _s = s;
    });
  }

  Future<void> _act(String action, String done) async {
    if (_busy) return;
    if (action == 'cancel') {
      final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
                backgroundColor: GacomColors.cardDark,
                title: const Text('End this campaign?', style: TextStyle(color: GacomColors.textPrimary)),
                content: const Text('It stops now and the unspent part of the budget returns to your wallet.', style: TextStyle(color: GacomColors.textMuted)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep running')),
                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('End it')),
                ],
              ));
      if (ok != true) return;
    }
    setState(() => _busy = true);
    final r = await AdsService.setStatus('${_c['id']}', action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Could not update', isError: true);
      return;
    }
    GacomSnackbar.show(context, done, isSuccess: true);
    _load();
  }

  Future<void> _edit() async {
    final head = TextEditingController(text: '${_c['headline'] ?? ''}');
    final body = TextEditingController(text: '${_c['body'] ?? ''}');
    final link = TextEditingController(text: '${_c['url'] ?? ''}');
    String cta = (_c['cta'] as String?) ?? 'Learn more';
    String? image = _c['image'] as String?;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: ListView(shrinkWrap: true, children: [
            const Text('Edit ad', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const Text('Budget, days and audience are fixed once the campaign is paid for.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                try {
                  final u = await pickAndUploadImage(bucket: 'ad-creatives');
                  if (u != null) setM(() => image = u);
                } catch (e) {
                  if (ctx.mounted) GacomSnackbar.show(ctx, '$e', isError: true);
                }
              },
              child: Container(
                height: 120,
                decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: image == null ? const Center(child: Icon(Icons.add_photo_alternate_rounded, color: GacomColors.deepOrange)) : Image.network(image!, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: head, maxLength: 40, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Headline')),
            TextField(controller: body, maxLength: 200, maxLines: 3, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Text')),
            TextField(controller: link, keyboardType: TextInputType.url, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(labelText: 'Link (https://)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: cta,
              dropdownColor: GacomColors.cardDark,
              decoration: const InputDecoration(labelText: 'Button'),
              items: AdsService.ctas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: GacomColors.textPrimary)))).toList(),
              onChanged: (v) => setM(() => cta = v ?? cta),
            ),
            const SizedBox(height: 16),
            GacomButton(
              label: 'SAVE CHANGES',
              onPressed: () async {
                final r = await AdsService.updateCreative('${_c['id']}', {
                  'headline': head.text.trim(), 'body': body.text.trim(), 'cta': cta,
                  'destination_url': link.text.trim(), 'creative_url': image,
                });
                if (!ctx.mounted) return;
                if (!r.success) {
                  GacomSnackbar.show(ctx, r.error ?? 'Could not save', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                if (mounted) {
                  GacomSnackbar.show(context, r.data['needs_review'] == true ? 'Saved. It will run again after a quick review.' : 'Saved', isSuccess: true);
                  _load();
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (_c['status'] as String?) ?? '';
    final col = statusColor(status);
    final s = _s;
    final live = status == 'active' || status == 'paused' || status == 'pending_review';
    final byDay = ((s?['by_day'] as List?) ?? []).whereType<Map>().toList();
    final maxDay = byDay.fold<num>(1, (m, d) => (d['impressions'] as num) > m ? d['impressions'] as num : m);
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text('${_c['title'] ?? 'Campaign'}'.toUpperCase())),
      body: RefreshIndicator(
        color: GacomColors.deepOrange,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(statusLabel(status), style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Text(_c['objective'] == 'traffic' ? 'Get visits' : 'Get seen', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ]),
          if (status == 'pending_review')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Waiting for approval. The run time starts when it is approved, so you get every paid day.', style: TextStyle(color: GacomColors.warning, fontSize: 12, height: 1.4)),
            ),
          if (status == 'rejected' && _c['review_note'] != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text('Reason: ${_c['review_note']}', style: const TextStyle(color: GacomColors.error, fontSize: 12))),
          if ((_c['refunded'] as num? ?? 0) > 0)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text('₦${_n(_c['refunded'] as num)} was returned to your wallet.', style: const TextStyle(color: GacomColors.success, fontSize: 12))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.1,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _Tile('People reached', _n((_c['reach'] as num?) ?? 0)),
              _Tile('Views', _n((_c['impressions'] as num?) ?? 0)),
              _Tile('Clicks', _n((_c['clicks'] as num?) ?? 0)),
              _Tile('Click rate', '${s?['ctr'] ?? 0}%'),
              _Tile('Spent', '₦${_n((_c['spend'] as num?) ?? 0)}'),
              _Tile('Remaining', '₦${_n((s?['remaining'] as num?) ?? 0)}'),
            ],
          ),
          const SizedBox(height: 6),
          Text('Each person saw the ad ${s?['frequency'] ?? 0} times on average. Cost per click: ₦${_n((s?['cost_per_click'] as num?) ?? 0)}.',
              style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          const SizedBox(height: 22),
          const Text('VIEWS PER DAY', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (byDay.isEmpty)
            const Text('No views yet.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))
          else
            SizedBox(
              height: 110,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in byDay.length > 30 ? byDay.sublist(byDay.length - 30) : byDay)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Tooltip(
                        message: '${d['day']}: ${d['impressions']} views, ${d['clicks']} clicks',
                        child: Container(
                          height: 8 + 100 * ((d['impressions'] as num) / maxDay).toDouble(),
                          decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Line('Budget', '₦${_n((_c['daily_budget'] as num?) ?? 0)} a day for ${_c['days']} days = ₦${_n((_c['total_budget'] as num?) ?? 0)}'),
              _Line('Where', ((_c['placements'] as List?) ?? []).join(', ')),
              _Line('Countries', ((_c['countries'] as List?) ?? []).isEmpty ? 'All' : ((_c['countries'] as List).join(', '))),
              _Line('Interests', ((_c['interests'] as List?) ?? []).isEmpty ? 'Everyone' : ((_c['interests'] as List).map((e) => AdsService.interests['$e'] ?? '$e').join(', '))),
              _Line('Runs', '${_d(_c['starts_at'])} to ${_d(_c['ends_at'])}'),
            ]),
          ),
          const SizedBox(height: 20),
          if (live) ...[
            Row(children: [
              if (status == 'active')
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _act('pause', 'Paused'), child: const Text('PAUSE')))
              else if (status == 'paused')
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _act('resume', 'Running again'), child: const Text('RESUME'))),
              if (status != 'pending_review') const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: _busy ? null : _edit, child: const Text('EDIT AD'))),
            ]),
            const SizedBox(height: 10),
            TextButton(onPressed: _busy ? null : () => _act('cancel', 'Campaign ended'), child: const Text('End campaign and refund the rest', style: TextStyle(color: GacomColors.error))),
          ] else
            GacomButton(
              label: 'RUN IT AGAIN',
              onPressed: () async {
                final rates = await AdsService.rates();
                if (!context.mounted) return;
                final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CampaignBuilder(rates: rates, from: _c)));
                if (ok == true && context.mounted) Navigator.of(context).pop();
              },
            ),
        ]),
      ),
    );
  }

  String _d(dynamic v) {
    final t = DateTime.tryParse('$v')?.toLocal();
    return t == null ? '-' : '${t.day}/${t.month}/${t.year}';
  }
}

class _Tile extends StatelessWidget {
  final String label, value;
  const _Tile(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          Text(value, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20)),
        ]),
      );
}

class _Line extends StatelessWidget {
  final String k, v;
  const _Line(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(k, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))),
          Expanded(child: Text(v, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12))),
        ]),
      );
}
