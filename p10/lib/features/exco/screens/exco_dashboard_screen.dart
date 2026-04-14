import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_button.dart';

/// The Exco Dashboard — only for users with role = 'exco'.
/// Shows only the tools relevant to their specific exco_role assignment.
/// They never see the admin dashboard.
class ExcoDashboardScreen extends ConsumerStatefulWidget {
  const ExcoDashboardScreen({super.key});
  @override
  ConsumerState<ExcoDashboardScreen> createState() => _ExcoDashboardScreenState();
}

class _ExcoDashboardScreenState extends ConsumerState<ExcoDashboardScreen> {
  String? _excoRole;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) { if (mounted) context.go(AppConstants.loginRoute); return; }
    try {
      final p = await SupabaseService.client
          .from('profiles').select('display_name, avatar_url, role').eq('id', uid).single();

      if ((p['role'] as String?) != 'exco') {
        // Not exco — redirect them away
        if (mounted) { GacomSnackbar.show(context, 'Access denied', isError: true); context.go(AppConstants.homeRoute); }
        return;
      }

      // Get their specific exco role
      final assignment = await SupabaseService.client
          .from('exco_assignments').select('exco_role').eq('exco_id', uid).maybeSingle();

      if (mounted) setState(() {
        _profile = p;
        _excoRole = assignment?['exco_role'] as String?;
        _loading = false;
      });
    } catch (_) { if (mounted) context.go(AppConstants.homeRoute); }
  }

  String get _roleLabel {
    switch (_excoRole) {
      case 'inventory_manager': return 'Inventory Manager';
      case 'blog_editor': return 'Blog Editor';
      case 'community_manager': return 'Community Manager';
      case 'finance_team': return 'Finance Team';
      case 'customer_agent': return 'Customer Agent';
      default: return 'Exco Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: GacomColors.border,
            backgroundImage: _profile?['avatar_url'] != null ? CachedNetworkImageProvider(_profile!['avatar_url']) : null,
            child: _profile?['avatar_url'] == null ? Text((_profile?['display_name'] ?? 'E')[0], style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)) : null),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_profile?['display_name'] ?? 'Exco', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
            Container(margin: const EdgeInsets.only(top: 3), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.info.withOpacity(0.4))),
              child: Text(_roleLabel, style: const TextStyle(color: GacomColors.info, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
          ])),
          IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GacomColors.textMuted, size: 18), onPressed: () => context.go(AppConstants.homeRoute)),
        ])),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(height: 1, color: GacomColors.border)),
        const SizedBox(height: 8),

        // Role-specific content
        Expanded(child: _buildRoleContent()),
      ])),
    );
  }

  Widget _buildRoleContent() {
    switch (_excoRole) {
      case 'inventory_manager': return _InventoryManagerView();
      case 'blog_editor': return _BlogEditorView();
      case 'community_manager': return _CommunityManagerView();
      case 'finance_team': return _FinanceTeamView();
      case 'customer_agent': return _CustomerAgentView();
      default: return _GenericExcoView(role: _excoRole ?? 'unknown');
    }
  }
}

// ── Inventory Manager ─────────────────────────────────────────────────────────
class _InventoryManagerView extends ConsumerStatefulWidget {
  @override ConsumerState<_InventoryManagerView> createState() => _InventoryManagerViewState();
}
class _InventoryManagerViewState extends ConsumerState<_InventoryManagerView> {
  List<Map<String, dynamic>> _products = []; bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('products').select('*').order('created_at', ascending: false).limit(50);
      if (mounted) setState(() { _products = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MARKETPLACE', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
          Text('Manage all products in the store', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        ])),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          label: const Text('ADD', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          // ✅ Go directly to the store screen which has the add product sheet
          onPressed: () => context.go(AppConstants.storeRoute),
        ),
      ])),
      // Quick stats
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
        _StatChip('Total Products', '${_products.length}', GacomColors.info),
        const SizedBox(width: 10),
        _StatChip('Active', '${_products.where((p) => p['is_active'] == true).length}', GacomColors.success),
        const SizedBox(width: 10),
        _StatChip('Out of Stock', '${_products.where((p) => (p['stock'] as int? ?? 1) == 0).length}', GacomColors.error),
      ])),
      const SizedBox(height: 16),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else Expanded(child: RefreshIndicator(color: GacomColors.deepOrange, onRefresh: () async { setState(() => _loading = true); await _load(); },
        child: ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), itemCount: _products.length,
          itemBuilder: (_, i) {
            final p = _products[i];
            final images = (p['images'] as List?)?.cast<String>() ?? [];
            final isActive = p['is_active'] as bool? ?? true;
            final stock = p['stock'] as int? ?? 0;
            return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: stock == 0 ? GacomColors.error.withOpacity(0.3) : GacomColors.border, width: 0.5)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(width: 52, height: 52, color: GacomColors.surfaceDark,
                  child: images.isNotEmpty ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover) : const Icon(Icons.inventory_2_rounded, color: GacomColors.textMuted))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 14)),
                  Text('₦${(p['price'] as num?)?.toStringAsFixed(0) ?? '0'} · Stock: $stock', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                ])),
                // Toggle active
                GestureDetector(
                  onTap: () async {
                    await SupabaseService.client.from('products').update({'is_active': !isActive}).eq('id', p['id']);
                    await _load();
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: (isActive ? GacomColors.success : GacomColors.textMuted).withOpacity(0.12), borderRadius: BorderRadius.circular(50), border: Border.all(color: (isActive ? GacomColors.success : GacomColors.textMuted).withOpacity(0.4))),
                    child: Text(isActive ? 'LIVE' : 'HIDDEN', style: TextStyle(color: isActive ? GacomColors.success : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11))),
                ),
              ])).animate(delay: (i * 30).ms).fadeIn();
          }))),
    ]);
  }
}

