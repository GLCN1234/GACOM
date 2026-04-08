import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});
  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _subCommunities = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isMember = false;
  bool _joining = false;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUserId;
    try {
      final comm = await SupabaseService.client
          .from('communities')
          .select('*, created_by_profile:profiles!created_by(username, display_name, avatar_url)')
          .eq('id', widget.communityId)
          .single();
      final subs = await SupabaseService.client
          .from('communities').select('*')
          .eq('parent_id', widget.communityId)
          .order('members_count', ascending: false).limit(10);
      final ps = await SupabaseService.client
          .from('posts')
          .select('*, author:profiles!author_id(username, display_name, avatar_url, verification_status)')
          .eq('community_id', widget.communityId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false).limit(20);
      bool isMember = false;
      if (userId != null) {
        final check = await SupabaseService.client
            .from('community_members').select('id')
            .eq('community_id', widget.communityId)
            .eq('user_id', userId).maybeSingle();
        isMember = check != null;
      }
      if (mounted) {
        setState(() {
          _community = comm;
          _subCommunities = List<Map<String, dynamic>>.from(subs);
          _posts = List<Map<String, dynamic>>.from(ps);
          _isMember = isMember;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _joining = true);
    try {
      await SupabaseService.client
          .from('community_members')
          .insert({'community_id': widget.communityId, 'user_id': userId});
      if (mounted) {
        setState(() { _isMember = true; _joining = false; });
        GacomSnackbar.show(context, 'Joined ${_community?['name']}!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _joining = false);
        GacomSnackbar.show(context, 'Failed to join', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: GacomColors.obsidian,
          body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    }
    final c = _community!;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: GacomColors.obsidian,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                c['banner_url'] != null
                    ? CachedNetworkImage(imageUrl: c['banner_url'], fit: BoxFit.cover)
                    : Container(decoration: const BoxDecoration(gradient: GacomColors.orangeGradient)),
                Container(decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.transparent, GacomColors.obsidian.withOpacity(0.8)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: c['icon_url'] != null
                        ? CachedNetworkImage(imageUrl: c['icon_url'], width: 64, height: 64, fit: BoxFit.cover)
                        : Container(
                            width: 64, height: 64,
                            decoration: const BoxDecoration(gradient: GacomColors.orangeGradient),
                            child: Center(child: Text((c['name'] ?? 'G')[0],
                                style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                    Text(c['game_name'] ?? '', style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w600)),
                    Text('${c['members_count'] ?? 0} members', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                  ])),
                ]),
                const SizedBox(height: 14),
                if (c['description'] != null)
                  Text(c['description'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.5)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _isMember
                        ? GacomButton(label: 'JOINED ✓', isOutlined: true, height: 44, onPressed: () {})
                        : GacomButton(label: 'JOIN COMMUNITY', height: 44, isLoading: _joining, onPressed: _join),
                  ),
                  if (_isMember) ...[
                    const SizedBox(width: 10),
                    GacomButton(
                        label: '',
                        width: 44, height: 44,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                        onPressed: () => context.go('/chat')),
                  ],
                ]),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tab,
                  indicatorColor: GacomColors.deepOrange,
                  labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [Tab(text: 'POSTS'), Tab(text: 'SUB-GROUPS'), Tab(text: 'COMPETITIONS')],
                ),
              ]),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _PostsTab(posts: _posts),
            // ✅ FIXED: pass verified status for access control
            _SubCommunitiesTab(
                communityId: widget.communityId,
                subs: _subCommunities,
                isMember: _isMember),
            _CompetitionsTab(communityId: widget.communityId),
          ],
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _PostsTab({required this.posts});
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No posts yet. Be the first!', style: TextStyle(color: GacomColors.textMuted)));
    }
    return ListView.builder(
      // ✅ Bottom padding so last item doesn't hide behind nav bar
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final p = posts[i];
        final author = p['author'] as Map<String, dynamic>? ?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: GacomColors.border,
                  backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null,
                  child: author['avatar_url'] == null ? Text((author['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary)) : null),
              const SizedBox(width: 10),
              Text(author['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            if (p['caption'] != null) Text(p['caption'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.5)),
          ]),
        );
      },
    );
  }
}

