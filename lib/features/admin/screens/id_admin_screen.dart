import 'package:flutter/material.dart';
import '../../../core/services/pricing_admin_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// ID checks waiting for a decision. The pictures are deleted when you approve or reject.
class IdAdminScreen extends StatefulWidget {
  const IdAdminScreen({super.key});
  @override
  State<IdAdminScreen> createState() => _IdAdminScreenState();
}

class _IdAdminScreenState extends State<IdAdminScreen> {
  List<Map<String, dynamic>> _q = [];
  final Map<String, List<String?>> _urls = {};
  bool _loading = true;

  static const _types = {'nin': 'NIN / national ID', 'drivers_licence': "Driver's licence", 'passport': 'Passport', 'voters_card': "Voter's card"};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = await PricingAdmin.idQueue();
    final urls = <String, List<String?>>{};
    for (final r in q) {
      urls['${r['user_id']}'] = [
        r['doc_path'] == null ? null : await PricingAdmin.signedUrl('${r['doc_path']}'),
        r['selfie_path'] == null ? null : await PricingAdmin.signedUrl('${r['selfie_path']}'),
      ];
    }
    if (!mounted) return;
    setState(() { _q = q; _urls..clear()..addAll(urls); _loading = false; });
  }

  Future<void> _decide(Map<String, dynamic> r, bool approve) async {
    String? note;
    if (!approve) {
      final ctl = TextEditingController(text: 'The photos were not clear enough. Please try again.');
      final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
                backgroundColor: GacomColors.cardDark,
                title: const Text('Reject this ID', style: TextStyle(color: GacomColors.textPrimary)),
                content: TextField(controller: ctl, maxLines: 3, style: const TextStyle(color: GacomColors.textPrimary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Reject')),
                ],
              ));
      if (ok != true) return;
      note = ctl.text.trim();
    }
    final err = await PricingAdmin.idReview('${r['user_id']}', approve, note);
    if (!mounted) return;
    GacomSnackbar.show(context, err ?? (approve ? 'Approved' : 'Rejected'), isError: err != null, isSuccess: err == null);
    if (err == null) _load();
  }

  Widget _img(String? url, String label) => Expanded(
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: url == null
                  ? Container(color: GacomColors.surfaceDark, child: const Center(child: Icon(Icons.broken_image_rounded, color: GacomColors.border)))
                  : GestureDetector(
                      onTap: () => showDialog<void>(context: context, builder: (d) => Dialog(backgroundColor: Colors.black, child: InteractiveViewer(child: Image.network(url)))),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('ID CHECKS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _q.isEmpty
              ? const Center(child: Text('Nothing waiting', style: TextStyle(color: GacomColors.textMuted)))
              : RefreshIndicator(
                  color: GacomColors.deepOrange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _q.length,
                    itemBuilder: (_, i) {
                      final r = _q[i];
                      final u = _urls['${r['user_id']}'] ?? [null, null];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['full_name']}', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                          Text('@${r['username']}  |  ${_types['${r['doc_type']}'] ?? r['doc_type']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 10),
                          Row(children: [_img(u[0], 'ID'), const SizedBox(width: 10), _img(u[1], 'Selfie')]),
                          const SizedBox(height: 6),
                          const Text('Check that the face matches, the name matches what was typed, and the ID is not expired.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: const Text('REJECT', style: TextStyle(color: GacomColors.error)))),
                            const SizedBox(width: 10),
                            Expanded(child: ElevatedButton(onPressed: () => _decide(r, true), style: ElevatedButton.styleFrom(backgroundColor: GacomColors.success), child: const Text('APPROVE', style: TextStyle(color: Colors.white)))),
                          ]),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
