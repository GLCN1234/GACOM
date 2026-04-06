import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gacom_widgets.dart';
import '../../models/competition_model.dart';
import '../../services/supabase_service.dart';
import 'competition_detail_screen.dart';

final competitionsProvider = FutureProvider.family<List<CompetitionModel>, String?>((ref, status) async {
  final data = await SupabaseService.getCompetitions(status: status);
  return data.map((c) => CompetitionModel.fromJson(c)).toList();
});

class CompetitionsScreen extends ConsumerStatefulWidget {
  const CompetitionsScreen({super.key});
  @override
  ConsumerState<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends ConsumerState<CompetitionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['All', 'Live', 'Upcoming', 'Ended'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: GacomColors.background,
            pinned: true,
            title: Text('COMPETITIONS', style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
            actions: [
              IconButton(icon: const Icon(Icons.filter_list, color: GacomColors.textSecondary), onPressed: () {}),
              IconButton(icon: const Icon(Icons.search, color: GacomColors.textSecondary), onPressed: () {}),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: GacomColors.primary,
              indicatorWeight: 3,
              labelColor: GacomColors.primary,
              unselectedLabelColor: GacomColors.textMuted,
              labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _CompetitionList(status: null),
            _CompetitionList(status: 'live'),
            _CompetitionList(status: 'upcoming'),
            _CompetitionList(status: 'ended'),
          ],
        ),
      ),
    );
  }
}

class _CompetitionList extends ConsumerWidget {
  final String? status;
  const _CompetitionList({this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionsAsync = ref.watch(competitionsProvider(status));
    return competitionsAsync.when(
      data: (competitions) {
        if (competitions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, color: GacomColors.textMuted, size: 60),
                const SizedBox(height: 16),
                Text('No competitions yet', style: GoogleFonts.rajdhani(color: GacomColors.textSecondary, fontSize: 18)),
              ],
            ),
          );
        }
        // Featured (first item big)
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: competitions.length,
          itemBuilder: (_, i) => CompetitionCard(
            competition: competitions[i],
            featured: i == 0,
          ).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideY(begin: 0.1, end: 0),
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => const _CompetitionSkeleton(),
      ),
      error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.outfit(color: GacomColors.error))),
    );
  }
}

class CompetitionCard extends StatelessWidget {
  final CompetitionModel competition;
  final bool featured;
  const CompetitionCard({super.key, required this.competition, this.featured = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompetitionDetailScreen(competitionId: competition.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: GacomColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: competition.status == CompetitionStatus.live ? GacomColors.primary.withOpacity(0.4) : GacomColors.cardBorder),
          boxShadow: competition.status == CompetitionStatus.live
              ? [BoxShadow(color: GacomColors.primary.withOpacity(0.15), blurRadius: 20)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  competition.bannerUrl != null
                      ? CachedNetworkImage(imageUrl: competition.bannerUrl!, width: double.infinity, height: featured ? 200 : 140, fit: BoxFit.cover)
                      : Container(
                          height: featured ? 200 : 140,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF1A0A00), Color(0xFF2D1500)]),
                          ),
                          child: Center(child: Icon(Icons.sports_esports, color: GacomColors.primary.withOpacity(0.4), size: 60)),
                        ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StatusBadge(status: competition.status),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: PrizeBadge(amount: competition.prizePool),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GacomBadge(text: competition.game),
                      const SizedBox(width: 8),
                      if (!competition.isFree) GacomBadge(text: '₦${competition.entryFee} Entry', color: GacomColors.warning),
                      if (competition.isFree) const GacomBadge(text: 'FREE', color: GacomColors.success),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(competition.title, style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatChip(icon: Icons.people, value: '${competition.currentParticipants}/${competition.maxParticipants}'),
                      const SizedBox(width: 16),
                      StatChip(
                        icon: Icons.calendar_today_outlined,
                        value: DateFormat('dd MMM yyyy').format(competition.startDate),
                      ),
                      const Spacer(),
                      // Progress bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${((competition.currentParticipants / competition.maxParticipants) * 100).toInt()}% full',
                            style: GoogleFonts.outfit(color: GacomColors.textMuted, fontSize: 10)),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: competition.currentParticipants / competition.maxParticipants,
                                backgroundColor: GacomColors.cardBorder,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  competition.currentParticipants / competition.maxParticipants > 0.8
                                      ? GacomColors.error : GacomColors.primary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _StatusBadge extends StatelessWidget {
  final CompetitionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      CompetitionStatus.live => ('● LIVE', GacomColors.error),
      CompetitionStatus.upcoming => ('UPCOMING', GacomColors.warning),
      CompetitionStatus.ended => ('ENDED', GacomColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: GoogleFonts.rajdhani(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
    );
  }
}

class _CompetitionSkeleton extends StatelessWidget {
  const _CompetitionSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        GacomShimmer(height: 140, width: double.infinity, borderRadius: 20),
        const SizedBox(height: 8),
        GacomShimmer(height: 60, width: double.infinity, borderRadius: 12),
      ]),
    );
  }
}
