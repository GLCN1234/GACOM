import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'flyer_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/edu_prefs.dart' as edu_prefs;
import '../../../shared/widgets/gacom_snackbar.dart';

/// Banner for competitions that are open or about to open. Shown on the main
/// home feed and on the GACOM Edu home. Renders nothing when there is none.
/// A student can register straight from it, and is taken into GACOM Edu.
class EduCompetitionBanner extends StatefulWidget {
  /// True when shown inside GACOM Edu (changes the wording of the buttons).
  final bool inEdu;
  const EduCompetitionBanner({super.key, this.inEdu = false});
  @override
  State<EduCompetitionBanner> createState() => _EduCompetitionBannerState();
}

class _EduCompetitionBannerState extends State<EduCompetitionBanner> {
  List<Map<String, dynamic>> _items = [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await SupabaseService.client.rpc('edu_comp_banners');
      if (!mounted) return;
      if (res is List) {
        setState(() => _items = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (_) {
      // No banner is better than an error on the home screen.
    }
  }

  void _openEdu(Map<String, dynamic> c) {
    edu_prefs.setEduMode(true);
    context.go('/edu/competition/${c['id']}');
  }

  Future<void> _register(Map<String, dynamic> c) async {
    if (_busyId != null) return;
    setState(() => _busyId = '${c['id']}');
    try {
      final res = await SupabaseService.client.rpc('edu_comp_register', params: {'p_comp': c['id']});
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        GacomSnackbar.show(context, res['already'] == true ? 'You are already registered' : 'You are registered. Opening GACOM Edu...', isSuccess: true);
        _openEdu(c);
      } else if (res is Map && res['code'] == 'need_school') {
        GacomSnackbar.show(context, 'Choose your school first, then register again.');
        edu_prefs.setEduMode(true);
        context.go('/edu/setup');
      } else {
        GacomSnackbar.show(context, (res is Map ? res['error'] : null)?.toString() ?? 'Could not register', isError: true);
      }
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not register. Check your connection and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _when(Map<String, dynamic> c) {
    final s = DateTime.tryParse('${c['starts_at']}')?.toLocal();
    final e = DateTime.tryParse('${c['ends_at']}')?.toLocal();
    final now = DateTime.now();
    if (s != null && s.isAfter(now)) {
      final d = s.difference(now);
      if (d.inDays >= 1) return 'Starts in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
      if (d.inHours >= 1) return 'Starts in ${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
      return 'Starts in ${d.inMinutes < 1 ? 1 : d.inMinutes} min';
    }
    if (e != null) {
      final d = e.difference(now);
      if (d.inDays >= 1) return 'Live now  |  ${d.inDays} day${d.inDays == 1 ? '' : 's'} left';
      if (d.inHours >= 1) return 'Live now  |  ${d.inHours} hour${d.inHours == 1 ? '' : 's'} left';
      return 'Live now  |  ending soon';
    }
    return 'Live now';
  }

  String _subjectsText(Map<String, dynamic> c) {
    final subs = c['subjects'];
    if (subs is! List || subs.isEmpty) return '';
    const names = {'math': 'Maths', 'english': 'English'};
    return subs.map((e) => names['$e'] ?? '$e').join(' and ');
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(children: [for (final c in _items) _card(c)]),
    );
  }

  Widget _card(Map<String, dynamic> c) {
    final registered = c['registered'] == true;
    final isEdu = c['kind'] == 'edu';
    final banner = (c['banner_url'] as String?) ?? '';
    final subjects = _subjectsText(c);
    final busy = _busyId == '${c['id']}';
    final prize = num.tryParse('${c['prize_pool'] ?? 0}') ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GacomColors.deepOrange.withOpacity(0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (banner.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 7,
            child: FlyerImage(url: banner),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
                child: Text(isEdu ? 'GACOM EDU COMPETITION' : 'COMPETITION', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.deepOrange, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_when(c), style: const TextStyle(color: GacomColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            Text('${c['title'] ?? ''}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 19, color: GacomColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              [
                if (isEdu && subjects.isNotEmpty) '$subjects only',
                if (prize > 0) 'Prize pool ₦${prize.toInt()}',
                '${c['participants'] ?? 0} registered',
              ].join('  |  '),
              style: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
            ),
            if (registered && (c['my_points'] ?? 0) != 0) ...[
              const SizedBox(height: 4),
              Text('Your points: ${c['my_points']}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 12),
            if (registered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _openEdu(c),
                  child: Text(isEdu ? (widget.inEdu ? 'OPEN COMPETITION' : 'OPEN IN GACOM EDU') : 'VIEW COMPETITION', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              )
            else if (isEdu)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: busy ? null : () => _register(c),
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('REGISTER NOW', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                if (!widget.inEdu)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('New to GACOM Edu? Tap Register and we take you there.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  ),
              ])
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.deepOrange), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => context.push('/competitions/${c['id']}'),
                  child: const Text('VIEW AND JOIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.deepOrange)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
