import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/router_service.dart';
import 'core/services/supabase_service.dart';
import 'features/profile/screens/settings_screen.dart' show themeModeProvider;

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
    runApp(const ProviderScope(child: GacomApp()));
  }, (error, stack) {
    debugPrint('ZONE ERROR: $error\n$stack');
    _showFatalErrorOnPage(error.toString(), stack.toString());
  });
}

void _showFatalErrorOnPage(String error, String stack) {
  // Avoid stacking duplicate overlays if multiple errors fire
  html.document.getElementById('gacom-fatal-error')?.remove();
  final div = html.DivElement()
    ..id = 'gacom-fatal-error'
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.left = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.background = '#1a0000'
    ..style.color = '#ffffff'
    ..style.padding = '20px'
    ..style.zIndex = '999999'
    ..style.fontFamily = 'monospace'
    ..style.fontSize = '12px'
    ..style.overflow = 'auto'
    ..style.whiteSpace = 'pre-wrap'
    ..text = '⚠️ App crashed — screenshot this:\n\n$error\n\n$stack';
  html.document.body?.append(div);
}

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
