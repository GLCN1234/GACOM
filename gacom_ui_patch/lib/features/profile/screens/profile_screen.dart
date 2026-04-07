import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  late TabController _tab;

  bool get _isOwnProfile => SupabaseService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .single();
      final posts = await SupabaseService.client
          .from('posts')
          .select('*')
          .eq('author_id', widget.userId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(30);
      bool isFollowing = false;
      final myId = SupabaseService.currentUserId;
      if (myId != null && !_isOwnProfile) {
        final check = await SupabaseService.client
            .from('follows')
            .select('id')
            .eq('follower_id', myId)
            .eq('following_id', widget.userId)
            .maybeSingle();
        isFollowing = check != null;
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _posts = List<Map<String, dynamic>>.from(posts);
          _isFollowing = isFollowing;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await SupabaseService.client
            .from('follows')
            .delete()
            .eq('follower_id', myId)
            .eq('following_id', widget.userId);
      } else {
        await SupabaseService.client.from('follows').insert({
          'follower_id': myId,
          'following_id': widget.userId,
        });
      }
      if (mounted) setState(() { _isFollowing = !_isFollowing; _followLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: Center(child: _LoadingIndicator()),
      );
    }
    final p = _profile!;
    final isVerified = p['verification_status'] == 'verified';
    final verPending = p['verification_status'] == 'pending';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverHeader(p, isVerified, verPending),
        ],
        body: _buildTabBody(),
      ),
    );
  }

  Widget _buildSliverHeader(Map<String, dynamic> p, bool isVerified, bool verPending) {
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      stretch: true,
      backgroundColor: GacomColors.obsidian,
      actions: [
        if (_isOwnProfile) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditProfileSheet(context, p),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => context.go(AppConstants.settingsRoute),
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          children: [
            // Banner
            _BannerImage(bannerUrl: p['banner_url']),

            // Bottom gradient fade
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, GacomColors.obsidian],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Profile info overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar
                        _GlowAvatar(
                          avatarUrl: p['avatar_url'],
                          displayName: p['display_name'] ?? 'G',
                          isVerified: isVerified,
                        ),
                        const Spacer(),
                        // Action buttons
                        if (!_isOwnProfile) ...[
                          _CircleIconBtn(
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _FollowButton(
                            isFollowing: _isFollowing,
                            isLoading: _followLoading,
                            onTap: _toggleFollow,
                          ),
                        ],
                        if (_isOwnProfile)
                          _OutlineBtn(
                            label: 'Edit Profile',
                            onTap: () => _showEditProfileSheet(context, p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Name row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          p['display_name'] ?? '',
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: GacomColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          _VerifiedBadge(),
                        ],
                        if (verPending) ...[
                          const SizedBox(width: 6),
                          _PendingBadge(),
                        ],
                      ],
                    ),
                    Text(
                      '@${p['username'] ?? ''}',
                      style: const TextStyle(color: GacomColors.textMuted, fontSize: 13, letterSpacing: 0.3),
                    ),
                    if (p['gamer_tag'] != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: GacomColors.deepOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: GacomColors.borderOrange, width: 0.8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.sports_esports_rounded, size: 12, color: GacomColors.deepOrange),
                            const SizedBox(width: 4),
                            Text(p['gamer_tag'], style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          ]),
                        ),
                      ]),
                    ],
                    if (p['bio'] != null) ...[
                      const SizedBox(height: 10),
                      Text(p['bio'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.5, fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
                    // Stats row
                    _StatsRow(p: p),
                    const SizedBox(height: 16),

                    // Verification CTA for own profile
                    if (_isOwnProfile && p['verification_status'] == 'unverified') ...[
                      _VerifyCta(onTap: () => context.go(AppConstants.settingsRoute + '/verify')),
                      const SizedBox(height: 12),
                    ],

                    // Tab bar
                    TabBar(
                      controller: _tab,
                      tabs: const [
                        Tab(text: 'POSTS'),
                        Tab(text: 'CLIPS'),
                        Tab(text: 'WINS'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    return TabBarView(
      controller: _tab,
      children: [
        _PostsGrid(posts: _posts.where((p) => p['post_type'] != 'clip').toList()),
        _PostsGrid(posts: _posts.where((p) => p['post_type'] == 'clip').toList(), isClips: true),
        _WinsTab(userId: widget.userId),
      ],
    );
  }

  void _showEditProfileSheet(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: p, onSaved: _load),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.block_outlined, color: GacomColors.error),
            title: const Text('Block User', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.report_gmailerrorred_outlined, color: GacomColors.textSecondary),
            title: const Text('Report Profile', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Sub-Widgets ────────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(
        color: GacomColors.deepOrange,
        strokeWidth: 2,
      ),
    );
  }
}

class _BannerImage extends StatelessWidget {
  final String? bannerUrl;
  const _BannerImage({this.bannerUrl});

  @override
  Widget build(BuildContext context) {
    if (bannerUrl != null) {
      return SizedBox.expand(
        child: CachedNetworkImage(imageUrl: bannerUrl!, fit: BoxFit.cover),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0800), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GacomColors.deepOrange.withOpacity(0.06)
      ..strokeWidth = 0.5;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Glow center
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [GacomColors.deepOrange.withOpacity(0.2), Colors.transparent],
        radius: 0.6,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GlowAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final bool isVerified;
  const _GlowAvatar({this.avatarUrl, required this.displayName, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isVerified
            ? [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isVerified ? GacomColors.orangeGradient : null,
          color: isVerified ? null : GacomColors.border,
        ),
        child: CircleAvatar(
          radius: 44,
          backgroundColor: GacomColors.surfaceDark,
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 32, fontFamily: 'Rajdhani'),
                )
              : null,
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: GacomColors.orangeGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.3), blurRadius: 8)],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded, size: 11, color: Colors.white),
        SizedBox(width: 3),
        Text('VERIFIED', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
      ]),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: GacomColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GacomColors.warning.withOpacity(0.4), width: 0.8),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule_rounded, size: 11, color: GacomColors.warning),
        SizedBox(width: 3),
        Text('PENDING', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 9, fontWeight: FontWeight.w700, color: GacomColors.warning, letterSpacing: 0.8)),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> p;
  const _StatsRow({required this.p});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(value: '${p['posts_count'] ?? 0}', label: 'Posts'),
        const SizedBox(width: 4),
        _StatDivider(),
        const SizedBox(width: 4),
        _StatBox(value: _fmt(p['followers_count'] ?? 0), label: 'Followers'),
        const SizedBox(width: 4),
        _StatDivider(),
        const SizedBox(width: 4),
        _StatBox(value: _fmt(p['following_count'] ?? 0), label: 'Following'),
        const SizedBox(width: 4),
        _StatDivider(),
        const SizedBox(width: 4),
        _StatBox(value: '${p['competitions_won'] ?? 0}', label: 'Wins', valueColor: GacomColors.warning),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color? valueColor;
  const _StatBox({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: valueColor ?? GacomColors.textPrimary)),
        Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 0.3)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: GacomColors.border);
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing, isLoading;
  final VoidCallback onTap;
  const _FollowButton({required this.isFollowing, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: isFollowing
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: GacomColors.deepOrange, width: 1.5),
              )
            : BoxDecoration(
                gradient: GacomColors.orangeGradient,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
        child: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange))
            : Text(
                isFollowing ? 'FOLLOWING' : 'FOLLOW',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: isFollowing ? GacomColors.deepOrange : Colors.white,
                ),
              ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: GacomColors.borderBright, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8, color: GacomColors.textPrimary),
        ),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GacomColors.borderBright, width: 1),
          color: GacomColors.surfaceDark,
        ),
        child: Icon(icon, size: 18, color: GacomColors.textSecondary),
      ),
    );
  }
}

