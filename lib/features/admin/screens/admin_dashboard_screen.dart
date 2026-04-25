import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

// Permission + Role enums
class AdminPermission {
  static const createCompetitions = 'create_competitions';
  static const manageBlog = 'manage_blog';
  static const manageStore = 'manage_store';
  static const manageCommunities = 'manage_communities';
  static const manageUsers = 'manage_users';
}

class ExcoRole {
  static const communityManager = 'community_manager';
  static const inventoryManager = 'inventory_manager';
  static const financeTeam = 'finance_team';
  static const customerAgent = 'customer_agent';
  static const blogEditor = 'blog_editor';
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedSection = 0;
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _userRole;

  final _sections = ['Dashboard', 'Users', 'Competitions', 'Communities', 'Blog', 'Payments', 'Verification', 'Exco & Roles'];
  final _sectionIcons = [Icons.dashboard_rounded, Icons.people_rounded, Icons.sports_esports_rounded, Icons.groups_rounded, Icons.article_rounded, Icons.account_balance_wallet_rounded, Icons.verified_rounded, Icons.admin_panel_settings_rounded];

  @override
  void initState() { super.initState(); _checkAccess(); _loadStats(); }

  Future<void> _checkAccess() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) { if (mounted) context.go(AppConstants.loginRoute); return; }
    try {
      final p = await SupabaseService.client.from('profiles').select('role').eq('id', uid).single();
      final role = p['role'] as String? ?? 'user';
      if (mounted) setState(() => _userRole = role);
      // ✅ FIX: exco is NO LONGER allowed into admin dashboard
      // exco users get their own /exco-dashboard screen instead
      final allowed = ['admin', 'super_admin', 'moderator'];
      if (!allowed.contains(role)) {
        if (mounted) {
          GacomSnackbar.show(context, 'Access denied — use your Team Dashboard instead', isError: true);
          context.go(AppConstants.homeRoute);
        }
      }
    } catch (_) { if (mounted) context.go(AppConstants.homeRoute); }
  }

  Future<void> _loadStats() async {
    try {
      final users = await SupabaseService.client.from('profiles').select('id');
      final competitions = await SupabaseService.client.from('competitions').select('id');
      final communities = await SupabaseService.client.from('communities').select('id');
      final verifications = await SupabaseService.client.from('verification_requests').select('id').eq('status', 'pending');
      final blogs = await SupabaseService.client.from('blog_posts').select('id');
      if (mounted) setState(() {
        _stats = {'users': (users as List).length, 'competitions': (competitions as List).length, 'communities': (communities as List).length, 'pending_verifications': (verifications as List).length, 'blogs': (blogs as List).length};
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: isWide
          ? Row(children: [_Sidebar(sections: _sections, icons: _sectionIcons, selected: _selectedSection, onSelect: (i) => setState(() => _selectedSection = i)), Expanded(child: _buildSection())])
          : Scaffold(
              backgroundColor: GacomColors.obsidian,
              appBar: AppBar(title: const Text('GACOM ADMIN'), leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer()))),
              drawer: Drawer(backgroundColor: GacomColors.darkVoid, child: _Sidebar(sections: _sections, icons: _sectionIcons, selected: _selectedSection, onSelect: (i) { setState(() => _selectedSection = i); Navigator.pop(context); })),
              body: _buildSection()),
    );
  }

  Widget _buildSection() {
    switch (_selectedSection) {
      case 0: return _DashboardSection(stats: _stats, loading: _loading);
      case 1: return const _UsersSection();
      case 2: return const _CompetitionsAdminSection();
      case 3: return const _CommunitiesAdminSection();
      case 4: return const _BlogAdminSection();
      case 6: return const _VerificationSection();
      case 7: return const _ExcoSection();
      default: return Center(child: Text(_sections[_selectedSection], style: const TextStyle(color: GacomColors.textMuted, fontSize: 20)));
    }
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<String> sections; final List<IconData> icons; final int selected; final Function(int) onSelect;
  const _Sidebar({required this.sections, required this.icons, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(width: 220, color: GacomColors.darkVoid, child: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        ClipOval(child: Image.network(AppConstants.logoUrl, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 36, height: 36, decoration: const BoxDecoration(gradient: GacomColors.orangeGradient, shape: BoxShape.circle), child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))))),
        const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('GACOM', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)), Text('ADMIN', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 10, color: GacomColors.deepOrange, letterSpacing: 2))]),
      ])),
      const Divider(color: GacomColors.border, height: 1), const SizedBox(height: 8),
      Expanded(child: ListView.builder(itemCount: sections.length, itemBuilder: (_, i) {
        final sel = i == selected;
        return AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: sel ? GacomColors.deepOrange.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: ListTile(dense: true, leading: Icon(icons[i], color: sel ? GacomColors.deepOrange : GacomColors.textMuted, size: 20), title: Text(sections[i], style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: sel ? GacomColors.deepOrange : GacomColors.textSecondary)), onTap: () => onSelect(i)));
      })),
      const Divider(color: GacomColors.border, height: 1),
      ListTile(dense: true, leading: const Icon(Icons.arrow_back_rounded, color: GacomColors.textMuted, size: 20), title: const Text('Back to App', style: TextStyle(fontFamily: 'Rajdhani', color: GacomColors.textMuted, fontSize: 14)), onTap: () => context.go(AppConstants.homeRoute)),
      const SizedBox(height: 8),
    ])));
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────
class _DashboardSection extends StatelessWidget {
  final Map<String, dynamic> stats; final bool loading;
  const _DashboardSection({required this.stats, required this.loading});
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('OVERVIEW', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary, letterSpacing: 2)),
      const SizedBox(height: 20),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _StatCard('Total Users', '${stats['users'] ?? 0}', Icons.people_rounded, GacomColors.info),
        _StatCard('Competitions', '${stats['competitions'] ?? 0}', Icons.sports_esports_rounded, GacomColors.deepOrange),
        _StatCard('Communities', '${stats['communities'] ?? 0}', Icons.groups_rounded, GacomColors.success),
        _StatCard('Pending Verif.', '${stats['pending_verifications'] ?? 0}', Icons.verified_rounded, GacomColors.warning),
        _StatCard('Blog Posts', '${stats['blogs'] ?? 0}', Icons.article_rounded, GacomColors.info),
      ]),
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(width: 160, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
    ]));
}

