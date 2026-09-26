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
    return _FriendlyErrorWidget(error: details.exceptionAsString(), stack: details.stack.toString());
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
      _logErrorToDatabase(details.exceptionAsString(), details.stack.toString());
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
    _logErrorToDatabase(error.toString(), stack.toString());
  });
}

/// Best-effort, fire-and-forget — logging a crash should never itself
/// be able to cause a problem. Route is captured from the current URL
/// on web, since that's the cheapest reliable signal for "where was
/// the user when this happened" without threading context through
/// every error handler.
void _logErrorToDatabase(String error, String stack) {
  try {
    final route = Uri.base.path.isNotEmpty ? Uri.base.path : null;
    SupabaseService.client.from('error_logs').insert({
      'user_id': SupabaseService.currentUserId,
      'error': error.length > 4000 ? error.substring(0, 4000) : error,
      'stack': stack.length > 8000 ? stack.substring(0, 8000) : stack,
      'route': route,
    }).then((_) {}, onError: (_) {});
  } catch (_) {
    // Never let logging itself throw.
  }
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

/// Shown in place of any widget that fails to build — friendly by
/// default (no raw stack trace thrown at the user), with full details
/// still one tap away for debugging when genuinely needed.
class _FriendlyErrorWidget extends StatefulWidget {
  final String error;
  final String stack;
  const _FriendlyErrorWidget({required this.error, required this.stack});
  @override State<_FriendlyErrorWidget> createState() => _FriendlyErrorWidgetState();
}

class _FriendlyErrorWidgetState extends State<_FriendlyErrorWidget> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF0A0A0F),
    padding: const EdgeInsets.all(24),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('⚠', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 16),
        const Text('Something went wrong', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('This part of the app ran into a problem. The rest of GACOM should still work fine.',
          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84B00), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
          child: const Text('Go Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showDetails = !_showDetails),
          child: Text(_showDetails ? 'Hide technical details' : 'Show technical details', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ),
        if (_showDetails) Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 300),
          decoration: BoxDecoration(color: const Color(0xFF1A0000), borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(child: Text('${widget.error}\n\n${widget.stack}',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'))),
        ),
      ]),
    ),
  );
}
