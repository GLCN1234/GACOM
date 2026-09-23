import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
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
      // Check the REAL like state instead of always starting from false —
      // that mismatch (showing "not liked" when a like already exists)
      // is exactly what caused the duplicate-key crash when tapping like
      // on a post already liked in an earlier visit.
      final userId = SupabaseService.currentUserId;
      bool alreadyLiked = false;
      if (userId != null) {
        final existing = await SupabaseService.client.from('blog_likes')
            .select('blog_post_id').eq('blog_post_id', widget.blogId).eq('user_id', userId).maybeSingle();
        alreadyLiked = existing != null;
      }
      if (mounted) setState(() { _post = post; _liked = alreadyLiked; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleLike() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final wasLiked = _liked;
    setState(() => _liked = !_liked);
    try {
      if (!wasLiked) {
        await SupabaseService.client.from('blog_likes').insert({'blog_post_id': widget.blogId, 'user_id': userId});
      } else {
        await SupabaseService.client.from('blog_likes').delete().eq('blog_post_id', widget.blogId).eq('user_id', userId);
      }
    } catch (e) {
      // Defensive backstop: if the state ever ends up mismatched again for
      // any reason, a duplicate-like or delete-nothing error just means
      // the like already reflects reality — don't crash the page over it,
      // just keep the UI where it already moved to.
      if (e is PostgrestException && e.code == '23505') return;
      if (mounted) setState(() => _liked = wasLiked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_post == null) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Text('Post not found.', style: TextStyle(color: GacomColors.textMuted))));

    final p = _post!;
    final author = p['author'] as Map<String, dynamic>? ?? {};
    final publishedAt = DateTime.tryParse(p['published_at'] ?? '') ?? DateTime.now();
    final hasCoverImage = p['cover_image_url'] != null && (p['cover_image_url'] as String).isNotEmpty;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasCoverImage ? 240 : 0,
            pinned: true,
            backgroundColor: GacomColors.obsidian,
            flexibleSpace: hasCoverImage ? FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: p['cover_image_url'],
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(color: GacomColors.elevatedCard,
                  child: const Center(child: Icon(Icons.broken_image_rounded, color: GacomColors.textMuted, size: 40))),
              ),
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
                  CircleAvatar(radius: 18, backgroundColor: GacomColors.border, backgroundImage: (author['avatar_url'] != null && (author['avatar_url'] as String).isNotEmpty) ? CachedNetworkImageProvider(author['avatar_url']) : null, onBackgroundImageError: (author['avatar_url'] != null && (author['avatar_url'] as String).isNotEmpty) ? (exception, stackTrace) {} : null, child: (author['avatar_url'] == null || (author['avatar_url'] as String).isEmpty) ? Text((author['display_name'] ?? 'G')[0], style: const TextStyle(fontSize: 12, color: GacomColors.textPrimary)) : null),
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
                ..._parseHtmlParagraphs(p['content'] ?? ''),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// Lightweight, dependency-free HTML renderer for blog post content, which
// is always simple <p> and <a> tags only (that's what the AI generator is
// prompted to produce). Avoids pulling in flutter_html, whose 3.0.0
// release has a genuine incompatibility with this project's Dart SDK
// (fails to compile on Flutter web: "Method not found: 'matches'" in its
// internal CSS-selector code) — this sidesteps that risk entirely rather
// than chasing a compatible third-party version.
List<Widget> _parseHtmlParagraphs(String html) {
  final paragraphRegex = RegExp(r'<p([^>]*)>(.*?)</p>', dotAll: true);
  final matches = paragraphRegex.allMatches(html).toList();
  if (matches.isEmpty) {
    // No <p> tags matched at all — fall back to showing stripped plain
    // text rather than an empty post.
    final stripped = html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (stripped.isEmpty) return const [];
    return [Text(_unescapeHtml(stripped), style: const TextStyle(color: GacomColors.textSecondary, fontSize: 16, height: 1.8))];
  }
  final widgets = <Widget>[];
  for (final match in matches) {
    final attrs = match.group(1) ?? '';
    final inner = match.group(2) ?? '';
    final isSmallPrint = attrs.contains('12px') || attrs.contains('font-size:12');
    widgets.add(_buildParagraph(inner, isSmallPrint: isSmallPrint));
    widgets.add(const SizedBox(height: 16));
  }
  return widgets;
}

Widget _buildParagraph(String inner, {bool isSmallPrint = false}) {
  final baseStyle = isSmallPrint
      ? const TextStyle(color: GacomColors.textMuted, fontSize: 12)
      : const TextStyle(color: GacomColors.textSecondary, fontSize: 16, height: 1.8);
  final linkRegex = RegExp(r'<a\s+href="([^"]*)"[^>]*>(.*?)</a>', dotAll: true);
  final spans = <InlineSpan>[];
  int lastEnd = 0;
  for (final m in linkRegex.allMatches(inner)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: _unescapeHtml(inner.substring(lastEnd, m.start))));
    }
    final url = m.group(1) ?? '';
    final linkText = _unescapeHtml(m.group(2) ?? '');
    spans.add(TextSpan(
      text: linkText,
      style: TextStyle(color: GacomColors.deepOrange, decoration: TextDecoration.underline, fontSize: baseStyle.fontSize),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          final uri = Uri.tryParse(url);
          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        },
    ));
    lastEnd = m.end;
  }
  if (lastEnd < inner.length) {
    spans.add(TextSpan(text: _unescapeHtml(inner.substring(lastEnd))));
  }
  return RichText(text: TextSpan(style: baseStyle, children: spans));
}

String _unescapeHtml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .trim();

