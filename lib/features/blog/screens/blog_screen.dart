import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});
  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('blog_posts').select('*, author:profiles!author_id(username, display_name, avatar_url)').eq('is_published', true).order('published_at', ascending: false).limit(20);
      if (mounted) setState(() { _posts = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('GACOM BLOG')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _posts.isEmpty
              ? const Center(child: Text('No blog posts yet.', style: TextStyle(color: GacomColors.textMuted)))
              : RefreshIndicator(
                  color: GacomColors.deepOrange,
                  onRefresh: () async { setState(() => _loading = true); await _load(); },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (_, i) => _BlogCard(post: _posts[i]).animate(delay: (i * 80).ms).fadeIn().slideY(begin: 0.2, end: 0),
                  ),
                ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _BlogCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final publishedAt = DateTime.tryParse(post['published_at'] ?? '') ?? DateTime.now();
    final views = post['views_count'] ?? 0;
    final readTime = post['read_time_minutes'] ?? 5;

    return GestureDetector(
      onTap: () => context.go('/blog/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['cover_image_url'] != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(imageUrl: post['cover_image_url'], fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['category'] != null) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
                    child: Text(post['category'].toString().toUpperCase(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1)),
                  ),
                  const SizedBox(height: 10),
                  Text(post['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, height: 1.2)),
                  const SizedBox(height: 8),
                  if (post['excerpt'] != null) Text(post['excerpt'], style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: GacomColors.border,
                        backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null,
                        child: author['avatar_url'] == null ? Text((author['display_name'] ?? 'G')[0], style: const TextStyle(fontSize: 12, color: GacomColors.textPrimary)) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(author['display_name'] ?? '', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
                      const Icon(Icons.visibility_outlined, size: 13, color: GacomColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$views', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule_rounded, size: 13, color: GacomColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$readTime min', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text(timeago.format(publishedAt), style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
