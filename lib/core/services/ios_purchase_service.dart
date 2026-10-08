import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../features/edu/edu_subscription_service.dart';
import '../platform_policy.dart';
import 'supabase_service.dart';

/// Product ids created in App Store Connect. They must match exactly, and the
/// wallet credit per pack lives server-side in the apple_products table.
class IosProducts {
  static const String prefix = 'com.mobtechsynergies.gacom.';
  static const String premium = '${prefix}premium_monthly';
  static const List<String> topups = <String>[
    '${prefix}topup_1000',
    '${prefix}topup_2500',
    '${prefix}topup_5000',
    '${prefix}topup_10000',
  ];
  static const Set<String> all = <String>{
    premium,
    '${prefix}topup_1000',
    '${prefix}topup_2500',
    '${prefix}topup_5000',
    '${prefix}topup_10000',
  };

  /// Naira credited by each top-up pack (shown to the player; the server holds
  /// the authoritative copy).
  static int creditFor(String productId) {
    final String tail = productId.startsWith(prefix) ? productId.substring(prefix.length) : productId;
    return int.tryParse(tail.replaceAll('topup_', '')) ?? 0;
  }
}

/// Apple In-App Purchase for the iOS app only. Every purchase Apple reports is
/// confirmed by the apple-verify edge function before anything is credited.
class IosPurchaseService {
  IosPurchaseService._();
  static final IosPurchaseService instance = IosPurchaseService._();

  // Lazy on purpose: InAppPurchase.instance registers the Android or StoreKit
  // plugin by defaultTargetPlatform, which crashes a phone browser (Int64
  // accessor not supported by dart2js). Only touched inside the iOS app.
  late final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _started = false;

  /// True while a purchase is in flight.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// Last user-facing message (error or success), or null.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  /// Bumped after each purchase that was confirmed and applied.
  final ValueNotifier<int> completed = ValueNotifier<int>(0);

  /// Kind of the last applied purchase: 'topup' or 'subscription'.
  String lastKind = '';

  final Map<String, ProductDetails> products = <String, ProductDetails>{};
  bool storeAvailable = false;

  /// Start listening for purchases. Safe to call repeatedly; does nothing
  /// outside the iOS app.
  Future<void> start() async {
    if (!PlatformPolicy.usesAppleIap || _started) return;
    _started = true;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      busy.value = false;
      message.value = 'The App Store had a problem. Please try again.';
    });
    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!PlatformPolicy.usesAppleIap) return;
    try {
      storeAvailable = await _iap.isAvailable();
      if (!storeAvailable) return;
      final ProductDetailsResponse res = await _iap.queryProductDetails(IosProducts.all);
      products
        ..clear()
        ..addEntries(res.productDetails.map((ProductDetails p) => MapEntry<String, ProductDetails>(p.id, p)));
    } catch (_) {
      storeAvailable = false;
    }
  }

  Future<void> buyTopUp(String productId) async {
    if (!PlatformPolicy.usesAppleIap) return;
    final ProductDetails? p = products[productId];
    if (p == null) {
      message.value = 'This pack is not available right now.';
      return;
    }
    message.value = null;
    busy.value = true;
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      busy.value = false;
      message.value = 'Could not start the purchase.';
    }
  }

  Future<void> buyPremium() async {
    if (!PlatformPolicy.usesAppleIap) return;
    final ProductDetails? p = products[IosProducts.premium];
    if (p == null) {
      message.value = 'Premium is not available right now.';
      return;
    }
    message.value = null;
    busy.value = true;
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      busy.value = false;
      message.value = 'Could not start the purchase.';
    }
  }

  Future<void> restore() async {
    if (!PlatformPolicy.usesAppleIap) return;
    message.value = null;
    busy.value = true;
    try {
      await _iap.restorePurchases();
    } catch (_) {
      message.value = 'Could not restore purchases.';
    }
    // The purchase stream answers for any restored items. Stop the spinner
    // if Apple has nothing to send back.
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (busy.value) busy.value = false;
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final PurchaseDetails pd in list) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          busy.value = true;
          break;
        case PurchaseStatus.error:
          busy.value = false;
          message.value = pd.error?.message ?? 'The purchase did not go through.';
          if (pd.pendingCompletePurchase) await _iap.completePurchase(pd);
          break;
        case PurchaseStatus.canceled:
          busy.value = false;
          if (pd.pendingCompletePurchase) await _iap.completePurchase(pd);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(pd);
          break;
      }
    }
  }

  Future<void> _verify(PurchaseDetails pd) async {
    final String? txId = pd.purchaseID;
    if (txId == null || txId.isEmpty) {
      busy.value = false;
      return;
    }
    try {
      final res = await SupabaseService.client.functions.invoke(
        'apple-verify',
        body: <String, dynamic>{'transaction_id': txId, 'product_id': pd.productID},
      );
      final dynamic data = res.data;
      final bool ok = res.status == 200 && data is Map && data['success'] == true;
      if (ok) {
        lastKind = '${data['kind'] ?? ''}';
        EduSubscriptionService.clearCache();
        // Only tell Apple the purchase is finished once we have honoured it.
        if (pd.pendingCompletePurchase) await _iap.completePurchase(pd);
        message.value = lastKind == 'subscription' ? 'Premium is active.' : 'Wallet topped up.';
        completed.value = completed.value + 1;
      } else {
        // Leave the purchase unfinished so Apple hands it to us again.
        final String err = data is Map ? '${data['error'] ?? ''}' : '';
        message.value = err.isNotEmpty ? err : 'We could not confirm the purchase yet. It will retry.';
      }
    } catch (_) {
      message.value = 'We could not confirm the purchase yet. It will retry.';
    }
    busy.value = false;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