// ── Users Section — FIXED ─────────────────────────────────────────────────────
class _UsersSection extends ConsumerStatefulWidget {
  const _UsersSection();
  @override ConsumerState<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends ConsumerState<_UsersSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load([String? query]) async {
    if (mounted) setState(() => _loading = true);
    try {
      // ✅ FIX: profiles table does NOT have 'email'. 
      // Search by username or display_name only (email is in auth.users, not accessible client-side).
      // 'location' may be null — use nullable-safe select.
      var q = SupabaseService.client
          .from('profiles')
          .select('id, display_name, username, role, verification_status, is_banned, created_at, location');
      
      if (query != null && query.trim().isNotEmpty) {
        // ✅ FIX: search username column (text), NOT id column (UUID)
        q = q.or('username.ilike.%${query.trim()}%,display_name.ilike.%${query.trim()}%') as dynamic;
      }
      
      final data = await (q as dynamic).order('created_at', ascending: false).limit(50);
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); GacomSnackbar.show(context, 'Failed to load users: $e', isError: true); }
    }
  }

  Future<void> _toggleBan(String userId, bool isBanned) async {
    try {
      await SupabaseService.client.from('profiles').update({'is_banned': !isBanned, 'ban_reason': isBanned ? null : 'Admin ban'}).eq('id', userId);
      await _load(_searchCtrl.text.isNotEmpty ? _searchCtrl.text : null);
      GacomSnackbar.show(context, isBanned ? 'User unbanned ✅' : 'User banned', isSuccess: !isBanned);
    } catch (e) { GacomSnackbar.show(context, 'Failed: $e', isError: true); }
  }

  Future<void> _grantPermission(String userId) async {
    try {
      await SupabaseService.client.from('admin_permissions').upsert({
        'admin_id': userId, 'permission': AdminPermission.createCompetitions, 'granted_by': SupabaseService.currentUserId,
      }, onConflict: 'admin_id,permission');
      GacomSnackbar.show(context, 'Competition permission granted ✅', isSuccess: true);
    } catch (e) { GacomSnackbar.show(context, 'Failed: $e', isError: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: TextField(controller: _searchCtrl, style: const TextStyle(color: GacomColors.textPrimary),
          decoration: InputDecoration(hintText: 'Search by username or name...', hintStyle: const TextStyle(color: GacomColors.textMuted), prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted), filled: true, fillColor: GacomColors.cardDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border))),
          onSubmitted: _load)),
        const SizedBox(width: 10),
        GestureDetector(onTap: () => _load(_searchCtrl.text.isNotEmpty ? _searchCtrl.text : null), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.search_rounded, color: Colors.white, size: 20))),
      ])),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _users.isEmpty
              ? const Center(child: Text('No users found', style: TextStyle(color: GacomColors.textMuted)))
              : RefreshIndicator(color: GacomColors.deepOrange, onRefresh: () => _load(),
                  child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _users.length, itemBuilder: (_, i) {
                    final u = _users[i]; final banned = u['is_banned'] as bool? ?? false;
                    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: banned ? GacomColors.error.withOpacity(0.3) : GacomColors.border, width: 0.5)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(gradient: GacomColors.orangeGradient, shape: BoxShape.circle), child: Center(child: Text((u['display_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(u['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15)),
                            Text('@${u['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                            if (u['location'] != null) Text('📍 ${u['location']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (banned ? GacomColors.error : GacomColors.success).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(u['role']?.toString().toUpperCase() ?? 'USER', style: TextStyle(color: banned ? GacomColors.error : GacomColors.success, fontSize: 10, fontWeight: FontWeight.w700))),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, children: [
                          _ActionBtn(label: banned ? 'Unban' : 'Ban', color: banned ? GacomColors.success : GacomColors.error, onTap: () => _toggleBan(u['id'], banned)),
                          _ActionBtn(label: 'Allow Competitions', color: GacomColors.info, onTap: () => _grantPermission(u['id'])),
                        ]),
                      ]));
                  }))),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.35))), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))));
}

