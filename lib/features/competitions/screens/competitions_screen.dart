import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class CompetitionsScreen extends ConsumerStatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  ConsumerState<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends ConsumerState<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _competitions = [];
  bool _loading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCompetitions();
  }

  Future<void> _loadCompetitions() async {
    try {
      final data = await SupabaseService.client
          .from('competitions')
          .select('''
            *,
            created_by_profile:profiles!created_by(username, display_name, avatar_url),
            community:communities(name, icon_url)
          ''')
          .order('starts_at', ascending: true)
          .limit(30);
      if (mounted) setState(() { _competitions = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 'all') return _competitions;
    return _competitions.where((c) => c['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('COMPETITIONS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: 'ALL'), Tab(text: 'LIVE 🔴'), Tab(text: 'UPCOMING')],
          onTap: (i) {
            setState(() => _selectedFilter = i == 0 ? 'all' : i == 1 ? 'live' : 'upcoming');
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: () async { setState(() { _loading = true; _competitions = []; }); await _loadCompetitions(); },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _CompetitionCard(competition: _filtered[i])
                    .animate(delay: (i * 80).ms)
                    .fadeIn()
                    .slideY(begin: 0.2, end: 0),
              ),
            ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Competitions', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['All', 'Free', 'Paid', 'My Region'].map((f) => FilterChip(
                label: Text(f),
                selected: false,
                onSelected: (_) {},
                backgroundColor: GacomColors.cardDark,
                selectedColor: GacomColors.deepOrange.withOpacity(0.3),
                labelStyle: const TextStyle(color: GacomColors.textPrimary),
                side: const BorderSide(color: GacomColors.border),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  final Map<String, dynamic> competition;
  const _CompetitionCard({required this.competition});

  @override
  Widget build(BuildContext context) {
    final status = competition['status'] as String? ?? 'upcoming';
    final isLive = status == 'live';
    final isPaid = competition['competition_type'] == 'paid';
    final prizePool = (competition['prize_pool'] as num?)?.toDouble() ?? 0;
    final entryFee = (competition['entry_fee'] as num?)?.toDouble() ?? 0;
    final participants = competition['current_participants'] ?? 0;
    final maxParticipants = competition['max_participants'];
    final startsAt = DateTime.tryParse(competition['starts_at'] ?? '') ?? DateTime.now();

    return GestureDetector(
      onTap: () => context.go('/competitions/${competition['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLive ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border,
            width: isLive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner / header
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: isLive
                      ? [GacomColors.darkOrange, GacomColors.deepOrange]
                      : [GacomColors.surfaceDark, GacomColors.cardDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  if (competition['banner_url'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedNetworkImage(
                        imageUrl: competition['banner_url'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: GacomColors.error,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: Colors.white),
                                SizedBox(width: 4),
                                Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1)),
                              ],
                            ),
                          ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? GacomColors.warning.withOpacity(0.9) : GacomColors.success.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            isPaid ? '₦${entryFee.toStringAsFixed(0)} ENTRY' : 'FREE',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        competition['game_name'] ?? '',
                        style: const TextStyle(color: GacomColors.textPrimary, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    competition['title'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GacomColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.emoji_events_rounded,
                        label: '₦${_formatAmount(prizePool)}',
                        color: GacomColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.people_outline_rounded,
                        label: maxParticipants != null
                            ? '$participants/$maxParticipants'
                            : '$participants players',
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        label: isLive ? 'LIVE NOW' : DateFormat('MMM d, HH:mm').format(startsAt),
                        color: isLive ? GacomColors.error : null,
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

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? GacomColors.textMuted).withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: (color ?? GacomColors.border).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? GacomColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color ?? GacomColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Rajdhani',
            ),
          ),
        ],
      ),
    );
  }
}
