import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

// Demo profile used when Supabase returns nothing
final _demoProfile = {
  'id': 'demo',
  'display_name': 'Ghost Striker',
  'username': 'ghost_striker99',
  'gamer_tag': 'GhostXPRO',
  'bio': 'Top 1% PUBG Mobile player 🔥 | Nigeria #1 | Content Creator | DM for sponsorships',
  'avatar_url': null,
  'banner_url': null,
  'verification_status': 'verified',
  'posts_count': 247,
  'followers_count': 12840,
  'following_count': 389,
  'competitions_won': 34,
  'wallet_balance': 45200.0,
  'rank': 'Diamond',
  'win_rate': 68.4,
  'global_rank': 142,
};

final _demoAchievements = [
  {'icon': Icons.emoji_events_rounded, 'label': 'Champion', 'color': 0xFFFFD700},
  {'icon': Icons.military_tech_rounded, 'label': 'Top 1%', 'color': 0xFFE84B00},
  {'icon': Icons.local_fire_department_rounded, 'label': '30-Win Streak', 'color': 0xFFFF5A1F},
  {'icon': Icons.star_rounded, 'label': 'Verified', 'color': 0xFF0095FF},
  {'icon': Icons.shield_rounded, 'label': 'Veteran', 'color': 0xFF00D68F},
];

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

  bool get _isOwn => SupabaseService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SupabaseService.client
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
          .limit(20);
      bool following = false;
      final myId = SupabaseService.currentUserId;
      if (myId != null && !_isOwn) {
        final chk = await SupabaseService.client
            .from('follows')
            .select('id')
            .eq('follower_id', myId)
            .eq('following_id', widget.userId)
            .maybeSingle();
        following = chk != null;
      }
      if (mounted) {
        setState(() {
          _profile = p;
          _posts = List<Map<String, dynamic>>.from(posts);
          _isFollowing = following;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(_demoProfile);
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    setState(() => _followLoading = true);
    try {
      _isFollowing
          ? await SupabaseService.client.from('follows').delete().eq('follower_id', myId).eq('following_id', widget.userId)
          : await SupabaseService.client.from('follows').insert({'follower_id': myId, 'following_id': widget.userId});
      if (mounted) setState(() { _isFollowing = !_isFollowing; _followLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)),
      );
    }

    final p = _profile!;
    final verified = p['verification_status'] == 'verified';
    final rank = p['rank'] as String? ?? 'Bronze';
    final winRate = (p['win_rate'] as num?)?.toDouble() ?? 0;
    final globalRank = p['global_rank'] ?? 0;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Banner + Avatar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: GacomColors.obsidian,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (_isOwn)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.settings_outlined, size: 18, color: Colors.white),
                  ),
                  onPressed: () => context.go(AppConstants.settingsRoute),
                ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner
                  p['banner_url'] != null
                      ? CachedNetworkImage(imageUrl: p['banner_url'], fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [GacomColors.darkOrange.withOpacity(0.5), GacomColors.obsidian],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CustomPaint(painter: _GridPainter()),
                        ),
                  // Overlay scrim
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, GacomColors.obsidian.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Rank badge top-right
                  Positioned(
                    top: 60,
                    right: 20,
                    child: _RankBadge(rank: rank),
                  ),
                ],
              ),
            ),
          ),

          // ── Profile info ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: GacomColors.deepOrange, width: 3),
                            boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 20)],
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: GacomColors.border,
                            backgroundImage: p['avatar_url'] != null
                                ? CachedNetworkImageProvider(p['avatar_url'])
                                : null,
                            child: p['avatar_url'] == null
                                ? Text((p['display_name'] ?? 'G')[0],
                                    style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 36))
                                : null,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!_isOwn) ...[
                        GacomButton(
                          label: _isFollowing ? 'FOLLOWING' : 'FOLLOW',
                          width: 110, height: 40,
                          isOutlined: _isFollowing,
                          isLoading: _followLoading,
                          onPressed: _toggleFollow,
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: GacomColors.deepOrange, width: 1.2),
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded,
                                size: 16, color: GacomColors.deepOrange),
                          ),
                        ),
                      ] else
                        GacomButton(
                          label: 'EDIT PROFILE', width: 130, height: 40,
                          isOutlined: true,
                          onPressed: () => GacomSnackbar.show(context, 'Edit profile coming soon'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Name + verify
                  Row(children: [
                    Text(p['display_name'] ?? '',
                        style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GacomColors.deepOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.verified_rounded, size: 11, color: GacomColors.deepOrange),
                          SizedBox(width: 3),
                          Text('VERIFIED', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 9, fontWeight: FontWeight.w800, color: GacomColors.deepOrange, letterSpacing: 0.5)),
                        ]),
                      ),
                    ],
                  ]),
                  Text('@${p['username'] ?? ''}',
                      style: const TextStyle(color: GacomColors.textMuted, fontSize: 13, fontFamily: 'Rajdhani')),

                  if (p['gamer_tag'] != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.sports_esports_rounded, size: 13, color: GacomColors.deepOrange),
                      const SizedBox(width: 5),
                      Text(p['gamer_tag'],
                          style: const TextStyle(color: GacomColors.deepOrange, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')),
                    ]),
                  ],

                  if (p['bio'] != null) ...[
                    const SizedBox(height: 10),
                    Text(p['bio'],
                        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5)),
                  ],

                  const SizedBox(height: 18),

                  // ── Stats row — FortDice style ───────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: GacomDecorations.glassCard(radius: 18),
                    child: Row(children: [
                      _Stat('${p['posts_count'] ?? 0}', 'Posts'),
                      _StatDiv(),
                      _Stat(_fmtCount(p['followers_count'] ?? 0), 'Followers'),
                      _StatDiv(),
                      _Stat(_fmtCount(p['following_count'] ?? 0), 'Following'),
                      _StatDiv(),
                      _Stat('${p['competitions_won'] ?? 0}', 'Wins',
                          color: GacomColors.warning),
                    ]),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 12),

                  // ── Performance row ──────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _PerfCard(
                          icon: Icons.leaderboard_rounded,
                          label: 'Global Rank',
                          value: '#$globalRank',
                          color: GacomColors.gold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PerfCard(
                          icon: Icons.analytics_rounded,
                          label: 'Win Rate',
                          value: '${winRate.toStringAsFixed(1)}%',
                          color: GacomColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PerfCard(
                          icon: Icons.emoji_events_rounded,
                          label: 'Trophies',
                          value: '${p['competitions_won'] ?? 0}',
                          color: GacomColors.deepOrange),
                    ),
                  ]).animate(delay: 150.ms).fadeIn(),

                  const SizedBox(height: 12),

                  // ── Achievements ─────────────────────────────────────────
                  const Text('Achievements',
                      style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _demoAchievements.map((a) => Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(a['color'] as int).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Color(a['color'] as int).withOpacity(0.3), width: 0.8),
                        ),
                        child: Row(children: [
                          Icon(a['icon'] as IconData, size: 14, color: Color(a['color'] as int)),
                          const SizedBox(width: 6),
                          Text(a['label'] as String,
                              style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: Color(a['color'] as int))),
                        ]),
                      )).toList(),
                    ),
                  ).animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 16),

                  // Tab bar
                  TabBar(
                    controller: _tab,
                    tabs: const [Tab(text: 'POSTS'), Tab(text: 'CLIPS'), Tab(text: 'STATS')],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _Grid(posts: _posts.where((x) => x['post_type'] != 'clip').toList()),
            _Grid(posts: _posts.where((x) => x['post_type'] == 'clip').toList()),
            _StatsTab(profile: p),
          ],
        ),
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Rank badge ────────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final String rank;
  const _RankBadge({required this.rank});

  Color get _color {
    switch (rank.toLowerCase()) {
      case 'diamond': return const Color(0xFF00BFFF);
      case 'platinum': return const Color(0xFF00D68F);
      case 'gold': return GacomColors.gold;
      default: return GacomColors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(50),
      border: Border.all(color: _color.withOpacity(0.5), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.diamond_rounded, size: 12, color: _color),
      const SizedBox(width: 5),
      Text(rank.toUpperCase(),
          style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: _color, letterSpacing: 1)),
    ]),
  );
}

