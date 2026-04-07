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
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends ConsumerState<AdminDashboardScreen> {
  int _selectedSection = 0;
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  final _sections = [
    'Dashboard',
    'Users',
    'Competitions',
    'Communities',
    'Store',
    'Finance',
    'Verification',
    'Exco / Tasks',
    'Support',
  ];
  final _sectionIcons = [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.sports_esports_rounded,
    Icons.groups_rounded,
    Icons.storefront_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.verified_rounded,
    Icons.badge_rounded,
    Icons.support_agent_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadStats();
  }

  Future<void> _checkAdmin() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) context.go(AppConstants.loginRoute);
      return;
    }
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      if (!['admin', 'super_admin'].contains(profile['role'])) {
        if (mounted) {
          GacomSnackbar.show(context, 'Access denied.', isError: true);
          context.go(AppConstants.homeRoute);
        }
      }
    } catch (_) {
      if (mounted) context.go(AppConstants.homeRoute);
    }
  }

  Future<void> _loadStats() async {
    try {
      final users =
          await SupabaseService.client.from('profiles').select('id');
      final competitions = await SupabaseService.client
          .from('competitions')
          .select('id');
      final communities =
          await SupabaseService.client.from('communities').select('id');
      final verifications = await SupabaseService.client
          .from('verification_requests')
          .select('id')
          .eq('status', 'pending');
      final tickets = await SupabaseService.client
          .from('support_tickets')
          .select('id')
          .eq('status', 'open');

      // Geo stats
      final geoRows = await SupabaseService.client
          .from('profiles')
          .select('location');

      Map<String, int> geoCounts = {};
      for (final row in (geoRows as List)) {
        final loc = (row['location'] as String?) ?? 'Unknown';
        final country =
            loc.split(',').last.trim().isEmpty ? 'Unknown' : loc.split(',').last.trim();
        geoCounts[country] = (geoCounts[country] ?? 0) + 1;
      }
      final sortedGeo = geoCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _stats = {
            'users': (users as List).length,
            'competitions': (competitions as List).length,
            'communities': (communities as List).length,
            'pending_verifications': (verifications as List).length,
            'open_tickets': (tickets as List).length,
            'geo': sortedGeo.take(10).toList(),
          };
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: isWide
          ? Row(children: [
              _Sidebar(
                  sections: _sections,
                  icons: _sectionIcons,
                  selected: _selectedSection,
                  onSelect: (i) => setState(() => _selectedSection = i)),
              Expanded(child: _buildSection()),
            ])
          : Scaffold(
              appBar: AppBar(
                title: const Text('GACOM ADMIN'),
                backgroundColor: GacomColors.darkVoid,
              ),
              drawer: Drawer(
                backgroundColor: GacomColors.darkVoid,
                child: _Sidebar(
                    sections: _sections,
                    icons: _sectionIcons,
                    selected: _selectedSection,
                    onSelect: (i) {
                      setState(() => _selectedSection = i);
                      Navigator.pop(context);
                    }),
              ),
              body: _buildSection(),
            ),
    );
  }

  Widget _buildSection() {
    switch (_selectedSection) {
      case 0:
        return _DashboardSection(stats: _stats, loading: _loading);
      case 1:
        return const _UsersSection();
      case 2:
        return const _CompetitionsAdminSection();
      case 3:
        return const _CommunitiesAdminSection();
      case 5:
        return const _FinanceSection();
      case 6:
        return const _VerificationSection();
      case 7:
        return const _ExcoSection();
      case 8:
        return const _SupportAdminSection();
      default:
        return Center(
            child: Text(_sections[_selectedSection],
                style: const TextStyle(
                    color: GacomColors.textMuted, fontSize: 20)));
    }
  }
}

