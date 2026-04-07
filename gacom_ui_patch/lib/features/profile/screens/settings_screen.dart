import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: GacomColors.border),
        ),
      ),
      body: _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final p = await SupabaseService.client.from('profiles').select('*').eq('id', userId).single();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final isVerified = p?['verification_status'] == 'verified';
    final verPending = p?['verification_status'] == 'pending';

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Profile header card
        if (p != null) _ProfileHeaderCard(profile: p),

        const SizedBox(height: 8),

        // Verification Banner
        if (!isVerified && !verPending)
          _VerificationBanner(onTap: () {
            _showVerificationSheet(context);
          }).animate().fadeIn(delay: 100.ms),

        if (verPending)
          _PendingBanner().animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 4),

        // Run an Ad CTA
        _AdsBanner(onTap: () => _showAdsSheet(context)).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: 8),

        _SectionHeader('Account'),
        _SettingsTile(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: () {}),
        _SettingsTile(icon: Icons.lock_outline_rounded, title: 'Change Password', onTap: () {}),
        _SettingsTile(icon: Icons.account_balance_wallet_outlined, title: 'Bank Accounts', subtitle: 'Manage payout accounts', onTap: () {}),
        _SettingsTile(icon: Icons.history_rounded, title: 'Transaction History', onTap: () => context.go(AppConstants.walletRoute)),

        _SectionHeader('Promotions'),
        _SettingsTile(
          icon: Icons.campaign_outlined,
          title: 'Run an Ad',
          subtitle: 'Boost your profile or post',
          onTap: () => _showAdsSheet(context),
          accent: true,
        ),
        _SettingsTile(
          icon: Icons.verified_outlined,
          title: isVerified ? 'Verified Account' : verPending ? 'Verification Pending' : 'Get Verified',
          subtitle: isVerified ? 'Your account is verified' : verPending ? 'Under review — usually 24–48 hrs' : 'Get the orange badge · ₦${AppConstants.verificationFee}',
          onTap: isVerified ? null : () => _showVerificationSheet(context),
          trailingWidget: isVerified
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(20)),
                  child: const Text('VERIFIED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.8, color: Colors.white)),
                )
              : null,
        ),

        _SectionHeader('Preferences'),
        _SettingsTile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),
        _SettingsTile(icon: Icons.privacy_tip_outlined, title: 'Privacy & Safety', onTap: () {}),
        _SettingsTile(icon: Icons.language_rounded, title: 'Language', subtitle: 'English', onTap: () {}),
        _SettingsTile(icon: Icons.dark_mode_outlined, title: 'Appearance', subtitle: 'Dark mode', onTap: () {}),

        _SectionHeader('Support'),
        _SettingsTile(icon: Icons.help_outline_rounded, title: 'Help Center', onTap: () {}),
        _SettingsTile(icon: Icons.bug_report_outlined, title: 'Report a Bug', onTap: () {}),
        _SettingsTile(icon: Icons.info_outline_rounded, title: 'About Gacom', subtitle: 'Version 1.0.0', onTap: () {}),
        _SettingsTile(icon: Icons.description_outlined, title: 'Terms & Privacy Policy', onTap: () {}),

        _SectionHeader('Danger Zone'),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          isDestructive: true,
          onTap: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go(AppConstants.loginRoute);
          },
        ),
        _SettingsTile(
          icon: Icons.delete_outline_rounded,
          title: 'Delete Account',
          subtitle: 'This action is permanent',
          isDestructive: true,
          onTap: () => GacomSnackbar.show(context, 'Please contact support to delete your account', isError: false),
        ),
      ],
    );
  }

  void _showVerificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VerificationSheet(),
    );
  }

  void _showAdsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdsSheet(),
    );
  }
}

// ─── Profile Header Card ────────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileHeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isVerified = profile['verification_status'] == 'verified';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GacomColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isVerified ? GacomColors.orangeGradient : null,
              color: isVerified ? null : GacomColors.border,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: GacomColors.surfaceDark,
              backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
              child: profile['avatar_url'] == null
                  ? Text((profile['display_name'] ?? 'G')[0], style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 24, color: GacomColors.textPrimary))
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(profile['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
                if (isVerified) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.verified_rounded, color: GacomColors.deepOrange, size: 15),
                ],
              ]),
              Text('@${profile['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GacomColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GacomColors.border, width: 0.8),
            ),
            child: Text(
              '₦${((profile['wallet_balance'] as num?) ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Verification Banner ────────────────────────────────────────────────────

class _VerificationBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _VerificationBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [GacomColors.deepOrange.withOpacity(0.15), GacomColors.obsidian],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GacomColors.borderOrange, width: 1),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Get Verified on Gacom', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
            Text('Unlock the orange badge · Build trust · ₦2,000 one-time fee', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: GacomColors.textMuted),
        ]),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GacomColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GacomColors.warning.withOpacity(0.3), width: 0.8),
      ),
      child: Row(children: const [
        Icon(Icons.schedule_rounded, color: GacomColors.warning, size: 20),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Verification Pending', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
          Text('Your request is under review. Usually 24–48 hours.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ─── Ads Banner ─────────────────────────────────────────────────────────────

class _AdsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AdsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GacomColors.borderBright, width: 0.8),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GacomColors.info.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_outlined, color: GacomColors.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Promote Your Content', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
            Text('Reach more gamers with targeted ads', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Text('BOOST', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8, color: GacomColors.info)),
          ),
        ]),
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.textMuted, letterSpacing: 2),
      ),
    );
  }
}

