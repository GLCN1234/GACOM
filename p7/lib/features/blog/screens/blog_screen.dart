import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});
  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _canWrite = false; // ✅ true for admins, super_admin, exco with blog_editor role
  String? _selectedCategory;

  final _categories = ['All', 'News', 'Esports', 'Reviews', 'Tips', 'Tournaments', 'Community'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() => _selectedCategory = _tab.index == 0 ? null : _categories[_tab.index]);
        _load();
      }
    });
    _checkWriteAccess();
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  /// Check if current user is admin/exco with blog write permission
  Future<void> _checkWriteAccess() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final p = await SupabaseService.client.from('profiles').select('role').eq('id', uid).single();
      final role = p['role'] as String? ?? 'user';
      if (['admin', 'super_admin'].contains(role)) {
        if (mounted) setState(() => _canWrite = true);
        return;
      }
      // Check exco_assignments for blog_editor
      final exco = await SupabaseService.client.from('exco_assignments')
          .select('exco_role').eq('exco_id', uid).eq('exco_role', 'blog_editor').maybeSingle();
      if (mounted) setState(() => _canWrite = exco != null);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      // Build filter chain first — ilike() must come before order()/limit()
      var baseQuery = SupabaseService.client
          .from('blog_posts')
          .select('*, author:profiles!author_id(username, display_name, avatar_url, verification_status)')
          .eq('is_published', true);

      if (_selectedCategory != null) {
        baseQuery = baseQuery.ilike('category', _selectedCategory!);
      }

      final data = await baseQuery
          .order('published_at', ascending: false)
          .limit(30);
      final all = List<Map<String, dynamic>>.from(data);
      final featured = all.where((p) => p['is_featured'] == true).take(3).toList();

      if (mounted) setState(() {
        _featured = featured;
        _posts = all;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreatePost() {
    final titleCtrl = TextEditingController();
    final excerptCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'News';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Write Article', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          GacomTextField(controller: titleCtrl, label: 'Title *', hint: 'Article title'),
          const SizedBox(height: 12),
          GacomTextField(controller: excerptCtrl, label: 'Excerpt', hint: 'Short summary...', maxLines: 2),
          const SizedBox(height: 12),
          GacomTextField(controller: contentCtrl, label: 'Content *', hint: 'Write your article...', maxLines: 8),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft, child: Text('Category', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, fontFamily: 'Rajdhani', letterSpacing: 1))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: ['News', 'Esports', 'Reviews', 'Tips', 'Tournaments', 'Community'].map((c) =>
            GestureDetector(onTap: () => setDlg(() => category = c), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: category == c ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: category == c ? GacomColors.deepOrange : GacomColors.border)),
              child: Text(c, style: TextStyle(color: category == c ? GacomColors.deepOrange : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13))))).toList()),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: GacomColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                GacomSnackbar.show(ctx, 'Title and content required', isError: true);
                return;
              }
              try {
                final slug = '${titleCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
                await SupabaseService.client.from('blog_posts').insert({
                  'title': titleCtrl.text.trim(),
                  'slug': slug,
                  'excerpt': excerptCtrl.text.trim().isEmpty ? null : excerptCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                  'category': category,
                  'author_id': SupabaseService.currentUserId,
                  'is_published': true,
                  'published_at': DateTime.now().toIso8601String(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                GacomSnackbar.show(context, 'Article published! ✅', isSuccess: true);
                setState(() => _loading = true);
                await _load();
              } catch (e) {
                GacomSnackbar.show(ctx, 'Failed: $e', isError: true);
              }
            },
            child: const Text('PUBLISH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      // ✅ Write FAB — only shown to admins and blog_editor exco
      floatingActionButton: _canWrite ? FloatingActionButton.extended(
        onPressed: _showCreatePost,
        backgroundColor: GacomColors.deepOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text('Write', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15)),
      ) : null,
      body: SafeArea(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GACOM', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 13, fontWeight: FontWeight.w700, color: GacomColors.deepOrange, letterSpacing: 3)),
                  Text('Blog', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w800, color: GacomColors.textPrimary, height: 1)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded, color: GacomColors.textSecondary),
                onPressed: () => context.go('/search'),
              ),
            ]),
          ),

          // ── Category tabs ───────────────────────────────────────────────────
          const SizedBox(height: 12),
          TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: GacomColors.deepOrange,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14),
            labelColor: GacomColors.deepOrange,
            unselectedLabelColor: GacomColors.textMuted,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: _categories.map((c) => Tab(text: c.toUpperCase())).toList(),
          ),
          const SizedBox(height: 4),
          const Divider(color: GacomColors.border, height: 1),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                : _posts.isEmpty
                    ? _EmptyBlog()
                    : RefreshIndicator(
                        color: GacomColors.deepOrange,
                        backgroundColor: GacomColors.cardDark,
                        onRefresh: () async { setState(() => _loading = true); await _load(); },
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 80),
                          children: [
                            // Featured carousel
                            if (_featured.isNotEmpty && _selectedCategory == null) ...[
                              const SizedBox(height: 16),
                              _FeaturedCarousel(posts: _featured),
                              const SizedBox(height: 20),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                                child: Text('LATEST ARTICLES', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 13, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 2)),
                              ),
                            ] else
                              const SizedBox(height: 16),

                            // Article list
                            ..._posts.asMap().entries.map((e) =>
                              _ArticleCard(post: e.value)
                                  .animate(delay: (e.key * 60).ms)
                                  .fadeIn()
                                  .slideY(begin: 0.15, end: 0),
                            ),
                          ],
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ── Featured carousel ─────────────────────────────────────────────────────────
class _FeaturedCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  const _FeaturedCarousel({required this.posts});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  int _current = 0;
  final _ctrl = PageController(viewportFraction: 0.88);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 220,
        child: PageView.builder(
          controller: _ctrl,
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.posts.length,
          itemBuilder: (_, i) => _FeaturedCard(post: widget.posts[i]),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.posts.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _current ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _current ? GacomColors.deepOrange : GacomColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        )),
      ),
    ]);
  }
}