// ─────────────────── Sidebar ────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<String> sections;
  final List<IconData> icons;
  final int selected;
  final void Function(int) onSelect;
  const _Sidebar(
      {required this.sections,
      required this.icons,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        color: GacomColors.darkVoid,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                ClipOval(
                  child: Image.network(AppConstants.logoUrl,
                      width: 36, height: 36, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                                gradient: GacomColors.orangeGradient,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.sports_esports_rounded,
                                color: Colors.white, size: 18),
                          )),
                ),
                const SizedBox(width: 10),
                const Text('ADMIN',
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: GacomColors.deepOrange,
                        letterSpacing: 2)),
              ]),
            ),
            const Divider(color: GacomColors.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sections.length,
                itemBuilder: (_, i) {
                  final isSel = selected == i;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: isSel
                              ? GacomColors.deepOrange.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSel
                              ? Border.all(
                                  color: GacomColors.deepOrange
                                      .withOpacity(0.4))
                              : null),
                      child: Row(children: [
                        Icon(icons[i],
                            size: 18,
                            color: isSel
                                ? GacomColors.deepOrange
                                : GacomColors.textMuted),
                        const SizedBox(width: 10),
                        Text(sections[i],
                            style: TextStyle(
                                color: isSel
                                    ? GacomColors.deepOrange
                                    : GacomColors.textSecondary,
                                fontFamily: 'Rajdhani',
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      );
}

// ─────────────────── Dashboard ──────────────────────────────────────────
class _DashboardSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool loading;
  const _DashboardSection({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: GacomColors.deepOrange));
    }
    final geo =
        stats['geo'] as List<MapEntry<String, int>>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('OVERVIEW',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: GacomColors.textPrimary,
                letterSpacing: 2)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
                label: 'Total Users',
                value: '${stats['users'] ?? 0}',
                icon: Icons.people_rounded,
                color: GacomColors.deepOrange),
            _StatCard(
                label: 'Competitions',
                value: '${stats['competitions'] ?? 0}',
                icon: Icons.sports_esports_rounded,
                color: GacomColors.info),
            _StatCard(
                label: 'Communities',
                value: '${stats['communities'] ?? 0}',
                icon: Icons.groups_rounded,
                color: GacomColors.success),
            _StatCard(
                label: 'Pending Verif.',
                value: '${stats['pending_verifications'] ?? 0}',
                icon: Icons.verified_rounded,
                color: GacomColors.warning),
            _StatCard(
                label: 'Open Tickets',
                value: '${stats['open_tickets'] ?? 0}',
                icon: Icons.support_agent_rounded,
                color: GacomColors.error),
          ],
        ),
        const SizedBox(height: 32),
        if (geo.isNotEmpty) ...[
          const Text('USERS BY COUNTRY',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: GacomColors.textPrimary,
                  letterSpacing: 1)),
          const SizedBox(height: 16),
          ...geo.map((e) {
            final total = stats['users'] as int? ?? 1;
            final pct = (e.value / total * 100).toStringAsFixed(1);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: GacomColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: GacomColors.border, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            color: GacomColors.textPrimary,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  Text('${e.value} users • $pct%',
                      style: const TextStyle(
                          color: GacomColors.textMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / total,
                    backgroundColor: GacomColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        GacomColors.deepOrange),
                    minHeight: 4,
                  ),
                ),
              ]),
            );
          }).toList(),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 30)),
          Text(label,
              style: const TextStyle(
                  color: GacomColors.textMuted, fontSize: 12)),
        ]),
      );
}

