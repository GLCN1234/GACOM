import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class GameDeveloperApplicationScreen extends StatefulWidget {
  const GameDeveloperApplicationScreen({super.key});
  @override
  State<GameDeveloperApplicationScreen> createState() => _GameDeveloperApplicationScreenState();
}

class _GameDeveloperApplicationScreenState extends State<GameDeveloperApplicationScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gameNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _demoLinkCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _gameNameCtrl.dispose();
    _descCtrl.dispose(); _genreCtrl.dispose(); _demoLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty ||
        _gameNameCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      GacomSnackbar.show(context, 'Please fill in your name, email, game name, and description', isError: true);
      return;
    }
    if (!_emailCtrl.text.contains('@')) {
      GacomSnackbar.show(context, 'Please enter a valid email', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await SupabaseService.client.from('game_developer_applications').insert({
        'developer_name': _nameCtrl.text.trim(),
        'developer_email': _emailCtrl.text.trim(),
        'game_name': _gameNameCtrl.text.trim(),
        'game_description': _descCtrl.text.trim(),
        'genre': _genreCtrl.text.trim().isEmpty ? null : _genreCtrl.text.trim(),
        'demo_link': _demoLinkCtrl.text.trim().isEmpty ? null : _demoLinkCtrl.text.trim(),
      });
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        GacomSnackbar.show(context, 'Could not submit: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('SUBMIT YOUR GAME')),
      body: _submitted ? _buildSuccessState() : _buildForm(),
    );
  }

  Widget _buildSuccessState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline_rounded, color: GacomColors.success, size: 64),
        const SizedBox(height: 20),
        const Text('Application submitted!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Our team reviews every submission. If yours is approved, we\'ll reach out at the email you provided.',
          textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),
        GacomButton(label: 'DONE', onPressed: () => Navigator.pop(context)),
      ]),
    ),
  );

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tell us about your game', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Every submission is reviewed by our team before anything goes live.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      const SizedBox(height: 24),
      GacomTextField(controller: _nameCtrl, label: 'Your Name *', hint: 'Full name', prefixIcon: Icons.person_outline_rounded),
      const SizedBox(height: 12),
      GacomTextField(controller: _emailCtrl, label: 'Your Email *', hint: 'you@example.com', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      GacomTextField(controller: _gameNameCtrl, label: 'Game Name *', hint: 'e.g. Word Rush', prefixIcon: Icons.sports_esports_outlined),
      const SizedBox(height: 12),
      GacomTextField(controller: _genreCtrl, label: 'Genre', hint: 'e.g. Puzzle, Card, Strategy', prefixIcon: Icons.category_outlined),
      const SizedBox(height: 12),
      GacomTextField(controller: _descCtrl, label: 'Description *', hint: 'What is it, how do you play, what makes it fun?', prefixIcon: Icons.description_outlined, maxLines: 4),
      const SizedBox(height: 12),
      GacomTextField(controller: _demoLinkCtrl, label: 'Demo / Build Link (optional)', hint: 'Link to a playable demo, video, or repo', prefixIcon: Icons.link_rounded),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: GacomButton(
        label: _submitting ? 'SUBMITTING...' : 'SUBMIT APPLICATION',
        onPressed: _submitting ? null : _submit,
      )),
    ]),
  );
}