// ── Blog Editor ───────────────────────────────────────────────────────────────
class _BlogEditorView extends ConsumerStatefulWidget {
  @override ConsumerState<_BlogEditorView> createState() => _BlogEditorViewState();
}
class _BlogEditorViewState extends ConsumerState<_BlogEditorView> {
  List<Map<String, dynamic>> _posts = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('blog_posts').select('*, author:profiles!author_id(display_name)').order('created_at', ascending: false).limit(30);
      if (mounted) setState(() { _posts = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  void _showCreate() {
    final titleCtrl = TextEditingController(); final excerptCtrl = TextEditingController(); final contentCtrl = TextEditingController(); String category = 'News';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(backgroundColor: GacomColors.cardDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Write Article', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        GacomTextField(controller: titleCtrl, label: 'Title *', hint: 'Article title'),
        const SizedBox(height: 12),
        GacomTextField(controller: excerptCtrl, label: 'Excerpt', hint: 'Short summary...', maxLines: 2),
        const SizedBox(height: 12),
        GacomTextField(controller: contentCtrl, label: 'Content *', hint: 'Write your article...', maxLines: 8),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: ['News', 'Esports', 'Reviews', 'Tips', 'Tournaments', 'Community'].map((c) =>
          GestureDetector(onTap: () => setDlg(() => category = c), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: category == c ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: category == c ? GacomColors.deepOrange : GacomColors.border)),
            child: Text(c, style: TextStyle(color: category == c ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13))))).toList()),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: GacomColors.textMuted))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async {
          if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) { GacomSnackbar.show(ctx, 'Title and content required', isError: true); return; }
          try {
            final slug = '${titleCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
            await SupabaseService.client.from('blog_posts').insert({'title': titleCtrl.text.trim(), 'slug': slug, 'excerpt': excerptCtrl.text.trim().isEmpty ? null : excerptCtrl.text.trim(), 'content': contentCtrl.text.trim(), 'category': category, 'author_id': SupabaseService.currentUserId, 'is_published': true, 'published_at': DateTime.now().toIso8601String()});
            if (ctx.mounted) Navigator.pop(ctx);
            GacomSnackbar.show(context, 'Published! ✅', isSuccess: true);
            _load();
          } catch (e) { GacomSnackbar.show(ctx, 'Failed: $e', isError: true); }
        }, child: const Text('PUBLISH', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))])));
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BLOG POSTS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)), Text('Write and manage articles', style: TextStyle(color: GacomColors.textMuted, fontSize: 13))]),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18), label: const Text('WRITE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)), onPressed: _showCreate),
      ])),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), itemCount: _posts.length, itemBuilder: (_, i) {
        final p = _posts[i]; final isPublished = p['is_published'] as bool? ?? false;
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 14)), Text('${p['category'] ?? 'Updates'} · ${(p['author'] as Map?)?['display_name'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11))])),
            GestureDetector(onTap: () async { await SupabaseService.client.from('blog_posts').update({'is_published': !isPublished, 'published_at': !isPublished ? DateTime.now().toIso8601String() : null}).eq('id', p['id']); _load(); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isPublished ? GacomColors.success : GacomColors.textMuted).withOpacity(0.12), borderRadius: BorderRadius.circular(50), border: Border.all(color: (isPublished ? GacomColors.success : GacomColors.textMuted).withOpacity(0.4))),
                child: Text(isPublished ? 'LIVE' : 'DRAFT', style: TextStyle(color: isPublished ? GacomColors.success : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11)))),
          ])).animate(delay: (i * 30).ms).fadeIn();
      })),
    ]);
  }
}

