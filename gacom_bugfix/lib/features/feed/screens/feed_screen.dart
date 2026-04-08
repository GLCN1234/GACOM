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

// ── Demo data ──────────────────────────────────────────────────────────────────
final _demoPosts = [
  {
    'id': 'demo1',
    'author': {'id': 'u1', 'username': 'xXSniperKingXx', 'display_name': 'Sniper King', 'avatar_url': null, 'verification_status': 'verified'},
    'caption': '🔥 Just hit Diamond rank in PUBG Mobile after 3 days straight. The grind never stops. Who else is in Diamond?',
    'post_type': 'text', 'media_urls': [], 'likes_count': 1247, 'comments_count': 89, 'shares_count': 34,
    'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'is_liked': [],
    '_score': 0.0,
  },
  {
    'id': 'demo2',
    'author': {'id': 'u2', 'username': 'NijaGameQueen', 'display_name': 'Nija Game Queen', 'avatar_url': null, 'verification_status': 'verified'},
    'caption': '🏆 Won ₦50,000 in the weekend tournament! First time ever. Gacom platform is legit, no cap.',
    'post_type': 'text', 'media_urls': [], 'likes_count': 3821, 'comments_count': 204, 'shares_count': 118,
    'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'is_liked': [],
    '_score': 0.0,
  },
  {
    'id': 'demo3',
    'author': {'id': 'u3', 'username': 'LagosGamer247', 'display_name': 'Lagos Gamer', 'avatar_url': null, 'verification_status': 'unverified'},
    'caption': 'FC25 Ultimate team finally done 💎 Took me 6 months. Rate my squad below 👇',
    'post_type': 'text', 'media_urls': [], 'likes_count': 892, 'comments_count': 156, 'shares_count': 22,
    'created_at': DateTime.now().subtract(const Duration(hours: 9)).toIso8601String(), 'is_liked': [],
    '_score': 0.0,
  },
];

final _demoTrending = [
  {'tag': '#PUBGNigeria', 'posts': '12.4K'},
  {'tag': '#FC25Ultimate', 'posts': '8.9K'},
  {'tag': '#GacomTournament', 'posts': '6.2K'},
  {'tag': '#MobileGaming', 'posts': '4.1K'},
];

// ── ALGORITHM ENGINE ──────────────────────────────────────────────────────────
//
// Gacom Feed Algorithm v1 — "Arena Score"
//
// Score = (engagement_score * engagement_weight)
//       + (recency_score * recency_weight)
//       + (social_score * social_weight)
//       + (diversity_bonus)
//
// Engagement Score:
//   likes * 1.0 + comments * 3.0 + shares * 5.0 + saves * 2.0
//   Normalised to [0,1] with log dampening (prevents viral posts from dominating)
//
// Recency Score:
//   Exponential decay: e^(-λt) where t = hours since post, λ = 0.08
//   Half-life ≈ 8.7 hours — posts stay relevant ~24h then decay fast
//
// Social Score:
//   +0.4 if you follow the author
//   +0.2 if you've liked their content before
//   +0.1 if author is verified
//
// Diversity Injection:
//   Every 5th slot gets a "discovery" post — something outside your bubble
//   This is Gacom's answer to TikTok's "interest graph expansion"
//
// Final list = sort by score DESC, inject diversity posts at positions 5,10,15...

class _AlgorithmEngine {
  static const double _engagementWeight = 0.40;
  static const double _recencyWeight = 0.35;
  static const double _socialWeight = 0.25;
  static const double _decayLambda = 0.08; // half-life ~8.7h

  /// Score a single post. Returns score in [0, ~1.2]
  static double score({
    required Map<String, dynamic> post,
    required Set<String> followedIds,
    required Set<String> likedAuthorIds,
  }) {
    // ── Engagement ───────────────────────────────────────────────────────────
    final likes = (post['likes_count'] as int? ?? 0).toDouble();
    final comments = (post['comments_count'] as int? ?? 0).toDouble();
    final shares = (post['shares_count'] as int? ?? 0).toDouble();
    final rawEngagement = likes * 1.0 + comments * 3.0 + shares * 5.0;
    // Log dampening — prevents mega-viral posts from burying everything
    final engagementScore = rawEngagement > 0
        ? math.log(rawEngagement + 1) / math.log(10000)
        : 0.0;

    // ── Recency ──────────────────────────────────────────────────────────────
    final createdAt =
        DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();
    final ageHours =
        DateTime.now().difference(createdAt).inMinutes / 60.0;
    final recencyScore = math.exp(-_decayLambda * ageHours);

    // ── Social graph ─────────────────────────────────────────────────────────
    final authorId = (post['author'] as Map<String, dynamic>?)?['id'] as String? ??
        post['author_id'] as String? ?? '';
    double socialScore = 0.0;
    if (followedIds.contains(authorId)) socialScore += 0.4;
    if (likedAuthorIds.contains(authorId)) socialScore += 0.2;
    final isVerified = (post['author'] as Map<String, dynamic>?)?
            ['verification_status'] == 'verified';
    if (isVerified) socialScore += 0.1;
    // Cap social score at 1.0
    socialScore = math.min(socialScore, 1.0);

    return (engagementScore * _engagementWeight) +
        (recencyScore * _recencyWeight) +
        (socialScore * _socialWeight);
  }

