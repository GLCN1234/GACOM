import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

// Theme mode provider
final themeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _notifPosts = true;
  bool _notifCompetitions = true;
  bool _notifMessages = true;
  bool _notifWallet = true;
  bool _privateAccount = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final p = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.currentUser?.email ?? '';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          // Profile card
          _buildProfileCard(email),

          const SizedBox(height: 24),
          _SectionLabel('ACCOUNT'),
          _SettingsGroup([
            _Tile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              onTap: () => _showEditProfile(context),
            ),
            _Tile(
              icon: Icons.alternate_email_rounded,
              label: 'Change Username',
              onTap: () => _showChangeUsername(context),
            ),
            _Tile(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              onTap: () => _showChangePassword(context),
            ),
            _Tile(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              subtitle: email,
              onTap: () {},
            ),
          ]).animate(delay: 60.ms).fadeIn(),

          const SizedBox(height: 20),
          _SectionLabel('GAMING'),
          _SettingsGroup([
            _Tile(
              icon: Icons.sports_esports_rounded,
              label: 'Gamer Tag',
              subtitle: _profile?['gamer_tag'] ?? 'Not set',
              onTap: () => _showGamerTag(context),
            ),
            _Tile(
              icon: Icons.emoji_events_rounded,
              label: 'My Competitions',
              onTap: () => context.go(AppConstants.competitionsRoute),
            ),
            _Tile(
              icon: Icons.storefront_rounded,
              label: 'Marketplace',
              subtitle: 'Buy & sell gaming gear',
              onTap: () => context.go(AppConstants.storeRoute),
            ),
            _Tile(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Wallet & Payments',
              onTap: () => context.go(AppConstants.walletRoute),
            ),
            _Tile(
              icon: Icons.account_balance_outlined,
              label: 'Bank Withdrawal',
              subtitle: 'Add bank account',
              onTap: () => _showBankWithdrawal(context),
            ),
          ]).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 20),
          _SectionLabel('VERIFICATION'),
          _buildVerificationCard(context),

          const SizedBox(height: 20),
          _SectionLabel('PREFERENCES'),
          _SettingsGroup([
            _TileExpand(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              child: _buildNotifSection(),
            ),
            _TileExpand(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy & Safety',
              child: _buildPrivacySection(),
            ),
            _Tile(
              icon: Icons.language_rounded,
              label: 'Language',
              subtitle: 'English',
              onTap: () => _showLanguagePicker(context),
            ),
            _TileSwitch(
              icon: Icons.dark_mode_outlined,
              label: 'Dark Mode',
              value: isDark,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).state =
                    v ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ]).animate(delay: 140.ms).fadeIn(),

          const SizedBox(height: 20),
          _SectionLabel('SUPPORT'),
          _SettingsGroup([
            _Tile(
              icon: Icons.help_outline_rounded,
              label: 'Help Center',
              onTap: () => _showHelpCenter(context),
            ),
            _Tile(
              icon: Icons.policy_outlined,
              label: 'Privacy Policy',
              onTap: () => _showPrivacyPolicy(context),
            ),
            _Tile(
              icon: Icons.bug_report_outlined,
              label: 'Report a Bug',
              onTap: () => _showReportBug(context),
            ),
            _Tile(
              icon: Icons.support_agent_rounded,
              label: 'Contact Support',
              onTap: () => context.go(AppConstants.supportRoute),
            ),
            _Tile(
              icon: Icons.campaign_outlined,
              label: 'Advertise on Gacom',
              onTap: () => context.go('/ads'),
            ),
            _Tile(
              icon: Icons.info_outline_rounded,
              label: 'About Gacom',
              subtitle: 'Version ${AppConstants.appVersion}',
              onTap: () => _showAbout(context),
            ),
          ]).animate(delay: 180.ms).fadeIn(),

          const SizedBox(height: 20),
          _SectionLabel('DANGER ZONE'),
          _SettingsGroup([
            _Tile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: GacomColors.error,
              onTap: () => _confirmSignOut(context),
            ),
            _Tile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Account',
              color: GacomColors.error,
              onTap: () => GacomSnackbar.show(
                  context, 'Contact support to delete account'),
            ),
          ]).animate(delay: 220.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String email) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: GacomDecorations.neonCard(context, radius: 20),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
              gradient: GacomColors.orangeGradient,
              shape: BoxShape.circle),
          child: _profile?['avatar_url'] != null
              ? ClipOval(
                  child: Image.network(_profile!['avatar_url'],
                      fit: BoxFit.cover, width: 52, height: 52))
              : Center(
                  child: Text(
                    ((_profile?['display_name'] ?? email)[0])
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 22),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(_profile?['display_name'] ?? 'Gamer',
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: GacomColors.textPrimary)),
          Text(email,
              style: const TextStyle(
                  color: GacomColors.textMuted, fontSize: 12)),
        ])),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: GacomColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border:
                Border.all(color: GacomColors.success.withOpacity(0.3)),
          ),
          child: const Text('ACTIVE',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: GacomColors.success,
                  letterSpacing: 0.8)),
        ),
      ]),
    );
  }

  Widget _buildVerificationCard(BuildContext context) {
    final status =
        _profile?['verification_status'] as String? ?? 'unverified';
    Color color = status == 'verified'
        ? GacomColors.success
        : status == 'pending'
            ? GacomColors.warning
            : GacomColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GacomColors.border, width: 0.5)),
      child: Row(children: [
        Icon(Icons.verified_rounded, color: color, size: 32),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(
              status == 'verified'
                  ? 'Account Verified'
                  : status == 'pending'
                      ? 'Verification Pending'
                      : 'Get Verified',
              style: TextStyle(
                  color: color,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const Text(
              'Verified users can create sub-communities',
              style: TextStyle(
                  color: GacomColors.textMuted, fontSize: 12)),
        ])),
        if (status == 'unverified')
          GestureDetector(
            onTap: () => _requestVerification(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  gradient: GacomColors.orangeGradient,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('APPLY',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ),
      ]),
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _buildNotifSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        _NotifToggle('New posts from following', _notifPosts,
            (v) => setState(() => _notifPosts = v)),
        _NotifToggle('Competition updates', _notifCompetitions,
            (v) => setState(() => _notifCompetitions = v)),
        _NotifToggle('Messages', _notifMessages,
            (v) => setState(() => _notifMessages = v)),
        _NotifToggle('Wallet activity', _notifWallet,
            (v) => setState(() => _notifWallet = v)),
      ]),
    );
  }

  Widget _buildPrivacySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _NotifToggle('Private Account', _privateAccount,
          (v) async {
        setState(() => _privateAccount = v);
        await SupabaseService.client.from('profiles').update(
            {'is_private': v}).eq('id', SupabaseService.currentUserId!);
      }),
    );
  }

  // ── Action sheets ──────────────────────────────────────────────────

  void _showEditProfile(BuildContext context) {
    final nameCtrl =
        TextEditingController(text: _profile?['display_name'] ?? '');
    final bioCtrl = TextEditingController(text: _profile?['bio'] ?? '');
    final locCtrl =
        TextEditingController(text: _profile?['location'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Edit Profile'),
          const SizedBox(height: 16),
          GacomTextField(
              controller: nameCtrl,
              label: 'Display Name',
              hint: '',
              prefixIcon: Icons.person_rounded),
          const SizedBox(height: 12),
          GacomTextField(
              controller: bioCtrl,
              label: 'Bio',
              hint: '',
              prefixIcon: Icons.info_outline_rounded,
              maxLines: 3),
          const SizedBox(height: 12),
          GacomTextField(
              controller: locCtrl,
              label: 'Location',
              hint: 'e.g. Lagos, Nigeria',
              prefixIcon: Icons.location_on_rounded),
          const SizedBox(height: 24),
          GacomButton(
            label: 'SAVE',
            onPressed: () async {
              await SupabaseService.client.from('profiles').update({
                'display_name': nameCtrl.text.trim(),
                'bio': bioCtrl.text.trim(),
                'location': locCtrl.text.trim(),
              }).eq('id', SupabaseService.currentUserId!);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                GacomSnackbar.show(context, 'Profile updated ✅',
                    isSuccess: true);
                await _loadProfile();
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showChangeUsername(BuildContext context) {
    final ctrl = TextEditingController(text: _profile?['username'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Change Username'),
          const SizedBox(height: 6),
          const Text('Choose carefully — others find you by this.',
              style:
                  TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          GacomTextField(
              controller: ctrl,
              label: 'Username',
              hint: 'no spaces, letters & numbers only',
              prefixIcon: Icons.alternate_email_rounded),
          const SizedBox(height: 24),
          GacomButton(
            label: 'UPDATE USERNAME',
            onPressed: () async {
              final uname = ctrl.text
                  .trim()
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9_]'), '');
              if (uname.length < 3) {
                GacomSnackbar.show(ctx, 'Min 3 characters', isError: true);
                return;
              }
              try {
                await SupabaseService.client
                    .from('profiles')
                    .update({'username': uname}).eq(
                        'id', SupabaseService.currentUserId!);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  GacomSnackbar.show(
                      context, 'Username updated ✅',
                      isSuccess: true);
                  await _loadProfile();
                }
              } catch (_) {
                GacomSnackbar.show(ctx, 'Username taken or invalid',
                    isError: true);
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Change Password'),
          const SizedBox(height: 16),
          GacomTextField(
              controller: newCtrl,
              label: 'New Password',
              hint: 'Min 8 characters',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true),
          const SizedBox(height: 12),
          GacomTextField(
              controller: confirmCtrl,
              label: 'Confirm Password',
              hint: '',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true),
          const SizedBox(height: 24),
          GacomButton(
            label: 'UPDATE PASSWORD',
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                GacomSnackbar.show(ctx, 'Passwords do not match',
                    isError: true);
                return;
              }
              if (newCtrl.text.length < 8) {
                GacomSnackbar.show(ctx, 'Min 8 characters',
                    isError: true);
                return;
              }
              try {
                await Supabase.instance.client.auth
                    .updateUser(UserAttributes(password: newCtrl.text));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  GacomSnackbar.show(
                      context, 'Password updated ✅',
                      isSuccess: true);
                }
              } catch (_) {
                GacomSnackbar.show(ctx, 'Failed. Try logging out first.',
                    isError: true);
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showGamerTag(BuildContext context) {
    final ctrl =
        TextEditingController(text: _profile?['gamer_tag'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Gamer Tag'),
          const SizedBox(height: 16),
          GacomTextField(
              controller: ctrl,
              label: 'Gamer Tag',
              hint: 'Your in-game identity',
              prefixIcon: Icons.sports_esports_rounded),
          const SizedBox(height: 24),
          GacomButton(
            label: 'SAVE',
            onPressed: () async {
              await SupabaseService.client
                  .from('profiles')
                  .update({'gamer_tag': ctrl.text.trim()}).eq(
                      'id', SupabaseService.currentUserId!);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                GacomSnackbar.show(context, 'Gamer tag updated ✅',
                    isSuccess: true);
                await _loadProfile();
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showBankWithdrawal(BuildContext context) {
    final accountCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Bank Account for Withdrawal'),
          const SizedBox(height: 16),
          GacomTextField(
              controller: nameCtrl,
              label: 'Account Name',
              hint: 'Full name as on bank',
              prefixIcon: Icons.person_rounded),
          const SizedBox(height: 12),
          GacomTextField(
              controller: accountCtrl,
              label: 'Account Number',
              hint: '10 digits',
              prefixIcon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          GacomTextField(
              controller: bankCtrl,
              label: 'Bank Name',
              hint: 'e.g. GTBank, Opay',
              prefixIcon: Icons.account_balance_rounded),
          const SizedBox(height: 24),
          GacomButton(
            label: 'SAVE ACCOUNT',
            onPressed: () async {
              try {
                await SupabaseService.client
                    .from('bank_accounts')
                    .upsert({
                  'user_id': SupabaseService.currentUserId,
                  'account_name': nameCtrl.text.trim(),
                  'account_number': accountCtrl.text.trim(),
                  'bank_name': bankCtrl.text.trim(),
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  GacomSnackbar.show(
                      context, 'Bank account saved ✅',
                      isSuccess: true);
                }
              } catch (_) {
                GacomSnackbar.show(ctx, 'Failed to save', isError: true);
              }
            },
          ),
        ]),
      ),
    );
  }

  void _requestVerification(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_rounded,
              color: GacomColors.deepOrange, size: 48),
          const SizedBox(height: 12),
          const Text('Get Verified',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'Verification costs ₦2,000. Verified users can create sub-communities and get a verified badge.',
              style: TextStyle(
                  color: GacomColors.textMuted, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GacomButton(
            label: 'APPLY FOR ₦2,000',
            onPressed: () async {
              await SupabaseService.client
                  .from('verification_requests')
                  .insert({
                'user_id': SupabaseService.currentUserId,
                'status': 'pending',
              });
              await SupabaseService.client.from('profiles').update(
                  {'verification_status': 'pending'}).eq(
                  'id', SupabaseService.currentUserId!);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                GacomSnackbar.show(context, 'Verification request sent ✅',
                    isSuccess: true);
                await _loadProfile();
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Language'),
          const SizedBox(height: 16),
          ...['English', 'Yoruba', 'Igbo', 'Hausa', 'Pidgin']
              .map((l) => ListTile(
                    title: Text(l,
                        style: const TextStyle(
                            color: GacomColors.textPrimary)),
                    trailing: l == 'English'
                        ? const Icon(Icons.check_rounded,
                            color: GacomColors.deepOrange)
                        : null,
                    onTap: () => Navigator.pop(context),
                  )),
        ]),
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const _HelpCenterScreen()));
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const _PrivacyPolicyScreen()));
  }

  void _showReportBug(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetTitle('Report a Bug'),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            maxLines: 5,
            style: const TextStyle(color: GacomColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Describe the bug in detail. Include steps to reproduce...',
              hintStyle:
                  const TextStyle(color: GacomColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: GacomColors.surfaceDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: GacomColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: GacomColors.border)),
            ),
          ),
          const SizedBox(height: 24),
          GacomButton(
            label: 'SUBMIT REPORT',
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await SupabaseService.client.from('bug_reports').insert({
                'user_id': SupabaseService.currentUserId,
                'description': ctrl.text.trim(),
                'app_version': AppConstants.appVersion,
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                GacomSnackbar.show(
                    context, 'Bug reported! Thanks 🐛',
                    isSuccess: true);
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipOval(
            child: Image.network(AppConstants.logoUrl,
                width: 72, height: 72, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                          gradient: GacomColors.orangeGradient,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.sports_esports_rounded,
                          color: Colors.white, size: 36),
                    )),
          ),
          const SizedBox(height: 12),
          const Text('GACOM',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GacomColors.textPrimary,
                  letterSpacing: 4)),
          const Text('Game. Connect. Dominate.',
              style:
                  TextStyle(color: GacomColors.deepOrange, fontSize: 13)),
          const SizedBox(height: 8),
          Text('Version ${AppConstants.appVersion}',
              style: const TextStyle(
                  color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          const Text(
              'GACOM is Africa\'s premier social gaming platform for competitive gamers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: GacomColors.textSecondary,
                  fontSize: 13,
                  height: 1.5)),
        ]),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Sign Out',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                color: GacomColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: GacomColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go(AppConstants.loginRoute);
            },
            child: const Text('SIGN OUT',
                style: TextStyle(
                    color: GacomColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Help Center Screen ────────────────────────────────────────────────────────
class _HelpCenterScreen extends StatelessWidget {
  const _HelpCenterScreen();
  @override
  Widget build(BuildContext context) {
    final faqs = [
      (
        'How do I fund my wallet?',
        'Go to Wallet → Fund Wallet. Choose an amount or enter custom. We use Paystack for secure payments. You\'ll be redirected to Paystack\'s payment page. After success, your balance updates within minutes.'
      ),
      (
        'How do I join a competition?',
        'Go to Competitions → tap any competition. Read the details and tap "Enter Competition". For paid competitions, entry fee is deducted from your wallet. Ensure you have enough balance first.'
      ),
      (
        'How do I get verified?',
        'Go to Settings → Verification → Apply. A ₦2,000 fee applies. The admin team reviews within 48 hours. Verified users get a badge and can create sub-communities.'
      ),
      (
        'How do withdrawals work?',
        'Go to Wallet → Withdraw. Enter your bank details and amount. Minimum withdrawal is ₦1,000. Finance team processes within 24 hours on business days.'
      ),
      (
        'Can I create a community?',
        'Any verified user can create sub-communities under an existing community. Admins can create top-level communities. Go to Communities and tap the + button (visible if eligible).'
      ),
      (
        'How do I create a post?',
        'Tap the + button on the home feed or go to Create Post. Add text, images, or video. Add tags to help others find your content. Tap POST to publish.'
      ),
      (
        'How do I change my username?',
        'Go to Settings → Change Username. Usernames must be 3+ characters, letters and numbers only. Choose carefully as this affects how others find you.'
      ),
      (
        'What is the Gamer Tag?',
        'Your Gamer Tag is your in-game identity displayed on your profile. It\'s separate from your username. Update it in Settings → Gamer Tag.'
      ),
      (
        'I can\'t log in. What do I do?',
        'Make sure you\'re using the correct email and password. Try "Forgot Password" on the login screen. If still stuck, tap Contact Support and our team will help.'
      ),
      (
        'How do I contact support?',
        'Go to Settings → Contact Support. Our AI assistant can handle most issues instantly. For complex cases, it connects you to a live agent who can see your chat history.'
      ),
    ];

    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(title: const Text('HELP CENTER')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: GacomDecorations.neonCard(context, radius: 20),
            child: const Column(children: [
              Icon(Icons.help_outline_rounded,
                  color: GacomColors.deepOrange, size: 40),
              SizedBox(height: 10),
              Text('How can we help?',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: GacomColors.textPrimary)),
              SizedBox(height: 6),
              Text(
                  'Find answers to common questions below. Still need help? Use Contact Support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: GacomColors.textMuted,
                      fontSize: 13,
                      height: 1.5)),
            ]),
          ),
          const SizedBox(height: 24),
          ...faqs.asMap().entries.map((e) => _FaqTile(
                question: e.value.$1,
                answer: e.value.$2,
              ).animate(delay: (e.key * 40).ms).fadeIn()),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question, answer;
  const _FaqTile({required this.question, required this.answer});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(
                            color: GacomColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14))),
                Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: GacomColors.deepOrange),
              ]),
            ),
            if (_open)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(widget.answer,
                    style: const TextStyle(
                        color: GacomColors.textSecondary,
                        fontSize: 13,
                        height: 1.5)),
              ),
          ]),
        ),
      );
}

