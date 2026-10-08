import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/ios_purchase_service.dart';
import '../../core/theme/app_theme.dart';

/// Premium subscription through Apple In-App Purchase (iOS app only).
/// Shown in place of the Paystack button on the paywall.
class IosSubscribeBlock extends StatefulWidget {
  const IosSubscribeBlock({super.key});
  @override
  State<IosSubscribeBlock> createState() => _IosSubscribeBlockState();
}

class _IosSubscribeBlockState extends State<IosSubscribeBlock> {
  final IosPurchaseService _svc = IosPurchaseService.instance;
  int _seen = 0;

  // Replace the privacy address with the page you publish. Apple requires a
  // working privacy policy and terms link next to any subscription.
  static const String _privacyUrl = 'https://gamicom.net/privacy';
  static const String _termsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  @override
  void initState() {
    super.initState();
    _seen = _svc.completed.value;
    _svc.completed.addListener(_onCompleted);
    _svc.start().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _svc.completed.removeListener(_onCompleted);
    super.dispose();
  }

  void _onCompleted() {
    if (!mounted || _svc.completed.value == _seen) return;
    _seen = _svc.completed.value;
    if (_svc.lastKind == 'subscription') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium is active.')));
      if (context.canPop()) context.pop();
    }
  }

  Future<void> _open(String url) async {
    final Uri u = Uri.parse(url);
    if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ProductDetails? p = _svc.products[IosProducts.premium];
    return ValueListenableBuilder<bool>(
      valueListenable: _svc.busy,
      builder: (BuildContext context, bool busy, Widget? _) {
        return Column(children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (busy || p == null) ? null : () => _svc.buyPremium(),
              style: ElevatedButton.styleFrom(
                backgroundColor: GacomColors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(p == null ? 'PREMIUM UNAVAILABLE' : 'SUBSCRIBE FOR ${p.price}/MONTH',
                      style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _svc.message,
            builder: (BuildContext context, String? msg, Widget? _) => msg == null
                ? const SizedBox.shrink()
                : Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.warning, fontSize: 12))),
          ),
          TextButton(onPressed: busy ? null : () => _svc.restore(), child: const Text('Restore purchases')),
          const Text(
            'GACOM Premium is a monthly auto-renewing subscription. Payment is charged to your Apple ID at confirmation of purchase. '
            'The subscription renews automatically unless it is cancelled at least 24 hours before the end of the current period. '
            'You can manage or cancel it in your Apple ID account settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            TextButton(onPressed: () => _open(_termsUrl), child: const Text('Terms of Use', style: TextStyle(fontSize: 12))),
            const Text('|', style: TextStyle(color: GacomColors.textMuted)),
            TextButton(onPressed: () => _open(_privacyUrl), child: const Text('Privacy Policy', style: TextStyle(fontSize: 12))),
          ]),
        ]);
      },
    );
  }
}