// ── Competitions Admin ─────────────────────────────────────────────────────────
class _CompetitionsAdminSection extends ConsumerStatefulWidget {
  const _CompetitionsAdminSection();
  @override ConsumerState<_CompetitionsAdminSection> createState() => _CompetitionsAdminState();
}
class _CompetitionsAdminState extends ConsumerState<_CompetitionsAdminSection> {
  List<Map<String, dynamic>> _comps = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final data = await SupabaseService.client.from('competitions').select('*').order('created_at', ascending: false).limit(30); if (mounted) setState(() { _comps = List<Map<String, dynamic>>.from(data); _loading = false; }); }
    catch (_) { if (mounted) setState(() => _loading = false); }
  }
  void _showCreate() {
    final titleCtrl = TextEditingController(); final gameCtrl = TextEditingController(); final prizeCtrl = TextEditingController(); final entryCtrl = TextEditingController(); String type = 'free'; DateTime? starts; DateTime? ends;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(backgroundColor: GacomColors.cardDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('CREATE COMPETITION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary, fontSize: 18)),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _AdminField(titleCtrl, 'Title *'), const SizedBox(height: 12), _AdminField(gameCtrl, 'Game Name *'), const SizedBox(height: 12), _AdminField(prizeCtrl, 'Prize Pool (₦)', type: TextInputType.number), const SizedBox(height: 12),
        Row(children: [const Text('Type: ', style: TextStyle(color: GacomColors.textSecondary)), const SizedBox(width: 8), ChoiceChip(label: const Text('Free'), selected: type == 'free', selectedColor: GacomColors.deepOrange, onSelected: (_) => setDlg(() => type = 'free'), labelStyle: TextStyle(color: type == 'free' ? Colors.white : GacomColors.textMuted)),
          const SizedBox(width: 8), ChoiceChip(label: const Text('Paid'), selected: type == 'paid', selectedColor: GacomColors.deepOrange, onSelected: (_) => setDlg(() => type = 'paid'), labelStyle: TextStyle(color: type == 'paid' ? Colors.white : GacomColors.textMuted))]),
        if (type == 'paid') ...[const SizedBox(height: 12), _AdminField(entryCtrl, 'Entry Fee (₦)', type: TextInputType.number)],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () async { final d = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setDlg(() => starts = d); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)), child: Text(starts == null ? 'Start Date' : '${starts!.day}/${starts!.month}/${starts!.year}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Outfit', fontSize: 13))))),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: () async { final d = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setDlg(() => ends = d); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)), child: Text(ends == null ? 'End Date' : '${ends!.day}/${ends!.month}/${ends!.year}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Outfit', fontSize: 13))))),
        ]),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async {
          if (titleCtrl.text.isEmpty || gameCtrl.text.isEmpty || starts == null || ends == null) { GacomSnackbar.show(ctx, 'Fill all required fields', isError: true); return; }
          try {
            await SupabaseService.client.from('competitions').insert({'title': titleCtrl.text.trim(), 'game_name': gameCtrl.text.trim(), 'competition_type': type, 'prize_pool': double.tryParse(prizeCtrl.text) ?? 0, 'entry_fee': double.tryParse(entryCtrl.text) ?? 0, 'starts_at': starts!.toIso8601String(), 'ends_at': ends!.toIso8601String(), 'status': 'upcoming', 'created_by': SupabaseService.currentUserId, 'is_admin_created': true});
            Navigator.pop(ctx); _load(); GacomSnackbar.show(context, 'Competition created! ✅', isSuccess: true);
          } catch (e) { GacomSnackbar.show(ctx, 'Error: $e', isError: true); }
        }, child: const Text('CREATE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)))])));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('COMPETITIONS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _showCreate, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('CREATE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))])),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: _comps.length, itemBuilder: (_, i) {
        final c = _comps[i]; final status = c['status'] as String? ?? 'upcoming';
        final statusColor = status == 'live' ? GacomColors.error : status == 'upcoming' ? GacomColors.info : GacomColors.textMuted;
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c['title'] ?? 'Untitled', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)), Text('${c['game_name']} · ₦${c['prize_pool'] ?? 0} prize', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(50)), child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: statusColor)))]));
      })),
    ]);
  }
}

