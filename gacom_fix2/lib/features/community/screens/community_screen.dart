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
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
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

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // FIX: check create permission FIRST, independently — so a communities query
    // failure doesn't silently prevent the FAB from appearing
    await _checkCreatePermission();

    try {
      final all = await SupabaseService.client
          .from('communities')
          .select('id, name, slug, game_name, description, banner_url, icon_url, members_count, parent_id, is_active, created_by')
          .eq('is_active', true)
          .isFilter('parent_id', null)
          .order('members_count', ascending: false)
          .limit(30);

      List<Map<String, dynamic>> mine = [];
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        try {
          final rows = await SupabaseService.client
              .from('community_members')
              .select('community_id, communities(id, name, game_name, icon_url, members_count, parent_id, is_active)')
              .eq('user_id', userId)
              .limit(30);

          mine = (rows as List)
              .map((e) => e['communities'])
              .whereType<Map<String, dynamic>>()
              .where((c) => c['is_active'] == true)
              .toList();
        } catch (_) {
          // My communities failed — not critical, just show empty
        }
      }

      if (mounted) {
        setState(() {
          _allCommunities = List<Map<String, dynamic>>.from(all);
          _myCommunities = mine;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Separated so it never gets swallowed by the communities query try-catch
  Future<void> _checkCreatePermission() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('verification_status, role')
          .eq('id', userId)
          .single();
      final verif = profile['verification_status'] as String? ?? 'unverified';
      final role = profile['role'] as String? ?? 'user';
      if (mounted) {
        setState(() {
          _canCreateSub = verif == 'verified' ||
              ['admin', 'super_admin', 'exco'].contains(role);
        });
      }
    } catch (_) {
      // Can't determine — default false (safe)
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
          labelColor: GacomColors.deepOrange,
          unselectedLabelColor: GacomColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY GROUPS')],
        ),
      ),
      // FIX: FAB is shown for verified users + admins.
      // Also added a fallback info button so unverified users know what to do.
      floatingActionButton: _canCreateSub
          ? FloatingActionButton.extended(
              backgroundColor: GacomColors.deepOrange,
              onPressed: () => _showCreateSubSheet(context),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Sub-Community',
                  style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
            )
          : FloatingActionButton.extended(
              backgroundColor: GacomColors.cardDark,
              onPressed: () => GacomSnackbar.show(
                context,
                '🔒 Get verified to create sub-communities. Go to Settings → Verification.',
              ),
              icon: const Icon(Icons.lock_outline_rounded, color: GacomColors.textMuted, size: 18),
              label: const Text('Get Verified',
                  style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: _load,
              child: TabBarView(
                controller: _tab,
                children: [
                  _CommunityList(
                    communities: _allCommunities,
                    emptyMessage: 'No communities yet',
                  ),
                  _CommunityList(
                    communities: _myCommunities,
                    emptyMessage: 'Join some communities first!',
                  ),
                ],
              ),
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
          initialChildSize: 0.88,
          builder: (_, scroll) => Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: ListView(controller: scroll, children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GacomColors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_add_rounded, color: GacomColors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Create Sub-Community',
                      style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  Text('Verified users only',
                      style: TextStyle(color: GacomColors.success, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 20),

              // Parent community picker
              const Text('PARENT COMMUNITY',
                  style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              if (_allCommunities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No communities available', style: TextStyle(color: GacomColors.textMuted)),
                )
              else
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _allCommunities.length,
                    itemBuilder: (_, i) {
                      final c = _allCommunities[i];
                      final sel = selectedParentId == c['id'];
                      return GestureDetector(
                        onTap: () => setModal(() => selectedParentId = c['id'] as String?),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border),
                          ),
                          child: Text(c['name'] as String? ?? '',
                              style: TextStyle(
                                color: sel ? GacomColors.deepOrange : GacomColors.textSecondary,
                                fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13,
                              )),
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
                prefixIcon: Icons.group_rounded,
              ),
              const SizedBox(height: 12),
              GacomTextField(
                controller: gameCtrl,
                label: 'Game',
                hint: 'e.g. PUBG Mobile',
                prefixIcon: Icons.sports_esports_rounded,
              ),
              const SizedBox(height: 12),
              GacomTextField(
                controller: descCtrl,
                label: 'Description',
                hint: 'What is this sub-community about?',
                prefixIcon: Icons.description_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              GacomButton(
                label: 'CREATE SUB-COMMUNITY',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || gameCtrl.text.trim().isEmpty) {
                    GacomSnackbar.show(ctx, 'Name and game are required', isError: true);
                    return;
                  }
                  try {
                    final slug = nameCtrl.text
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9]'), '-');
                    await SupabaseService.client.from('communities').insert({
                      'name': nameCtrl.text.trim(),
                      'slug': '$slug-${DateTime.now().millisecondsSinceEpoch}',
                      'game_name': gameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'parent_id': selectedParentId,
                      'created_by': SupabaseService.currentUserId,
                      'is_admin_created': false,
                      'is_active': true,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      GacomSnackbar.show(context, 'Sub-community created! 🎮', isSuccess: true);
                      await _load();
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      GacomSnackbar.show(ctx, 'Failed: ${e.toString()}', isError: true);
                    }
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

// ── Community list ────────────────────────────────────────────────────────────

class _CommunityList extends StatelessWidget {
  final List<Map<String, dynamic>> communities;
  final String emptyMessage;
  const _CommunityList({required this.communities, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.groups_rounded, size: 64, color: GacomColors.border),
        const SizedBox(height: 16),
        Text(emptyMessage, style: const TextStyle(color: GacomColors.textMuted, fontSize: 16)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: communities.length,
      itemBuilder: (_, i) => _CommunityCard(community: communities[i])
          .animate(delay: (i * 50).ms)
          .fadeIn()
          .slideY(begin: 0.15, end: 0),
    );
  }
}

// ── Community card ────────────────────────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final Map<String, dynamic> community;
  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    final members = community['members_count'] as int? ?? 0;
    final isSub = community['parent_id'] != null;

    return GestureDetector(
      onTap: () => context.push('/communities/${community['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GacomColors.border, width: 0.5),
        ),
        child: Row(children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: GacomColors.orangeGradient,
            ),
            child: community['icon_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: community['icon_url'],
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.groups_rounded, color: Colors.white),
                    ),
                  )
                : const Icon(Icons.groups_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(community['name'] ?? '',
                      style: const TextStyle(
                          color: GacomColors.textPrimary,
                          fontFamily: 'Rajdhani',
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                if (isSub)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GacomColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GacomColors.info.withOpacity(0.3)),
                    ),
                    child: const Text('SUB',
                        style: TextStyle(color: GacomColors.info, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(community['game_name'] ?? '',
                  style: const TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontFamily: 'Rajdhani')),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.people_rounded, size: 13, color: GacomColors.textMuted),
                const SizedBox(width: 4),
                Text('$members members',
                    style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
        ]),
      ),
    );
  }
}
