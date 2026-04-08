import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

final _demoProfile = {
  'id': 'demo',
  'display_name': 'Ghost Striker',
  'username': 'ghost_striker99',
  'gamer_tag': 'GhostXPRO',
  'bio': 'Top 1% PUBG Mobile player 🔥 | Nigeria #1 | Content Creator',
  'avatar_url': null,
  'banner_url': null,
  'verification_status': 'verified',
  'posts_count': 247,
  'followers_count': 12840,
  'following_count': 389,
  'competitions_won': 34,
  'wallet_balance': 45200.0,
  'rank': 'Diamond',
  'win_rate': 68.4,
  'global_rank': 142,
};

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  late TabController _tab;

  bool get _isOwn => SupabaseService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SupabaseService.client
          .from('profiles').select('*').eq('id', widget.userId).single();
      final posts = await SupabaseService.client
          .from('posts').select('*')
          .eq('author_id', widget.userId).eq('is_deleted', false)
          .order('created_at', ascending: false).limit(30);
      bool following = false;
      final myId = SupabaseService.currentUserId;
      if (myId != null && !_isOwn) {
        final chk = await SupabaseService.client.from('follows').select('id')
            .eq('follower_id', myId).eq('following_id', widget.userId).maybeSingle();
        following = chk != null;
      }
      if (mounted) {
        setState(() {
          _profile = p;
          _posts = List<Map<String, dynamic>>.from(posts);
          _isFollowing = following;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _profile = Map<String, dynamic>.from(_demoProfile); _loading = false; });
    }
  }

  Future<void> _toggleFollow() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    setState(() => _followLoading = true);
    try {
      _isFollowing
          ? await SupabaseService.client.from('follows').delete()
              .eq('follower_id', myId).eq('following_id', widget.userId)
          : await SupabaseService.client.from('follows')
              .insert({'follower_id': myId, 'following_id': widget.userId});
      if (mounted) setState(() { _isFollowing = !_isFollowing; _followLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final path = '${SupabaseService.currentUserId}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final url = await SupabaseService.uploadFile(bucket: AppConstants.avatarBucket, path: path, bytes: bytes, contentType: 'image/jpeg');
      await SupabaseService.client.from('profiles').update({'avatar_url': url}).eq('id', SupabaseService.currentUserId!);
      if (mounted) { setState(() => _profile!['avatar_url'] = url); GacomSnackbar.show(context, 'Avatar updated!', isSuccess: true); }
    } catch (_) {
      if (mounted) GacomSnackbar.show(context, 'Failed to upload avatar', isError: true);
    }
  }

  void _showEditSheet() {
    final displayCtrl = TextEditingController(text: _profile?['display_name'] ?? '');
    final bioCtrl = TextEditingController(text: _profile?['bio'] ?? '');
    final tagCtrl = TextEditingController(text: _profile?['gamer_tag'] ?? '');
    final locCtrl = TextEditingController(text: _profile?['location'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, scroll) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: ListView(controller: scroll, children: [
            const Text('Edit Profile', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
            const SizedBox(height: 20),
            GacomTextField(controller: displayCtrl, label: 'Display Name', hint: 'Your name', prefixIcon: Icons.person_rounded),
            const SizedBox(height: 12),
            GacomTextField(controller: bioCtrl, label: 'Bio', hint: 'Tell the world who you are', prefixIcon: Icons.info_outline_rounded, maxLines: 3),
            const SizedBox(height: 12),
            GacomTextField(controller: tagCtrl, label: 'Gamer Tag', hint: 'Your in-game ID', prefixIcon: Icons.sports_esports_rounded),
            const SizedBox(height: 12),
            GacomTextField(controller: locCtrl, label: 'Location', hint: 'e.g. Lagos, Nigeria', prefixIcon: Icons.location_on_rounded),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: GacomButton(
                label: 'SAVE CHANGES',
                height: 54,
                onPressed: () async {
                  try {
                    await SupabaseService.client.from('profiles').update({
                      'display_name': displayCtrl.text.trim(),
                      'bio': bioCtrl.text.trim(),
                      'gamer_tag': tagCtrl.text.trim(),
                      'location': locCtrl.text.trim(),
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', SupabaseService.currentUserId!);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      GacomSnackbar.show(context, 'Profile updated! ✅', isSuccess: true);
                      setState(() => _loading = true);
                      await _load();
                    }
                  } catch (_) {
                    GacomSnackbar.show(ctx, 'Failed to save changes', isError: true);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Show a post in a full-screen modal — caption, media, likes
  void _openPost(Map<String, dynamic> post) {
    final urls = post['media_urls'] as List? ?? [];
    final caption = post['caption'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(controller: scroll, children: [
          // Drag handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)),
          )),
          // Media
          if (urls.isNotEmpty)
            ClipRRect(
              child: CachedNetworkImage(
                imageUrl: urls.first as String,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(height: 200, color: GacomColors.cardDark,
                    child: const Icon(Icons.image_not_supported_outlined, color: GacomColors.textMuted)),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GacomColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GacomColors.border),
              ),
              child: const Icon(Icons.text_snippet_outlined, color: GacomColors.textMuted, size: 40),
            ),
          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(caption, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 15, height: 1.6)),
            ),
          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Row(children: [
              const Icon(Icons.favorite_border_rounded, color: GacomColors.textMuted, size: 18),
              const SizedBox(width: 6),
              Text('${post['likes_count'] ?? 0}', style: const TextStyle(color: GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline_rounded, color: GacomColors.textMuted, size: 18),
              const SizedBox(width: 6),
              Text('${post['comments_count'] ?? 0}', style: const TextStyle(color: GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)),
      );
    }

    final p = _profile!;
    final verified = p['verification_status'] == 'verified';
    final rank = p['rank'] as String? ?? 'Bronze';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: GacomColors.obsidian,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (_isOwn)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.settings_outlined, size: 18, color: Colors.white),
                  ),
                  onPressed: () => context.go(AppConstants.settingsRoute),
                ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(fit: StackFit.expand, children: [
                p['banner_url'] != null
                    ? CachedNetworkImage(imageUrl: p['banner_url'], fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [GacomColors.darkOrange.withOpacity(0.5), GacomColors.obsidian],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                        child: CustomPaint(painter: _GridPainter()),
                      ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, GacomColors.obsidian],
                      begin: const Alignment(0, 0.4), end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(top: 60, right: 16, child: _RankBadge(rank: rank)),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: GacomColors.obsidian,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Stack(children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: GacomColors.obsidian, width: 3),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: GacomColors.deepOrange, width: 2),
                          boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.3), blurRadius: 16)],
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: GacomColors.cardDark,
                          backgroundImage: p['avatar_url'] != null ? CachedNetworkImageProvider(p['avatar_url']) : null,
                          child: p['avatar_url'] == null
                              ? Text((p['display_name'] ?? 'G')[0].toUpperCase(),
                                  style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30))
                              : null,
                        ),
                      ),
                    ),
                    if (_isOwn)
                      Positioned(
                        bottom: 2, right: 2,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: GacomColors.orangeGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: GacomColors.obsidian, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                  ]),

                  const Spacer(),

                  if (!_isOwn) ...[
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange, width: 1.2)),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: GacomColors.deepOrange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GacomButton(label: _isFollowing ? 'FOLLOWING' : 'FOLLOW', width: 100, height: 38, isOutlined: _isFollowing, isLoading: _followLoading, onPressed: _toggleFollow),
                  ] else
                    GestureDetector(
                      onTap: _showEditSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange, width: 1.2)),
                        child: const Text('Edit Profile', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.deepOrange)),
                      ),
                    ),
                ]),

                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Text(p['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
                  if (verified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_rounded, size: 10, color: GacomColors.deepOrange),
                        SizedBox(width: 3),
                        Text('VERIFIED', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 9, fontWeight: FontWeight.w800, color: GacomColors.deepOrange, letterSpacing: 0.5)),
                      ]),
                    ),
                ]),

                Text('@${p['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13, fontFamily: 'Rajdhani')),

                if (p['gamer_tag'] != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.sports_esports_rounded, size: 13, color: GacomColors.deepOrange),
                    const SizedBox(width: 5),
                    Text(p['gamer_tag'], style: const TextStyle(color: GacomColors.deepOrange, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')),
                  ]),
                ],

                if (p['bio'] != null) ...[
                  const SizedBox(height: 10),
                  Text(p['bio'], style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5)),
                ],

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: GacomDecorations.glassCard(radius: 16),
                  child: Row(children: [
                    _Stat('${p['posts_count'] ?? 0}', 'Posts'),
                    _StatDiv(),
                    _Stat(_fmt(p['followers_count'] ?? 0), 'Followers'),
                    _StatDiv(),
                    _Stat(_fmt(p['following_count'] ?? 0), 'Following'),
                    _StatDiv(),
                    _Stat('${p['competitions_won'] ?? 0}', 'Wins', color: GacomColors.gold),
                  ]),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 16),
              ]),
            ),
          ),

          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(TabBar(
              controller: _tab,
              indicatorColor: GacomColors.deepOrange,
              labelColor: GacomColors.textPrimary,
              unselectedLabelColor: GacomColors.textMuted,
              labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [Tab(text: 'POSTS'), Tab(text: 'CLIPS'), Tab(text: 'STATS')],
            )),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            // ✅ FIXED: Grid items are now tappable — shows post detail modal
            _Grid(posts: _posts.where((x) => x['post_type'] != 'clip').toList(), onTap: _openPost),
            _Grid(posts: _posts.where((x) => x['post_type'] == 'clip').toList(), onTap: _openPost),
            _StatsTab(profile: p),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic n) {
    final i = (n as num?)?.toInt() ?? 0;
    if (i >= 1000000) return '${(i / 1000000).toStringAsFixed(1)}M';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(1)}K';
    return '$i';
  }
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: GacomColors.obsidian, child: tabBar);
  @override bool shouldRebuild(_TabDelegate old) => false;
}

