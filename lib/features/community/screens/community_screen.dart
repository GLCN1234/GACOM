import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() =>
      _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _allCommunities = [];
  List<Map<String, dynamic>> _myCommunities = [];
  bool _loading = true;
  bool _canCreateSub = false;

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
          .select(
              '*, created_by_profile:profiles!created_by(display_name, avatar_url)')
          .eq('is_active', true)
          .isFilter('parent_id', null)
          .order('members_count', ascending: false)
          .limit(30);

      List<Map<String, dynamic>> mine = [];
      if (userId != null) {
        final rows = await SupabaseService.client
            .from('community_members')
            .select('community:communities(*)')
            .eq('user_id', userId)
            .limit(20);
        mine = List<Map<String, dynamic>>.from(
            rows.map((e) => e['community']).whereType<Map<String, dynamic>>());

        // Check if user is verified or admin — can create sub-communities
        final profile = await SupabaseService.client
            .from('profiles')
            .select('verification_status, role')
            .eq('id', userId)
            .single();
        final verif =
            profile['verification_status'] as String? ?? 'unverified';
        final role = profile['role'] as String? ?? 'user';
        _canCreateSub = verif == 'verified' ||
            ['admin', 'super_admin'].contains(role);
      }

      if (mounted) {
        setState(() {
          _allCommunities =
              List<Map<String, dynamic>>.from(all);
          _myCommunities = mine;
          _loading = false;
        });
      }
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
          labelStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY GROUPS')],
        ),
      ),
      floatingActionButton: _canCreateSub
          ? FloatingActionButton.extended(
              backgroundColor: GacomColors.deepOrange,
              onPressed: () => _showCreateSubSheet(context),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Sub-Community',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700)),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: GacomColors.deepOrange))
          : TabBarView(
              controller: _tab,
              children: [
                _CommunityList(
                    communities: _allCommunities,
                    emptyMessage: 'No communities yet'),
                _CommunityList(
                    communities: _myCommunities,
                    emptyMessage: 'Join some communities!'),
              ],
            ),
    );
  }

  void _showCreateSubSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final gameCtrl = TextEditingController();
    String? selectedParentId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, scroll) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: ListView(controller: scroll, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: GacomColors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.group_add_rounded,
                      color: GacomColors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Create Sub-Community',
                        style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: GacomColors.textPrimary)),
                    Text('Verified users only',
                        style: TextStyle(
                            color: GacomColors.success,
                            fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              // Parent community selector
              const Text('Parent Community',
                  style: TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _allCommunities.length,
                  itemBuilder: (_, i) {
                    final c = _allCommunities[i];
                    final isSelected = selectedParentId == c['id'];
                    return GestureDetector(
                      onTap: () =>
                          setModal(() => selectedParentId = c['id']),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(10),
                        width: 140,
                        decoration: BoxDecoration(
                            color: isSelected
                                ? GacomColors.deepOrange.withOpacity(0.15)
                                : GacomColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSelected
                                    ? GacomColors.deepOrange
                                    : GacomColors.border)),
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                          Text(c['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isSelected
                                      ? GacomColors.deepOrange
                                      : GacomColors.textPrimary,
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(c['game_name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: GacomColors.textMuted,
                                  fontSize: 11)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              GacomTextField(
                  controller: nameCtrl,
                  label: 'Sub-Community Name',
                  hint: 'e.g. PUBG Nigeria Ranked',
                  prefixIcon: Icons.group_rounded),
              const SizedBox(height: 12),
              GacomTextField(
                  controller: gameCtrl,
                  label: 'Game',
                  hint: 'e.g. PUBG Mobile',
                  prefixIcon: Icons.sports_esports_rounded),
              const SizedBox(height: 12),
              GacomTextField(
                  controller: descCtrl,
                  label: 'Description',
                  hint: 'What is this sub-community about?',
                  prefixIcon: Icons.description_rounded,
                  maxLines: 3),
              const SizedBox(height: 24),
              GacomButton(
                label: 'CREATE SUB-COMMUNITY',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      gameCtrl.text.trim().isEmpty) {
                    GacomSnackbar.show(ctx, 'Name and game required',
                        isError: true);
                    return;
                  }
                  try {
                    final slug = nameCtrl.text
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9]'), '-');
                    await SupabaseService.client
                        .from('communities')
                        .insert({
                      'name': nameCtrl.text.trim(),
                      'slug':
                          '$slug-${DateTime.now().millisecondsSinceEpoch}',
                      'game_name': gameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'parent_id': selectedParentId,
                      'created_by': SupabaseService.currentUserId,
                      'is_admin_created': false,
                      'is_active': true,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      GacomSnackbar.show(context,
                          'Sub-community created! 🎮',
                          isSuccess: true);
                      setState(() => _loading = true);
                      await _load();
                    }
                  } catch (e) {
                    GacomSnackbar.show(ctx, 'Failed. Try again.',
                        isError: true);
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CommunityList extends StatelessWidget {
  final List<Map<String, dynamic>> communities;
  final String emptyMessage;
  const _CommunityList(
      {required this.communities, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.groups_rounded,
                size: 64, color: GacomColors.border),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: const TextStyle(
                    color: GacomColors.textMuted, fontSize: 16)),
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: communities.length,
      itemBuilder: (_, i) =>
          _CommunityCard(community: communities[i])
              .animate(delay: (i * 50).ms)
              .fadeIn()
              .slideY(begin: 0.2, end: 0),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Map<String, dynamic> community;
  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    final members = community['members_count'] as int? ?? 0;
    final isParent = community['parent_id'] == null;
    return GestureDetector(
      onTap: () => context.push('/communities/${community['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: GacomColors.orangeGradient),
            child: community['icon_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                        imageUrl: community['icon_url'],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.groups_rounded,
                                color: Colors.white)))
                : const Icon(Icons.groups_rounded,
                    color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(children: [
              Expanded(
                child: Text(community['name'] ?? '',
                    style: const TextStyle(
                        color: GacomColors.textPrimary,
                        fontFamily: 'Rajdhani',
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              if (!isParent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: GacomColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: GacomColors.info.withOpacity(0.3))),
                  child: const Text('SUB',
                      style: TextStyle(
                          color: GacomColors.info,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 2),
            Text(community['game_name'] ?? '',
                style: const TextStyle(
                    color: GacomColors.deepOrange,
                    fontSize: 12,
                    fontFamily: 'Rajdhani')),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.people_rounded,
                  size: 13, color: GacomColors.textMuted),
              const SizedBox(width: 4),
              Text('$members members',
                  style: const TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded,
              color: GacomColors.textMuted),
        ]),
      ),
    );
  }
}