class _SubCommunitiesTab extends StatefulWidget {
  final String communityId;
  final List<Map<String, dynamic>> subs;
  final bool isMember;
  const _SubCommunitiesTab({required this.communityId, required this.subs, required this.isMember});
  @override
  State<_SubCommunitiesTab> createState() => _SubCommunitiesTabState();
}

class _SubCommunitiesTabState extends State<_SubCommunitiesTab> {
  List<Map<String, dynamic>> _subs = [];
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _subs = widget.subs;
    _checkVerified();
  }

  Future<void> _checkVerified() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final p = await SupabaseService.client
          .from('profiles').select('verification_status, role').eq('id', uid).single();
      final status = p['verification_status'] as String? ?? '';
      final role = p['role'] as String? ?? '';
      if (mounted) {
        setState(() => _isVerified =
            status == 'verified' || role == 'admin' || role == 'super_admin');
      }
    } catch (_) {}
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Sub-Community',
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          GacomTextField(controller: nameCtrl, label: 'Name', hint: 'Sub-community name'),
          const SizedBox(height: 12),
          GacomTextField(controller: descCtrl, label: 'Description', hint: 'What is this about?', maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await SupabaseService.client.from('communities').insert({
                  'name': name,
                  'slug': '${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}',
                  'description': descCtrl.text.trim(),
                  'parent_id': widget.communityId,
                  'game_name': 'Sub-community',
                  'created_by': SupabaseService.currentUserId,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  GacomSnackbar.show(context, 'Sub-community created!', isSuccess: true);
                  // Refresh list
                  final subs = await SupabaseService.client
                      .from('communities').select('*')
                      .eq('parent_id', widget.communityId)
                      .order('members_count', ascending: false).limit(10);
                  if (mounted) setState(() => _subs = List<Map<String, dynamic>>.from(subs));
                }
              } catch (e) {
                if (context.mounted) GacomSnackbar.show(context, 'Failed to create', isError: true);
              }
            },
            child: const Text('CREATE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ✅ FIXED: bottom:100 clears the nav bar so the button is always accessible
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Show create button only to verified users or members
        if (widget.isMember && _isVerified) ...[
          GacomButton(
            label: '+ CREATE SUB-COMMUNITY',
            isOutlined: true,
            height: 48,
            onPressed: _showCreateDialog,
          ),
          const SizedBox(height: 16),
        ] else if (widget.isMember && !_isVerified) ...[
          // Show info that verification is needed
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GacomColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GacomColors.warning.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.verified_outlined, color: GacomColors.warning, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Get verified to create sub-communities',
                style: TextStyle(color: GacomColors.warning, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600),
              )),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        if (_subs.isEmpty)
          const Center(child: Text('No sub-communities yet.', style: TextStyle(color: GacomColors.textMuted)))
        else
          ..._subs.map((s) => GestureDetector(
                onTap: () => context.go('/communities/${widget.communityId}/sub/${s['id']}'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
                  child: Row(children: [
                    const Icon(Icons.group_work_outlined, color: GacomColors.deepOrange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                      Text('${s['members_count'] ?? 0} members', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
                  ]),
                ),
              )),
      ],
    );
  }
}

class _CompetitionsTab extends ConsumerStatefulWidget {
  final String communityId;
  const _CompetitionsTab({required this.communityId});
  @override
  ConsumerState<_CompetitionsTab> createState() => _CompetitionsTabState();
}

class _CompetitionsTabState extends ConsumerState<_CompetitionsTab> {
  List<Map<String, dynamic>> _competitions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('competitions').select('*')
          .eq('community_id', widget.communityId)
          .order('starts_at').limit(10);
      if (mounted) setState(() { _competitions = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_competitions.isEmpty) return const Center(child: Text('No competitions yet.', style: TextStyle(color: GacomColors.textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _competitions.length,
      itemBuilder: (_, i) {
        final c = _competitions[i];
        return GestureDetector(
          onTap: () => context.go('/competitions/${c['id']}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
            child: Row(children: [
              const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 15)),
                Text('Prize: ₦${c['prize_pool'] ?? 0}  |  ${c['status']}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
            ]),
          ),
        );
      },
    );
  }
}
