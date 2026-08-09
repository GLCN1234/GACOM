import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/paystack_service.dart';

/// Edu Gaming paywall — ₦3,500/month for full access.
/// Free tier: 1 level of Mathematics (Foundation only) with all other subjects locked.
class EduPaywallScreen extends StatefulWidget {
  final String? lockedSubject;
  const EduPaywallScreen({super.key, this.lockedSubject});
  @override State<EduPaywallScreen> createState() => _EduPaywallState();
}

class _EduPaywallState extends State<EduPaywallScreen> {
  bool _paying = false;

  static const _features = [
    'All 24 subjects unlocked',
    'All 5 difficulty levels per topic',
    'AI-powered curriculum games from your school',
    'Live student competitions with voice chat',
    'Progress tracking & parent reports',
    'WAEC, NECO & JAMB preparation packs',
    'Weekly achievement certificates',
    'Unlimited subject leaderboards',
  ];

  Future<void> _subscribe() async {
    setState(() => _paying = true);
    try {
      // Initialize Paystack payment for edu subscription
      final uid = SupabaseService.currentUserId!;
      final email = SupabaseService.client.auth.currentUser?.email ?? '';
      final ref = 'EDU_${uid.substring(0,8)}_${DateTime.now().millisecondsSinceEpoch}';

      // Record pending subscription
      await SupabaseService.client.from('edu_subscriptions').upsert({
        'user_id': uid,
        'status': 'pending',
        'plan': 'monthly',
        'amount': 350000, // kobo
        'reference': ref,
      });

      // Launch Paystack directly for this subscription — do NOT route through
      // the wallet screen, which has no awareness of edu_sub/ref/amount params
      // and would just show the user's regular wallet balance instead.
      if (mounted) {
        final launched = await PaystackService.initializeAndPay(
          context: context,
          amountNaira: 3500.0,
          reference: ref,
          callbackUrl: 'https://gamicom.net/#/edu',
        );
        if (launched == null && mounted) setState(() => _paying = false);
      }
    } catch (e) {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('UPGRADE EDU GAMING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
    ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Lock message if coming from a locked subject
      if (widget.lockedSubject != null)
        Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.error.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.lock_rounded, color: GacomColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('${widget.lockedSubject} is locked on the free plan. Upgrade to unlock all subjects.', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
          ])),

      // Free vs Pro comparison
      Row(children: [
        // Free tier
        Expanded(child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FREE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text('₦0', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.textPrimary)),
            const Text('forever', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            ...[
              '✓ Mathematics only',
              '✓ Foundation level only',
              '✓ Basic leaderboard',
              '✗ All other subjects',
              '✗ AI curriculum games',
              '✗ Competitions',
            ].map((f) => Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(f, style: TextStyle(color: f.startsWith('✓') ? GacomColors.textSecondary : GacomColors.textMuted, fontSize: 11)))),
          ]))),
        const SizedBox(width: 12),
        // Pro tier
        Expanded(child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.deepOrange, width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('PRO', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.deepOrange, letterSpacing: 1)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 4),
            const Text('₦3,500', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.deepOrange)),
            const Text('per month', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            ...[
              '✓ All 24 subjects',
              '✓ All 5 levels',
              '✓ AI curriculum games',
              '✓ Live competitions',
              '✓ Parent reports',
              '✓ Exam prep packs',
            ].map((f) => Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(f, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)))),
          ]))),
      ]),
      const SizedBox(height: 24),

      // Features list
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EVERYTHING IN PRO', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textPrimary, letterSpacing: 1)),
          const SizedBox(height: 12),
          ..._features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(f, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
            ]))),
        ])),
      const SizedBox(height: 24),

      // CTA
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _paying ? null : _subscribe,
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _paying ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          : const Text('UPGRADE FOR ₦3,500/MONTH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
      const SizedBox(height: 8),
      const Text('Cancel anytime. Billed monthly. Secure payment via Paystack.', style: TextStyle(color: GacomColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
      const SizedBox(height: 40),
    ])),
  );
}
