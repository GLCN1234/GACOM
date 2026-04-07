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

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: GacomColors.obsidian,
            elevation: 0,
            toolbarHeight: 64,
            title: _GacomLogoHeader(),
            actions: [
              _IconAction(
                icon: Icons.search_rounded,
                onTap: () => context.go(AppConstants.searchRoute),
              ),
              _NotificationAction(
                onTap: () => context.go(AppConstants.notificationsRoute),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GacomColors.border, width: 0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: GacomColors.deepOrange,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: const [Tab(text: 'FOR YOU'), Tab(text: 'FOLLOWING')],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostFeed(key: const ValueKey('foryou'), isFollowing: false),
            _PostFeed(key: const ValueKey('following'), isFollowing: true),
          ],
        ),
      ),
    );
  }
}

class _GacomLogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: GacomColors.orangeGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text('G',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) =>
              GacomColors.orangeGradient.createShader(bounds),
          child: const Text(
            'GACOM',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GacomColors.border, width: 0.8),
        ),
        child: Icon(icon, color: GacomColors.textPrimary, size: 18),
      ),
    );
  }
}

class _NotificationAction extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GacomColors.border, width: 0.8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined,
                color: GacomColors.textPrimary, size: 18),
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

// ─── Feed ────────────────────────────────────────────────────────────────────

class _PostFeed extends ConsumerStatefulWidget {
  final bool isFollowing;
  const _PostFeed({super.key, required this.isFollowing});

  @override
  ConsumerState<_PostFeed> createState() => _PostFeedState();
}

