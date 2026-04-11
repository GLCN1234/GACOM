import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});
  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  final _pageCtrl = PageController();
  int _currentIndex = 0;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('posts')
          .select('*, author:profiles!author_id(id, username, display_name, avatar_url, verification_status), is_liked:post_likes(user_id)')
          .eq('is_deleted', false)
          .inFilter('post_type', ['image', 'video', 'clip'])
          .order('likes_count', ascending: false)
          .limit(50);

      List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(data);
      if (posts.length < 5) {
        final textPosts = await SupabaseService.client
            .from('posts')
            .select('*, author:profiles!author_id(id, username, display_name, avatar_url, verification_status), is_liked:post_likes(user_id)')
            .eq('is_deleted', false)
            .order('likes_count', ascending: false)
            .limit(20);
        posts = List<Map<String, dynamic>>.from(textPosts);
      }

      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)),
      );
    }

    if (_posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop())),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.play_circle_outline_rounded, size: 80, color: GacomColors.deepOrange),
          const SizedBox(height: 16),
          const Text('No clips yet', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Be the first to post a gaming clip!', style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/create-post'),
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
            child: const Text('POST A CLIP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
          ),
        ])),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('CLIPS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: 2)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.white), onPressed: () => context.go('/create-post')),
          ],
        ),
        body: PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          onPageChanged: (i) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = i);
          },
          itemCount: _posts.length,
          itemBuilder: (_, i) => _ReelItem(
            post: _posts[i],
            isActive: i == _currentIndex,
          ),
        ),
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  const _ReelItem({required this.post, required this.isActive});

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoCtrl;
  bool _liked = false;
  int _likes = 0;
  bool _showHeart = false;
  late AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    _liked = (widget.post['is_liked'] as List?)?.isNotEmpty ?? false;
    _likes = widget.post['likes_count'] ?? 0;
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    final mediaUrls = widget.post['media_urls'] as List? ?? [];
    final postType = widget.post['post_type'] as String? ?? 'text';
    if ((postType == 'video' || postType == 'clip') && mediaUrls.isNotEmpty) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(mediaUrls.first))
        ..initialize().then((_) {
          if (mounted && widget.isActive) {
            _videoCtrl!.play();
            _videoCtrl!.setLooping(true);
          }
          setState(() {});
        });
    }
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _videoCtrl?.play();
    } else if (!widget.isActive && old.isActive) {
      _videoCtrl?.pause();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
    if (_liked) {
      _showHeart = true;
      _heartCtrl.forward(from: 0).then((_) => setState(() => _showHeart = false));
      await SupabaseService.client.from('post_likes').insert({'post_id': widget.post['id'], 'user_id': userId});
    } else {
      await SupabaseService.client.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', userId);
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post['author'] as Map<String, dynamic>? ?? {};
    final mediaUrls = widget.post['media_urls'] as List? ?? [];
    final postType = widget.post['post_type'] as String? ?? 'text';
    final caption = widget.post['caption'] as String? ?? '';
    final comments = widget.post['comments_count'] ?? 0;
    final shares = widget.post['shares_count'] ?? 0;
    final isVerified = author['verification_status'] == 'verified';

    return GestureDetector(
      onDoubleTap: _toggleLike,
      child: Stack(fit: StackFit.expand, children: [

        // ── Background media ────────────────────────────────────────────────
        _buildMedia(postType, mediaUrls, caption),

        // ── Dark gradient overlay ───────────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0, 0.15, 0.55, 1],
            ),
          ),
        ),

        // ── Double-tap heart ────────────────────────────────────────────────
        if (_showHeart)
          Center(
            child: ScaleTransition(
              scale: Tween(begin: 0.0, end: 1.4).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut)),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 90),
            ),
          ),

        // ── Right side actions ──────────────────────────────────────────────
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(children: [
            // Author avatar
            GestureDetector(
              onTap: () => context.go('/profile/${author['id']}'),
              child: Stack(alignment: Alignment.bottomCenter, children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: GacomColors.border,
                    backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null,
                    child: author['avatar_url'] == null ? Text((author['display_name'] ?? 'G')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                  ),
                ),
                Positioned(
                  bottom: -4,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: GacomColors.deepOrange, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Like
            _ActionBtn(
              icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: _fmt(_likes),
              color: _liked ? GacomColors.deepOrange : Colors.white,
              onTap: _toggleLike,
            ),
            const SizedBox(height: 18),

            // Comment
            _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: _fmt(comments),
              color: Colors.white,
              onTap: () {},
            ),
            const SizedBox(height: 18),

            // Share
            _ActionBtn(
              icon: Icons.reply_rounded,
              label: _fmt(shares),
              color: Colors.white,
              onTap: () => Share.share('Check out this clip on Gacom! 🎮\n${widget.post['caption'] ?? ''}'),
              mirrorIcon: true,
            ),
            const SizedBox(height: 18),

            // More
            _ActionBtn(
              icon: Icons.more_vert_rounded,
              label: '',
              color: Colors.white,
              onTap: () {},
            ),
          ]),
        ),

        // ── Bottom info ─────────────────────────────────────────────────────
        Positioned(
          left: 16, right: 80, bottom: 40,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Author
            GestureDetector(
              onTap: () => context.go('/profile/${author['id']}'),
              child: Row(children: [
                Text('@${author['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
                if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 14, color: GacomColors.deepOrange)],
              ]),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(caption, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, shadows: [Shadow(color: Colors.black54, blurRadius: 8)]), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            // Game tag
            if ((widget.post['game_tags'] as List?)?.isNotEmpty == true)
              Row(children: [
                const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 14),
                const SizedBox(width: 4),
                Text((widget.post['game_tags'] as List).first.toString(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
              ]),
          ]),
        ),

        // ── Video progress bar ──────────────────────────────────────────────
        if (_videoCtrl != null && _videoCtrl!.value.isInitialized)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(
              _videoCtrl!,
              allowScrubbing: true,
              colors: VideoProgressColors(playedColor: GacomColors.deepOrange, bufferedColor: Colors.white30, backgroundColor: Colors.white10),
              padding: EdgeInsets.zero,
            ),
          ),
      ]),
    );
  }

  Widget _buildMedia(String postType, List mediaUrls, String caption) {
    if ((postType == 'video' || postType == 'clip') && _videoCtrl != null && _videoCtrl!.value.isInitialized) {
      return FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoCtrl!.value.size.width, height: _videoCtrl!.value.size.height, child: VideoPlayer(_videoCtrl!)));
    }

    if (mediaUrls.isNotEmpty) {
      final thumb = widget.post['thumbnail_url'] ?? mediaUrls.first;
      return CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _TextBackground(caption: caption));
    }

    return _TextBackground(caption: caption);
  }
}

class _TextBackground extends StatelessWidget {
  final String caption;
  const _TextBackground({required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0500), GacomColors.obsidian, Color(0xFF0D0D0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            caption,
            style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool mirrorIcon;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap, this.mirrorIcon = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Transform(
          transform: mirrorIcon ? Matrix4.rotationY(3.14) : Matrix4.identity(),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 28, shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)])),
        ],
      ]),
    );
  }
}
