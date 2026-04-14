import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';

// ── Demo posts ────────────────────────────────────────────────────────────────
final _demoPosts = [
  {'id': 'demo1', 'author': {'id': 'u1', 'username': 'xXSniperKingXx', 'display_name': 'Sniper King', 'avatar_url': null, 'verification_status': 'verified'}, 'caption': '🔥 Just hit Diamond rank in PUBG Mobile after 3 days straight. The grind never stops. Who else is in Diamond?', 'post_type': 'text', 'media_urls': [], 'likes_count': 1247, 'comments_count': 89, 'shares_count': 34, 'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'is_liked': [], '_score': 0.0},
  {'id': 'demo2', 'author': {'id': 'u2', 'username': 'NijaGameQueen', 'display_name': 'Nija Game Queen', 'avatar_url': null, 'verification_status': 'verified'}, 'caption': '🏆 Won ₦50,000 in the weekend tournament! First time ever. Gacom platform is legit, no cap.', 'post_type': 'text', 'media_urls': [], 'likes_count': 3821, 'comments_count': 204, 'shares_count': 118, 'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'is_liked': [], '_score': 0.0},
  {'id': 'demo3', 'author': {'id': 'u3', 'username': 'LagosGamer247', 'display_name': 'Lagos Gamer', 'avatar_url': null, 'verification_status': 'unverified'}, 'caption': 'FC25 Ultimate team finally done 💎 Took me 6 months. Rate my squad below 👇', 'post_type': 'text', 'media_urls': [], 'likes_count': 892, 'comments_count': 156, 'shares_count': 22, 'created_at': DateTime.now().subtract(const Duration(hours: 9)).toIso8601String(), 'is_liked': [], '_score': 0.0},
];
final _demoTrending = [
  {'tag': '#PUBGNigeria', 'posts': '12.4K'}, {'tag': '#FC25Ultimate', 'posts': '8.9K'}, {'tag': '#GacomTournament', 'posts': '6.2K'}, {'tag': '#MobileGaming', 'posts': '4.1K'},
];

// ── Algorithm engine ──────────────────────────────────────────────────────────
class _AlgorithmEngine {
  static double score({required Map<String, dynamic> post, required Set<String> followedIds, required Set<String> likedAuthorIds}) {
    final likes = (post['likes_count'] as int? ?? 0).toDouble();
    final comments = (post['comments_count'] as int? ?? 0).toDouble();
    final shares = (post['shares_count'] as int? ?? 0).toDouble();
    final rawEng = likes * 1.0 + comments * 3.0 + shares * 5.0;
    final engScore = rawEng > 0 ? math.log(rawEng + 1) / math.log(10000) : 0.0;
    final createdAt = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();
    final ageHours = DateTime.now().difference(createdAt).inMinutes / 60.0;
    final recency = math.exp(-0.08 * ageHours);
    final authorId = (post['author'] as Map?)?['id'] as String? ?? post['author_id'] as String? ?? '';
    double social = 0;
    if (followedIds.contains(authorId)) social += 0.4;
    if (likedAuthorIds.contains(authorId)) social += 0.2;
    if ((post['author'] as Map?)?['verification_status'] == 'verified') social += 0.1;
    return (engScore * 0.40) + (recency * 0.35) + (math.min(social, 1.0) * 0.25);
  }

  static List<Map<String, dynamic>> rank({required List<Map<String, dynamic>> posts, required List<Map<String, dynamic>> discoveryPool, required Set<String> followedIds, required Set<String> likedAuthorIds}) {
    if (posts.isEmpty) return posts;
    final scored = posts.map((p) => {...p, '_score': score(post: p, followedIds: followedIds, likedAuthorIds: likedAuthorIds)}).toList()
      ..sort((a, b) => (b['_score'] as double).compareTo(a['_score'] as double));
    final result = <Map<String, dynamic>>[];
    int di = 0;
    for (int i = 0; i < scored.length; i++) {
      result.add(scored[i]);
      if ((i + 1) % 5 == 0 && di < discoveryPool.length) {
        result.add({...discoveryPool[di], '_is_discovery': true});
        di++;
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

class _FeedScreenState extends ConsumerState<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _myProfile;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _loadProfile(); }

  Future<void> _loadProfile() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final p = await SupabaseService.client.from('profiles').select('display_name, avatar_url').eq('id', uid).single();
      if (mounted) setState(() => _myProfile = p);
    } catch (_) {}
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  String get _greeting { final h = DateTime.now().hour; if (h < 12) return 'Good Morning'; if (h < 17) return 'Good Afternoon'; return 'Good Evening'; }

  @override
  Widget build(BuildContext context) {
    final name = _myProfile?['display_name'] ?? 'Gamer';
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(pinned: false, floating: true, snap: true, backgroundColor: Colors.transparent, elevation: 0, expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(collapseMode: CollapseMode.pin,
              background: _Header(greeting: _greeting, name: name, avatarUrl: _myProfile?['avatar_url'], onSearch: () => context.go(AppConstants.searchRoute), onNotifs: () => context.go(AppConstants.notificationsRoute)))),
          SliverToBoxAdapter(child: _TrendingStrip(tags: _demoTrending)),
          SliverPersistentHeader(pinned: true, delegate: _TabDelegate(TabBar(controller: _tab, indicatorColor: GacomColors.deepOrange, indicatorWeight: 2.5, tabs: const [Tab(text: 'FOR YOU'), Tab(text: 'FOLLOWING')]))),
        ],
        body: TabBarView(controller: _tab, children: [
          _PostList(key: const ValueKey('fy'), isFollowing: false),
          _PostList(key: const ValueKey('fl'), isFollowing: true),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting, name; final String? avatarUrl; final VoidCallback onSearch, onNotifs;
  const _Header({required this.greeting, required this.name, required this.avatarUrl, required this.onSearch, required this.onNotifs});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [GacomColors.darkOrange.withOpacity(0.28), GacomColors.obsidian], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 2)),
            child: CircleAvatar(backgroundColor: GacomColors.border, backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
              child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18)) : null)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani', letterSpacing: 0.5)),
            Text(name, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0.3)),
          ])),
          _HeaderBtn(icon: Icons.search_rounded, onTap: onSearch), const SizedBox(width: 8), _HeaderBtn(icon: Icons.notifications_outlined, onTap: onNotifs, hasDot: true),
        ]),
        const SizedBox(height: 16),
        GestureDetector(onTap: onSearch, child: Container(height: 44,
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border, width: 0.7)),
          child: const Row(children: [SizedBox(width: 16), Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18), SizedBox(width: 10), Text('Search players, games, communities...', style: TextStyle(color: GacomColors.textMuted, fontSize: 13, fontFamily: 'Rajdhani'))]))),
      ]),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool hasDot;
  const _HeaderBtn({required this.icon, required this.onTap, this.hasDot = false});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(width: 38, height: 38,
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border, width: 0.7)),
    child: Stack(alignment: Alignment.center, children: [Icon(icon, color: GacomColors.textSecondary, size: 18),
      if (hasDot) Positioned(top: 7, right: 7, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: GacomColors.deepOrange, shape: BoxShape.circle)))])));
}