// ─── Settings Tile ───────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool accent;
  final Widget? trailingWidget;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
    this.accent = false,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive
        ? GacomColors.error
        : accent
            ? GacomColors.deepOrange
            : GacomColors.textSecondary;
    final textColor = isDestructive ? GacomColors.error : GacomColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: GacomColors.deepOrange.withOpacity(0.05),
        highlightColor: GacomColors.deepOrange.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDestructive
                    ? GacomColors.error.withOpacity(0.08)
                    : accent
                        ? GacomColors.deepOrange.withOpacity(0.08)
                        : GacomColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 16)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.3)),
              ],
            )),
            trailingWidget ?? Icon(Icons.chevron_right_rounded, color: onTap != null ? GacomColors.textMuted : Colors.transparent, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─── Verification Sheet ──────────────────────────────────────────────────────

class _VerificationSheet extends StatefulWidget {
  const _VerificationSheet();

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  String? _idType;
  final _idNumberCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      // First deduct fee
      await SupabaseService.client.from('verification_requests').insert({
        'user_id': userId,
        'full_name': _nameCtrl.text.trim(),
        'id_type': _idType ?? 'NIN',
        'id_number': _idNumberCtrl.text.trim(),
        'id_front_url': 'pending_upload',
        'selfie_url': 'pending_upload',
        'status': 'pending',
      });
      await SupabaseService.client.from('profiles').update({'verification_status': 'pending'}).eq('id', userId);
      if (mounted) {
        Navigator.pop(context);
        GacomSnackbar.show(context, 'Verification request submitted!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GacomSnackbar.show(context, 'Failed to submit request', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.verified_rounded, color: Colors.white, size: 22)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Get Verified', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 22, color: GacomColors.textPrimary)),
                Text('One-time fee: ₦2,000', style: TextStyle(color: GacomColors.deepOrange, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 20),
            // Steps
            _StepIndicator(currentStep: _step),
            const SizedBox(height: 24),
            if (_step == 0) ..._buildStep0() else if (_step == 1) ..._buildStep1() else ..._buildStep2(),
            const SizedBox(height: 24),
            if (_step < 2)
              SizedBox(
                width: double.infinity,
                child: _GradientButton(
                  label: 'CONTINUE',
                  onTap: () => setState(() => _step++),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: _GradientButton(
                  label: 'SUBMIT & PAY ₦2,000',
                  loading: _loading,
                  onTap: _submit,
                ),
              ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildStep0() => [
    const Text('Why get verified?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
    const SizedBox(height: 12),
    ...[
      ('🏅', 'Orange verified badge on your profile'),
      ('🔒', 'Protect your identity from impersonators'),
      ('⬆️', 'Priority ranking in search results'),
      ('💰', 'Access to paid competitions and exclusive features'),
    ].map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(item.$1, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text(item.$2, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14)),
      ]),
    )),
  ];

  List<Widget> _buildStep1() => [
    const Text('Your Information', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
    const SizedBox(height: 16),
    TextField(
      controller: _nameCtrl,
      style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 15),
      decoration: const InputDecoration(labelText: 'Full Legal Name', prefixIcon: Icon(Icons.person_outline)),
    ),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      value: _idType,
      dropdownColor: GacomColors.elevatedCard,
      style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 15),
      decoration: const InputDecoration(labelText: 'ID Type', prefixIcon: Icon(Icons.badge_outlined)),
      items: ['NIN', 'International Passport', 'Drivers License', 'Voters Card']
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) => setState(() => _idType = v),
    ),
    const SizedBox(height: 14),
    TextField(
      controller: _idNumberCtrl,
      style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 15),
      decoration: const InputDecoration(labelText: 'ID Number', prefixIcon: Icon(Icons.numbers_rounded)),
    ),
  ];

  List<Widget> _buildStep2() => [
    const Text('Final Step', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
    const SizedBox(height: 12),
    const Text('Upload a photo of your ID card and a selfie holding it. Documents are reviewed by our team within 24–48 hours.',
        style: TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.5)),
    const SizedBox(height: 20),
    _UploadBox(icon: Icons.credit_card_outlined, label: 'ID Card (Front)', onTap: () {}),
    const SizedBox(height: 12),
    _UploadBox(icon: Icons.face_outlined, label: 'Selfie with ID', onTap: () {}),
  ];
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['Overview', 'Identity', 'Documents'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 1, color: i ~/ 2 < currentStep ? GacomColors.deepOrange : GacomColors.border));
        }
        final step = i ~/ 2;
        final isDone = step < currentStep;
        final isActive = step == currentStep;
        return Column(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? GacomColors.deepOrange : isActive ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
              border: Border.all(color: isActive || isDone ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : Text('${step + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: isActive ? GacomColors.deepOrange : GacomColors.textMuted)),
            ),
          ),
          const SizedBox(height: 4),
          Text(steps[step], style: TextStyle(fontFamily: 'Rajdhani', fontSize: 10, letterSpacing: 0.5, color: isActive || isDone ? GacomColors.textPrimary : GacomColors.textMuted)),
        ]);
      }),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _UploadBox({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: GacomColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GacomColors.border, width: 1, style: BorderStyle.solid),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: GacomColors.textMuted, size: 22),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Icon(Icons.upload_rounded, color: GacomColors.deepOrange, size: 18),
        ]),
      ),
    );
  }
}