// ── Privacy Policy ────────────────────────────────────────────────────────────
class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(title: const Text('PRIVACY POLICY')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PolicySection('1. Information We Collect',
              'We collect information you provide directly: display name, username, email, profile photo, gamer tag, and location. We also collect usage data including posts, competition participation, wallet transactions, and community activity.'),
          _PolicySection('2. How We Use Your Information',
              'Your information is used to: provide and improve the GACOM platform, process payments via Paystack, match you with competitions and communities, send relevant notifications, and detect fraud or abuse.'),
          _PolicySection('3. Payment Data',
              'All payments are processed by Paystack. GACOM does not store your card details. Paystack is PCI-DSS compliant. Your wallet balance is stored securely in our database.'),
          _PolicySection('4. Data Sharing',
              'We do not sell your personal data. We share data only with: Paystack (for payment processing), Supabase (our secure database provider), and Anthropic (for AI-powered support responses). No advertising third parties have access to your data.'),
          _PolicySection('5. Your Rights',
              'You have the right to: access your data, correct inaccurate data, delete your account, opt out of non-essential notifications, and export your data. Contact support@gacom.gg to exercise these rights.'),
          _PolicySection('6. Data Retention',
              'Your data is retained while your account is active. After account deletion, we retain transaction records for 7 years as required by Nigerian financial regulations. All other data is deleted within 30 days.'),
          _PolicySection('7. Security',
              'We use industry-standard security measures including TLS encryption for data in transit, AES-256 encryption for sensitive data at rest, and regular security audits. However, no system is 100% secure.'),
          _PolicySection('8. Cookies & Tracking',
              'We use minimal cookies necessary for authentication and session management only. We do not use advertising or tracking cookies. No third-party trackers are embedded in our platform.'),
          _PolicySection('9. Children',
              'GACOM is not intended for users under 13. If you believe a child has created an account, contact support@gacom.gg immediately and we will delete the account.'),
          _PolicySection('10. Contact Us',
              'For privacy-related questions: support@gacom.gg\nGACOM Technologies, Lagos, Nigeria.\nLast updated: January 2026'),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title, body;
  const _PolicySection(this.title, this.body);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: GacomColors.deepOrange,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  color: GacomColors.textSecondary,
                  fontSize: 13,
                  height: 1.6)),
        ]),
      );
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SheetTitle extends StatelessWidget {
  final String text;
  const _SheetTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: GacomColors.textPrimary));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(label,
            style: const TextStyle(
                color: GacomColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup(this.children);
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(
          children: children
              .asMap()
              .entries
              .map((e) => Column(children: [
                    e.value,
                    if (e.key < children.length - 1)
                      const Divider(
                          height: 1,
                          indent: 52,
                          color: GacomColors.border),
                  ]))
              .toList(),
        ),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  const _Tile(
      {required this.icon,
      required this.label,
      this.subtitle,
      this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon,
            color: color ?? GacomColors.textSecondary, size: 20),
        title: Text(label,
            style: TextStyle(
                color: color ?? GacomColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(
                    color: GacomColors.textMuted, fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: GacomColors.textMuted, size: 18),
        dense: true,
      );
}

class _TileSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _TileSwitch(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => ListTile(
        leading:
            Icon(icon, color: GacomColors.textSecondary, size: 20),
        title: Text(label,
            style: const TextStyle(
                color: GacomColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: GacomColors.deepOrange),
        dense: true,
      );
}

class _TileExpand extends StatefulWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _TileExpand(
      {required this.icon, required this.label, required this.child});
  @override
  State<_TileExpand> createState() => _TileExpandState();
}

class _TileExpandState extends State<_TileExpand> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          onTap: () => setState(() => _open = !_open),
          leading: Icon(widget.icon,
              color: GacomColors.textSecondary, size: 20),
          title: Text(widget.label,
              style: const TextStyle(
                  color: GacomColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          trailing: Icon(
              _open
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: GacomColors.textMuted,
              size: 18),
          dense: true,
        ),
        if (_open) widget.child,
      ]);
}

class _NotifToggle extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _NotifToggle(this.label, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: GacomColors.textSecondary, fontSize: 13))),
        Switch(
            value: value,
            onChanged: onChanged,
            activeColor: GacomColors.deepOrange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]);
}