// ── Communities Admin ─────────────────────────────────────────────────────────
class _CommunitiesAdminSection extends ConsumerStatefulWidget {
  const _CommunitiesAdminSection();
  @override ConsumerState<_CommunitiesAdminSection> createState() => _CommunitiesAdminState();
}
class _CommunitiesAdminState extends ConsumerState<_CommunitiesAdminSection> {
  List<Map<String, dynamic>> _communities = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final data = await SupabaseService.client.from('communities').select('*').order('members_count', ascending: false).limit(30); if (mounted) setState(() { _communities = List<Map<String, dynamic>>.from(data); _loading = false; }); }
    catch (_) { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text('COMMUNITIES', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)))),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: _communities.length, itemBuilder: (_, i) {
        final c = _communities[i];
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)), Text('${c['game_name']} · ${c['members_count'] ?? 0} members', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))])),
          Icon((c['is_active'] as bool? ?? true) ? Icons.check_circle_rounded : Icons.cancel_rounded, color: (c['is_active'] as bool? ?? true) ? GacomColors.success : GacomColors.error, size: 20)]));
      })),
    ]);
  }
}

// ── Blog Admin — allows exco blog_editor + admins ─────────────────────────────
class _BlogAdminSection extends ConsumerStatefulWidget {
  const _BlogAdminSection();
  @override ConsumerState<_BlogAdminSection> createState() => _BlogAdminState();
}
class _BlogAdminState extends ConsumerState<_BlogAdminSection> {
  List<Map<String, dynamic>> _posts = []; bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final data = await SupabaseService.client.from('blog_posts').select('*, author:profiles!author_id(display_name, username)').order('created_at', ascending: false).limit(30); if (mounted) setState(() { _posts = List<Map<String, dynamic>>.from(data); _loading = false; }); }
    catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showCreatePost() {
    final titleCtrl = TextEditingController(); final excerptCtrl = TextEditingController(); final contentCtrl = TextEditingController(); final categoryCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: GacomColors.cardDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('NEW BLOG POST', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _AdminField(titleCtrl, 'Title *'), const SizedBox(height: 12), _AdminField(excerptCtrl, 'Excerpt / Summary', maxLines: 2), const SizedBox(height: 12), _AdminField(contentCtrl, 'Full Content *', maxLines: 6), const SizedBox(height: 12), _AdminField(categoryCtrl, 'Category (e.g. Announcements)'),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async {
          if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) { GacomSnackbar.show(ctx, 'Title and content required', isError: true); return; }
          try {
            final slug = titleCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-') + '-${DateTime.now().millisecondsSinceEpoch}';
            await SupabaseService.client.from('blog_posts').insert({'title': titleCtrl.text.trim(), 'slug': slug, 'excerpt': excerptCtrl.text.trim().isEmpty ? null : excerptCtrl.text.trim(), 'content': contentCtrl.text.trim(), 'category': categoryCtrl.text.trim().isEmpty ? 'Updates' : categoryCtrl.text.trim(), 'author_id': SupabaseService.currentUserId, 'is_published': true, 'published_at': DateTime.now().toIso8601String()});
            Navigator.pop(ctx); _load(); GacomSnackbar.show(context, 'Post published! ✅', isSuccess: true);
          } catch (e) { GacomSnackbar.show(ctx, 'Error: $e', isError: true); }
        }, child: const Text('PUBLISH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)))]));
  }

  Future<void> _togglePublish(String id, bool isPublished) async {
    await SupabaseService.client.from('blog_posts').update({'is_published': !isPublished, 'published_at': !isPublished ? DateTime.now().toIso8601String() : null}).eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('BLOG POSTS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _showCreatePost, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('NEW POST', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Icon(Icons.info_outline_rounded, size: 14, color: GacomColors.info), SizedBox(width: 6), Expanded(child: Text('Blog posts are written by Gacom team (exco & admins). Users can only read, not write.', style: TextStyle(color: GacomColors.info, fontSize: 12)))])),
      const SizedBox(height: 8),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else if (_posts.isEmpty) const Expanded(child: Center(child: Text('No blog posts yet.', style: TextStyle(color: GacomColors.textMuted))))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: _posts.length, itemBuilder: (_, i) {
        final p = _posts[i]; final author = p['author'] as Map? ?? {}; final isPublished = p['is_published'] as bool? ?? false;
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)), Text('By ${author['display_name'] ?? 'Unknown'} · ${p['category'] ?? 'Updates'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))])),
          GestureDetector(onTap: () => _togglePublish(p['id'], isPublished), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isPublished ? GacomColors.success : GacomColors.textMuted).withOpacity(0.12), borderRadius: BorderRadius.circular(50), border: Border.all(color: (isPublished ? GacomColors.success : GacomColors.textMuted).withOpacity(0.4))), child: Text(isPublished ? 'LIVE' : 'DRAFT', style: TextStyle(color: isPublished ? GacomColors.success : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11))))]));
      })),
    ]);
  }
}