// ─── Ads Sheet ───────────────────────────────────────────────────────────────

class _AdsSheet extends StatefulWidget {
  const _AdsSheet();

  @override
  State<_AdsSheet> createState() => _AdsSheetState();
}

class _AdsSheetState extends State<_AdsSheet> {
  String _adType = 'profile';
  String _budget = '₦1,000';
  int _duration = 3;

  final _budgets = ['₦500', '₦1,000', '₦2,500', '₦5,000', '₦10,000'];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.campaign_outlined, color: GacomColors.info, size: 22)),
              const SizedBox(width: 14),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Promote on Gacom', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 22, color: GacomColors.textPrimary)),
                Text('Reach thousands of gamers', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 24),
            const Text('What do you want to promote?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
            const SizedBox(height: 12),
            Row(children: [
              _AdTypeBtn(icon: Icons.person_outline, label: 'Profile', selected: _adType == 'profile', onTap: () => setState(() => _adType = 'profile')),
              const SizedBox(width: 10),
              _AdTypeBtn(icon: Icons.image_outlined, label: 'Post', selected: _adType == 'post', onTap: () => setState(() => _adType = 'post')),
              const SizedBox(width: 10),
              _AdTypeBtn(icon: Icons.play_circle_outline, label: 'Clip', selected: _adType == 'clip', onTap: () => setState(() => _adType = 'clip')),
            ]),
            const SizedBox(height: 20),
            const Text('Budget', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: _budgets.map((b) => GestureDetector(
              onTap: () => setState(() => _budget = b),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _budget == b ? GacomColors.deepOrange.withOpacity(0.12) : GacomColors.surfaceDark,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: _budget == b ? GacomColors.deepOrange : GacomColors.border, width: 1),
                ),
                child: Text(b, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: _budget == b ? GacomColors.deepOrange : GacomColors.textSecondary)),
              ),
            )).toList()),
            const SizedBox(height: 20),
            Row(children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Duration', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                Text('How many days', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ]),
              const Spacer(),
              Row(children: [
                _IconCircleBtn(icon: Icons.remove_rounded, onTap: () { if (_duration > 1) setState(() => _duration--); }),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_duration days', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary))),
                _IconCircleBtn(icon: Icons.add_rounded, onTap: () { if (_duration < 30) setState(() => _duration++); }),
              ]),
            ]),
            const SizedBox(height: 20),
            // Estimate
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.8)),
              child: Row(children: [
                const Icon(Icons.bar_chart_rounded, color: GacomColors.textMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estimated Reach', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                  Text('2,000 – 8,000 gamers', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_budget, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.success))),
              ]),
            ),
            const SizedBox(height: 24),
            _GradientButton(
              label: 'LAUNCH CAMPAIGN',
              onTap: () {
                Navigator.pop(context);
                GacomSnackbar.show(context, 'Ad campaign submitted for review!', isError: false);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _AdTypeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AdTypeBtn({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? GacomColors.deepOrange.withOpacity(0.1) : GacomColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? GacomColors.deepOrange : GacomColors.border, width: selected ? 1.5 : 0.8),
          ),
          child: Column(children: [
            Icon(icon, color: selected ? GacomColors.deepOrange : GacomColors.textSecondary, size: 22),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5, color: selected ? GacomColors.deepOrange : GacomColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

class _IconCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GacomColors.border, width: 1),
          color: GacomColors.surfaceDark,
        ),
        child: Icon(icon, color: GacomColors.textSecondary, size: 16),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _GradientButton({required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: GacomColors.orangeGradient,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5, color: Colors.white)),
        ),
      ),
    );
  }
}
