import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedSection = 0;
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  final _sections = ['Dashboard','Users','Competitions','Communities','Store','Blog','Payments','Verification','Admins'];
  final _sectionIcons = [Icons.dashboard_rounded,Icons.people_rounded,Icons.sports_esports_rounded,Icons.groups_rounded,Icons.storefront_rounded,Icons.article_rounded,Icons.account_balance_wallet_rounded,Icons.verified_rounded,Icons.admin_panel_settings_rounded];

  @override
  void initState() { super.initState(); _checkAdmin(); _loadStats(); }

  Future<void> _checkAdmin() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) { if (mounted) context.go(AppConstants.loginRoute); return; }
    try {
      final profile = await SupabaseService.client.from('profiles').select('role').eq('id', userId).single();
      if (!['admin','super_admin'].contains(profile['role'])) {
        if (mounted) { GacomSnackbar.show(context, 'Access denied.', isError: true); context.go(AppConstants.homeRoute); }
      }
    } catch (e) { if (mounted) context.go(AppConstants.homeRoute); }
  }

  Future<void> _loadStats() async {
    try {
      final users = await SupabaseService.client.from('profiles').select('id');
      final competitions = await SupabaseService.client.from('competitions').select('id');
      final communities = await SupabaseService.client.from('communities').select('id');
      final verifications = await SupabaseService.client.from('verification_requests').select('id').eq('status', 'pending');
      if (mounted) setState(() {
        _stats = {
          'users': (users as List).length,
          'competitions': (competitions as List).length,
          'communities': (communities as List).length,
          'pending_verifications': (verifications as List).length,
        };
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: isWide
          ? Row(children: [_Sidebar(sections: _sections, icons: _sectionIcons, selected: _selectedSection, onSelect: (i) => setState(() => _selectedSection = i)), Expanded(child: _buildSection())])
          : Scaffold(
              appBar: AppBar(title: const Text('GACOM ADMIN')),
              drawer: Drawer(backgroundColor: GacomColors.darkVoid, child: _Sidebar(sections: _sections, icons: _sectionIcons, selected: _selectedSection, onSelect: (i) { setState(() => _selectedSection = i); Navigator.pop(context); })),
              body: _buildSection(),
            ),
    );
  }

  Widget _buildSection() {
    switch (_selectedSection) {
      case 0: return _DashboardSection(stats: _stats, loading: _loading);
      case 1: return const _UsersSection();
      case 7: return const _VerificationSection();
      case 8: return const _AdminsSection();
      default: return Center(child: Text(_sections[_selectedSection], style: const TextStyle(color: GacomColors.textMuted, fontSize: 20)));
    }
  }
}

class _Sidebar extends StatelessWidget {
  final List<String> sections; final List<IconData> icons; final int selected; final void Function(int) onSelect;
  const _Sidebar({required this.sections, required this.icons, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Container(
    width: 220, color: GacomColors.darkVoid,
    child: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.all(20), child: Text('GACOM ADMIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.deepOrange, letterSpacing: 2))),
      const Divider(color: GacomColors.border),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final isSel = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: isSel ? GacomColors.deepOrange.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: isSel ? Border.all(color: GacomColors.deepOrange.withOpacity(0.3)) : null),
              child: Row(children: [
                Icon(icons[i], color: isSel ? GacomColors.deepOrange : GacomColors.textMuted, size: 18),
                const SizedBox(width: 10),
                Text(sections[i], style: TextStyle(color: isSel ? GacomColors.deepOrange : GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, fontSize: 15)),
              ]),
            ),
          );
        },
      )),
      const Divider(color: GacomColors.border),
      ListTile(leading: const Icon(Icons.home_outlined, color: GacomColors.textMuted, size: 18), title: const Text('Back to App', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontSize: 14)), onTap: () => context.go(AppConstants.homeRoute)),
    ])),
  );
}