  /// Rank a list of posts and inject discovery posts every 5 slots.
  static List<Map<String, dynamic>> rank({
    required List<Map<String, dynamic>> posts,
    required List<Map<String, dynamic>> discoveryPool,
    required Set<String> followedIds,
    required Set<String> likedAuthorIds,
  }) {
    if (posts.isEmpty) return posts;

    // Score each post
    final scored = posts.map((p) {
      return {...p, '_score': score(
        post: p,
        followedIds: followedIds,
        likedAuthorIds: likedAuthorIds,
      )};
    }).toList()
      ..sort((a, b) =>
          (b['_score'] as double).compareTo(a['_score'] as double));

    // Inject discovery posts every 5 positions (TikTok-style interest expansion)
    final result = <Map<String, dynamic>>[];
    int discoveryIdx = 0;
    for (int i = 0; i < scored.length; i++) {
      result.add(scored[i]);
      if ((i + 1) % 5 == 0 && discoveryIdx < discoveryPool.length) {
        result.add({...discoveryPool[discoveryIdx], '_is_discovery': true});
        discoveryIdx++;
      }
    }

    return result;
  }
}

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
          SliverToBoxAdapter(child: _TrendingStrip(tags: _demoTrending)),
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

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting, name;
  final String? avatarUrl;
  final VoidCallback onSearch, onNotifs;
  const _Header({
    required this.greeting, required this.name,
    required this.avatarUrl, required this.onSearch, required this.onNotifs,
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
          Row(children: [
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
            _HeaderBtn(icon: Icons.search_rounded, onTap: onSearch),
            const SizedBox(width: 8),
            _HeaderBtn(icon: Icons.notifications_outlined, onTap: onNotifs, hasDot: true),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onSearch,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: GacomColors.cardDark,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: GacomColors.border, width: 0.7),
              ),
              child: const Row(children: [
                SizedBox(width: 16),
                Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18),
                SizedBox(width: 10),
                Text('Search players, games, communities...',
                    style: TextStyle(
                        color: GacomColors.textMuted,
                        fontSize: 13,
                        fontFamily: 'Rajdhani')),
              ]),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GacomColors.border, width: 0.7),
          ),
          child: Stack(alignment: Alignment.center, children: [
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
          ]),
        ),
      );
}

// ── Trending strip ─────────────────────────────────────────────────────────────

class _TrendingStrip extends StatelessWidget {
  final List<Map<String, dynamic>> tags;
  const _TrendingStrip({required this.tags});
  @override
  Widget build(BuildContext context) => Container(
        color: GacomColors.obsidian,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tags.map((t) => Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: GacomColors.cardDark,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: GacomColors.border, width: 0.7),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.trending_up_rounded, size: 12, color: GacomColors.deepOrange),
                const SizedBox(width: 5),
                Text(t['tag'] as String,
                    style: const TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: GacomColors.textPrimary)),
                const SizedBox(width: 6),
                Text(t['posts'] as String,
                    style: const TextStyle(fontSize: 10, color: GacomColors.textMuted)),
              ]),
            )).toList(),
          ),
        ),
      );
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tab;
  _TabDelegate(this.tab);
  @override double get minExtent => 46;
  @override double get maxExtent => 46;
  @override bool shouldRebuild(_) => false;
  @override
  Widget build(_, __, ___) =>
      Container(color: GacomColors.obsidian, child: tab);
}