class _TrendingStrip extends StatelessWidget {
  final List<Map<String, dynamic>> tags;
  const _TrendingStrip({required this.tags});
  @override
  Widget build(BuildContext context) => Container(color: GacomColors.obsidian, padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: tags.map((t) => Container(
      margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border, width: 0.7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.trending_up_rounded, size: 12, color: GacomColors.deepOrange), const SizedBox(width: 5), Text(t['tag'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textPrimary)), const SizedBox(width: 6), Text(t['posts'] as String, style: const TextStyle(fontSize: 10, color: GacomColors.textMuted))]))).toList())));
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tab; _TabDelegate(this.tab);
  @override double get minExtent => 46; @override double get maxExtent => 46; @override bool shouldRebuild(_) => false;
  @override Widget build(_, __, ___) => Container(color: GacomColors.obsidian, child: tab);
}

// ── Post List ─────────────────────────────────────────────────────────────────
class _PostList extends ConsumerStatefulWidget {
  final bool isFollowing;
  const _PostList({super.key, required this.isFollowing});
  @override ConsumerState<_PostList> createState() => _PostListState();
}

class _PostListState extends ConsumerState<_PostList> {
  List<Map<String, dynamic>> _posts = []; bool _loading = true; bool _hasMore = true; int _page = 0;
  Set<String> _followedIds = {}; Set<String> _likedAuthorIds = {}; List<Map<String, dynamic>> _discoveryPool = [];