// ── Verification Section ──────────────────────────────────────────────────────
class _VerificationSection extends ConsumerStatefulWidget {
  const _VerificationSection();
  @override ConsumerState<_VerificationSection> createState() => _VerificationSectionState();
}
class _VerificationSectionState extends ConsumerState<_VerificationSection> {
  List<Map<String, dynamic>> _requests = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final data = await SupabaseService.client.from('verification_requests').select('*, user:profiles!user_id(display_name, username)').eq('status', 'pending').order('created_at').limit(30); if (mounted) setState(() { _requests = List<Map<String, dynamic>>.from(data); _loading = false; }); }
    catch (_) { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _review(String id, String userId, bool approve) async {
    await SupabaseService.client.from('verification_requests').update({'status': approve ? 'verified' : 'rejected', 'reviewed_by': SupabaseService.currentUserId, 'reviewed_at': DateTime.now().toIso8601String()}).eq('id', id);
    if (approve) await SupabaseService.client.from('profiles').update({'verification_status': 'verified'}).eq('id', userId);
    _load(); GacomSnackbar.show(context, approve ? 'User verified ✓' : 'Request rejected', isSuccess: approve);
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text('PENDING VERIFICATIONS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)))),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else if (_requests.isEmpty) const Expanded(child: Center(child: Text('No pending verifications ✅', style: TextStyle(color: GacomColors.textMuted))))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: _requests.length, itemBuilder: (_, i) {
        final r = _requests[i]; final user = r['user'] as Map? ?? {};
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.warning.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['display_name'] ?? 'Unknown', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
            Text('@${user['username']} · ${r['id_type']} · ${r['full_name']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => _review(r['id'], r['user_id'], false), child: Container(height: 40, decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.error.withOpacity(0.3))), child: const Center(child: Text('REJECT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.error)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(onTap: () => _review(r['id'], r['user_id'], true), child: Container(height: 40, decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.success.withOpacity(0.3))), child: const Center(child: Text('APPROVE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.success)))))),
            ]),
          ]));
      })),
    ]);
  }
}

