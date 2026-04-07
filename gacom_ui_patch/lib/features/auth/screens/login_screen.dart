import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bgAnim.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      GacomSnackbar.show(context, 'Please fill all fields', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) context.go(AppConstants.homeRoute);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GacomSnackbar.show(context, 'Invalid email or password', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Stack(
        children: [
          // Animated background
          _AnimatedBackground(controller: _bgAnim),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  _GacomLogo().animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 48),

                  const Text('Welcome back', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 32, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: 0.5))
                      .animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 4),
                  const Text('Sign in to continue your gaming journey', style: TextStyle(color: GacomColors.textMuted, fontSize: 14, height: 1.4))
                      .animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 40),

                  // Email
                  _GlassField(controller: _emailCtrl, label: 'Email', icon: Icons.email_outlined, type: TextInputType.emailAddress)
                      .animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 14),

                  // Password
                  _GlassField(
                    controller: _passCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: GacomColors.textMuted, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Forgot Password?', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
                  ).animate().fadeIn(delay: 380.ms),
                  const SizedBox(height: 32),

                  // Sign In button
                  _PrimaryBtn(label: 'SIGN IN', loading: _loading, onTap: _signIn)
                      .animate().fadeIn(delay: 420.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 28),

                  // Divider
                  Row(children: [
                    Expanded(child: Container(height: 0.5, color: GacomColors.border)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                    ),
                    Expanded(child: Container(height: 0.5, color: GacomColors.border)),
                  ]).animate().fadeIn(delay: 450.ms),
                  const SizedBox(height: 24),

                  // Social (placeholders)
                  Row(children: [
                    Expanded(child: _SocialBtn(label: 'Google', icon: Icons.g_mobiledata_rounded, onTap: () {})),
                    const SizedBox(width: 12),
                    Expanded(child: _SocialBtn(label: 'Discord', icon: Icons.discord, onTap: () {})),
                  ]).animate().fadeIn(delay: 480.ms),
                  const SizedBox(height: 40),

                  Center(
                    child: GestureDetector(
                      onTap: () => context.go(AppConstants.registerRoute),
                      child: RichText(text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: GacomColors.textMuted, fontSize: 14),
                        children: [TextSpan(text: 'Sign Up', style: TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700))],
                      )),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background Widget ───────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _BgPainter(controller.value),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = GacomColors.deepOrange.withOpacity(0.04)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Glow orb
    final orbX = size.width * 0.7 + (size.width * 0.2 * t);
    final orbY = size.height * 0.15;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [GacomColors.deepOrange.withOpacity(0.12 + 0.04 * t), Colors.transparent],
        radius: 0.4,
      ).createShader(Rect.fromCircle(center: Offset(orbX, orbY), radius: size.width * 0.5));
    canvas.drawCircle(Offset(orbX, orbY), size.width * 0.5, glowPaint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Logo ────────────────────────────────────────────────────────────────────

class _GacomLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]),
        child: const Center(child: Text('G', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white))),
      ),
      const SizedBox(width: 10),
      ShaderMask(
        shaderCallback: (b) => GacomColors.orangeGradient.createShader(b),
        child: const Text('GACOM', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: Colors.white, letterSpacing: 3)),
      ),
    ]);
  }
}

// ─── Glass Text Field ────────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;
  const _GlassField({required this.controller, required this.label, required this.icon, this.obscure = false, this.type, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: GacomColors.textMuted, size: 18),
        suffixIcon: suffix,
      ),
    );
  }
}

// ─── Primary Button ──────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _PrimaryBtn({required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: GacomColors.orangeGradient,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 2, color: Colors.white)),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: GacomColors.border, width: 0.8),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: GacomColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14, color: GacomColors.textSecondary)),
        ]),
      ),
    );
  }
}
