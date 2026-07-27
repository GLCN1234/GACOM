import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/router_service.dart';
import 'core/services/supabase_service.dart';
import 'features/profile/screens/settings_screen.dart' show themeModeProvider;
import 'core/utils/fatal_error_handler_stub.dart'
    if (dart.library.html) 'core/utils/fatal_error_handler_web.dart' as fatal_error;

void main() async {
  // Flutter's default release-mode behavior on any widget-build error is to
  // render a blank/empty box with NO error text — by design, to avoid
  // leaking internals in production. That's indistinguishable from a real
  // crash and made bugs like this impossible to diagnose from a screenshot.
  // Show the actual error on screen instead so it can just be screenshotted.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFF1A0000),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Text(
          '⚠️ Something broke here:\n\n${details.exceptionAsString()}',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  };

  // runZonedGuarded catches errors that escape Flutter's own error pipeline
  // entirely (e.g. an unawaited async error) — these are the ones that
  // produce a fully blank page with nothing in ErrorWidget.builder or even
  // FlutterError.onError. Writing straight to the DOM guarantees visibility
  // even if Flutter's whole render tree is broken.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _showFatalErrorOnPage(details.exceptionAsString(), details.stack.toString());
    };

    await SupabaseService.initialize();

    // Check for a returning Paystack payment reference at the earliest
    // possible point — before any routing or screen widget exists. We'd
    // previously relied on WalletScreen's own initState to catch this, but
    // that depends on the router actually landing on /wallet with the
    // right timing, which proved unreliable. This runs unconditionally on
    // every app boot regardless of which screen ends up rendering.
    await _checkAndVerifyReturningPayment();

    runApp(const ProviderScope(child: GacomApp()));
  }, (error, stack) {
    debugPrint('ZONE ERROR: $error\n$stack');
    _showFatalErrorOnPage(error.toString(), stack.toString());
  });
}

Future<void> _checkAndVerifyReturningPayment() async {
  try {
    String? reference = Uri.base.queryParameters['reference'] ?? Uri.base.queryParameters['trxref'];
    if (reference == null) {
      final fragment = Uri.base.fragment;
      if (fragment.contains('?')) {
        final fragUri = Uri.parse(fragment.startsWith('/') ? fragment : '/$fragment');
        reference = fragUri.queryParameters['reference'] ?? fragUri.queryParameters['trxref'];
      }
    }
    if (reference == null || reference.isEmpty) return;
    if (SupabaseService.currentUserId == null) return; // not logged in yet, nothing to credit

    debugPrint('Detected returning payment reference: $reference — verifying...');
    final res = await SupabaseService.client.functions.invoke(
      'paystack-verify',
      body: {'reference': reference},
    ).timeout(const Duration(seconds: 20));
    debugPrint('paystack-verify result: ${res.data}');
  } catch (e) {
    debugPrint('paystack-verify check failed: $e');
    // Deliberately not fatal — a failed verify check shouldn't block the
    // app from loading. The transaction stays 'pending' and can be
    // reconciled later; it doesn't disappear.
  }
}

void _showFatalErrorOnPage(String error, String stack) => fatal_error.showFatalErrorOnPage(error, stack);

class GacomApp extends ConsumerWidget {
  const GacomApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: GacomTheme.lightTheme,
      darkTheme: GacomTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
