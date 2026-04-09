import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// This screen handles the deep link from the password reset email.
/// Supabase redirects to: https://gamicom.netlify.app/#/reset-password
/// (or whatever redirectTo you set in _sendPasswordReset)
/// The hash fragment carries the access_token Supabase needs.
/// supabase_flutter automatically picks it up on web — we just show the form.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _done = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (pass.length < 8) {
      GacomSnackbar.show(context, 'Password must be at least 8 characters', isError: true);
      return;
    }
    if (pass != confirm) {
      GacomSnackbar.show(context, 'Passwords do not match', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (mounted) setState(() { _done = true; _loading = false; });
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GacomSnackbar.show(context, e.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GacomSnackbar.show(context, 'Something went wrong. Try again.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _done ? _SuccessView() : _FormView(
            passCtrl: _passCtrl,
            confirmCtrl: _confirmCtrl,
            loading: _loading,
            obscure: _obscure,
            obscureConfirm: _obscureConfirm,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onToggleObscureConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final TextEditingController passCtrl, confirmCtrl;
  final bool loading, obscure, obscureConfirm;
  final VoidCallback onToggleObscure, onToggleObscureConfirm, onSubmit;

  const _FormView({
    required this.passCtrl, required this.confirmCtrl,
    required this.loading, required this.obscure, required this.obscureConfirm,
    required this.onToggleObscure, required this.onToggleObscureConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: GacomColors.orangeGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 24)],
          ),
          child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 32),
        ).animate().scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        const Text('Set New Password',
            style: TextStyle(fontFamily: 'Rajdhani', fontSize: 34, fontWeight: FontWeight.w800, color: GacomColors.textPrimary, height: 1.1))
            .animate(delay: 100.ms).fadeIn().slideY(begin: 0.3, end: 0),
        const SizedBox(height: 8),
        const Text('Choose a strong password for your Gacom account.',
            style: TextStyle(color: GacomColors.textSecondary, fontSize: 15))
            .animate(delay: 200.ms).fadeIn(),
        const SizedBox(height: 40),
        GacomTextField(
          controller: passCtrl,
          label: 'New Password',
          hint: 'Min. 8 characters',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscure,
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: GacomColors.textMuted),
            onPressed: onToggleObscure,
          ),
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 16),
        GacomTextField(
          controller: confirmCtrl,
          label: 'Confirm Password',
          hint: 'Repeat your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: GacomColors.textMuted),
            onPressed: onToggleObscureConfirm,
          ),
        ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 32),
        GacomButton(label: 'UPDATE PASSWORD', isLoading: loading, onPressed: onSubmit)
            .animate(delay: 500.ms).fadeIn(),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 44),
        ).animate().scale(begin: const Offset(0.4, 0.4), duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        const Text('Password Updated!',
            style: TextStyle(fontFamily: 'Rajdhani', fontSize: 30, fontWeight: FontWeight.w800, color: GacomColors.textPrimary))
            .animate(delay: 200.ms).fadeIn(),
        const SizedBox(height: 10),
        const Text('Your new password is active.\nSign in to get back in the arena.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.6))
            .animate(delay: 300.ms).fadeIn(),
        const SizedBox(height: 48),
        GacomButton(
          label: 'GO TO LOGIN',
          onPressed: () => context.go('/login'),
        ).animate(delay: 400.ms).fadeIn(),
      ],
    );
  }
}
