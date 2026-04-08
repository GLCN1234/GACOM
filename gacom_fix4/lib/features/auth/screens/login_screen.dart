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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      GacomSnackbar.show(context, 'Please fill in both fields', isError: true);
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
      if (!mounted) return;
      // If login fails due to invalid credentials, hint the migration popup
      // for users who were on the old Wix platform
      final msg = e.message.toLowerCase();
      final isCredentialError = msg.contains('invalid') ||
          msg.contains('credentials') ||
          msg.contains('password') ||
          msg.contains('not found');

      if (isCredentialError) {
        _showMigrationHint(email);
      } else {
        GacomSnackbar.show(context, e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Shown when a Wix-migrated user tries to log in with their old password
  void _showMigrationHint(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: GacomColors.orangeGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GacomColors.deepOrange.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'We\'ve Moved to a\nNew Platform! 🎮',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: GacomColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'GACOM has upgraded to a faster, better platform. Your account has been moved over automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GacomColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            // Steps
            _MigrationStep(
              number: '1',
              text: 'Tap "Reset My Password" below',
            ),
            _MigrationStep(
              number: '2',
              text: 'Check your email for the reset link',
            ),
            _MigrationStep(
              number: '3',
              text: 'Set a new password and log in',
            ),
            _MigrationStep(
              number: '4',
              text: 'Complete your profile and start gaming!',
            ),
            const SizedBox(height: 24),
            // Reset button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GacomColors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendPasswordReset(email, fromMigration: true);
                },
                child: const Text(
                  'RESET MY PASSWORD',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Dismiss
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'I\'ll do this later',
                style: TextStyle(color: GacomColors.textMuted, fontSize: 13),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // Forgot password dialog — clean, minimal
  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GacomColors.deepOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: GacomColors.deepOrange, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reset Password',
                    style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
                Text('We\'ll send a reset link to your email',
                    style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 20),
            GacomTextField(
              controller: emailCtrl,
              label: 'Email Address',
              hint: 'your@email.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GacomColors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) {
                    GacomSnackbar.show(ctx, 'Enter your email address', isError: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  _sendPasswordReset(email);
                },
                child: const Text(
                  'SEND RESET LINK',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendPasswordReset(String email, {bool fromMigration = false}) async {
    if (email.isEmpty) {
      GacomSnackbar.show(context, 'Enter your email address first', isError: true);
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://gacom.gg/reset-password',
      );
      if (mounted) {
        _showResetSentDialog(email, fromMigration: fromMigration);
      }
    } on AuthException catch (e) {
      if (mounted) GacomSnackbar.show(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        // Supabase returns success even for unknown emails (security measure)
        // so we always show the confirmation
        _showResetSentDialog(email, fromMigration: fromMigration);
      }
    }
  }

  void _showResetSentDialog(String email, {bool fromMigration = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: GacomColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: GacomColors.success, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Check Your Email',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: GacomColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We sent a password reset link to\n$email',
              textAlign: TextAlign.center,
              style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GacomColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GacomColors.border),
              ),
              child: Column(children: [
                _HintRow(icon: Icons.inbox_rounded, text: 'Check your inbox and spam folder'),
                const SizedBox(height: 6),
                _HintRow(icon: Icons.link_rounded, text: 'Tap the link in the email'),
                const SizedBox(height: 6),
                _HintRow(icon: Icons.lock_open_rounded, text: 'Set your new password'),
                if (fromMigration) ...[
                  const SizedBox(height: 6),
                  _HintRow(icon: Icons.person_rounded, text: 'Complete your gamer profile'),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GacomColors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('GOT IT',
                    style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _sendPasswordReset(email, fromMigration: fromMigration);
              },
              child: const Text(
                'Resend email',
                style: TextStyle(color: GacomColors.textMuted, fontSize: 13),
              ),
            ),
          ]),
        ),
      ),
    );
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
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: GacomColors.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('G',
                        style: TextStyle(fontFamily: 'Rajdhani', fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('GACOM',
                    style: TextStyle(fontFamily: 'Rajdhani', fontSize: 26, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: 4)),
              ]).animate().fadeIn().slideX(begin: -0.2, end: 0),
              const SizedBox(height: 60),
              const Text(
                'Welcome\nBack, Gamer.',
                style: TextStyle(fontFamily: 'Rajdhani', fontSize: 38, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, height: 1.1),
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
                  onPressed: _showForgotPasswordDialog, // FIXED: now actually works
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GacomButton(
                label: 'SIGN IN',
                isLoading: _loading,
                onPressed: _login,
              ).animate(delay: 500.ms).fadeIn(),
              const SizedBox(height: 20),
              // Migration banner — helps Wix users find their way
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GacomColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GacomColors.info.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: GacomColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5),
                        children: [
                          TextSpan(text: 'Old Wix member? '),
                          TextSpan(
                            text: 'Use Forgot Password',
                            style: TextStyle(color: GacomColors.info, fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' to set a new password and access your account.'),
                        ],
                      ),
                    ),
                  ),
                ]),
              ).animate(delay: 550.ms).fadeIn(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: GacomColors.textSecondary)),
                  GestureDetector(
                    onTap: () => context.go(AppConstants.registerRoute),
                    child: const Text('Join Now',
                        style: TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700)),
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

// ── Helper widgets ────────────────────────────────────────────────────────────

class _MigrationStep extends StatelessWidget {
  final String number;
  final String text;
  const _MigrationStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          gradient: GacomColors.orangeGradient,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani')),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4)),
      ),
    ]),
  );
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: GacomColors.deepOrange),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4))),
  ]);
}
