import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';

// ── Demo data shown when Supabase returns nothing ─────────────────────────────
final _demoPosts = [
  {
    'id': 'demo1',
    'author': {'id': 'u1', 'username': 'xXSniperKingXx', 'display_name': 'Sniper King', 'avatar_url': null, 'verification_status': 'verified'},
    'caption': '🔥 Just hit Diamond rank in PUBG Mobile after 3 days straight. The grind never stops. Who else is in Diamond?',
    'post_type': 'text',
    'media_urls': [],
    'likes_count': 1247,
    'comments_count': 89,
    'shares_count': 34,
    'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    'is_liked': [],
  },
  {
    'id': 'demo2',
    'author': {'id': 'u2', 'username': 'NijaGameQueen', 'display_name': 'Nija Game Queen', 'avatar_url': null, 'verification_status': 'verified'},
    'caption': '🏆 Won ₦50,000 in the weekend tournament! First time ever. Gacom platform is legit, no cap.',
    'post_type': 'text',
    'media_urls': [],
    'likes_count': 3821,
    'comments_count': 204,
    'shares_count': 118,
    'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
    'is_liked': [],
  },
  {
    'id': 'demo3',
    'author': {'id': 'u3', 'username': 'LagosGamer247', 'display_name': 'Lagos Gamer', 'avatar_url': null, 'verification_status': 'unverified'},
    'caption': 'FC25 Ultimate team finally done 💎 Took me 6 months. Rate my squad below 👇',
    'post_type': 'text',
    'media_urls': [],
    'likes_count': 892,
    'comments_count': 156,
    'shares_count': 22,
    'created_at': DateTime.now().subtract(const Duration(hours: 9)).toIso8601String(),
    'is_liked': [],
  },
];

