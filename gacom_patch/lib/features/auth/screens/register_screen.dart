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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _gamerTagCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _gamerTagCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_agreeToTerms) {
      GacomSnackbar.show(context, 'Please agree to the terms', isError: true);
      return;
    }
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final username = _usernameCtrl.text.trim().toLowerCase();
    final displayName = _displayNameCtrl.text.trim();
    final gamerTag = _gamerTagCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || username.isEmpty || displayName.isEmpty) {
      GacomSnackbar.show(context, 'Please fill all required fields', isError: true);
      return;
    }
    if (pass.length < 8) {
      GacomSnackbar.show(context, 'Password must be at least 8 characters', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      // Pass all fields in metadata — the DB trigger `handle_new_user` reads these
      // and creates the profile row. We do NOT insert into profiles manually here.
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        data: {
          'username': username,
          'display_name': displayName,
          'gamer_tag': gamerTag,
        },
      );
      if (mounted) {
        GacomSnackbar.show(context, 'Account created! Welcome to the arena 🎮');
        context.go(AppConstants.homeRoute);
      }
    } on AuthException catch (e) {
      if (mounted) GacomSnackbar.show(context, e.message, isError: true);
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Something went wrong. Please try again.', isError: true);
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
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => context.go(AppConstants.loginRoute),
                child: const Icon(Icons.arrow_back_rounded, color: GacomColors.textPrimary),
              ),
              const SizedBox(height: 32),
              const Text(
                'Create Your\nGamer Profile.',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary,
                  height: 1.1,
                ),
              ).animate().fadeIn().slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              const Text(
                'Your arena awaits. Set up your identity.',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 16),
              ).animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 36),
              GacomTextField(
                controller: _displayNameCtrl,
                label: 'Display Name *',
                hint: 'How you appear to others',
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              GacomTextField(
                controller: _usernameCtrl,
                label: 'Username *',
                hint: '@yourusername',
                prefixIcon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 16),
              GacomTextField(
                controller: _gamerTagCtrl,
                label: 'Gamer Tag',
                hint: 'Your in-game name',
                prefixIcon: Icons.sports_esports_rounded,
              ),
              const SizedBox(height: 16),
              GacomTextField(
                controller: _emailCtrl,
                label: 'Email *',
                hint: 'your@email.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              GacomTextField(
                controller: _passCtrl,
                label: 'Password *',
                hint: 'Min. 8 characters',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePass,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: GacomColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
                    activeColor: GacomColors.deepOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13),
                        children: [
                          const TextSpan(text: 'I agree to Gacom\'s '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: GacomColors.deepOrange,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' & '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: GacomColors.deepOrange,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              GacomButton(
                label: 'CREATE ACCOUNT',
                isLoading: _loading,
                onPressed: _register,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: GacomColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppConstants.loginRoute),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: GacomColors.deepOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
