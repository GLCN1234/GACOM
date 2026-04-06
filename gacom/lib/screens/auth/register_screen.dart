import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gacom_widgets.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: GacomColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: GacomColors.textPrimary), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('CREATE\nACCOUNT',
              style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
            ).animate().fadeIn().slideX(begin: -0.1, end: 0),

            const SizedBox(height: 8),
            Text('Join the ultimate gaming platform', style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 15))
                .animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 40),

            _field('GAMER TAG', _usernameCtrl, Icons.person_outline, 'Your unique username'),
            const SizedBox(height: 16),
            _field('EMAIL', _emailCtrl, Icons.mail_outline, 'your@email.com', type: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _field('PASSWORD', _passCtrl, Icons.lock_outline, '••••••••', obscure: _obscure,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: GacomColors.textMuted, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 16),
            _field('CONFIRM PASSWORD', _confirmCtrl, Icons.lock_outline, '••••••••', obscure: true),
            const SizedBox(height: 20),

            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: GacomColors.primary,
                  side: const BorderSide(color: GacomColors.cardBorder),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'I agree to the ', style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 13)),
                        TextSpan(text: 'Terms of Service', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 13)),
                        TextSpan(text: ' and ', style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 13)),
                        TextSpan(text: 'Privacy Policy', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
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
              text: 'JOIN GACOM',
              width: double.infinity,
              isLoading: authState.isLoading,
              onPressed: _agreed ? () async {
                if (_passCtrl.text != _confirmCtrl.text) return;
                final success = await ref.read(authProvider.notifier).signUp(
                  _emailCtrl.text.trim(), _passCtrl.text, _usernameCtrl.text.trim(),
                );
                if (success && mounted) context.go('/home');
              } : null,
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already a gamer? ', style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text('Sign In', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, String hint,
      {TextInputType? type, bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.rajdhani(color: GacomColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          style: GoogleFonts.outfit(color: GacomColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: GacomColors.textMuted, size: 18),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