// ── Post List (algorithm-powered) ─────────────────────────────────────────────

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

  // Algorithm context
  Set<String> _followedIds = {};
  Set<String> _likedAuthorIds = {};
  List<Map<String, dynamic>> _discoveryPool = [];

  @override
  void initState() {
    super.initState();
    _loadAlgorithmContext().then((_) => _load());
  }

  /// Load user's social graph for the algorithm
  Future<void> _loadAlgorithmContext() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      // Who does this user follow?
      final follows = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);
      _followedIds = (follows as List)
          .map((f) => f['following_id'] as String)
          .toSet();

      // Which authors has this user liked content from?
      final likedPosts = await SupabaseService.client
          .from('post_likes')
          .select('post:posts!post_id(author_id)')
          .eq('user_id', uid)
          .limit(200);
      _likedAuthorIds = (likedPosts as List)
          .map((l) {
            final post = l['post'] as Map<String, dynamic>?;
            return post?['author_id'] as String? ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toSet();

      // Load discovery pool — posts from outside the user's follow graph
      // These are injected every 5th post for serendipity
      if (!widget.isFollowing && _followedIds.isNotEmpty) {
        final discovery = await SupabaseService.client
            .from('posts')
            .select('*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status)')
            .eq('is_deleted', false)
            .not('author_id', 'in', '(${_followedIds.join(',')})')
            .neq('author_id', uid)
            .order('likes_count', ascending: false)
            .limit(20);
        _discoveryPool = List<Map<String, dynamic>>.from(discovery);
      }
    } catch (_) {
      // Non-fatal — algorithm degrades gracefully
    }
  }

  Future<void> _load() async {
    try {
      late List rawPosts;

      if (widget.isFollowing) {
        // Following tab: only posts from followed users, sorted by algorithm
        if (_followedIds.isEmpty) {
          if (mounted) setState(() { _loading = false; _hasMore = false; });
          return;
        }
        rawPosts = await SupabaseService.client
            .from('posts')
            .select('*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status), is_liked:post_likes(user_id)')
            .eq('is_deleted', false)
            .inFilter('author_id', _followedIds.toList())
            .order('created_at', ascending: false)
            .range(_page * AppConstants.feedPageSize,
                (_page + 1) * AppConstants.feedPageSize - 1);
      } else {
        // For You tab: fetch broader pool, let algorithm rank them
        rawPosts = await SupabaseService.client
            .from('posts')
            .select('*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status), is_liked:post_likes(user_id)')
            .eq('is_deleted', false)
            .order('created_at', ascending: false)
            // Fetch 3x more than needed so algorithm has room to rerank
            .range(_page * AppConstants.feedPageSize * 3,
                (_page + 1) * AppConstants.feedPageSize * 3 - 1);
      }

      final typed = List<Map<String, dynamic>>.from(rawPosts);

      // Run the algorithm
      final ranked = _AlgorithmEngine.rank(
        posts: typed,
        discoveryPool: _discoveryPool,
        followedIds: _followedIds,
        likedAuthorIds: _likedAuthorIds,
      );

      if (mounted) {
        setState(() {
          if (_page == 0 && typed.isEmpty) {
            _posts = List<Map<String, dynamic>>.from(_demoPosts);
          } else {
            _posts.addAll(ranked);
          }
          _loading = false;
          _hasMore = typed.length == AppConstants.feedPageSize * 3;
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
          Text(
            widget.isFollowing
                ? 'Follow players to see their posts here'
                : 'Be the first to post in the arena',
            style: const TextStyle(color: GacomColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 28),
          GacomButton(
              label: 'CREATE POST',
              width: 180,
              height: 48,
              onPressed: () => context.go(AppConstants.createPostRoute)),
        ]),
      );
    }

    return RefreshIndicator(
      color: GacomColors.deepOrange,
      backgroundColor: GacomColors.cardDark,
      onRefresh: () async {
        setState(() { _posts = []; _page = 0; _loading = true; });
        await _loadAlgorithmContext();
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
              child: Center(
                  child: CircularProgressIndicator(
                      color: GacomColors.deepOrange, strokeWidth: 2)),
            );
          }
          final isDiscovery = _posts[i]['_is_discovery'] == true;
          return _PostCard(post: _posts[i], isDiscovery: isDiscovery)
              .animate(delay: Duration(milliseconds: math.min(i * 60, 240)))
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final bool isDiscovery;
  const _PostCard({required this.post, this.isDiscovery = false});
  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late int _likeCount;
  late AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    final likedList = widget.post['is_liked'] as List? ?? [];
    final myId = SupabaseService.currentUserId;
    _liked = likedList.any((l) =>
        (l is Map ? l['user_id'] : l) == myId);
    _likeCount = widget.post['likes_count'] as int? ?? 0;
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    HapticFeedback.lightImpact();

    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    _heartCtrl.forward(from: 0);

    try {
      final postId = widget.post['id'] as String;
      if (_liked) {
        await SupabaseService.client
            .from('post_likes')
            .upsert({'post_id': postId, 'user_id': myId});
      } else {
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', myId);
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likeCount += _liked ? 1 : -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final displayName = author['display_name'] as String? ?? 'Gamer';
    final username = author['username'] as String? ?? '';
    final avatarUrl = author['avatar_url'] as String?;
    final isVerified = author['verification_status'] == 'verified';
    final caption = post['caption'] as String? ?? '';
    final mediaUrls = post['media_urls'] as List? ?? [];
    final comments = post['comments_count'] as int? ?? 0;
    final shares = post['shares_count'] as int? ?? 0;
    final createdAt =
        DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      color: GacomColors.obsidian,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Discovery label
          if (widget.isDiscovery)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 12, color: GacomColors.deepOrange),
                const SizedBox(width: 4),
                const Text('Suggested for you',
                    style: TextStyle(
                        color: GacomColors.deepOrange,
                        fontSize: 11,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w600)),
              ]),
            ),

          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/profile/${author['id'] ?? ''}'),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: GacomColors.deepOrange.withOpacity(0.5),
                        width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: GacomColors.border,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(displayName[0].toUpperCase(),
                            style: const TextStyle(
                                color: GacomColors.textPrimary,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(displayName,
                          style: const TextStyle(
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: GacomColors.textPrimary)),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 13, color: GacomColors.deepOrange),
                      ],
                    ]),
                    Text('@$username · ${timeago.format(createdAt, locale: 'en_short')}',
                        style: const TextStyle(
                            color: GacomColors.textMuted,
                            fontSize: 11,
                            fontFamily: 'Rajdhani')),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: GacomColors.textMuted, size: 20),
                onPressed: () {},
              ),
            ]),
          ),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(caption,
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontSize: 14,
                      height: 1.5)),
            ),

          // Media
          if (mediaUrls.isNotEmpty)
            ClipRRect(
              child: CachedNetworkImage(
                imageUrl: mediaUrls.first as String,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    height: 280, color: GacomColors.cardDark),
                errorWidget: (_, __, ___) => Container(
                    height: 180,
                    color: GacomColors.cardDark,
                    child: const Icon(Icons.broken_image_outlined,
                        color: GacomColors.textMuted)),
              ),
            ),

          // Actions row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              // Like
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.3).chain(
                    CurveTween(curve: Curves.elasticOut)).animate(_heartCtrl),
                child: IconButton(
                  onPressed: _toggleLike,
                  icon: Icon(
                    _liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color:
                        _liked ? GacomColors.deepOrange : GacomColors.textMuted,
                    size: 22,
                  ),
                ),
              ),
              Text(_fmtCount(_likeCount),
                  style: const TextStyle(
                      color: GacomColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              // Comment
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    color: GacomColors.textMuted, size: 20),
              ),
              Text(_fmtCount(comments),
                  style: const TextStyle(
                      color: GacomColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              // Share
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.ios_share_rounded,
                    color: GacomColors.textMuted, size: 20),
              ),
              Text(_fmtCount(shares),
                  style: const TextStyle(
                      color: GacomColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              // Bookmark
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.bookmark_border_rounded,
                    color: GacomColors.textMuted, size: 20),
              ),
            ]),
          ),

          // Divider
          Container(height: 0.5, color: GacomColors.border),
        ],
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  final int delay;
  const _Skeleton({required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GacomColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Shimmer(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Shimmer(width: 120, height: 12),
            const SizedBox(height: 6),
            _Shimmer(width: 80, height: 10),
          ]),
        ]),
        const SizedBox(height: 14),
        _Shimmer(width: double.infinity, height: 14),
        const SizedBox(height: 6),
        _Shimmer(width: 220, height: 14),
        const SizedBox(height: 14),
        _Shimmer(width: double.infinity, height: 200),
      ]),
    ).animate(delay: Duration(milliseconds: delay)).shimmer(
          duration: 1200.ms,
          color: GacomColors.border,
        );
  }
}

class _Shimmer extends StatelessWidget {
  final double width, height;
  final double radius;
  const _Shimmer({required this.width, required this.height, this.radius = 8});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: GacomColors.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