final _demoTrending = [
  {'tag': '#PUBGNigeria', 'posts': '12.4K'},
  {'tag': '#FC25Ultimate', 'posts': '8.9K'},
  {'tag': '#GacomTournament', 'posts': '6.2K'},
  {'tag': '#MobileGaming', 'posts': '4.1K'},
];

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _myProfile;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final p = await SupabaseService.client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', uid)
          .single();
      if (mounted) setState(() => _myProfile = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = _myProfile?['display_name'] ?? 'Gamer';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, scrolled) => [
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _Header(
                greeting: _greeting,
                name: name,
                avatarUrl: _myProfile?['avatar_url'],
                onSearch: () => context.go(AppConstants.searchRoute),
                onNotifs: () => context.go(AppConstants.notificationsRoute),
              ),
            ),
          ),
          // Trending pills
          SliverToBoxAdapter(
            child: _TrendingStrip(tags: _demoTrending),
          ),
          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(
              TabBar(
                controller: _tab,
                indicatorColor: GacomColors.deepOrange,
                indicatorWeight: 2.5,
                tabs: const [Tab(text: 'FOR YOU'), Tab(text: 'FOLLOWING')],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _PostList(key: const ValueKey('fy'), isFollowing: false),
            _PostList(key: const ValueKey('fl'), isFollowing: true),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting, name;
  final String? avatarUrl;
  final VoidCallback onSearch, onNotifs;
  const _Header({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.onSearch,
    required this.onNotifs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GacomColors.darkOrange.withOpacity(0.28),
            GacomColors.obsidian,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GacomColors.deepOrange, width: 2),
                ),
                child: CircleAvatar(
                  backgroundColor: GacomColors.border,
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? Text(name[0].toUpperCase(),
                          style: const TextStyle(
                              color: GacomColors.textPrimary,
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w700,
                              fontSize: 18))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting,
                        style: const TextStyle(
                            color: GacomColors.textMuted,
                            fontSize: 12,
                            fontFamily: 'Rajdhani',
                            letterSpacing: 0.5)),
                    Text(name,
                        style: const TextStyle(
                            color: GacomColors.textPrimary,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: 0.3)),
                  ],
                ),
              ),
              // Icon buttons — Image 1 style boxed
              _HeaderBtn(icon: Icons.search_rounded, onTap: onSearch),
              const SizedBox(width: 8),
              _HeaderBtn(icon: Icons.notifications_outlined, onTap: onNotifs, hasDot: true),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar — Image 1 style pill
          GestureDetector(
            onTap: onSearch,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: GacomColors.cardDark,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: GacomColors.border, width: 0.7),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 16),
                  Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18),
                  SizedBox(width: 10),
                  Text('Search players, games, communities...',
                      style: TextStyle(
                          color: GacomColors.textMuted,
                          fontSize: 13,
                          fontFamily: 'Rajdhani')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasDot;
  const _HeaderBtn({required this.icon, required this.onTap, this.hasDot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GacomColors.border, width: 0.7),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: GacomColors.textSecondary, size: 18),
            if (hasDot)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: GacomColors.deepOrange, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Trending strip ─────────────────────────────────────────────────────────────

class _TrendingStrip extends StatelessWidget {
  final List<Map<String, dynamic>> tags;
  const _TrendingStrip({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GacomColors.obsidian,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tags.map((t) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: GacomColors.cardDark,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: GacomColors.border, width: 0.7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up_rounded,
                      size: 12, color: GacomColors.deepOrange),
                  const SizedBox(width: 5),
                  Text(t['tag'] as String,
                      style: const TextStyle(
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: GacomColors.textPrimary)),
                  const SizedBox(width: 6),
                  Text(t['posts'] as String,
                      style: const TextStyle(
                          fontSize: 10, color: GacomColors.textMuted)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Tab persistence delegate ──────────────────────────────────────────────────
class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tab;
  _TabDelegate(this.tab);
  @override double get minExtent => 46;
  @override double get maxExtent => 46;
  @override bool shouldRebuild(_) => false;
  @override
  Widget build(_, __, ___) => Container(
        color: GacomColors.obsidian,
        child: tab,
      );
}

// ── Post List ─────────────────────────────────────────────────────────────────

class _PostList extends ConsumerStatefulWidget {
  final bool isFollowing;
  const _PostList({super.key, required this.isFollowing});

  @override
  ConsumerState<_PostList> createState() => _PostListState();
}

class _PostListState extends ConsumerState<_PostList> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await SupabaseService.client
          .from('posts')
          .select('''*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status), is_liked:post_likes!inner(user_id)''')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(_page * AppConstants.feedPageSize,
              (_page + 1) * AppConstants.feedPageSize - 1);
      if (mounted) {
        setState(() {
          if (_page == 0 && (res as List).isEmpty) {
            _posts = List<Map<String, dynamic>>.from(_demoPosts);
          } else {
            _posts.addAll(List<Map<String, dynamic>>.from(res));
          }
          _loading = false;
          _hasMore = (res as List).length == AppConstants.feedPageSize;
          _page++;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_page == 0) _posts = List<Map<String, dynamic>>.from(_demoPosts);
          _loading = false;
          _hasMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: 3,
        itemBuilder: (_, i) => _Skeleton(delay: i * 120),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: GacomColors.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: GacomColors.border)),
            child: const Icon(Icons.videogame_asset_off_outlined,
                size: 48, color: GacomColors.textMuted),
          ),
          const SizedBox(height: 20),
          const Text('Nothing here yet',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Follow players or create the first post',
              style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 28),
          GacomButton(label: 'CREATE POST', width: 180, height: 48,
              onPressed: () => context.go(AppConstants.createPostRoute)),
        ]),
      );
    }

    return RefreshIndicator(
      color: GacomColors.deepOrange,
      backgroundColor: GacomColors.cardDark,
      onRefresh: () async {
        setState(() { _posts = []; _page = 0; _loading = true; });
        await _load();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _posts.length) {
            _load();
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(
                  color: GacomColors.deepOrange, strokeWidth: 2)),
            );
          }
          return _PostCard(post: _posts[i])
              .animate(delay: Duration(milliseconds: math.min(i * 60, 240)))
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

