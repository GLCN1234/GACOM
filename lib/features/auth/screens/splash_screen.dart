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
    await Future.delayed(const Duration(milliseconds: 3000));
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
            // GACOM Logo from cloudinary – blended into dark background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GacomColors.deepOrange.withOpacity(0.45),
                    blurRadius: 50,
                    spreadRadius: 12,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  'https://res.cloudinary.com/dtchp470a/image/upload/v1775540390/WhatsApp_Image_2026-03-27_at_03.12.01_3_jxyhbj.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('G',
                          style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 60,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 700.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(),
            const SizedBox(height: 28),
            const Text(
              'GACOM',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: GacomColors.textPrimary,
                letterSpacing: 10,
              ),
            ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.3, end: 0),
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
            ).animate(delay: 550.ms).fadeIn().slideY(begin: 0.3, end: 0),
            const SizedBox(height: 80),
            SizedBox(
              width: 48,
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: GacomColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(GacomColors.deepOrange),
                borderRadius: BorderRadius.circular(10),
              ),
            ).animate(delay: 900.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
