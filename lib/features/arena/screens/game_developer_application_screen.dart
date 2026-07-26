import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

// ── Developer Portal ────────────────────────────────────────────────────────
// ₦45,000/year to publish a game on GACOM. Covers review, hosting,
// distribution, and access to GACOM's user base and payment infra.
// Payment runs through the existing Paystack/wallet flow.

enum _Step { pricing, details, upload, submitted }

class GameDeveloperApplicationScreen extends StatefulWidget {
  const GameDeveloperApplicationScreen({super.key});
  @override State<GameDeveloperApplicationScreen> createState() => _GameDevState();
}

class _GameDevState extends State<GameDeveloperApplicationScreen> {
  _Step _step = _Step.pricing;
  bool _submitting = false;

  // Form fields
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _gameNameCtrl    = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _genreCtrl       = TextEditingController();
  final _demoLinkCtrl    = TextEditingController();
  final _revenueModelCtrl= TextEditingController();

  // File state (web-safe: we just store bytes + filename)
  String? _buildFileName;
  Uint8List? _buildBytes;
  String? _iconFileName;
  Uint8List? _iconBytes;
  String? _screenshotFileName;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _gameNameCtrl, _descCtrl, _genreCtrl, _demoLinkCtrl, _revenueModelCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isIcon) async {
    final result = await FilePicker.platform.pickFiles(
      type: isIcon ? FileType.image : FileType.any,
      withData: true,
    );
    if (result == null) return;
    final file = result.files.first;
    setState(() {
      if (isIcon) { _iconFileName = file.name; _iconBytes = file.bytes; }
      else { _buildFileName = file.name; _buildBytes = file.bytes; }
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty ||
        _gameNameCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      GacomSnackbar.show(context, 'Please fill in all required fields', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await SupabaseService.client.from('game_developer_applications').insert({
        'developer_name':  _nameCtrl.text.trim(),
        'developer_email': _emailCtrl.text.trim(),
        'game_name':       _gameNameCtrl.text.trim(),
        'game_description':_descCtrl.text.trim(),
        'genre':           _genreCtrl.text.trim().isEmpty ? null : _genreCtrl.text.trim(),
        'demo_link':       _demoLinkCtrl.text.trim().isEmpty ? null : _demoLinkCtrl.text.trim(),
        'admin_notes':     _revenueModelCtrl.text.trim().isEmpty ? null : 'Revenue model: ${_revenueModelCtrl.text.trim()}',
        'status': 'pending',
      });
      if (mounted) setState(() { _submitting = false; _step = _Step.submitted; });
    } catch (e) {
      if (mounted) { setState(() => _submitting = false); GacomSnackbar.show(context, 'Error: $e', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('DEVELOPER PORTAL')),
      body: _body(),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.pricing:    return _buildPricing();
      case _Step.details:    return _buildDetails();
      case _Step.upload:     return _buildUpload();
      case _Step.submitted:  return _buildSuccess();
    }
  }

  // ── Step 1: Pricing ───────────────────────────────────────────────────────
  Widget _buildPricing() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.rocket_launch_outlined, color: GacomColors.deepOrange, size: 28),
            SizedBox(width: 12),
            Text('GACOM DEVELOPER PLAN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
          ]),
          const SizedBox(height: 16),
          const Text('₦45,000', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 48, color: GacomColors.deepOrange)),
          const Text('per year', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          ...[
            '✅ Publish your game to GACOM\'s full player base',
            '✅ Access GACOM\'s built-in payment & wallet infrastructure',
            '✅ Add your own in-game purchases & monetisation',
            '✅ Appear in the Game Store with a featured listing',
            '✅ Real-time analytics & player statistics dashboard',
            '✅ Priority review by GACOM\'s game team (within 7 days)',
            '✅ GACOM Verified Developer badge on your profile',
            '✅ Access to multiplayer and tournament infrastructure',
          ].map((f) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(f, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.3)))),
        ])),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.2))),
        child: const Text('💡 Your game can include its own payment system, subscriptions, or virtual currency — GACOM does not take any cut of your in-game revenue. The ₦45,000 is purely the annual platform listing fee.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.5))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => setState(() => _step = _Step.details),
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('GET STARTED — ₦45,000/year', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
      const SizedBox(height: 12),
      Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now', style: TextStyle(color: GacomColors.textMuted)))),
    ]),
  );

  // ── Step 2: Game Details ──────────────────────────────────────────────────
  Widget _buildDetails() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepIndicator(current: 1, total: 2, labels: const ['Game Details', 'Upload Files']),
      const SizedBox(height: 24),
      const Text('ABOUT YOUR GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textMuted, letterSpacing: 1)),
      const SizedBox(height: 12),
      GacomTextField(controller: _nameCtrl, label: 'Your Name *', hint: 'Full name', prefixIcon: Icons.person_outline_rounded),
      const SizedBox(height: 12),
      GacomTextField(controller: _emailCtrl, label: 'Email Address *', hint: 'you@example.com', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      GacomTextField(controller: _gameNameCtrl, label: 'Game Name *', hint: 'e.g. Space Warriors', prefixIcon: Icons.sports_esports_outlined),
      const SizedBox(height: 12),
      GacomTextField(controller: _genreCtrl, label: 'Genre', hint: 'e.g. Puzzle, Action, Strategy', prefixIcon: Icons.category_outlined),
      const SizedBox(height: 12),
      GacomTextField(controller: _descCtrl, label: 'Game Description *', hint: 'Describe your game, how it\'s played, and what makes it unique...', prefixIcon: Icons.description_outlined, maxLines: 4),
      const SizedBox(height: 12),
      GacomTextField(controller: _demoLinkCtrl, label: 'Demo / Playable Link (optional)', hint: 'https://...', prefixIcon: Icons.link_rounded),
      const SizedBox(height: 12),
      GacomTextField(controller: _revenueModelCtrl, label: 'Revenue Model', hint: 'e.g. Free, In-app purchases, Subscription...', prefixIcon: Icons.monetization_on_outlined),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () {
          if (_gameNameCtrl.text.isEmpty || _descCtrl.text.isEmpty) { GacomSnackbar.show(context, 'Please fill in the required fields', isError: true); return; }
          setState(() => _step = _Step.upload);
        },
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('NEXT: UPLOAD FILES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
    ]),
  );

  // ── Step 3: Upload ────────────────────────────────────────────────────────
  Widget _buildUpload() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepIndicator(current: 2, total: 2, labels: const ['Game Details', 'Upload Files']),
      const SizedBox(height: 24),
      const Text('UPLOAD YOUR GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textMuted, letterSpacing: 1)),
      const SizedBox(height: 4),
      const Text('Accepted: Flutter/Dart source (.zip), APK/AAB, or a web build folder (.zip)', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      const SizedBox(height: 16),
      _UploadTile(
        label: 'Game Build *',
        hint: 'ZIP, APK, or AAB file',
        icon: Icons.folder_zip_outlined,
        fileName: _buildFileName,
        onTap: () => _pickFile(false),
      ),
      const SizedBox(height: 12),
      _UploadTile(
        label: 'Game Icon *',
        hint: 'PNG/JPG, min 512×512px',
        icon: Icons.image_outlined,
        fileName: _iconFileName,
        onTap: () => _pickFile(true),
      ),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REVIEW PROCESS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
          const SizedBox(height: 8),
          ...[
            '1. Submit application + payment confirmation',
            '2. GACOM reviews within 7 business days',
            '3. Feedback or approval sent to your email',
            '4. Approved games go live in the Game Store',
          ].map((s) => Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Text(s, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _submitting
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Text('SUBMIT APPLICATION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
      const SizedBox(height: 8),
      Center(child: TextButton(onPressed: () => setState(() => _step = _Step.details), child: const Text('← Back', style: TextStyle(color: GacomColors.textMuted)))),
    ]),
  );

  // ── Step 4: Success ───────────────────────────────────────────────────────
  Widget _buildSuccess() => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.verified_outlined, color: GacomColors.success, size: 72),
      const SizedBox(height: 20),
      const Text('Application Submitted!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      const Text('Our team will review your game within 7 business days. You\'ll receive feedback or an approval at the email you provided.\n\nWelcome to the GACOM Developer Community 🎮', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      GacomButton(label: 'DONE', onPressed: () => Navigator.pop(context)),
    ])),
  );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current, total;
  final List<String> labels;
  const _StepIndicator({required this.current, required this.total, required this.labels});
  @override
  Widget build(BuildContext context) => Row(children: List.generate(total, (i) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(children: [
    Row(children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: i < current ? GacomColors.success : i == current ? GacomColors.deepOrange : GacomColors.elevatedCard),
        child: Center(child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)))),
      if (i < total - 1) Expanded(child: Container(height: 1, color: i < current ? GacomColors.success : GacomColors.border)),
    ]),
    const SizedBox(height: 4),
    Text(labels[i], style: TextStyle(fontSize: 10, color: i == current ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
  ])))));
}

class _UploadTile extends StatelessWidget {
  final String label, hint; final IconData icon; final String? fileName; final VoidCallback onTap;
  const _UploadTile({required this.label, required this.hint, required this.icon, required this.fileName, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: fileName != null ? GacomColors.success : GacomColors.border, width: fileName != null ? 1.5 : 1)),
      child: Row(children: [
        Icon(fileName != null ? Icons.check_circle_rounded : icon, color: fileName != null ? GacomColors.success : GacomColors.textMuted, size: 24),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
          Text(fileName ?? hint, style: TextStyle(color: fileName != null ? GacomColors.success : GacomColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
        ])),
        const Icon(Icons.upload_rounded, color: GacomColors.textMuted, size: 20),
      ])),
  );
}
