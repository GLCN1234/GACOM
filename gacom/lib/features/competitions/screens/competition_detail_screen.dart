import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class CompetitionDetailScreen extends ConsumerStatefulWidget {
  final String competitionId;
  const CompetitionDetailScreen({super.key, required this.competitionId});

  @override
  ConsumerState<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends ConsumerState<CompetitionDetailScreen> {
  Map<String, dynamic>? _competition;
  List<Map<String, dynamic>> _participants = [];
  bool _loading = true;
  bool _isParticipant = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final comp = await SupabaseService.client
          .from('competitions')
          .select('*, created_by_profile:profiles!created_by(username, display_name, avatar_url), community:communities(name, icon_url)')
          .eq('id', widget.competitionId)
          .single();
      final parts = await SupabaseService.client
          .from('competition_participants')
          .select('*, user:profiles!user_id(username, display_name, avatar_url, verification_status)')
          .eq('competition_id', widget.competitionId)
          .limit(20);
      final userId = SupabaseService.currentUserId;
      bool isParticipant = false;
      if (userId != null) {
        final check = await SupabaseService.client
            .from('competition_participants')
            .select('id')
            .eq('competition_id', widget.competitionId)
            .eq('user_id', userId)
            .maybeSingle();
        isParticipant = check != null;
      }
      if (mounted) {
        setState(() {
          _competition = comp;
          _participants = List<Map<String, dynamic>>.from(parts);
          _isParticipant = isParticipant;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinCompetition() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final isPaid = _competition?['competition_type'] == 'paid';
    final entryFee = (_competition?['entry_fee'] as num?)?.toDouble() ?? 0;

    if (isPaid) {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .single();
      final balance = (profile['wallet_balance'] as num).toDouble();
      if (balance < entryFee) {
        if (mounted) GacomSnackbar.show(context, 'Insufficient wallet balance. Please fund your wallet.', isError: true);
        return;
      }
    }

    setState(() => _joining = true);
    try {
      await SupabaseService.client.from('competition_participants').insert({
        'competition_id': widget.competitionId,
        'user_id': userId,
        'payment_status': isPaid ? 'paid' : 'free',
        'gamer_tag_used': SupabaseService.currentUser?.userMetadata?['gamer_tag'],
      });

      if (isPaid) {
        final profile = await SupabaseService.client.from('profiles').select('wallet_balance').eq('id', userId).single();
        final currentBalance = (profile['wallet_balance'] as num).toDouble();
        await SupabaseService.client.from('profiles').update({'wallet_balance': currentBalance - entryFee, 'wallet_locked_balance': entryFee}).eq('id', userId);
        await SupabaseService.client.from('wallet_transactions').insert({
          'user_id': userId,
          'type': 'competition_entry',
          'amount': entryFee,
          'balance_before': currentBalance,
          'balance_after': currentBalance - entryFee,
          'status': 'success',
          'description': 'Entry fee: ${_competition?['title']}',
        });
      }

      if (mounted) {
        setState(() { _isParticipant = true; _joining = false; });
        GacomSnackbar.show(context, 'You\'re in! Good luck 🎮', isSuccess: true);
        _load();
      }
    } catch (e) {
      if (mounted) { setState(() => _joining = false); GacomSnackbar.show(context, 'Failed to join. Try again.', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));

    final c = _competition!;
    final status = c['status'] as String? ?? 'upcoming';
    final isLive = status == 'live';
    final isPaid = c['competition_type'] == 'paid';
    final prizePool = (c['prize_pool'] as num?)?.toDouble() ?? 0;
    final entryFee = (c['entry_fee'] as num?)?.toDouble() ?? 0;
    final participants = c['current_participants'] ?? 0;
    final maxParticipants = c['max_participants'];
    final startsAt = DateTime.tryParse(c['starts_at'] ?? '') ?? DateTime.now();
    final endsAt = DateTime.tryParse(c['ends_at'] ?? '') ?? DateTime.now();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: GacomColors.obsidian,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  c['banner_url'] != null
                      ? CachedNetworkImage(imageUrl: c['banner_url'], fit: BoxFit.cover)
                      : Container(decoration: const BoxDecoration(gradient: GacomColors.orangeGradient)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, GacomColors.obsidian.withOpacity(0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      top: 80,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: GacomColors.error, borderRadius: BorderRadius.circular(50)),
                        child: const Row(children: [Icon(Icons.circle, size: 8, color: Colors.white), SizedBox(width: 6), Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani', letterSpacing: 1))]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(c['title'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                const SizedBox(height: 8),
                Text(c['game_name'] ?? '', style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    _StatBox(label: 'PRIZE POOL', value: '₦${_fmt(prizePool)}', icon: Icons.emoji_events_rounded, color: GacomColors.warning),
                    const SizedBox(width: 10),
                    _StatBox(label: 'ENTRY FEE', value: isPaid ? '₦${_fmt(entryFee)}' : 'FREE', icon: Icons.local_activity_rounded, color: isPaid ? GacomColors.deepOrange : GacomColors.success),
                    const SizedBox(width: 10),
                    _StatBox(label: 'PLAYERS', value: maxParticipants != null ? '$participants/$maxParticipants' : '$participants', icon: Icons.people_rounded, color: GacomColors.info),
                  ],
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 20),

                // Dates
                _InfoRow(icon: Icons.play_arrow_rounded, label: 'Starts', value: DateFormat('MMM d, yyyy HH:mm').format(startsAt)),
                _InfoRow(icon: Icons.stop_rounded, label: 'Ends', value: DateFormat('MMM d, yyyy HH:mm').format(endsAt)),
                if (c['platform'] != null) _InfoRow(icon: Icons.devices_rounded, label: 'Platform', value: c['platform']),
                if (c['region'] != null) _InfoRow(icon: Icons.public_rounded, label: 'Region', value: c['region']),

                const SizedBox(height: 20),

                if (c['description'] != null) ...[
                  const Text('About', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(c['description'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 20),
                ],

                if (c['rules'] != null) ...[
                  const Text('Rules', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(c['rules'], style: const TextStyle(color: GacomColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 20),
                ],

                // Participants
                if (_participants.isNotEmpty) ...[
                  Text('Participants (${_participants.length})', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _participants.length,
                      itemBuilder: (_, i) {
                        final u = _participants[i]['user'] as Map<String, dynamic>? ?? {};
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: GacomColors.border,
                            backgroundImage: u['avatar_url'] != null ? CachedNetworkImageProvider(u['avatar_url']) : null,
                            child: u['avatar_url'] == null ? Text((u['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold)) : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Join button
                if (status != 'ended' && status != 'cancelled')
                  _isParticipant
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: GacomColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: GacomColors.success.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Icon(Icons.check_circle_rounded, color: GacomColors.success), SizedBox(width: 8), Text('You\'re Registered!', style: TextStyle(color: GacomColors.success, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16))],
                          ),
                        )
                      : GacomButton(
                          label: isPaid ? 'JOIN FOR ₦${_fmt(entryFee)}' : 'JOIN FREE',
                          isLoading: _joining,
                          onPressed: _joinCompetition,
                        ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontFamily: 'Rajdhani'), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: GacomColors.textMuted, size: 18),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
        Text(value, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
