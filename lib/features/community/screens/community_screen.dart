import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _allCommunities = [];
  List<Map<String, dynamic>> _myCommunities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUserId;
    try {
      final all = await SupabaseService.client
          .from('communities')
          .select('*, created_by_profile:profiles!created_by(display_name, avatar_url)')
          .eq('is_active', true)
          .isFilter('parent_id', null)
          .order('members_count', ascending: false)
          .limit(30);
      List<Map<String, dynamic>> mine = [];
      if (userId != null) {
        mine = await SupabaseService.client
            .from('community_members')
            .select('community:communities(*)')
            .eq('user_id', userId)
            .limit(20)
            .then((v) => List<Map<String, dynamic>>.from(v.map((e) => e['community'])));
      }
      if (mounted) setState(() { _allCommunities = List<Map<String, dynamic>>.from(all); _myCommunities = mine; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('COMMUNITIES'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY COMMUNITIES')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CommunityList(communities: _allCommunities, loading: _loading, onRefresh: _load),
          _CommunityList(communities: _myCommunities, loading: _loading, onRefresh: _load, emptyMessage: 'You haven\'t joined any communities yet.'),
        ],
      ),
    );
  }
}

class _CommunityList extends StatelessWidget {
  final List<Map<String, dynamic>> communities;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String? emptyMessage;
  const _CommunityList({required this.communities, required this.loading, required this.onRefresh, this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (communities.isEmpty) return Center(child: Text(emptyMessage ?? 'No communities found.', style: const TextStyle(color: GacomColors.textMuted)));
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: communities.length,
        itemBuilder: (_, i) => _CommunityCard(community: communities[i]).animate(delay: (i * 60).ms).fadeIn().slideY(begin: 0.2, end: 0),
      ),
    );
  }
}

class _CommunityCard extends ConsumerWidget {
  final Map<String, dynamic> community;
  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = community['members_count'] ?? 0;
    final isPaid = community['is_paid_entry'] == true;
    final entryFee = (community['entry_fee'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () => context.go('/communities/${community['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GacomColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: community['icon_url'] != null
                  ? CachedNetworkImage(imageUrl: community['icon_url'], width: 60, height: 60, fit: BoxFit.cover)
                  : Container(
                      width: 60, height: 60,
                      decoration: const BoxDecoration(gradient: GacomColors.orangeGradient),
                      child: Center(child: Text((community['name'] ?? 'G')[0], style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(community['name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(community['game_name'] ?? '', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.people_outline_rounded, size: 13, color: GacomColors.textMuted),
                    const SizedBox(width: 4),
                    Text('$members members', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                    if (isPaid) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: GacomColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.warning.withOpacity(0.3))),
                        child: Text('₦${entryFee.toStringAsFixed(0)}', style: const TextStyle(color: GacomColors.warning, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Rajdhani')),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
          ],
        ),
      ),
    );
  }
}
