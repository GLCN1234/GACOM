import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

/// Landing page for the links in sign-up, reset and sign-in emails.
///
/// The email links point at gamicom.net (not at the Supabase address):
///   https://gamicom.net/#/auth/confirm?token_hash=...&type=signup
/// This screen swaps the token for a session with verifyOTP and moves on.
class AuthConfirmScreen extends StatefulWidget {
  final String? tokenHash;
  final String? type;
  const AuthConfirmScreen({super.key, this.tokenHash, this.type});

  @override
  State<AuthConfirmScreen> createState() => _AuthConfirmScreenState();
}

class _AuthConfirmScreenState extends State<AuthConfirmScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  OtpType? _otp(String? t) {
    switch (t) {
      case 'signup':
        return OtpType.signup;
      case 'recovery':
        return OtpType.recovery;
      case 'magiclink':
        return OtpType.magiclink;
      case 'invite':
        return OtpType.invite;
      case 'email_change':
        return OtpType.emailChange;
      case 'email':
        return OtpType.email;
    }
    return null;
  }

  Future<void> _run() async {
    final String? hash = widget.tokenHash;
    final OtpType? type = _otp(widget.type);
    if (hash == null || hash.isEmpty || type == null) {
      setState(() => _error = 'This link is not valid. Please request a new email.');
      return;
    }
    try {
      await Supabase.instance.client.auth.verifyOTP(tokenHash: hash, type: type);
      if (!mounted) return;
      if (type == OtpType.recovery) {
        context.go('/reset-password');
      } else {
        context.go('/home');
      }
    } on AuthException catch (_) {
      if (mounted) setState(() => _error = 'This link has expired or was already used. Please request a new email.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _error == null
                ? const Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    CircularProgressIndicator(color: GacomColors.deepOrange),
                    SizedBox(height: 18),
                    Text('Confirming...', style: TextStyle(color: GacomColors.textSecondary, fontSize: 15)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    const Icon(Icons.link_off_rounded, color: GacomColors.textMuted, size: 40),
                    const SizedBox(height: 14),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 15)),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () => context.go('/login'), child: const Text('Go to login')),
                  ]),
          ),
        ),
      ),
    );
  }
}
