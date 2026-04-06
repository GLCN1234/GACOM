import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gacom_widgets.dart';
import '../../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: GacomColors.background,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              // Logo
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [GacomColors.primary, GacomColors.primaryDark]),
                      boxShadow: [BoxShadow(color: GacomColors.primary.withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: Center(child: Text('G', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 12),
                  Text('GACOM', style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 60),

              Text('WELCOME\nBACK,\nGAMER.',
                style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w900, height: 1),
              ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.2, end: 0),

              const SizedBox(height: 8),
              Text('Sign in to your account', style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 16))
                  .animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 48),

              // Email Field
              _buildLabel('EMAIL'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.outfit(color: GacomColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  prefixIcon: const Icon(Icons.mail_outline, color: GacomColors.textMuted, size: 20),
                ),
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              _buildLabel('PASSWORD'),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: GoogleFonts.outfit(color: GacomColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, color: GacomColors.textMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: GacomColors.textMuted, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text('Forgot password?', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 13)),
                ),
              ),

              if (authState.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GacomColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GacomColors.error.withOpacity(0.3)),
                  ),
                  child: Text(authState.error!, style: GoogleFonts.outfit(color: GacomColors.error, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 32),

              GlowButton(
                text: 'SIGN IN',
                width: double.infinity,
                isLoading: authState.isLoading,
                onPressed: () async {
                  final success = await ref.read(authProvider.notifier).signIn(_emailCtrl.text.trim(), _passCtrl.text);
                  if (success && mounted) context.go('/home');
                },
              ).animate(delay: 500.ms).fadeIn(),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text('Register', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ).animate(delay: 600.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
    style: GoogleFonts.rajdhani(color: GacomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5),
  );
}