  @override void initState() { super.initState(); _loadContext().then((_) => _load()); }

  Future<void> _loadContext() async {
    final uid = SupabaseService.currentUserId; if (uid == null) return;
    try {
      final follows = await SupabaseService.client.from('follows').select('following_id').eq('follower_id', uid);
      _followedIds = (follows as List).map((f) => f['following_id'] as String).toSet();
      final likedPosts = await SupabaseService.client.from('post_likes').select('post:posts!post_id(author_id)').eq('user_id', uid).limit(200);
      _likedAuthorIds = (likedPosts as List).map((l) { final p = l['post'] as Map?; return p?['author_id'] as String? ?? ''; }).where((id) => id.isNotEmpty).toSet();
      if (!widget.isFollowing) {
        final discovery = await SupabaseService.client.from('posts').select('*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status)').eq('is_deleted', false).order('likes_count', ascending: false).limit(20);
        _discoveryPool = List<Map<String, dynamic>>.from(discovery);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      late List rawPosts;
      if (widget.isFollowing) {
        if (_followedIds.isEmpty) { if (mounted) setState(() { _loading = false; _hasMore = false; }); return; }
        rawPosts = await SupabaseService.client.from('posts').select('*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status), is_liked:post_likes(user_id)').eq('is_deleted', false).inFilter('author_id', _followedIds.toList()).order('created_at', ascending: false).range(_page * AppConstants.feedPageSize, (_page + 1) * AppConstants.feedPageSize - 1);
      } else {
        rawPosts = await SupabaseService.client.from('posts').select('*, author:profiles!author_id(id,username,display_name,avatar_url,verification_status), is_liked:post_likes(user_id)').eq('is_deleted', false).order('created_at', ascending: false).range(_page * AppConstants.feedPageSize * 3, (_page + 1) * AppConstants.feedPageSize * 3 - 1);
      }
      final typed = List<Map<String, dynamic>>.from(rawPosts);
      final ranked = _AlgorithmEngine.rank(posts: typed, discoveryPool: _discoveryPool, followedIds: _followedIds, likedAuthorIds: _likedAuthorIds);
      if (mounted) setState(() {
        if (_page == 0 && typed.isEmpty) { _posts = List.from(_demoPosts); }
        else { _posts.addAll(ranked); }
        _loading = false; _hasMore = typed.length == AppConstants.feedPageSize * 3; _page++;
      });
    } catch (_) {
      if (mounted) setState(() { if (_page == 0) _posts = List.from(_demoPosts); _loading = false; _hasMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), itemCount: 3, itemBuilder: (_, i) => _Skeleton(delay: i * 120));
    if (_posts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: GacomColors.cardDark, shape: BoxShape.circle, border: Border.all(color: GacomColors.border)), child: const Icon(Icons.videogame_asset_off_outlined, size: 48, color: GacomColors.textMuted)),
      const SizedBox(height: 20),
      Text(widget.isFollowing ? 'Follow players to see their posts' : 'Be the first to post!', style: const TextStyle(color: GacomColors.textMuted)),
      const SizedBox(height: 24),
      GacomButton(label: 'CREATE POST', width: 180, height: 48, onPressed: () => context.go(AppConstants.createPostRoute)),
    ]));
    return RefreshIndicator(color: GacomColors.deepOrange, backgroundColor: GacomColors.cardDark,
      onRefresh: () async { setState(() { _posts = []; _page = 0; _loading = true; }); await _loadContext(); await _load(); },
      child: ListView.builder(padding: const EdgeInsets.fromLTRB(0, 8, 0, 120), itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _posts.length) { _load(); return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange, strokeWidth: 2))); }
          return _PostCard(post: _posts[i], isDiscovery: _posts[i]['_is_discovery'] == true)
              .animate(delay: Duration(milliseconds: math.min(i * 60, 240))).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
        }));
  }
}

