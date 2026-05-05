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
