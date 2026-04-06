import 'package:flutter/material.dart';
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
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
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
            title: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      GacomColors.orangeGradient.createShader(bounds),
                  child: const Text(
                    'GACOM',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: GacomColors.textPrimary),
                onPressed: () => context.go(AppConstants.searchRoute),
              ),
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined, color: GacomColors.textPrimary),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: GacomColors.deepOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () => context.go(AppConstants.notificationsRoute),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: GacomColors.deepOrange,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 1,
              ),
              labelColor: GacomColors.textPrimary,
              unselectedLabelColor: GacomColors.textMuted,
              tabs: const [
                Tab(text: 'FOR YOU'),
                Tab(text: 'FOLLOWING'),
              ],
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
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => const _PostSkeleton(),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videogame_asset_off_outlined,
                size: 64, color: GacomColors.border),
            const SizedBox(height: 16),
            const Text('No posts yet', style: TextStyle(color: GacomColors.textMuted)),
            const SizedBox(height: 24),
            GacomButton(
              label: 'CREATE FIRST POST',
              width: 200,
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            _loadPosts();
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: GacomColors.deepOrange),
              ),
            );
          }
          return _PostCard(post: _posts[i]);
        },
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _liked = (widget.post['is_liked'] as List?)?.isNotEmpty ?? false;
    _likesCount = widget.post['likes_count'] ?? 0;
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['id'];
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });

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
    final createdAt = DateTime.tryParse(widget.post['created_at'] ?? '') ?? DateTime.now();
    final isVerified = author['verification_status'] == 'verified';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GacomColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/profile/${author['id']}'),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: GacomColors.border,
                    backgroundImage: author['avatar_url'] != null
                        ? CachedNetworkImageProvider(author['avatar_url'])
                        : null,
                    child: author['avatar_url'] == null
                        ? Text(
                            (author['display_name'] ?? 'G')[0].toUpperCase(),
                            style: const TextStyle(
                              color: GacomColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            author['display_name'] ?? 'Gamer',
                            style: const TextStyle(
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: GacomColors.textPrimary,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: GacomColors.deepOrange,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${author['username'] ?? ''} · ${timeago.format(createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GacomColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: GacomColors.textMuted),
                  onPressed: () => _showOptions(context),
                ),
              ],
            ),
          ),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                caption,
                style: const TextStyle(
                  color: GacomColors.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),

          // Media
          if (mediaUrls.isNotEmpty && postType != 'text') ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)),
              child: AspectRatio(
                aspectRatio: postType == 'clip' ? 9 / 16 : 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: widget.post['thumbnail_url'] ?? mediaUrls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: GacomColors.border,
                    child: const Icon(Icons.broken_image_outlined,
                        color: GacomColors.textMuted),
                  ),
                ),
              ),
            ),
          ],

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ActionButton(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: _formatCount(_likesCount),
                  color: _liked ? GacomColors.deepOrange : GacomColors.textMuted,
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _formatCount(widget.post['comments_count'] ?? 0),
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.repeat_rounded,
                  label: _formatCount(widget.post['shares_count'] ?? 0),
                  onTap: () {},
                ),
                const Spacer(),
                _ActionButton(
                  icon: Icons.bookmark_border_rounded,
                  label: '',
                  onTap: () {},
                ),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: '',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: GacomColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.report_outlined, color: GacomColors.textSecondary),
            title: const Text('Report Post', style: TextStyle(color: GacomColors.textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: GacomColors.textSecondary),
            title: const Text('Unfollow', style: TextStyle(color: GacomColors.textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined, color: GacomColors.textSecondary),
            title: const Text('Copy Link', style: TextStyle(color: GacomColors.textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color ?? GacomColors.textMuted, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color ?? GacomColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Rajdhani',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 300,
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