// ── Post Card ─────────────────────────────────────────────────────────────────
class _PostCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> post; final bool isDiscovery;
  const _PostCard({required this.post, this.isDiscovery = false});
  @override ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> with SingleTickerProviderStateMixin {
  late bool _liked; late int _likeCount; late AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    final likedList = widget.post['is_liked'] as List? ?? [];
    final myId = SupabaseService.currentUserId;
    _liked = likedList.any((l) => (l is Map ? l['user_id'] : l) == myId);
    _likeCount = widget.post['likes_count'] as int? ?? 0;
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override void dispose() { _heartCtrl.dispose(); super.dispose(); }

  Future<void> _toggleLike() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    // Skip demo posts
    final postId = widget.post['id'] as String;
    if (postId.startsWith('demo')) return;
    HapticFeedback.lightImpact();
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    _heartCtrl.forward(from: 0);
    try {
      if (_liked) {
        await SupabaseService.client.from('post_likes').upsert({'post_id': postId, 'user_id': myId});
        // ✅ FIX: update likes_count directly — triggers are often the culprit for resets
        await SupabaseService.client.from('posts').update({'likes_count': _likeCount}).eq('id', postId);
      } else {
        await SupabaseService.client.from('post_likes').delete().eq('post_id', postId).eq('user_id', myId);
        await SupabaseService.client.from('posts').update({'likes_count': _likeCount}).eq('id', postId);
      }
    } catch (_) {
      if (mounted) setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    }
  }

  void _showComments() {
    final postId = widget.post['id'] as String;
    if (postId.startsWith('demo')) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CommentsSheet(postId: postId),
    );
  }

  void _sharePost() {
    final caption = widget.post['caption'] as String? ?? '';
    final author = (widget.post['author'] as Map?)?['username'] as String? ?? 'someone';
    Share.share('Check out this post by @$author on Gacom 🎮\n\n"$caption"\n\nhttps://gamicom.netlify.app');
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
    final postType = post['post_type'] as String? ?? 'text';
    final mediaUrls = post['media_urls'] as List? ?? [];
    final comments = post['comments_count'] as int? ?? 0;
    final shares = post['shares_count'] as int? ?? 0;
    final createdAt = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8), color: GacomColors.obsidian,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.isDiscovery)
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [const Icon(Icons.auto_awesome_rounded, size: 12, color: GacomColors.deepOrange), const SizedBox(width: 4), const Text('Suggested for you', style: TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))])),

        // Author
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: Row(children: [
          GestureDetector(onTap: () => context.go('/profile/${author['id'] ?? ''}'),
            child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange.withOpacity(0.5), width: 1.5)),
              child: CircleAvatar(radius: 20, backgroundColor: GacomColors.border, backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null ? Text(displayName[0].toUpperCase(), style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)) : null))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(displayName, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)), if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange)]]),
            Text('@$username · ${timeago.format(createdAt, locale: 'en_short')}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontFamily: 'Rajdhani')),
          ])),
          IconButton(icon: const Icon(Icons.more_horiz_rounded, color: GacomColors.textMuted, size: 20), onPressed: () {}),
        ])),

        if (caption.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(caption, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, height: 1.5))),

        // ✅ FIX: safe URL + proper video/image rendering
        if (mediaUrls.isNotEmpty) Builder(builder: (_) {
          final raw = mediaUrls.first;
          final url = raw is String ? raw : (raw?.toString() ?? '');
          if (url.isEmpty) return const SizedBox.shrink();
          final isVideo = postType == 'video' || postType == 'clip'
              || url.contains('.mp4') || url.contains('.mov') || url.contains('.webm');
          if (isVideo) {
            return _InlineVideoPlayer(url: url);
          }
          // ✅ FIX: AspectRatio 4:3 shows full image — no cropping, no tiny frame
          return AspectRatio(
            aspectRatio: 4 / 3,
            child: CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              fit: BoxFit.contain, // contain = show full image, no crop
              color: GacomColors.cardDark,
              colorBlendMode: BlendMode.dstOver, // cardDark fills the background
              placeholder: (_, __) => Container(
                color: GacomColors.cardDark,
                child: const Center(child: CircularProgressIndicator(
                    color: GacomColors.deepOrange, strokeWidth: 2))),
              errorWidget: (_, __, ___) => Container(
                color: GacomColors.cardDark,
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.image_not_supported_outlined, color: GacomColors.textMuted, size: 36),
                  SizedBox(height: 8),
                  Text('Image unavailable', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                ])),
            ),
          );
        }),

        // ✅ FIXED: All action buttons now functional
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: Row(children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)).animate(_heartCtrl),
            child: IconButton(onPressed: _toggleLike, icon: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? GacomColors.deepOrange : GacomColors.textMuted, size: 22))),
          Text(_fmt(_likeCount), style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          // ✅ Comment button — opens comments sheet
          IconButton(onPressed: _showComments, icon: const Icon(Icons.chat_bubble_outline_rounded, color: GacomColors.textMuted, size: 20)),
          Text(_fmt(comments), style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          // ✅ Share button — uses share_plus
          IconButton(onPressed: _sharePost, icon: const Icon(Icons.ios_share_rounded, color: GacomColors.textMuted, size: 20)),
          Text(_fmt(shares), style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_border_rounded, color: GacomColors.textMuted, size: 20)),
        ])),
        Container(height: 0.5, color: GacomColors.border),
      ]),
    );
  }

  String _fmt(int n) { if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M'; if (n >= 1000) return '${(n/1000).toStringAsFixed(1)}K'; return n.toString(); }
}

