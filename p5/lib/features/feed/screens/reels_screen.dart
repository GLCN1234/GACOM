import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  @override ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
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
      // Fetch image + video posts ordered by engagement score (likes * 1 + comments * 3)
      final data = await SupabaseService.client
          .from('posts')
          .select('*, author:profiles!author_id(id, username, display_name, avatar_url, verification_status), is_liked:post_likes(user_id)')
          .eq('is_deleted', false)
          .inFilter('post_type', ['image', 'video', 'clip'])
          .order('likes_count', ascending: false)
          .limit(50);

      List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(data);
      // Fill with text posts if not enough media
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
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
        ),
        title: const Text('REELS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE84B00)))
          : _posts.isEmpty
              ? _EmptyReels()
              : PageView.builder(
                  controller: _pageCtrl,
                  scrollDirection: Axis.vertical,
                  itemCount: _posts.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (_, i) => _ReelItem(post: _posts[i], isActive: i == _currentIndex),
                ),
    );
  }
}

class _EmptyReels extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 64),
    const SizedBox(height: 16),
    const Text('No reels yet', style: TextStyle(color: Colors.white60, fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Post images or videos to see them here', style: TextStyle(color: Colors.white38, fontSize: 13)),
  ]));
}

// ── Single Reel Item ─────────────────────────────────────────────────────────
class _ReelItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  const _ReelItem({required this.post, required this.isActive});
  @override State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _liked = false;
  late int _likeCount;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    final likedList = widget.post['is_liked'] as List? ?? [];
    final myId = SupabaseService.currentUserId;
    _liked = likedList.any((l) => (l is Map ? l['user_id'] : l) == myId);
    _likeCount = widget.post['likes_count'] as int? ?? 0;
    _initVideo();
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        _videoCtrl?.play();
      } else {
        _videoCtrl?.pause();
      }
    }
  }

  void _initVideo() {
    final postType = widget.post['post_type'] as String? ?? 'text';
    final mediaUrls = widget.post['media_urls'] as List? ?? [];
    if ((postType == 'video' || postType == 'clip') && mediaUrls.isNotEmpty) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(mediaUrls.first as String))
        ..initialize().then((_) {
          if (mounted) setState(() => _videoReady = true);
          if (widget.isActive) _videoCtrl?.play();
          _videoCtrl?.setLooping(true);
        });
    }
  }

  @override
  void dispose() { _videoCtrl?.dispose(); super.dispose(); }

  Future<void> _toggleLike() async {
    final myId = SupabaseService.currentUserId;
    final postId = widget.post['id'] as String;
    if (myId == null || postId.startsWith('demo')) return;
    HapticFeedback.lightImpact();
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; _showHeart = _liked; });
    if (_liked) Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() => _showHeart = false); });
    try {
      if (_liked) {
        await SupabaseService.client.from('post_likes').upsert({'post_id': postId, 'user_id': myId});
      } else {
        await SupabaseService.client.from('post_likes').delete().eq('post_id', postId).eq('user_id', myId);
      }
      await SupabaseService.client.from('posts').update({'likes_count': _likeCount}).eq('id', postId);
    } catch (_) { if (mounted) setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; }); }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final mediaUrls = post['media_urls'] as List? ?? [];
    final postType = post['post_type'] as String? ?? 'text';
    final caption = post['caption'] as String? ?? '';
    final comments = post['comments_count'] as int? ?? 0;
    final isVerified = author['verification_status'] == 'verified';

    return GestureDetector(
      onDoubleTap: _toggleLike,
      child: Stack(fit: StackFit.expand, children: [
        // ── Background (video/image/gradient) ───────────────────────────────
        if ((postType == 'video' || postType == 'clip') && _videoReady && _videoCtrl != null)
          FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoCtrl!.value.size.width, height: _videoCtrl!.value.size.height, child: VideoPlayer(_videoCtrl!)))
        else if (mediaUrls.isNotEmpty)
          CachedNetworkImage(imageUrl: mediaUrls.first as String, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
            placeholder: (_, __) => Container(color: const Color(0xFF111111)),
            errorWidget: (_, __, ___) => _GradientBackground(caption: caption))
        else
          _GradientBackground(caption: caption),

        // ── Gradient overlays (top + bottom) ────────────────────────────────
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.85)], stops: const [0, 0.2, 0.5, 1]))),

        // ── Double-tap heart animation ────────────────────────────────────────
        if (_showHeart)
          Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 400), builder: (_, v, __) => Opacity(opacity: v > 0.7 ? 1.0 - ((v - 0.7) / 0.3) : v / 0.7,
            child: Transform.scale(scale: v, child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 90))))),

        // ── Right side action buttons ─────────────────────────────────────────
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(children: [
            // Avatar
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _AuthorProfile(authorId: author['id'] as String? ?? ''))),
              child: Stack(children: [
                ClipOval(child: CachedNetworkImage(imageUrl: author['avatar_url'] ?? '', width: 48, height: 48, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: const Color(0xFFE84B00), child: Center(child: Text((author['display_name'] ?? 'G')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)))))),
                Positioned(bottom: 0, right: 0, left: 0, child: Center(child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFFE84B00), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 14)))),
              ]),
            ),
            const SizedBox(height: 24),
            // Like
            _SideAction(icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: _fmtCount(_likeCount), color: _liked ? const Color(0xFFE84B00) : Colors.white, onTap: _toggleLike),
            const SizedBox(height: 20),
            // Comment
            _SideAction(icon: Icons.chat_bubble_outline_rounded, label: _fmtCount(comments), onTap: () {}),
            const SizedBox(height: 20),
            // Share
            _SideAction(icon: Icons.ios_share_rounded, label: 'Share', onTap: () => Share.share('Check this out on Gacom 🎮\n"$caption"')),
            const SizedBox(height: 20),
            // More
            _SideAction(icon: Icons.more_vert_rounded, label: '', onTap: () {}),
          ]),
        ),

        // ── Bottom info ───────────────────────────────────────────────────────
        Positioned(
          left: 16,
          right: 80,
          bottom: 40,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('@${author['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
              if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFFE84B00), size: 14)],
            ]),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
            ],
            const SizedBox(height: 10),
            // Music/game tag bar (Instagram style)
            Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle), child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 14)),
              const SizedBox(width: 8),
              const Text('GACOM Arena', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Rajdhani')),
            ]),
          ]),
        ),

        // ── Video progress bar ────────────────────────────────────────────────
        if (_videoReady && _videoCtrl != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(_videoCtrl!, allowScrubbing: true,
              colors: VideoProgressColors(playedColor: const Color(0xFFE84B00), bufferedColor: Colors.white24, backgroundColor: Colors.black26)),
          ),
      ]),
    );
  }

  String _fmtCount(int n) { if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M'; if (n >= 1000) return '${(n/1000).toStringAsFixed(1)}K'; return n == 0 ? '' : '$n'; }
}

class _GradientBackground extends StatelessWidget {
  final String caption;
  const _GradientBackground({required this.caption});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0C0C0C), Color(0xFF1A0A00), Color(0xFF0C0C0C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, height: 1.4)))),
  );
}

class _SideAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Color? color;
  const _SideAction({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Column(children: [
    Icon(icon, color: color ?? Colors.white, size: 30, shadows: const [Shadow(color: Colors.black38, blurRadius: 6)]),
    if (label.isNotEmpty) ...[const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]))],
  ]));
}

// Minimal author profile view pushed modally from reel
class _AuthorProfile extends StatelessWidget {
  final String authorId;
  const _AuthorProfile({required this.authorId});
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, body: Center(child: GestureDetector(onTap: () { Navigator.pop(context); context.go('/profile/$authorId'); }, child: const Text('View Profile', style: TextStyle(color: Color(0xFFE84B00), fontSize: 18, decoration: TextDecoration.underline)))));
}