class _PostFeedState extends ConsumerState<_PostFeed> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final query = SupabaseService.client
          .from('posts')
          .select('''
            *,
            author:profiles!author_id(id, username, display_name, avatar_url, verification_status),
            community:communities(id, name, icon_url),
            is_liked:post_likes!inner(user_id)
          ''')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(_page * AppConstants.feedPageSize,
              (_page + 1) * AppConstants.feedPageSize - 1);

      final response = await query;
      if (mounted) {
        setState(() {
          _posts.addAll(List<Map<String, dynamic>>.from(response));
          _loading = false;
          _hasMore = response.length == AppConstants.feedPageSize;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: 4,
        itemBuilder: (_, i) => _PostSkeleton(delay: i * 100),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: GacomColors.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: GacomColors.border),
              ),
              child: const Icon(Icons.videogame_asset_off_outlined,
                  size: 48, color: GacomColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text('No posts yet',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: GacomColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Be the first to drop something',
                style:
                    TextStyle(color: GacomColors.textMuted, fontSize: 14)),
            const SizedBox(height: 28),
            GacomButton(
              label: 'CREATE POST',
              width: 180,
              height: 48,
              onPressed: () => context.go(AppConstants.createPostRoute),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: GacomColors.deepOrange,
      backgroundColor: GacomColors.cardDark,
      onRefresh: () async {
        setState(() {
          _posts = [];
          _page = 0;
          _loading = true;
        });
        await _loadPosts();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            _loadPosts();
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(
                      color: GacomColors.deepOrange, strokeWidth: 2)),
            );
          }
          return _PostCard(post: _posts[i])
              .animate(delay: Duration(milliseconds: math.min(i * 60, 300)))
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

// ─── Post Card ───────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  int _likesCount = 0;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _liked = (widget.post['is_liked'] as List?)?.isNotEmpty ?? false;
    _likesCount = widget.post['likes_count'] ?? 0;
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _heartScale = Tween<double>(begin: 1, end: 1.4).animate(
        CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final postId = widget.post['id'];
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    if (_liked) _heartCtrl.forward().then((_) => _heartCtrl.reverse());

    if (_liked) {
      await SupabaseService.client
          .from('post_likes')
          .insert({'post_id': postId, 'user_id': userId});
    } else {
      await SupabaseService.client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post['author'] as Map<String, dynamic>? ?? {};
    final mediaUrls = widget.post['media_urls'] as List? ?? [];
    final postType = widget.post['post_type'] as String? ?? 'text';
    final caption = widget.post['caption'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(widget.post['created_at'] ?? '') ?? DateTime.now();
    final isVerified = author['verification_status'] == 'verified';
    final hasMedia = mediaUrls.isNotEmpty && postType != 'text';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GacomColors.border, width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/profile/${author['id']}'),
                    child: _AvatarRing(
                      url: author['avatar_url'],
                      name: author['display_name'] ?? 'G',
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.go('/profile/${author['id']}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  author['display_name'] ?? 'Gamer',
                                  style: const TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: GacomColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded,
                                    size: 14, color: GacomColors.deepOrange),
                              ],
                            ],
                          ),
                          Text(
                            '@${author['username'] ?? ''} · ${timeago.format(createdAt)}',
                            style: const TextStyle(
                                fontSize: 11, color: GacomColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz,
                        color: GacomColors.textMuted, size: 18),
                    onPressed: () => _showOptions(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Caption ─────────────────────────────────────────────────
            if (caption.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, hasMedia ? 10 : 0),
                child: Text(
                  caption,
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontSize: 14,
                      height: 1.45),
                ),
              ),

            // ── Media ────────────────────────────────────────────────────
            if (hasMedia)
              AspectRatio(
                aspectRatio: postType == 'clip' ? 9 / 16 : 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl:
                          widget.post['thumbnail_url'] ?? mediaUrls.first,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: GacomColors.surfaceDark,
                        child: const Icon(Icons.broken_image_outlined,
                            color: GacomColors.textMuted),
                      ),
                    ),
                    if (postType == 'clip')
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),
                  ],
                ),
              ),

            // ── Actions ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  // Like with scale animation
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          ScaleTransition(
                            scale: _heartScale,
                            child: Icon(
                              _liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _liked
                                  ? GacomColors.deepOrange
                                  : GacomColors.textMuted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 5),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _formatCount(_likesCount),
                              key: ValueKey(_likesCount),
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _liked
                                    ? GacomColors.deepOrange
                                    : GacomColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _ActionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: _formatCount(
                        widget.post['comments_count'] ?? 0),
                    onTap: () {},
                  ),
                  _ActionBtn(
                    icon: Icons.repeat_rounded,
                    label: _formatCount(widget.post['shares_count'] ?? 0),
                    onTap: () {},
                  ),
                  const Spacer(),
                  _ActionBtn(
                      icon: Icons.bookmark_border_rounded,
                      label: '',
                      onTap: () {}),
                  _ActionBtn(
                      icon: Icons.ios_share_rounded,
                      label: '',
                      onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
                color: GacomColors.borderBright,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          _SheetTile(
              icon: Icons.report_outlined,
              label: 'Report Post',
              onTap: () => Navigator.pop(context)),
          _SheetTile(
              icon: Icons.person_remove_outlined,
              label: 'Unfollow',
              onTap: () => Navigator.pop(context)),
          _SheetTile(
              icon: Icons.copy_outlined,
              label: 'Copy Link',
              onTap: () => Navigator.pop(context)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  const _AvatarRing(
      {required this.url, required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: GacomColors.deepOrange.withOpacity(0.5), width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: GacomColors.border,
        backgroundImage:
            url != null ? CachedNetworkImageProvider(url!) : null,
        child: url == null
            ? Text(name[0].toUpperCase(),
                style: const TextStyle(
                    color: GacomColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Rajdhani'))
            : null,
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: GacomColors.textMuted, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GacomColors.textMuted)),
            ]
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: GacomColors.textSecondary, size: 20),
      title: Text(label,
          style: const TextStyle(
              color: GacomColors.textPrimary,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w600,
              fontSize: 16)),
      onTap: onTap,
      dense: true,
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _PostSkeleton extends StatefulWidget {
  final int delay;
  const _PostSkeleton({this.delay = 0});

  @override
  State<_PostSkeleton> createState() => _PostSkeletonState();
}

class _PostSkeletonState extends State<_PostSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = Color.lerp(
            GacomColors.cardDark, GacomColors.elevatedCard, _anim.value)!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GacomColors.border, width: 0.6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 20, backgroundColor: shimmer),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 120, height: 12, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(width: 80, height: 10, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(6))),
              ]),
            ]),
            const SizedBox(height: 14),
            Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 8),
            Container(width: 200, height: 14, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 14),
            Container(width: double.infinity, height: 180, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(16))),
          ]),
        );
      },
    ).animate(delay: Duration(milliseconds: widget.delay)).fadeIn();
  }
}
