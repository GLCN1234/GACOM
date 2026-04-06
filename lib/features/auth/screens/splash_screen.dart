import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      context.go(AppConstants.homeRoute);
    } else {
      context.go(AppConstants.onboardingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: GacomColors.orangeGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: GacomColors.deepOrange.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 60,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(),
            const SizedBox(height: 24),
            const Text(
              'GACOM',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: GacomColors.textPrimary,
                letterSpacing: 8,
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn()
                .slideY(begin: 0.3, end: 0),
            const SizedBox(height: 8),
            const Text(
              'GAME. CONNECT. DOMINATE.',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: GacomColors.deepOrange,
                letterSpacing: 4,
              ),
            )
                .animate(delay: 500.ms)
                .fadeIn()
                .slideY(begin: 0.3, end: 0),
            const SizedBox(height: 80),
            SizedBox(
              width: 40,
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: GacomColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  GacomColors.deepOrange,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ).animate(delay: 800.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