class _RankBadge extends StatelessWidget {
  final String rank;
  const _RankBadge({required this.rank});
  Color get _color {
    switch (rank.toLowerCase()) {
      case 'diamond': return const Color(0xFF00BFFF);
      case 'platinum': return GacomColors.success;
      case 'gold': return GacomColors.gold;
      default: return GacomColors.deepOrange;
    }
  }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: _color.withOpacity(0.15), borderRadius: BorderRadius.circular(50), border: Border.all(color: _color.withOpacity(0.5), width: 1)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.diamond_rounded, size: 12, color: _color),
      const SizedBox(width: 5),
      Text(rank.toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: _color, letterSpacing: 1)),
    ]),
  );
}

// ✅ FIXED: _Grid now accepts onTap callback and wraps each item in GestureDetector
class _Grid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final void Function(Map<String, dynamic>) onTap;
  const _Grid({required this.posts, required this.onTap});
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const Center(child: Text('No posts yet.', style: TextStyle(color: GacomColors.textMuted)));
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 100), // bottom padding clears nav bar
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final post = posts[i];
        final urls = post['media_urls'] as List? ?? [];
        return GestureDetector(
          onTap: () => onTap(post),
          child: ClipRRect(
            child: Stack(fit: StackFit.expand, children: [
              Container(
                color: GacomColors.cardDark,
                child: urls.isNotEmpty
                    ? CachedNetworkImage(imageUrl: post['thumbnail_url'] ?? urls.first, fit: BoxFit.cover)
                    : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.text_snippet_outlined, color: GacomColors.textMuted, size: 22),
                        if ((post['caption'] as String? ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              post['caption'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: GacomColors.textMuted, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ])),
              ),
              // Like count overlay
              Positioned(
                bottom: 4, left: 4,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.favorite_rounded, color: Colors.white, size: 11),
                  const SizedBox(width: 2),
                  Text('${post['likes_count'] ?? 0}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _StatsTab({required this.profile});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: [
    _Block('Tournament Record', [
      _Row('Competitions Won', '${profile['competitions_won'] ?? 0}'),
      _Row('Win Rate', '${(profile['win_rate'] as num?)?.toStringAsFixed(1) ?? '0'}%'),
      _Row('Global Rank', '#${profile['global_rank'] ?? 'N/A'}'),
    ]),
    const SizedBox(height: 16),
    _Block('Wallet', [
      _Row('Balance', '₦${(profile['wallet_balance'] as num?)?.toStringAsFixed(0) ?? '0'}'),
      _Row('Total Winnings', '₦${(profile['total_winnings'] as num?)?.toStringAsFixed(0) ?? '0'}'),
    ]),
  ]);
}

class _Block extends StatelessWidget {
  final String title; final List<Widget> rows;
  const _Block(this.title, this.rows);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: GacomDecorations.glassCard(radius: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
      const SizedBox(height: 12),
      ...rows,
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value; const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
      Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
    ]),
  );
}

class _Stat extends StatelessWidget {
  final String value, label; final Color? color;
  const _Stat(this.value, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: color ?? GacomColors.textPrimary)),
    Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani')),
  ]));
}

class _StatDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 30, color: GacomColors.border);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x09FF6600)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(_) => false;
}