class _VerifyCta extends StatelessWidget {
  final VoidCallback onTap;
  const _VerifyCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: GacomColors.deepOrange.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GacomColors.borderOrange, width: 0.8),
        ),
        child: Row(children: [
          const Icon(Icons.verified_outlined, color: GacomColors.deepOrange, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Get Verified', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
              Text('Build trust · Get the orange badge', style: TextStyle(fontSize: 11, color: GacomColors.textMuted)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: GacomColors.textMuted),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0);
  }
}

class _PostsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isClips;
  const _PostsGrid({required this.posts, this.isClips = false});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isClips ? Icons.play_circle_outline_rounded : Icons.image_outlined, size: 56, color: GacomColors.border),
            const SizedBox(height: 12),
            Text('No ${isClips ? 'clips' : 'posts'} yet', style: const TextStyle(color: GacomColors.textMuted, fontSize: 15)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: isClips ? 9 / 16 : 1,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final p = posts[i];
        final mediaUrls = p['media_urls'] as List? ?? [];
        return ClipRRect(
          child: Container(
            color: GacomColors.cardDark,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (mediaUrls.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: p['thumbnail_url'] ?? mediaUrls.first,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: GacomColors.border),
                  )
                else
                  const Icon(Icons.article_outlined, color: GacomColors.textMuted),
                if (isClips)
                  Positioned(
                    bottom: 6, left: 6,
                    child: Row(children: const [
                      Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 14),
                    ]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WinsTab extends StatefulWidget {
  final String userId;
  const _WinsTab({required this.userId});

  @override
  State<_WinsTab> createState() => _WinsTabState();
}

class _WinsTabState extends State<_WinsTab> {
  List<Map<String, dynamic>> _wins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wins = await SupabaseService.client
          .from('competition_results')
          .select('*, competition:competitions(title, game_name, banner_url, ends_at)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _wins = List<Map<String, dynamic>>.from(wins); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange, strokeWidth: 2));
    if (_wins.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.emoji_events_outlined, size: 56, color: GacomColors.border),
        SizedBox(height: 12),
        Text('No wins yet — enter a competition!', style: TextStyle(color: GacomColors.textMuted)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _wins.length,
      itemBuilder: (_, i) {
        final w = _wins[i];
        final comp = w['competition'] as Map<String, dynamic>? ?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: w['rank'] == 1 ? GacomColors.warning.withOpacity(0.4) : GacomColors.border, width: 0.8),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: w['rank'] == 1 ? GacomColors.warning.withOpacity(0.12) : GacomColors.surfaceDark,
              ),
              child: Center(
                child: Text(
                  '#${w['rank']}',
                  style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: w['rank'] == 1 ? GacomColors.warning : GacomColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(comp['title'] ?? 'Competition', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
              Text(comp['game_name'] ?? '', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            ])),
            if ((w['prize_amount'] as num? ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('₦${w['prize_amount']}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.success, fontSize: 14)),
              ),
          ]),
        ).animate(delay: (i * 60).ms).fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }
}

// ─── Edit Profile Sheet ─────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.profile, required this.onSaved});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _gamerTagCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _websiteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p['display_name'] ?? '');
    _bioCtrl = TextEditingController(text: p['bio'] ?? '');
    _gamerTagCtrl = TextEditingController(text: p['gamer_tag'] ?? '');
    _locationCtrl = TextEditingController(text: p['location'] ?? '');
    _websiteCtrl = TextEditingController(text: p['website'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _bioCtrl.dispose(); _gamerTagCtrl.dispose();
    _locationCtrl.dispose(); _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('profiles').update({
        'display_name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'gamer_tag': _gamerTagCtrl.text.trim().isEmpty ? null : _gamerTagCtrl.text.trim(),
        'location': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      }).eq('id', userId);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        GacomSnackbar.show(context, 'Profile updated!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        GacomSnackbar.show(context, 'Failed to update profile', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: const BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Edit Profile', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: GacomColors.textMuted)),
                ]),
                const SizedBox(height: 24),
                _Field(controller: _nameCtrl, label: 'Display Name', icon: Icons.person_outline),
                const SizedBox(height: 14),
                _Field(controller: _bioCtrl, label: 'Bio', icon: Icons.info_outline, maxLines: 3),
                const SizedBox(height: 14),
                _Field(controller: _gamerTagCtrl, label: 'Gamer Tag', icon: Icons.sports_esports_outlined),
                const SizedBox(height: 14),
                _Field(controller: _locationCtrl, label: 'Location', icon: Icons.location_on_outlined),
                const SizedBox(height: 14),
                _Field(controller: _websiteCtrl, label: 'Website', icon: Icons.link_rounded),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: GacomColors.orangeGradient,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('SAVE CHANGES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _Field({required this.controller, required this.label, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: GacomColors.textMuted, size: 18),
      ),
    );
  }
}