// ── Grid ──────────────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _Grid({required this.posts});
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const Center(child: Text('No posts yet.', style: TextStyle(color: GacomColors.textMuted)));
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final urls = posts[i]['media_urls'] as List? ?? [];
        return ClipRRect(
          child: Container(
            color: GacomColors.cardDark,
            child: urls.isNotEmpty
                ? CachedNetworkImage(imageUrl: posts[i]['thumbnail_url'] ?? urls.first, fit: BoxFit.cover)
                : const Icon(Icons.text_snippet_outlined, color: GacomColors.textMuted),
          ),
        );
      },
    );
  }
}

// ── Stats tab — FortDice performance matrix feel ───────────────────────────────

class _StatsTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _StatsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final wins = profile['competitions_won'] ?? 34;
    final wr = (profile['win_rate'] as num?)?.toDouble() ?? 68.4;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatBlock('Combat Stats', [
          _StatLine('Kill/Death Ratio', '3.8', GacomColors.deepOrange),
          _StatLine('Avg Damage/Match', '842', GacomColors.warning),
          _StatLine('Headshot Rate', '44%', GacomColors.info),
          _StatLine('Survival Rate', '72%', GacomColors.success),
        ]).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 16),
        _StatBlock('Tournament Record', [
          _StatLine('Tournaments Entered', '51', GacomColors.textSecondary),
          _StatLine('Tournaments Won', '$wins', GacomColors.gold),
          _StatLine('Win Rate', '${wr.toStringAsFixed(1)}%', GacomColors.success),
          _StatLine('Total Earnings', '₦182,400', GacomColors.deepOrange),
        ]).animate().fadeIn(delay: 180.ms),
        const SizedBox(height: 16),
        _StatBlock('Engagement', [
          _StatLine('Total Posts', '${profile['posts_count'] ?? 247}', GacomColors.textSecondary),
          _StatLine('Total Followers', _fmtN(profile['followers_count'] ?? 12840), GacomColors.info),
          _StatLine('Profile Views', '48.2K', GacomColors.textSecondary),
        ]).animate().fadeIn(delay: 250.ms),
        const SizedBox(height: 80),
      ],
    );
  }

  String _fmtN(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatBlock extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _StatBlock(this.title, this.rows);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: GacomDecorations.glassCard(radius: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
      const SizedBox(height: 14),
      ...rows,
    ]),
  );
}

class _StatLine extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatLine(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13, fontFamily: 'Rajdhani')),
      const Spacer(),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: color)),
    ]),
  );
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value, label;
  final Color? color;
  const _Stat(this.value, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: color ?? GacomColors.textPrimary)),
    Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani')),
  ]));
}

class _StatDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 0.7, height: 30, color: GacomColors.border);
}

class _PerfCard extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _PerfCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.25), width: 0.8),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani'), textAlign: TextAlign.center),
    ]),
  );
}

// ── Decorative grid painter for banner fallback ───────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GacomColors.deepOrange.withOpacity(0.06)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}
