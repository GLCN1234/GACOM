import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/router_service.dart';
import 'core/services/supabase_service.dart';
import 'features/profile/screens/settings_screen.dart' show themeModeProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

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

  // Catches errors that happen outside the widget build phase (e.g. inside
  // async callbacks) that would otherwise vanish silently into the console.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('UNCAUGHT ERROR: ${details.exceptionAsString()}\n${details.stack}');
  };

  runApp(const ProviderScope(child: GacomApp()));
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