// ── Comments Sheet ─────────────────────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});
  @override State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('post_comments')
          .select('*, author:profiles!author_id(id, username, display_name, avatar_url)')
          .eq('post_id', widget.postId).eq('is_deleted', false)
          .order('created_at').limit(50);
      if (mounted) setState(() { _comments = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = SupabaseService.currentUserId; if (uid == null) return;
    setState(() => _sending = true);
    try {
      final result = await SupabaseService.client.from('post_comments')
          .insert({'post_id': widget.postId, 'author_id': uid, 'content': text}).select('*, author:profiles!author_id(id, username, display_name, avatar_url)').single();
      // Also increment comment count
      await SupabaseService.client.rpc('increment_comments_count', params: {'post_id': widget.postId}).catchError((_) async {
        // fallback if rpc doesn't exist
        final p = await SupabaseService.client.from('posts').select('comments_count').eq('id', widget.postId).single();
        await SupabaseService.client.from('posts').update({'comments_count': ((p['comments_count'] as int? ?? 0) + 1)}).eq('id', widget.postId);
      });
      _ctrl.clear();
      if (mounted) setState(() { _comments.add(result); _sending = false; });
    } catch (_) { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
      builder: (_, scroll) => Column(children: [
        Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
        const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 12), child: Text('Comments', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _comments.isEmpty
            ? const Center(child: Text('No comments yet. Be first!', style: TextStyle(color: GacomColors.textMuted)))
            : ListView.builder(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _comments.length, itemBuilder: (_, i) {
                  final c = _comments[i]; final a = c['author'] as Map? ?? {};
                  return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(radius: 18, backgroundColor: GacomColors.border, backgroundImage: a['avatar_url'] != null ? CachedNetworkImageProvider(a['avatar_url']) : null, child: a['avatar_url'] == null ? Text((a['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12)) : null),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 13)),
                      Text(c['content'] ?? '', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.4)),
                    ])),
                  ]));
                })),
        Container(padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: GacomColors.border, width: 0.5))),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, style: const TextStyle(color: GacomColors.textPrimary), decoration: InputDecoration(hintText: 'Add a comment...', hintStyle: const TextStyle(color: GacomColors.textMuted), filled: true, fillColor: GacomColors.cardDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: GacomColors.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
            const SizedBox(width: 10),
            GestureDetector(onTap: _sending ? null : _sendComment, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(gradient: GacomColors.orangeGradient, shape: BoxShape.circle), child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
          ])),
      ]));
  }
}

