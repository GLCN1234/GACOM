import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  late TabController _tab;

  bool get _isOwnProfile => SupabaseService.currentUserId == widget.userId;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _load(); }

  Future<void> _load() async {
    try {
      final profile = await SupabaseService.client.from('profiles').select('*').eq('id', widget.userId).single();
      final posts = await SupabaseService.client.from('posts').select('*').eq('author_id', widget.userId).eq('is_deleted', false).order('created_at', ascending: false).limit(20);
      bool isFollowing = false;
      final myId = SupabaseService.currentUserId;
      if (myId != null && !_isOwnProfile) {
        final check = await SupabaseService.client.from('follows').select('id').eq('follower_id', myId).eq('following_id', widget.userId).maybeSingle();
        isFollowing = check != null;
      }
      if (mounted) setState(() { _profile = profile; _posts = List<Map<String, dynamic>>.from(posts); _isFollowing = isFollowing; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleFollow() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await SupabaseService.client.from('follows').delete().eq('follower_id', myId).eq('following_id', widget.userId);
      } else {
        await SupabaseService.client.from('follows').insert({'follower_id': myId, 'following_id': widget.userId});
      }
      if (mounted) setState(() { _isFollowing = !_isFollowing; _followLoading = false; });
    } catch (e) { if (mounted) setState(() => _followLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    final p = _profile!;
    final isVerified = p['verification_status'] == 'verified';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: GacomColors.obsidian,
            actions: [
              if (_isOwnProfile) IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.go(AppConstants.settingsRoute)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: p['banner_url'] != null
                  ? CachedNetworkImage(imageUrl: p['banner_url'], fit: BoxFit.cover)
                  : Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [GacomColors.darkOrange.withOpacity(0.3), GacomColors.obsidian], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.deepOrange, width: 3)),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: GacomColors.border,
                          backgroundImage: p['avatar_url'] != null ? CachedNetworkImageProvider(p['avatar_url']) : null,
                          child: p['avatar_url'] == null ? Text((p['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 32)) : null,
                        ),
                      ),
                      const Spacer(),
                      if (!_isOwnProfile) ...[
                        GacomButton(label: _isFollowing ? 'FOLLOWING' : 'FOLLOW', width: 110, height: 40, isOutlined: _isFollowing, isLoading: _followLoading, onPressed: _toggleFollow),
                        const SizedBox(width: 8),
                        GacomButton(label: '', width: 40, height: 40, isOutlined: true, icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: GacomColors.deepOrange), onPressed: () {}),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text(p['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                    if (isVerified) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: GacomColors.deepOrange, size: 18)],
                  ]),
                  Text('@${p['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
                  if (p['gamer_tag'] != null) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.sports_esports_rounded, size: 14, color: GacomColors.deepOrange), const SizedBox(width: 4), Text(p['gamer_tag'], style: const TextStyle(color: GacomColors.deepOrange, fontSize: 13, fontWeight: FontWeight.w600))])],
                  if (p['bio'] != null) ...[const SizedBox(height: 10), Text(p['bio'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.5))],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatItem(value: '${p['posts_count'] ?? 0}', label: 'Posts'),
                      const SizedBox(width: 24),
                      _StatItem(value: '${p['followers_count'] ?? 0}', label: 'Followers'),
                      const SizedBox(width: 24),
                      _StatItem(value: '${p['following_count'] ?? 0}', label: 'Following'),
                      const SizedBox(width: 24),
                      _StatItem(value: '${p['competitions_won'] ?? 0}', label: 'Wins', color: GacomColors.warning),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(controller: _tab, indicatorColor: GacomColors.deepOrange, labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13), tabs: const [Tab(text: 'POSTS'), Tab(text: 'CLIPS')]),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _PostsGrid(posts: _posts.where((p) => p['post_type'] != 'clip').toList()),
            _PostsGrid(posts: _posts.where((p) => p['post_type'] == 'clip').toList()),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color? color;
  const _StatItem({required this.value, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: color ?? GacomColors.textPrimary)),
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
    ]);
  }
}

class _PostsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _PostsGrid({required this.posts});
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const Center(child: Text('No posts yet.', style: TextStyle(color: GacomColors.textMuted)));
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final p = posts[i];
        final mediaUrls = p['media_urls'] as List? ?? [];
        return ClipRRect(
          child: Container(
            color: GacomColors.cardDark,
            child: mediaUrls.isNotEmpty
                ? CachedNetworkImage(imageUrl: p['thumbnail_url'] ?? mediaUrls.first, fit: BoxFit.cover)
                : const Icon(Icons.text_snippet_outlined, color: GacomColors.textMuted),
          ),
        );
      },
    );
  }
}
