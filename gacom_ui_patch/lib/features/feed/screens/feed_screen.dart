import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
            toolbarHeight: 60,
            title: Row(children: [
              // Logo
              ShaderMask(
                shaderCallback: (b) => GacomColors.orangeGradient.createShader(b),
                child: const Text(
                  'GACOM',
                  style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(6)),
                child: const Text('BETA', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 1, color: Colors.white)),
              ),
            ]),
            actions: [
              GestureDetector(
                onTap: () => context.go(AppConstants.searchRoute),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.search_rounded, color: GacomColors.textPrimary, size: 22),
                ),
              ),
              GestureDetector(
                onTap: () => context.go(AppConstants.notificationsRoute),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Stack(
                    children: [
                      const Icon(Icons.notifications_outlined, color: GacomColors.textPrimary, size: 22),
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: GacomColors.deepOrange,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.6), blurRadius: 4)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: TabBar(
                controller: _tabController,
                tabs: const [Tab(text: 'FOR YOU'), Tab(text: 'FOLLOWING')],
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
      final response = await SupabaseService.client
          .from('posts')
          .select('''
            *,
            author:profiles!author_id(id, username, display_name, avatar_url, verification_status),
            community:communities(id, name, icon_url),
            is_liked:post_likes!inner(user_id)
          ''')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(_page * AppConstants.feedPageSize, (_page + 1) * AppConstants.feedPageSize - 1);

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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.videogame_asset_off_outlined, size: 64, color: GacomColors.border),
          const SizedBox(height: 16),
          const Text('No posts yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Be the first to post!', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          GacomButton(label: 'CREATE FIRST POST', width: 200, height: 48, onPressed: () => context.go(AppConstants.createPostRoute)),
        ]),
      );
    }

    return RefreshIndicator(
      color: GacomColors.deepOrange,
      backgroundColor: GacomColors.cardDark,
      onRefresh: () async {
        setState(() { _posts = []; _page = 0; _loading = true; });
        await _loadPosts();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            _loadPosts();
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange, strokeWidth: 2)));
          }
          return _PostCard(post: _posts[i], index: i);
        },
      ),
    );
  }
}

// ─── Post Card ───────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int index;
  const _PostCard({required this.post, required this.index});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  bool _liked = false;
  int _likesCount = 0;
  late AnimationController _likeAnim;

  @override
  void initState() {
    super.initState();
    _liked = (widget.post['is_liked'] as List?)?.isNotEmpty ?? false;
    _likesCount = widget.post['likes_count'] ?? 0;
    _likeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _likeAnim.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['id'];
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    if (_liked) _likeAnim.forward(from: 0);
    if (_liked) {
      await SupabaseService.client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
    } else {
      await SupabaseService.client.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
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
    final community = widget.post['community'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: GacomDecorations.glassCard(
        radius: 22,
        shadows: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/profile/${author['id']}'),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isVerified ? [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.3), blurRadius: 8)] : null,
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: GacomColors.border,
                    backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null,
                    child: author['avatar_url'] == null
                        ? Text((author['display_name'] ?? 'G')[0].toUpperCase(), style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Rajdhani'))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(author['display_name'] ?? 'Gamer', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
                  if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange)],
                ]),
                Row(children: [
                  Text('@${author['username'] ?? ''} · ${timeago.format(createdAt)}', style: const TextStyle(fontSize: 12, color: GacomColors.textMuted)),
                  if (community != null) ...[
                    const Text(' · ', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                    Text(community['name'] ?? '', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ])),
              GestureDetector(
                onTap: () => _showOptions(context),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.more_horiz, color: GacomColors.textMuted, size: 20)),
              ),
            ]),
          ),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(caption, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 15, height: 1.4)),
            ),

          // Media
          if (mediaUrls.isNotEmpty && postType != 'text') ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: AspectRatio(
                aspectRatio: postType == 'clip' ? 9 / 16 : 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.post['thumbnail_url'] ?? mediaUrls.first,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: GacomColors.border, child: const Icon(Icons.broken_image_outlined, color: GacomColors.textMuted)),
                    ),
                    if (postType == 'clip' || postType == 'video')
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(children: [
              _ActionBtn(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(_liked),
                    color: _liked ? GacomColors.deepOrange : GacomColors.textMuted,
                    size: 20,
                  ),
                ),
                label: _fmt(_likesCount),
                onTap: _toggleLike,
                accent: _liked,
              ),
              _ActionBtn(icon: const Icon(Icons.chat_bubble_outline_rounded, color: GacomColors.textMuted, size: 20), label: _fmt(widget.post['comments_count'] ?? 0), onTap: () {}),
              _ActionBtn(icon: const Icon(Icons.repeat_rounded, color: GacomColors.textMuted, size: 20), label: _fmt(widget.post['shares_count'] ?? 0), onTap: () {}),
              const Spacer(),
              _ActionBtn(icon: const Icon(Icons.bookmark_border_rounded, color: GacomColors.textMuted, size: 20), label: '', onTap: () {}),
              _ActionBtn(icon: const Icon(Icons.share_outlined, color: GacomColors.textMuted, size: 20), label: '', onTap: () {}),
            ]),
          ),
        ],
      ),
    ).animate(delay: (widget.index * 50).ms).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
  }

  String _fmt(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.report_outlined, color: GacomColors.textSecondary), title: const Text('Report Post', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)), onTap: () => Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.person_remove_outlined, color: GacomColors.textSecondary), title: const Text('Unfollow', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)), onTap: () => Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.copy_outlined, color: GacomColors.textSecondary), title: const Text('Copy Link', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)), onTap: () => Navigator.pop(context)),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(children: [
          icon,
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: accent ? GacomColors.deepOrange : GacomColors.textMuted)),
          ],
        ]),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  final int delay;
  const _PostSkeleton({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: GacomDecorations.glassCard(radius: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.surfaceDark)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 120, height: 12, decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 6),
            Container(width: 80, height: 10, decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(6))),
          ]),
        ]),
        const SizedBox(height: 12),
        Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 6),
        Container(width: 200, height: 14, decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 12),
        Container(width: double.infinity, height: 180, decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(16))),
      ]),
    ).animate(delay: delay.ms).shimmer(duration: 1200.ms, color: GacomColors.borderBright.withOpacity(0.3));
  }
}