// ── Community Manager ─────────────────────────────────────────────────────────
class _CommunityManagerView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('COMMUNITY TOOLS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('Manage communities and sub-communities', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
    const SizedBox(height: 20),
    _ExcoTile(icon: Icons.groups_rounded, title: 'View All Communities', subtitle: 'Browse and manage communities', onTap: () => context.go(AppConstants.communityRoute)),
    _ExcoTile(icon: Icons.flag_rounded, title: 'Reported Content', subtitle: 'Review flagged posts & comments', onTap: () => GacomSnackbar.show(context, 'Coming soon')),
    _ExcoTile(icon: Icons.block_rounded, title: 'Manage Bans', subtitle: 'Community-level user bans', onTap: () => GacomSnackbar.show(context, 'Coming soon')),
  ]);
}

// ── Finance Team ──────────────────────────────────────────────────────────────
class _FinanceTeamView extends ConsumerStatefulWidget {
  @override ConsumerState<_FinanceTeamView> createState() => _FinanceTeamViewState();
}
class _FinanceTeamViewState extends ConsumerState<_FinanceTeamView> {
  List<Map<String, dynamic>> _withdrawals = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('withdrawal_requests').select('*, user:profiles!user_id(display_name, username)').eq('status', 'pending').order('created_at').limit(30);
      if (mounted) setState(() { _withdrawals = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _process(String id, bool approve) async {
    await SupabaseService.client.from('withdrawal_requests').update({'status': approve ? 'approved' : 'rejected', 'processed_by': SupabaseService.currentUserId, 'processed_at': DateTime.now().toIso8601String()}).eq('id', id);
    _load(); GacomSnackbar.show(context, approve ? 'Withdrawal approved ✅' : 'Rejected', isSuccess: approve);
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 16), child: Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('FINANCE TOOLS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)), Text('Process withdrawal requests', style: TextStyle(color: GacomColors.textMuted, fontSize: 13))]))),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
      else if (_withdrawals.isEmpty) const Expanded(child: Center(child: Text('No pending withdrawals ✅', style: TextStyle(color: GacomColors.textMuted))))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), itemCount: _withdrawals.length, itemBuilder: (_, i) {
        final w = _withdrawals[i]; final user = w['user'] as Map? ?? {};
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.warning.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['display_name'] ?? 'Unknown', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
            Text('₦${w['amount']} · ${w['bank_name']} · ${w['account_number']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => _process(w['id'], false), child: Container(height: 40, decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.error.withOpacity(0.3))), child: const Center(child: Text('REJECT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.error)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(onTap: () => _process(w['id'], true), child: Container(height: 40, decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.success.withOpacity(0.3))), child: const Center(child: Text('APPROVE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.success)))))),
            ]),
          ]));
      })),
    ]);
  }
}

// ── Customer Agent ─────────────────────────────────────────────────────────────
class _CustomerAgentView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('SUPPORT TOOLS', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('Handle user support tickets', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
    const SizedBox(height: 20),
    _ExcoTile(icon: Icons.support_agent_rounded, title: 'Support Chat', subtitle: 'Respond to user support tickets', onTap: () => context.go(AppConstants.agentChatRoute)),
    _ExcoTile(icon: Icons.notifications_active_rounded, title: 'Active Tickets', subtitle: 'View all open tickets', onTap: () => context.go(AppConstants.agentChatRoute)),
  ]);
}

// ── Generic fallback ──────────────────────────────────────────────────────────
class _GenericExcoView extends StatelessWidget {
  final String role;
  const _GenericExcoView({required this.role});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.badge_rounded, size: 64, color: GacomColors.info),
    const SizedBox(height: 16),
    Text('Exco: ${role.replaceAll('_', ' ').toUpperCase()}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
    const SizedBox(height: 8),
    const Text('Your role features are being set up.\nContact your admin.', textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted)),
  ]));
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis),
    ])));
}

class _ExcoTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ExcoTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: GacomColors.deepOrange, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)), Text(subtitle, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))])),
      const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
    ])));
}