class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _FeaturedCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final publishedAt = DateTime.tryParse(post['published_at'] ?? '') ?? DateTime.now();

    return GestureDetector(
      onTap: () => context.go('/blog/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(fit: StackFit.expand, children: [
            // Background image
            post['cover_image_url'] != null
                ? CachedNetworkImage(imageUrl: post['cover_image_url'], fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [GacomColors.darkOrange, GacomColors.obsidian],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (post['category'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(50)),
                    child: Text(post['category'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1)),
                  ),
                const SizedBox(height: 6),
                Text(post['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  CircleAvatar(radius: 10, backgroundColor: GacomColors.border, backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null, child: author['avatar_url'] == null ? const Icon(Icons.person, size: 10, color: Colors.white) : null),
                  const SizedBox(width: 6),
                  Text(author['display_name'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  Text(timeago.format(publishedAt), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Article list card ─────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _ArticleCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final publishedAt = DateTime.tryParse(post['published_at'] ?? '') ?? DateTime.now();
    final readTime = post['read_time_minutes'] ?? 5;
    final views = post['views_count'] ?? 0;
    final isVerified = author['verification_status'] == 'verified';

    return GestureDetector(
      onTap: () => context.go('/blog/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GacomColors.border, width: 0.5),
        ),
        child: Row(children: [
          // Thumbnail
          if (post['cover_image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: CachedNetworkImage(
                imageUrl: post['cover_image_url'],
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            )
          else
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Container(
                width: 110, height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [GacomColors.darkOrange, GacomColors.surfaceDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.article_rounded, color: Colors.white30, size: 40),
              ),
            ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (post['category'] != null)
                  Text(post['category'].toString().toUpperCase(), style: const TextStyle(color: GacomColors.deepOrange, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(post['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 15, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  CircleAvatar(radius: 10, backgroundColor: GacomColors.border, backgroundImage: author['avatar_url'] != null ? CachedNetworkImageProvider(author['avatar_url']) : null, child: author['avatar_url'] == null ? const Icon(Icons.person, size: 10, color: Colors.white) : null),
                  const SizedBox(width: 5),
                  Flexible(child: Text(author['display_name'] ?? '', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
                  if (isVerified) ...[const SizedBox(width: 2), const Icon(Icons.verified_rounded, size: 10, color: GacomColors.deepOrange)],
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 11, color: GacomColors.textMuted),
                  const SizedBox(width: 3),
                  Text('$readTime min', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  const SizedBox(width: 8),
                  const Icon(Icons.visibility_outlined, size: 11, color: GacomColors.textMuted),
                  const SizedBox(width: 3),
                  Text(_fmt(views), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  const Spacer(),
                  Text(timeago.format(publishedAt), style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _EmptyBlog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.article_outlined, size: 64, color: GacomColors.border),
        const SizedBox(height: 16),
        const Text('No articles yet', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Check back soon for gaming news & updates', style: TextStyle(color: GacomColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
      ]),
    );
  }
}