// ─────────────────── Users ──────────────────────────────────────────────
class _UsersSection extends ConsumerStatefulWidget {
  const _UsersSection();
  @override
  ConsumerState<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends ConsumerState<_UsersSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? query]) async {
    try {
      var q = SupabaseService.client
          .from('profiles')
          .select('id, display_name, username, email, role, verification_status, is_banned, created_at, location');
      if (query != null && query.isNotEmpty) {
        q = q.ilike('username', '%$query%') as dynamic;
      }
      final data = await (q as dynamic).order('created_at', ascending: false).limit(50);
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleBan(String userId, bool isBanned) async {
    await SupabaseService.client.from('profiles').update({
      'is_banned': !isBanned,
      'ban_reason': isBanned ? null : 'Admin ban'
    }).eq('id', userId);
    await _load();
    GacomSnackbar.show(context, isBanned ? 'User unbanned' : 'User banned', isSuccess: true);
  }

  Future<void> _grantCreateCompetitions(String userId) async {
    await SupabaseService.client.from('admin_permissions').upsert({
      'admin_id': userId,
      'permission': AdminPermission.createCompetitions,
      'granted_by': SupabaseService.currentUserId,
    });
    GacomSnackbar.show(context, 'Permission granted ✅', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: GacomColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: const TextStyle(color: GacomColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted),
                filled: true,
                fillColor: GacomColors.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border)),
              ),
              onSubmitted: _load,
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  final banned = u['is_banned'] as bool? ?? false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: GacomColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: banned ? GacomColors.error.withOpacity(0.3) : GacomColors.border, width: 0.5)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('@${u['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                          if (u['location'] != null) Text('📍 ${u['location']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: (banned ? GacomColors.error : GacomColors.success).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(u['role']?.toString().toUpperCase() ?? 'USER', style: TextStyle(color: banned ? GacomColors.error : GacomColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        _ActionBtn(label: banned ? 'Unban' : 'Ban', color: banned ? GacomColors.success : GacomColors.error, onTap: () => _toggleBan(u['id'], banned)),
                        _ActionBtn(label: 'Allow Competitions', color: GacomColors.info, onTap: () => _grantCreateCompetitions(u['id'])),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.35))),
          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      );
}

// ─────────────────── Competitions ───────────────────────────────────────
class _CompetitionsAdminSection extends ConsumerStatefulWidget {
  const _CompetitionsAdminSection();
  @override
  ConsumerState<_CompetitionsAdminSection> createState() => _CompetitionsAdminState();
}