class _Skeleton extends StatelessWidget {
  final int delay; const _Skeleton({required this.delay});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_Shim(w: 44, h: 44, r: 22), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Shim(w: 120, h: 12), const SizedBox(height: 6), _Shim(w: 80, h: 10)])]),
      const SizedBox(height: 14), _Shim(w: double.infinity, h: 14), const SizedBox(height: 6), _Shim(w: 220, h: 14), const SizedBox(height: 14), _Shim(w: double.infinity, h: 200),
    ])).animate(delay: Duration(milliseconds: delay)).shimmer(duration: 1200.ms, color: GacomColors.border);
}

class _Shim extends StatelessWidget {
  final double w, h; final double r; const _Shim({required this.w, required this.h, this.r = 8});
  @override Widget build(BuildContext context) => Container(width: w, height: h, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(r)));
}

// ── Inline Video Player ───────────────────────────────────────────────────────
// Shows in the feed for video/clip posts. Tap to play/pause.
// Muted by default so it doesn't blast audio when scrolling.
class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  const _InlineVideoPlayer({required this.url});
  @override State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _playing = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..setVolume(0) // muted by default while scrolling
        ..setLooping(false);
      await _ctrl!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    setState(() {
      if (_playing) {
        _ctrl!.pause();
        _playing = false;
      } else {
        _ctrl!.setVolume(1); // unmute when user actively plays
        _ctrl!.play();
        _playing = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        height: 220,
        color: GacomColors.cardDark,
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.videocam_off_rounded, color: GacomColors.textMuted, size: 40),
          SizedBox(height: 8),
          Text('Video unavailable', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        ]),
      );
    }

    if (!_initialized || _ctrl == null) {
      return Container(
        height: 220,
        color: GacomColors.cardDark,
        child: const Center(
          child: CircularProgressIndicator(color: GacomColors.deepOrange, strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(children: [
        // ✅ FIX: AspectRatio 16:9 — video shows at full natural size, not cropped
        AspectRatio(
          aspectRatio: _ctrl!.value.aspectRatio > 0
              ? _ctrl!.value.aspectRatio
              : 16 / 9, // use actual video ratio, fallback to 16:9
          child: VideoPlayer(_ctrl!),
        ),

        // Play/pause overlay — only visible when paused
        if (!_playing)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 64),
              ),
            ),
          ),

        // Muted indicator — shown when playing muted
        if (_playing)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(50)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.volume_up_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Tap to pause',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ]),
            ),
          ),

        // Progress bar at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: VideoProgressIndicator(
            _ctrl!,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: GacomColors.deepOrange,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.black26,
            ),
          ),
        ),
      ]),
    );
  }
}
