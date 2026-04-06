import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class BlogDetailScreen extends ConsumerStatefulWidget {
  final String blogId;
  const BlogDetailScreen({super.key, required this.blogId});
  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  bool _liked = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final post = await SupabaseService.client.from('blog_posts').select('*, author:profiles!author_id(username, display_name, avatar_url, verification_status)').eq('id', widget.blogId).single();
      await SupabaseService.client.from('blog_posts').update({'views_count': (post['views_count'] ?? 0) + 1}).eq('id', widget.blogId);
      if (mounted) setState(() { _post = post; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleLike() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _liked = !_liked);
    if (_liked) {
      await SupabaseService.client.from('blog_likes').insert({'blog_post_id': widget.blogId, 'user_id': userId});
    } else {
      await SupabaseService.client.from('blog_likes').delete().eq('blog_post_id', widget.blogId).eq('user_id', userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_post == null) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Text('Post not found.', style: TextStyle(color: GacomColors.textMuted))));

    final p = _post!;
    final author = p['author'] as Map<String, dynamic>? ?? {};
    final publishedAt = DateTime.tryParse(p['published_at'] ?? '') ?? DateTime.now();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: p['cover_image_url'] != null ? 240 : 0,
            pinned: true,
            backgroundColor: GacomColors.obsidian,
            flexibleSpace: p['cover_image_url'] != null ? FlexibleSpaceBar(
              background: CachedNetworkImage(imageUrl: p['cover_image_url'], fit: BoxFit.cover),
            ) : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (p['category'] != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
                  child: Text(p['category'].toString().toUpperCase(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1)),
                ),
                Text(p['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, height: 1.2)),
                const SizedBox(height: 16),
                Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: GacomColors.border, backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null, child: author['avatar_url'] == null ? Text((author['display_name'] ?? 'G')[0], style: const TextStyle(fontSize: 12, color: GacomColors.textPrimary)) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(author['display_name'] ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('${DateFormat('MMM d, yyyy').format(publishedAt)} · ${p['read_time_minutes'] ?? 5} min read', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                  ])),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(children: [
                      Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? GacomColors.deepOrange : GacomColors.textMuted, size: 20),
                      const SizedBox(width: 4),
                      Text('${p['likes_count'] ?? 0}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 24),
                const Divider(color: GacomColors.border),
                const SizedBox(height: 24),
                Text(p['content'] ?? '', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 16, height: 1.8)),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