class _CompetitionsAdminState extends ConsumerState<_CompetitionsAdminSection> {
  List<Map<String, dynamic>> _comps = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('competitions').select('*').order('created_at', ascending: false).limit(30);
      if (mounted) setState(() { _comps = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Text('Competitions', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showCreateDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, color: Colors.white, size: 16), SizedBox(width: 6), Text('CREATE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13))]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _comps.length,
                itemBuilder: (_, i) {
                  final c = _comps[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['title'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(c['game_name'] ?? '', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text((c['status'] ?? '').toUpperCase(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  void _showCreateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final gameCtrl = TextEditingController();
    final prizeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Create Competition', style: TextStyle(fontFamily: 'Rajdhani', color: GacomColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          GacomTextField(controller: titleCtrl, label: 'Title', hint: '', prefixIcon: Icons.title_rounded),
          const SizedBox(height: 12),
          GacomTextField(controller: gameCtrl, label: 'Game', hint: '', prefixIcon: Icons.sports_esports_rounded),
          const SizedBox(height: 12),
          GacomTextField(controller: prizeCtrl, label: 'Prize Pool ₦', hint: '0', prefixIcon: Icons.emoji_events_rounded, keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await SupabaseService.client.from('competitions').insert({
                'title': titleCtrl.text.trim(),
                'game_name': gameCtrl.text.trim(),
                'prize_pool': double.tryParse(prizeCtrl.text) ?? 0,
                'status': 'upcoming',
                'competition_type': 'free',
                'created_by': SupabaseService.currentUserId,
                'is_admin_created': true,
              });
              if (context.mounted) {
                Navigator.pop(context);
                GacomSnackbar.show(context, 'Competition created!', isSuccess: true);
                setState(() => _loading = true);
                _load();
              }
            },
            child: const Text('CREATE', style: TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Communities Admin ──────────────────────────────────
class _CommunitiesAdminSection extends ConsumerStatefulWidget {
  const _CommunitiesAdminSection();
  @override
  ConsumerState<_CommunitiesAdminSection> createState() => _CommunitiesAdminState();
}

class _CommunitiesAdminState extends ConsumerState<_CommunitiesAdminSection> {
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('communities').select('*').order('members_count', ascending: false).limit(30);
      if (mounted) setState(() { _communities = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Text('Communities', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showCreateDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, color: Colors.white, size: 16), SizedBox(width: 6), Text('CREATE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13))]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _communities.length,
                itemBuilder: (_, i) {
                  final c = _communities[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${c['members_count'] ?? 0} members • ${c['game_name'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      ])),
                      Switch(value: c['is_active'] as bool? ?? true, activeColor: GacomColors.deepOrange,
                        onChanged: (v) async {
                          await SupabaseService.client.from('communities').update({'is_active': v}).eq('id', c['id']);
                          await _load();
                        },
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final gameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Create Community', style: TextStyle(fontFamily: 'Rajdhani', color: GacomColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          GacomTextField(controller: nameCtrl, label: 'Name', hint: '', prefixIcon: Icons.group_rounded),
          const SizedBox(height: 12),
          GacomTextField(controller: gameCtrl, label: 'Game', hint: '', prefixIcon: Icons.sports_esports_rounded),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final slug = nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
              await SupabaseService.client.from('communities').insert({
                'name': nameCtrl.text.trim(),
                'slug': '$slug-${DateTime.now().millisecondsSinceEpoch}',
                'game_name': gameCtrl.text.trim(),
                'created_by': SupabaseService.currentUserId,
                'is_admin_created': true,
                'is_active': true,
              });
              if (context.mounted) {
                Navigator.pop(context);
                GacomSnackbar.show(context, 'Community created!', isSuccess: true);
                setState(() => _loading = true);
                _load();
              }
            },
            child: const Text('CREATE', style: TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Finance ────────────────────────────────────────────
class _FinanceSection extends ConsumerStatefulWidget {
  const _FinanceSection();
  @override
  ConsumerState<_FinanceSection> createState() => _FinanceSectionState();
}

class _FinanceSectionState extends ConsumerState<_FinanceSection> {
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('withdrawal_requests')
          .select('*, user:profiles!user_id(display_name, username)')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) setState(() { _withdrawals = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Align(alignment: Alignment.centerLeft, child: Text('Finance / Withdrawals', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary))),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : _withdrawals.isEmpty
                ? const Center(child: Text('No withdrawal requests', style: TextStyle(color: GacomColors.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _withdrawals.length,
                    itemBuilder: (_, i) {
                      final w = _withdrawals[i];
                      final status = w['status'] as String? ?? 'pending';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(w['user']?['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
                              Text('₦${w['amount']} → ${w['bank_name']} ${w['account_number']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: (status == 'pending' ? GacomColors.warning : GacomColors.success).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(status.toUpperCase(), style: TextStyle(color: status == 'pending' ? GacomColors.warning : GacomColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          if (status == 'pending') ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              _ActionBtn(label: 'Approve', color: GacomColors.success, onTap: () async {
                                await SupabaseService.client.from('withdrawal_requests').update({'status': 'approved'}).eq('id', w['id']);
                                await _load();
                              }),
                              const SizedBox(width: 8),
                              _ActionBtn(label: 'Reject', color: GacomColors.error, onTap: () async {
                                await SupabaseService.client.from('withdrawal_requests').update({'status': 'rejected'}).eq('id', w['id']);
                                await _load();
                              }),
                            ]),
                          ],
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// ─────────────────── Verification ───────────────────────────────────────
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
    try {
      final data = await SupabaseService.client
          .from('verification_requests')
          .select('*, user:profiles!user_id(display_name, username, avatar_url)')
          .order('created_at', ascending: false).limit(30);
      if (mounted) setState(() { _requests = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _decide(String requestId, String userId, String decision) async {
    await SupabaseService.client.from('verification_requests').update({'status': decision}).eq('id', requestId);
    await SupabaseService.client.from('profiles').update({'verification_status': decision}).eq('id', userId);
    await _load();
    GacomSnackbar.show(context, 'Verification ${decision}ed', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Align(alignment: Alignment.centerLeft, child: Text('Verification Requests', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary))),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _requests.length,
                itemBuilder: (_, i) {
                  final r = _requests[i];
                  final status = r['status'] as String? ?? 'pending';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r['user']?['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: GacomColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: const TextStyle(color: GacomColors.warning, fontSize: 10, fontWeight: FontWeight.w700))),
                      ]),
                      if (status == 'pending') ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          _ActionBtn(label: 'Approve', color: GacomColors.success, onTap: () => _decide(r['id'], r['user_id'], 'verified')),
                          const SizedBox(width: 8),
                          _ActionBtn(label: 'Reject', color: GacomColors.error, onTap: () => _decide(r['id'], r['user_id'], 'rejected')),
                        ]),
                      ],
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

// ─────────────────── Exco / Tasks ───────────────────────────────────────
class _ExcoSection extends ConsumerStatefulWidget {
  const _ExcoSection();
  @override
  ConsumerState<_ExcoSection> createState() => _ExcoSectionState();
}

class _ExcoSectionState extends ConsumerState<_ExcoSection> {
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  final _emailCtrl = TextEditingController();
  String _selectedRole = ExcoRole.customerAgent;

  final _roles = [
    (ExcoRole.communityManager, 'Community Manager'),
    (ExcoRole.inventoryManager, 'Inventory Manager'),
    (ExcoRole.financeTeam, 'Finance Team'),
    (ExcoRole.customerAgent, 'Customer Agent'),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('exco_assignments')
          .select('*, profile:profiles!exco_id(display_name, username, avatar_url)')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _assignments = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _assignExco() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    try {
      // Find user by email
      final users = await SupabaseService.client
          .from('profiles')
          .select('id, display_name')
          .ilike('id', '%') // We need to join auth.users which isn't directly available
          .limit(1);

      // Instead find by username/email field if stored
      final byEmail = await SupabaseService.client.rpc('get_user_id_by_email', params: {'email': email});
      if (byEmail == null) {
        GacomSnackbar.show(context, 'User not found', isError: true);
        return;
      }
      await SupabaseService.client.from('exco_assignments').upsert({
        'exco_id': byEmail,
        'exco_role': _selectedRole,
        'assigned_by': SupabaseService.currentUserId,
      });
      await SupabaseService.client.from('profiles').update({'role': 'exco'}).eq('id', byEmail);
      _emailCtrl.clear();
      GacomSnackbar.show(context, 'Exco assigned ✅', isSuccess: true);
      await _load();
    } catch (e) {
      GacomSnackbar.show(context, 'Failed. Check email.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Assign Exco Roles',
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Identify by email. They get special access for their role.',
            style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GacomTextField(controller: _emailCtrl, label: 'User Email', hint: 'executive@gacom.gg', prefixIcon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            const Text('Role', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _roles.map((r) {
              final isSelected = _selectedRole == r.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRole = r.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: isSelected ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: isSelected ? GacomColors.deepOrange : GacomColors.border)),
                  child: Text(r.$2, style: TextStyle(color: isSelected ? GacomColors.deepOrange : GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            GacomButton(label: 'ASSIGN ROLE', onPressed: _assignExco),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Current Exco', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
        else if (_assignments.isEmpty)
          const Text('No exco assigned yet.', style: TextStyle(color: GacomColors.textMuted))
        else
          ..._assignments.map((a) {
            final profile = a['profile'] as Map? ?? {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profile['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('@${profile['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: GacomColors.info.withOpacity(0.3))),
                  child: Text((a['exco_role'] as String? ?? '').replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: GacomColors.info, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }).toList(),
      ],
    );
  }
}

// ─────────────────── Support Admin ──────────────────────────────────────
class _SupportAdminSection extends ConsumerStatefulWidget {
  const _SupportAdminSection();
  @override
  ConsumerState<_SupportAdminSection> createState() => _SupportAdminState();
}

class _SupportAdminState extends ConsumerState<_SupportAdminSection> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('support_tickets')
          .select('*, user:profiles!user_id(display_name, username)')
          .order('created_at', ascending: false).limit(30);
      if (mounted) setState(() { _tickets = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Text('Support Tickets', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20, color: GacomColors.textPrimary)),
          const Spacer(),
          Text('${_tickets.where((t) => t['status'] == 'open').length} open', style: const TextStyle(color: GacomColors.warning, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
        ]),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tickets.length,
                itemBuilder: (_, i) {
                  final t = _tickets[i];
                  final status = t['status'] as String? ?? 'open';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['user']?['display_name'] ?? 'Unknown', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(t['issue'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: (status == 'open' ? GacomColors.warning : GacomColors.success).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(status.toUpperCase(), style: TextStyle(color: status == 'open' ? GacomColors.warning : GacomColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}
