import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/services/ios_purchase_service.dart';
import '../../../core/theme/app_theme.dart';

/// Wallet top-up through Apple In-App Purchase (iOS app only).
/// Returns true if at least one top-up was applied while the sheet was open.
Future<bool> showIosTopUp(BuildContext context) async {
  final IosPurchaseService svc = IosPurchaseService.instance;
  await svc.start();
  if (svc.products.isEmpty) await svc.loadProducts();
  if (!context.mounted) return false;
  final int before = svc.completed.value;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GacomColors.elevatedCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (BuildContext ctx) => const _IosTopUpBody(),
  );
  return svc.completed.value > before;
}

class _IosTopUpBody extends StatelessWidget {
  const _IosTopUpBody();

  @override
  Widget build(BuildContext context) {
    final IosPurchaseService svc = IosPurchaseService.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ValueListenableBuilder<bool>(
          valueListenable: svc.busy,
          builder: (BuildContext context, bool busy, Widget? _) {
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('Add to wallet', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Choose an amount. You pay through your Apple ID.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 14),
              if (svc.products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Top-up packs are not available right now. Please try again shortly.', style: TextStyle(color: GacomColors.textSecondary)),
                )
              else
                ...IosProducts.topups.where(svc.products.containsKey).map((String id) {
                  final ProductDetails p = svc.products[id]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: GacomColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: busy ? null : () => svc.buyTopUp(id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: <Widget>[
                            const Icon(Icons.account_balance_wallet_rounded, color: GacomColors.deepOrange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('₦${IosProducts.creditFor(id)} wallet credit',
                                  style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
                            ),
                            Text(p.price, style: const TextStyle(fontWeight: FontWeight.w800, color: GacomColors.deepOrange)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              ValueListenableBuilder<String?>(
                valueListenable: svc.message,
                builder: (BuildContext context, String? msg, Widget? _) => msg == null
                    ? const SizedBox.shrink()
                    : Padding(padding: const EdgeInsets.only(top: 4), child: Text(msg, style: const TextStyle(color: GacomColors.warning, fontSize: 13))),
              ),
              if (busy)
                const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => svc.restore(),
                  child: const Text('Restore purchases'),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