class _DashboardSection extends StatelessWidget {
  final Map<String, dynamic> stats; final bool loading;
  const _DashboardSection({required this.stats, required this.loading});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Dashboard', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
      const SizedBox(height: 24),
      if (loading) const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
      else Wrap(spacing: 16, runSpacing: 16, children: [
        _StatCard(label: 'Total Users', value: '${stats['users']??0}', icon: Icons.people_rounded, color: GacomColors.info),
        _StatCard(label: 'Competitions', value: '${stats['competitions']??0}', icon: Icons.sports_esports_rounded, color: GacomColors.deepOrange),
        _StatCard(label: 'Communities', value: '${stats['communities']??0}', icon: Icons.groups_rounded, color: GacomColors.success),
        _StatCard(label: 'Pending KYC', value: '${stats['pending_verifications']??0}', icon: Icons.verified_rounded, color: GacomColors.error),
      ]).animate().fadeIn(),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 180, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
      const SizedBox(height: 14),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
    ]),
  );
}

class _UsersSection extends ConsumerStatefulWidget {
  const _UsersSection();
  @override
  ConsumerState<_UsersSection> createState() => _UsersSectionState();
}
class _UsersSectionState extends ConsumerState<_UsersSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await SupabaseService.client.from('profiles').select('*').order('created_at', ascending: false).limit(50);
    if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Users', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)))),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)) : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final u = _users[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: GacomColors.border, child: Text((u['display_name']??'G')[0], style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['display_name']??'', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
              Text('@${u['username']??''} · ${u['role']??'user'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            ])),
          ]),
        );
      },
    )),
  ]);
}

class _VerificationSection extends ConsumerStatefulWidget {
  const _VerificationSection();
  @override
  ConsumerState<_VerificationSection> createState() => _VerificationSectionState();
}
class _VerificationSectionState extends ConsumerState<_VerificationSection> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await SupabaseService.client.from('verification_requests').select('*, user:profiles!user_id(username, display_name)').eq('status', 'pending').order('created_at').limit(20);
    if (mounted) setState(() { _requests = List<Map<String, dynamic>>.from(data); _loading = false; });
  }
  Future<void> _review(String reqId, String userId, bool approved) async {
    await SupabaseService.client.from('verification_requests').update({'status': approved ? 'verified' : 'rejected', 'reviewed_by': SupabaseService.currentUserId, 'reviewed_at': DateTime.now().toIso8601String()}).eq('id', reqId);
    if (approved) await SupabaseService.client.from('profiles').update({'verification_status': 'verified'}).eq('id', userId);
    _load();
    if (mounted) GacomSnackbar.show(context, approved ? 'User verified!' : 'Rejected.', isSuccess: approved);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Verification Requests', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)))),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)) : _requests.isEmpty ? const Center(child: Text('No pending requests.', style: TextStyle(color: GacomColors.textMuted))) : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _requests.length,
      itemBuilder: (_, i) {
        final r = _requests[i];
        final user = r['user'] as Map<String, dynamic>? ?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['display_name']??'', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 16)),
            Text('@${user['username']??''} · ${r['id_type']??''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GacomButton(label: 'APPROVE', height: 44, onPressed: () => _review(r['id'], r['user_id'], true))),
              const SizedBox(width: 10),
              Expanded(child: GacomButton(label: 'REJECT', height: 44, isOutlined: true, onPressed: () => _review(r['id'], r['user_id'], false))),
            ]),
          ]),
        );
      },
    )),
  ]);
}

class _AdminsSection extends ConsumerStatefulWidget {
  const _AdminsSection();
  @override
  ConsumerState<_AdminsSection> createState() => _AdminsSectionState();
}
class _AdminsSectionState extends ConsumerState<_AdminsSection> {
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await SupabaseService.client.from('profiles').select('*').inFilter('role', ['admin','super_admin']).order('created_at');
    if (mounted) setState(() { _admins = List<Map<String, dynamic>>.from(data); _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      const Text('Admins', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
      const Spacer(),
      GacomButton(label: '+ NEW ADMIN', width: 140, height: 42, onPressed: () => GacomSnackbar.show(context, 'Create admins via Supabase dashboard.')),
    ])),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)) : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _admins.length,
      itemBuilder: (_, i) {
        final a = _admins[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Row(children: [
            const Icon(Icons.admin_panel_settings_rounded, color: GacomColors.deepOrange, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['display_name']??'', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
              Text('@${a['username']??''} · ${a['role']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            ])),
          ]),
        );
      },
    )),
  ]);
}