// ── Post Card — FortDice depth + Image 1 card feel ────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  int _likes = 0;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _liked = (widget.post['is_liked'] as List?)?.isNotEmpty ?? false;
    _likes = widget.post['likes_count'] ?? 0;
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _heartScale = Tween(begin: 1.0, end: 1.45).animate(
        CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _heartCtrl.dispose(); super.dispose(); }

  Future<void> _like() async {
    HapticFeedback.lightImpact();
    final id = widget.post['id'];
    final uid = SupabaseService.currentUserId;
    setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
    if (_liked) _heartCtrl.forward().then((_) => _heartCtrl.reverse());
    if (uid == null || id.toString().startsWith('demo')) return;
    _liked
        ? await SupabaseService.client.from('post_likes').insert({'post_id': id, 'user_id': uid})
        : await SupabaseService.client.from('post_likes').delete().eq('post_id', id).eq('user_id', uid);
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post['author'] as Map<String, dynamic>? ?? {};
    final caption = widget.post['caption'] as String? ?? '';
    final urls = widget.post['media_urls'] as List? ?? [];
    final type = widget.post['post_type'] as String? ?? 'text';
    final at = DateTime.tryParse(widget.post['created_at'] ?? '') ?? DateTime.now();
    final verified = author['verification_status'] == 'verified';
    final hasMedia = urls.isNotEmpty && type != 'text';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GacomColors.border, width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/profile/${author['id']}'),
                child: _Avatar(url: author['avatar_url'], name: author['display_name'] ?? 'G'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(
                      author['display_name'] ?? 'Gamer',
                      style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange),
                    ],
                  ]),
                  Text('@${author['username'] ?? ''} · ${timeago.format(at)}',
                      style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 18, color: GacomColors.textMuted),
                onPressed: () => _options(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          // ── Caption ──────────────────────────────────────────────────────
          if (caption.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, hasMedia ? 10 : 0),
              child: Text(caption,
                  style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, height: 1.45)),
            ),

          // ── Media ────────────────────────────────────────────────────────
          if (hasMedia)
            AspectRatio(
              aspectRatio: type == 'clip' ? 9 / 16 : 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(
                  imageUrl: widget.post['thumbnail_url'] ?? urls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: GacomColors.surfaceDark,
                    child: const Icon(Icons.broken_image_outlined, color: GacomColors.textMuted),
                  ),
                ),
                if (type == 'clip')
                  Center(child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  )),
              ]),
            ),

          // ── Actions ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Row(children: [
              // Like
              GestureDetector(
                onTap: _like,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(children: [
                    ScaleTransition(
                      scale: _heartScale,
                      child: Icon(
                        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _liked ? GacomColors.deepOrange : GacomColors.textMuted,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 5),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(_fmt(_likes), key: ValueKey(_likes),
                          style: TextStyle(
                              fontFamily: 'Rajdhani', fontSize: 13, fontWeight: FontWeight.w600,
                              color: _liked ? GacomColors.deepOrange : GacomColors.textMuted)),
                    ),
                  ]),
                ),
              ),
              _Act(icon: Icons.chat_bubble_outline_rounded,
                  label: _fmt(widget.post['comments_count'] ?? 0), onTap: () {}),
              _Act(icon: Icons.repeat_rounded,
                  label: _fmt(widget.post['shares_count'] ?? 0), onTap: () {}),
              const Spacer(),
              _Act(icon: Icons.bookmark_border_rounded, label: '', onTap: () {}),
              _Act(icon: Icons.ios_share_rounded, label: '', onTap: () {}),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _options(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(width: 36, height: 3,
            decoration: BoxDecoration(color: GacomColors.borderBright, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),
        _Sheet(icon: Icons.report_outlined, label: 'Report Post', onTap: () => Navigator.pop(ctx)),
        _Sheet(icon: Icons.person_remove_outlined, label: 'Unfollow', onTap: () => Navigator.pop(ctx)),
        _Sheet(icon: Icons.copy_outlined, label: 'Copy Link', onTap: () => Navigator.pop(ctx)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url; final String name;
  const _Avatar({required this.url, required this.name});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GacomColors.deepOrange.withOpacity(0.5), width: 1.5)),
    child: CircleAvatar(
      radius: 19,
      backgroundColor: GacomColors.border,
      backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
      child: url == null
          ? Text(name[0].toUpperCase(),
              style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14))
          : null,
    ),
  );
}

class _Act extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _Act({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(children: [
        Icon(icon, color: GacomColors.textMuted, size: 19),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, fontWeight: FontWeight.w600, color: GacomColors.textMuted)),
        ],
      ]),
    ),
  );
}

class _Sheet extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _Sheet({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: GacomColors.textSecondary, size: 20),
    title: Text(label,
        style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 16)),
    onTap: onTap, dense: true,
  );
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  final int delay;
  const _Skeleton({this.delay = 0});
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) {
      final s = Color.lerp(GacomColors.cardDark, GacomColors.elevatedCard, _a.value)!;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(22), border: Border.all(color: GacomColors.border, width: 0.6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 19, backgroundColor: s),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 110, height: 11, decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Container(width: 75, height: 9, decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(6))),
            ]),
          ]),
          const SizedBox(height: 14),
          Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 7),
          Container(width: 180, height: 12, decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 14),
          Container(width: double.infinity, height: 160, decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(14))),
        ]),
      );
    },
  ).animate(delay: Duration(milliseconds: widget.delay)).fadeIn();
}