// ── Exco Section — FIXED ──────────────────────────────────────────────────────
class _ExcoSection extends ConsumerStatefulWidget {
  const _ExcoSection();
  @override ConsumerState<_ExcoSection> createState() => _ExcoSectionState();
}
class _ExcoSectionState extends ConsumerState<_ExcoSection> {
  List<Map<String, dynamic>> _assignments = []; bool _loading = true;
  final _emailCtrl = TextEditingController();
  String _selectedRole = ExcoRole.customerAgent;

  final _roles = [(ExcoRole.communityManager, 'Community Manager'), (ExcoRole.inventoryManager, 'Inventory Manager'), (ExcoRole.financeTeam, 'Finance Team'), (ExcoRole.customerAgent, 'Customer Agent'), (ExcoRole.blogEditor, 'Blog Editor')];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final data = await SupabaseService.client.from('exco_assignments').select('*, profile:profiles!exco_id(display_name, username, avatar_url)').order('created_at', ascending: false); if (mounted) setState(() { _assignments = List<Map<String, dynamic>>.from(data); _loading = false; }); }
    catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _removeExco(String assignmentId, String userId, String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Remove Exco', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
        content: Text('Remove this person from the ${role.replaceAll('_', ' ')} role?',
            style: const TextStyle(color: GacomColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE', style: TextStyle(color: GacomColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      // Delete the exco assignment row
      await SupabaseService.client
          .from('exco_assignments')
          .delete()
          .eq('id', assignmentId);

      // Check if user has any remaining exco roles; if not, revert role to 'user'
      final remaining = await SupabaseService.client
          .from('exco_assignments')
          .select('id')
          .eq('exco_id', userId);
      if ((remaining as List).isEmpty) {
        await SupabaseService.client
            .from('profiles')
            .update({'role': 'user'})
            .eq('id', userId);
      }

      GacomSnackbar.show(context, 'Exco role removed ✅', isSuccess: true);
      await _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Failed to remove: $e', isError: true);
    }
  }

  Future<void> _assignExco() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { GacomSnackbar.show(context, 'Enter user email', isError: true); return; }
    try {
      // ✅ FIX: Use the correct RPC. If it doesn't exist, fallback to searching profiles
      // by checking auth.users via a SQL function we create.
      // For now: search profiles where the user's email matches via a safe RPC.
      String? userId;
      
      try {
        // Try the RPC first
        final result = await SupabaseService.client.rpc('get_user_id_by_email', params: {'email': email});
        userId = result as String?;
      } catch (_) {
        // RPC doesn't exist yet — show helpful message
        GacomSnackbar.show(context, 'Missing DB function. Run the SQL in supabase/patch5.sql first.', isError: true);
        return;
      }

      if (userId == null || userId.isEmpty) {
        GacomSnackbar.show(context, 'No user found with email: $email', isError: true);
        return;
      }

      await SupabaseService.client.from('exco_assignments').upsert({'exco_id': userId, 'exco_role': _selectedRole, 'assigned_by': SupabaseService.currentUserId}, onConflict: 'exco_id,exco_role');
      await SupabaseService.client.from('profiles').update({'role': 'exco'}).eq('id', userId);
      
      // If blog editor, also grant blog permission
      if (_selectedRole == ExcoRole.blogEditor) {
      await SupabaseService.client.from('admin_permissions').upsert({
        'admin_id': userId, 'permission': AdminPermission.manageBlog, 'granted_by': SupabaseService.currentUserId,
      }, onConflict: 'admin_id,permission');
      }

      _emailCtrl.clear();
      GacomSnackbar.show(context, 'Exco assigned ✅', isSuccess: true);
      await _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Failed: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Assign Exco Roles', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('Identify by email address. They get special dashboard access.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GacomTextField(controller: _emailCtrl, label: 'User Email', hint: 'executive@gacom.gg', prefixIcon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        const Text('Role', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _roles.map((r) { final isSel = _selectedRole == r.$1; return GestureDetector(onTap: () => setState(() => _selectedRole = r.$1), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isSel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: isSel ? GacomColors.deepOrange : GacomColors.border)), child: Text(r.$2, style: TextStyle(color: isSel ? GacomColors.deepOrange : GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)))); }).toList()),
        const SizedBox(height: 16),
        GacomButton(label: 'ASSIGN ROLE', onPressed: _assignExco),
      ])),
      const SizedBox(height: 24),
      const Text('Current Exco', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
      const SizedBox(height: 12),
      if (_loading) const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
      else if (_assignments.isEmpty) const Text('No exco assigned yet.', style: TextStyle(color: GacomColors.textMuted))
      else ..._assignments.map((a) {
        final profile = a['profile'] as Map? ?? {};
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)), Text('@${profile['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))])),
            Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: GacomColors.info.withOpacity(0.3))),
                  child: Text((a['exco_role'] as String? ?? '').replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: GacomColors.info, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeExco(a['id'] as String, a['exco_id'] as String, a['exco_role'] as String? ?? ''),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: GacomColors.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: GacomColors.error.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.person_remove_rounded, size: 14, color: GacomColors.error),
                  ),
                ),
              ]));
      }),
    ]);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _AdminField extends StatelessWidget {
  final TextEditingController ctrl; final String label; final TextInputType? type; final int maxLines;
  const _AdminField(this.ctrl, this.label, {this.type, this.maxLines = 1});
  @override Widget build(BuildContext context) => TextField(controller: ctrl, keyboardType: type, maxLines: maxLines, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Outfit'), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: GacomColors.textSecondary), filled: true, fillColor: GacomColors.surfaceDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.deepOrange))));
}
