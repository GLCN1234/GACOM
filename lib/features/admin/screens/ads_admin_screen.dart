import 'package:flutter/material.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// Campaigns waiting for approval. Approving starts the run clock; rejecting
/// returns the advertiser's whole budget.
class AdsAdminScreen extends StatefulWidget {
  const AdsAdminScreen({super.key});
  @override
  State<AdsAdminScreen> createState() => _AdsAdminScreenState();
}

class _AdsAdminScreenState extends State<AdsAdminScreen> {
  List<Map<String, dynamic>> _q = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = await AdsService.adminQueue();
    if (mounted) setState(() { _q = q; _loading = false; });
  }

  Future<void> _decide(Map<String, dynamic> c, bool approve) async {
    String? note;
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
                backgroundColor: GacomColors.cardDark,
                title: const Text('Reject this ad', style: TextStyle(color: GacomColors.textPrimary)),
                content: TextField(controller: ctl, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(hintText: 'Reason shown to the advertiser')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Reject and refund')),
                ],
              ));
      if (ok != true) return;
      note = ctl.text.trim();
    }
    final r = await AdsService.adminReview('${c['id']}', approve, note);
    if (!mounted) return;
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Could not save', isError: true);
      return;
    }
    GacomSnackbar.show(context, approve ? 'Approved' : 'Rejected and refunded', isSuccess: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('AD REVIEW')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _q.isEmpty
              ? const Center(child: Text('Nothing waiting for review', style: TextStyle(color: GacomColors.textMuted)))
              : RefreshIndicator(
                  color: GacomColors.deepOrange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _q.length,
                    itemBuilder: (_, i) {
                      final c = _q[i];
                      final flag = c['flag_reason'] as String?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: flag != null ? GacomColors.warning : GacomColors.border, width: 0.8)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if ((c['image'] as String?) != null)
                            AspectRatio(aspectRatio: 16 / 9, child: Image.network(c['image'] as String, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: GacomColors.surfaceDark))),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${c['headline']}', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                              if ((c['body'] as String?)?.isNotEmpty == true) Text('${c['body']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text('By @${c['advertiser']}  |  ${c['objective']}  |  ${c['days']} days  |  N${c['total_budget']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                              Text('Link: ${c['url']}', style: const TextStyle(color: GacomColors.info, fontSize: 11)),
                              Text('Button: ${c['cta']}  |  Places: ${((c['placements'] as List?) ?? []).join(', ')}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                              if (flag != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Flagged terms: $flag', style: const TextStyle(color: GacomColors.warning, fontSize: 12, fontWeight: FontWeight.w600))),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: OutlinedButton(onPressed: () => _decide(c, false), child: const Text('REJECT', style: TextStyle(color: GacomColors.error)))),
                                const SizedBox(width: 10),
                                Expanded(child: ElevatedButton(onPressed: () => _decide(c, true), style: ElevatedButton.styleFrom(backgroundColor: GacomColors.success), child: const Text('APPROVE', style: TextStyle(color: Colors.white)))),
                              ]),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
