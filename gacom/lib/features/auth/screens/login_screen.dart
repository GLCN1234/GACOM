import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      GacomSnackbar.show(context, 'Please fill all fields', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      if (mounted) context.go(AppConstants.homeRoute);
    } on AuthException catch (e) {
      if (mounted) GacomSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'GACOM',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: GacomColors.textPrimary,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ).animate().fadeIn().slideX(begin: -0.2, end: 0),
              const SizedBox(height: 60),
              const Text(
                'Welcome\nBack, Gamer.',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary,
                  height: 1.1,
                ),
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              const Text(
                'Sign in to continue your grind.',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 16),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 48),
              GacomTextField(
                controller: _emailCtrl,
                label: 'Email',
                hint: 'your@email.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              GacomTextField(
                controller: _passCtrl,
                label: 'Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePass,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: GacomColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {}, // TODO: forgot password
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: GacomColors.deepOrange),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GacomButton(
                label: 'SIGN IN',
                isLoading: _loading,
                onPressed: _login,
              ).animate(delay: 500.ms).fadeIn(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: GacomColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppConstants.registerRoute),
                    child: const Text(
                      'Join Now',
                      style: TextStyle(
                        color: GacomColors.deepOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 600.ms).fadeIn(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
