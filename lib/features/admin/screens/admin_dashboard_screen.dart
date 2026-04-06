import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
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

  final _sections = ['Dashboard', 'Users', 'Competitions', 'Communities', 'Store', 'Blog', 'Payments', 'Verification', 'Admins'];
  final _sectionIcons = [Icons.dashboard_rounded, Icons.people_rounded, Icons.sports_esports_rounded, Icons.groups_rounded, Icons.storefront_rounded, Icons.article_rounded, Icons.account_balance_wallet_rounded, Icons.verified_rounded, Icons.admin_panel_settings_rounded];

  @override
  void initState() { super.initState(); _checkAdmin(); _loadStats(); }

  Future<void> _checkAdmin() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) { if (mounted) context.go(AppConstants.loginRoute); return; }
    final profile = await SupabaseService.client.from('profiles').select('role').eq('id', userId).single();
    if (!['admin', 'super_admin'].contains(profile['role'])) {
      if (mounted) { GacomSnackbar.show(context, 'Access denied. Admins only.', isError: true); context.go(AppConstants.homeRoute); }
    }
  }

  Future<void> _loadStats() async {
    try {
      final users = await SupabaseService.client.from('profiles').select('id', const FetchOptions(count: CountOption.exact)).limit(1);
      final competitions = await SupabaseService.client.from('competitions').select('id', const FetchOptions(count: CountOption.exact)).limit(1);
      final communities = await SupabaseService.client.from('communities').select('id', const FetchOptions(count: CountOption.exact)).limit(1);
      final orders = await SupabaseService.client.from('orders').select('total_amount').eq('status', 'delivered');
      final totalRevenue = (orders as List).fold<double>(0, (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0));
      final verifications = await SupabaseService.client.from('verification_requests').select('id', const FetchOptions(count: CountOption.exact)).eq('status', 'pending').limit(1);
      if (mounted) setState(() {
        _stats = {
          'users': users.count ?? 0,
          'competitions': competitions.count ?? 0,
          'communities': communities.count ?? 0,
          'revenue': totalRevenue,
          'pending_verifications': verifications.count ?? 0,
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
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        _Sidebar(sections: _sections, icons: _sectionIcons, selected: _selectedSection, onSelect: (i) => setState(() => _selectedSection = i)),
        Expanded(child: _buildSection()),
      ],
    );
  }

  Widget _narrowLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ShaderMask(shaderCallback: (b) => GacomColors.orangeGradient.createShader(b), child: const Text('GACOM ADMIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white, letterSpacing: 2))),
        ]),
      ),
      drawer: Drawer(
        backgroundColor: GacomColors.darkVoid,
        child: _Sidebar(sections: _sections, icons: _sectionIcons, selected: _selectedSection, onSelect: (i) { setState(() => _selectedSection = i); Navigator.pop(context); }),
      ),
      body: _buildSection(),
    );
  }

  Widget _buildSection() {
    switch (_selectedSection) {
      case 0: return _DashboardSection(stats: _stats, loading: _loading);
      case 1: return const _UsersSection();
      case 2: return const _CompetitionsSection();
      case 3: return const _CommunitiesSection();
      case 4: return const _StoreSection();
      case 5: return const _BlogSection();
      case 6: return const _PaymentsSection();
      case 7: return const _VerificationSection();
      case 8: return const _AdminsSection();
      default: return const SizedBox();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final List<String> sections;
  final List<IconData> icons;
  final int selected;
  final void Function(int) onSelect;
  const _Sidebar({required this.sections, required this.icons, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: GacomColors.darkVoid,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: ShaderMask(
                shaderCallback: (b) => GacomColors.orangeGradient.createShader(b),
                child: const Text('GACOM ADMIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white, letterSpacing: 2)),
              ),
            ),
            const Divider(color: GacomColors.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sections.length,
                itemBuilder: (_, i) {
                  final isSelected = selected == i;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? GacomColors.deepOrange.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: GacomColors.deepOrange.withOpacity(0.3)) : null,
                      ),
                      child: Row(children: [
                        Icon(icons[i], color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text(sections[i], style: TextStyle(color: isSelected ? GacomColors.deepOrange : GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 15)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: GacomColors.border),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: GacomColors.textMuted, size: 18),
              title: const Text('Back to App', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontSize: 14)),
              onTap: () => context.go(AppConstants.homeRoute),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool loading;
  const _DashboardSection({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard Overview', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Welcome back, Admin', style: TextStyle(color: GacomColors.textMuted)),
          const SizedBox(height: 24),
          if (loading)
            const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          else ...[
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(label: 'Total Users', value: '${stats['users'] ?? 0}', icon: Icons.people_rounded, color: GacomColors.info),
                _StatCard(label: 'Competitions', value: '${stats['competitions'] ?? 0}', icon: Icons.sports_esports_rounded, color: GacomColors.deepOrange),
                _StatCard(label: 'Communities', value: '${stats['communities'] ?? 0}', icon: Icons.groups_rounded, color: GacomColors.success),
                _StatCard(label: 'Revenue', value: '₦${_fmt(stats['revenue'] ?? 0)}', icon: Icons.account_balance_wallet_rounded, color: GacomColors.warning),
                _StatCard(label: 'Pending Verifications', value: '${stats['pending_verifications'] ?? 0}', icon: Icons.verified_rounded, color: stats['pending_verifications'] > 0 ? GacomColors.error : GacomColors.success),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 32),
            const Text('Quick Actions', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(label: 'Create Competition', icon: Icons.add_rounded, onTap: () {}),
                _QuickAction(label: 'Write Blog Post', icon: Icons.edit_rounded, onTap: () {}),
                _QuickAction(label: 'Add Product', icon: Icons.shopping_bag_rounded, onTap: () {}),
                _QuickAction(label: 'View Reports', icon: Icons.flag_rounded, onTap: () {}),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(dynamic v) {
    final d = (v as num).toDouble();
    if (d >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(0)}K';
    return d.toStringAsFixed(0);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 14),
        Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: GacomColors.deepOrange, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ───── USERS SECTION ─────
class _UsersSection extends ConsumerStatefulWidget {
  const _UsersSection();
  @override
  ConsumerState<_UsersSection> createState() => _UsersSectionState();
}
class _UsersSectionState extends ConsumerState<_UsersSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    var q = SupabaseService.client.from('profiles').select('*').order('created_at', ascending: false).limit(50);
    final data = await q;
    if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _banUser(String userId, bool ban) async {
    await SupabaseService.client.from('profiles').update({'is_banned': ban}).eq('id', userId);
    _load();
    if (mounted) GacomSnackbar.show(context, ban ? 'User banned.' : 'User unbanned.', isSuccess: !ban);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty ? _users : _users.where((u) => (u['username'] ?? '').toString().contains(_search) || (u['display_name'] ?? '').toString().contains(_search)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Text('Users', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const Spacer(),
            SizedBox(width: 220, child: TextField(
              style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search users...', hintStyle: const TextStyle(color: GacomColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18),
                filled: true, fillColor: GacomColors.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: GacomColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: GacomColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: GacomColors.deepOrange)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            )),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
                      child: Row(children: [
                        CircleAvatar(radius: 20, backgroundColor: GacomColors.border, child: Text((u['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(u['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                            const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(50)), child: Text(u['role'] ?? 'user', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 10, fontWeight: FontWeight.w700))),
                            if (u['is_banned'] == true) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(50)), child: const Text('BANNED', style: TextStyle(color: GacomColors.error, fontSize: 10, fontWeight: FontWeight.w700))),
                          ]),
                          Text('@${u['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                        ])),
                        PopupMenuButton<String>(
                          color: GacomColors.cardDark,
                          onSelected: (action) {
                            if (action == 'ban') _banUser(u['id'], true);
                            if (action == 'unban') _banUser(u['id'], false);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'view', child: Text('View Profile', style: TextStyle(color: GacomColors.textPrimary))),
                            PopupMenuItem(value: u['is_banned'] == true ? 'unban' : 'ban', child: Text(u['is_banned'] == true ? 'Unban User' : 'Ban User', style: TextStyle(color: u['is_banned'] == true ? GacomColors.success : GacomColors.error))),
                          ],
                          child: const Icon(Icons.more_vert_rounded, color: GacomColors.textMuted),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ───── VERIFICATION SECTION ─────
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
    final data = await SupabaseService.client.from('verification_requests').select('*, user:profiles!user_id(username, display_name, avatar_url)').eq('status', 'pending').order('created_at').limit(20);
    if (mounted) setState(() { _requests = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _review(String reqId, String userId, bool approved) async {
    final adminId = SupabaseService.currentUserId;
    await SupabaseService.client.from('verification_requests').update({'status': approved ? 'verified' : 'rejected', 'reviewed_by': adminId, 'reviewed_at': DateTime.now().toIso8601String()}).eq('id', reqId);
    if (approved) await SupabaseService.client.from('profiles').update({'verification_status': 'verified'}).eq('id', userId);
    _load();
    if (mounted) GacomSnackbar.show(context, approved ? 'User verified!' : 'Verification rejected.', isSuccess: approved);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Verification Requests', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
              : _requests.isEmpty
                  ? const Center(child: Text('No pending verification requests.', style: TextStyle(color: GacomColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _requests.length,
                      itemBuilder: (_, i) {
                        final r = _requests[i];
                        final user = r['user'] as Map<String, dynamic>? ?? {};
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border, width: 0.5)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(radius: 20, backgroundColor: GacomColors.border, child: Text((user['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary))),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(user['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                                Text('@${user['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                              ])),
                            ]),
                            const SizedBox(height: 12),
                            Text('ID Type: ${r['id_type'] ?? ''}', style: const TextStyle(color: GacomColors.textSecondary)),
                            Text('Full Name: ${r['full_name'] ?? ''}', style: const TextStyle(color: GacomColors.textSecondary)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: GacomButton(label: 'APPROVE', height: 44, onPressed: () => _review(r['id'], r['user_id'], true))),
                              const SizedBox(width: 10),
                              Expanded(child: GacomButton(label: 'REJECT', height: 44, isOutlined: true, color: GacomColors.error, onPressed: () => _review(r['id'], r['user_id'], false))),
                            ]),
                          ]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ───── ADMINS SECTION ─────
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
    final data = await SupabaseService.client.from('profiles').select('*, permissions:admin_permissions(permission)').inFilter('role', ['admin', 'super_admin']).order('created_at');
    if (mounted) setState(() { _admins = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  void _showCreateAdminDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final List<String> selectedPerms = [];
    final allPerms = [AdminPermission.manageUsers, AdminPermission.manageBlog, AdminPermission.manageCompetitions, AdminPermission.manageCommunities, AdminPermission.manageStore, AdminPermission.managePayments, AdminPermission.viewAnalytics, AdminPermission.manageVerification];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: GacomColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Admin Account', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 20)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              GacomTextField(controller: emailCtrl, label: 'Admin Email', hint: 'admin@gamicom.net', prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              GacomTextField(controller: passCtrl, label: 'Password', hint: 'Min 8 characters', prefixIcon: Icons.lock_outline_rounded, obscureText: true),
              const SizedBox(height: 16),
              const Text('Permissions', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
              const SizedBox(height: 8),
              ...allPerms.map((perm) => CheckboxListTile(
                dense: true,
                value: selectedPerms.contains(perm),
                onChanged: (v) => setInner(() { if (v == true) selectedPerms.add(perm); else selectedPerms.remove(perm); }),
                title: Text(perm.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                activeColor: GacomColors.deepOrange,
                checkColor: Colors.white,
                side: const BorderSide(color: GacomColors.border),
              )),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                final pass = passCtrl.text.trim();
                if (email.isEmpty || pass.length < 8) return;
                try {
                  final result = await SupabaseService.client.auth.admin.createUser(AdminUserAttributes(email: email, password: pass, emailConfirm: true));
                  if (result.user != null) {
                    await SupabaseService.client.from('profiles').update({'role': 'admin'}).eq('id', result.user!.id);
                    for (final perm in selectedPerms) {
                      await SupabaseService.client.from('admin_permissions').insert({'admin_id': result.user!.id, 'permission': perm, 'granted_by': SupabaseService.currentUserId});
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) GacomSnackbar.show(context, 'Admin account created!', isSuccess: true);
                } catch (e) {
                  if (mounted) GacomSnackbar.show(context, 'Failed: $e', isError: true);
                }
              },
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Text('Admin Management', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const Spacer(),
            GacomButton(label: '+ NEW ADMIN', width: 140, height: 42, onPressed: _showCreateAdminDialog),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _admins.length,
                  itemBuilder: (_, i) {
                    final a = _admins[i];
                    final perms = (a['permissions'] as List? ?? []);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.admin_panel_settings_rounded, color: GacomColors.deepOrange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                            Text('@${a['username'] ?? ''} · ${a['role']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                          ])),
                        ]),
                        if (perms.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, children: perms.map((p) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
                            child: Text((p['permission'] ?? '').toString().replaceAll('_', ' '), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                          )).toList()),
                        ],
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Stub sections
class _CompetitionsSection extends StatelessWidget {
  const _CompetitionsSection();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Competitions Admin Panel', style: TextStyle(color: GacomColors.textMuted)));
}
class _CommunitiesSection extends StatelessWidget {
  const _CommunitiesSection();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Communities Admin Panel', style: TextStyle(color: GacomColors.textMuted)));
}
class _StoreSection extends StatelessWidget {
  const _StoreSection();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Store Admin Panel', style: TextStyle(color: GacomColors.textMuted)));
}
class _BlogSection extends StatelessWidget {
  const _BlogSection();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Blog Admin Panel', style: TextStyle(color: GacomColors.textMuted)));
}
class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Payments Admin Panel', style: TextStyle(color: GacomColors.textMuted)));
}
