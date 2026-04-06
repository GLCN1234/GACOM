import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../widgets/gacom_widgets.dart';
import '../../models/post_model.dart';
import '../../services/supabase_service.dart';
import 'create_post_screen.dart';

final feedProvider = FutureProvider<List<PostModel>>((ref) async {
  final posts = await SupabaseService.getFeedPosts();
  return posts.map((p) => PostModel.fromJson(p)).toList();
});

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedAsync = ref.watch(feedProvider);
    return Scaffold(
      backgroundColor: GacomColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildStories(),
          _buildCreatePost(),
          feedAsync.when(
            data: (posts) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => PostCard(post: posts[i]).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideY(begin: 0.1, end: 0),
                childCount: posts.length,
              ),
            ),
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _PostSkeleton(),
                childCount: 5,
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Failed to load feed', style: GoogleFonts.outfit(color: GacomColors.textSecondary))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: GacomColors.background,
      floating: true,
      snap: true,
      title: Text('GACOM', style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
      actions: [
        IconButton(icon: const Icon(Icons.search, color: GacomColors.textPrimary), onPressed: () {}),
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: GacomColors.textPrimary),
              Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: GacomColors.primary, shape: BoxShape.circle))),
            ],
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildStories() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 8,
          itemBuilder: (_, i) {
            if (i == 0) return _AddStoryItem();
            return _StoryItem(index: i);
          },
        ),
      ),
    );
  }

  Widget _buildCreatePost() {
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GacomColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GacomColors.cardBorder),
          ),
          child: Row(
            children: [
              const GacomAvatar(username: 'U', size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text("What's your game move today?",
                  style: GoogleFonts.outfit(color: GacomColors.textMuted, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [GacomColors.primary, GacomColors.primaryDark]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('POST', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late int _likes;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likes = widget.post.likesCount;
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    if (_liked) {
      SupabaseService.likePost(widget.post.id, SupabaseService.currentUserId ?? '');
    } else {
      SupabaseService.unlikePost(widget.post.id, SupabaseService.currentUserId ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      color: GacomColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                GacomAvatar(username: post.user.username, imageUrl: post.user.avatarUrl, isVerified: post.user.isVerified, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(post.user.username, style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          if (post.user.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 14, color: GacomColors.primary),
                          ],
                        ],
                      ),
                      Text(timeago.format(post.createdAt), style: GoogleFonts.outfit(color: GacomColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_horiz, color: GacomColors.textMuted, size: 20), onPressed: () {}),
              ],
            ),
          ),

          // Content
          if (post.content != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content!,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(color: GacomColors.textPrimary, fontSize: 14, height: 1.5),
                  ),
                  if (post.content!.length > 150) GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Less' : 'More', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 13)),
                  ),
                ],
              ),
            ),

          // Media
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMedia(post),
          ],

          // Tags
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 6,
                children: post.tags.map((t) => Text('#$t', style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 13))).toList(),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                _ActionBtn(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  label: _likes.toString(),
                  color: _liked ? Colors.red : null,
                  onTap: _toggleLike,
                ),
                _ActionBtn(icon: Icons.chat_bubble_outline, label: post.commentsCount.toString(), onTap: () {}),
                _ActionBtn(icon: Icons.repeat_rounded, label: post.sharesCount.toString(), onTap: () {}),
                const Spacer(),
                _ActionBtn(icon: Icons.bookmark_border, label: '', onTap: () {}),
              ],
            ),
          ),

          const Divider(height: 1, color: GacomColors.cardBorder),
        ],
      ),
    );
  }

  Widget _buildMedia(PostModel post) {
    if (post.mediaUrls.length == 1) {
      return CachedNetworkImage(
        imageUrl: post.mediaUrls.first,
        width: double.infinity,
        height: 320,
        fit: BoxFit.cover,
        placeholder: (_, __) => const GacomShimmer(height: 320, borderRadius: 0),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: post.mediaUrls.length,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(right: 8),
          width: 180,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(imageUrl: post.mediaUrls[i], fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? GacomColors.textSecondary),
            if (label.isNotEmpty) ...[const SizedBox(width: 4), Text(label, style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 13))],
          ],
        ),
      ),
    );
  }
}

class _AddStoryItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GacomColors.cardBorder, width: 2),
              color: GacomColors.surfaceVariant,
            ),
            child: const Icon(Icons.add, color: GacomColors.primary),
          ),
          const SizedBox(height: 4),
          Text('Your Story', style: GoogleFonts.outfit(color: GacomColors.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final int index;
  const _StoryItem({required this.index});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [GacomColors.primary, GacomColors.primaryDark]),
              border: Border.all(color: GacomColors.background, width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text('Gamer$index', style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GacomShimmer(height: 40, width: 40, borderRadius: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GacomShimmer(height: 14, width: 120),
              const SizedBox(height: 4),
              GacomShimmer(height: 10, width: 80),
            ]),
          ]),
          const SizedBox(height: 12),
          GacomShimmer(height: 14, width: double.infinity),
          const SizedBox(height: 6),
          GacomShimmer(height: 14, width: 200),
          const SizedBox(height: 12),
          GacomShimmer(height: 200, width: double.infinity),
        ],
      ),
    );
  }
}
