import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class CompetitionsScreen extends ConsumerStatefulWidget {
  const CompetitionsScreen({super.key});
  @override
  ConsumerState<CompetitionsScreen> createState() =>
      _CompetitionsScreenState();
}

class _CompetitionsScreenState extends ConsumerState<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _competitions = [];
  bool _loading = true;
  String _selectedFilter = 'all';
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCompetitions();
    _checkCreatePermission();
  }

  Future<void> _checkCreatePermission() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      final role = profile['role'] as String? ?? 'user';
      bool hasPermission =
          ['admin', 'super_admin'].contains(role);
      if (!hasPermission) {
        // Check if user has create_competitions permission
        final perm = await SupabaseService.client
            .from('admin_permissions')
            .select('id')
            .eq('admin_id', userId)
            .eq('permission', AdminPermission.createCompetitions)
            .maybeSingle();
        hasPermission = perm != null;
      }
      if (mounted) setState(() => _canCreate = hasPermission);
    } catch (_) {}
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
      if (mounted) {
        setState(() {
          _competitions = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 'all') return _competitions;
    return _competitions
        .where((c) => c['status'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('COMPETITIONS'),
        actions: [
          if (_canCreate)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded,
                  color: GacomColors.deepOrange),
              tooltip: 'Create Competition',
              onPressed: () => _showCreateSheet(context),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
              fontSize: 14),
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'LIVE 🔴'),
            Tab(text: 'UPCOMING')
          ],
          onTap: (i) => setState(() =>
              _selectedFilter = i == 0 ? 'all' : i == 1 ? 'live' : 'upcoming'),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: () async {
                setState(() {
                  _loading = true;
                  _competitions = [];
                });
                await _loadCompetitions();
              },
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          const Icon(Icons.sports_esports_rounded,
                              size: 64, color: GacomColors.border),
                          const SizedBox(height: 16),
                          Text(
                              _selectedFilter == 'all'
                                  ? 'No competitions yet'
                                  : 'No $_selectedFilter competitions',
                              style: const TextStyle(
                                  color: GacomColors.textMuted,
                                  fontSize: 16)),
                          if (_canCreate) ...[
                            const SizedBox(height: 24),
                            GacomButton(
                              label: 'CREATE FIRST',
                              onPressed: () => _showCreateSheet(context),
                            ),
                          ]
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _CompetitionCard(
                          competition: _filtered[i])
                          .animate(delay: (i * 50).ms)
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Filter Competitions',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary)),
          const SizedBox(height: 16),
          ...[
            ('all', 'All Competitions', Icons.grid_view_rounded),
            ('live', 'Live Now', Icons.circle),
            ('upcoming', 'Upcoming', Icons.schedule_rounded),
            ('ended', 'Ended', Icons.flag_rounded),
          ].map((e) => ListTile(
                leading:
                    Icon(e.$3, color: GacomColors.deepOrange, size: 20),
                title: Text(e.$2,
                    style: const TextStyle(
                        color: GacomColors.textPrimary)),
                trailing: _selectedFilter == e.$1
                    ? const Icon(Icons.check_rounded,
                        color: GacomColors.deepOrange)
                    : null,
                onTap: () {
                  setState(() => _selectedFilter = e.$1);
                  Navigator.pop(context);
                },
              )),
        ]),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final gameCtrl = TextEditingController();
    final prizeCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    String type = 'free';
    DateTime? startsAt;
    DateTime? endsAt;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          builder: (_, scroll) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: ListView(
              controller: scroll,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: GacomColors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: GacomColors.deepOrange),
                  ),
                  const SizedBox(width: 12),
                  const Text('Create Competition',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: GacomColors.textPrimary)),
                ]),
                const SizedBox(height: 20),
                GacomTextField(
                    controller: titleCtrl,
                    label: 'Competition Title',
                    hint: 'e.g. GACOM PUBG Championship',
                    prefixIcon: Icons.title_rounded),
                const SizedBox(height: 12),
                GacomTextField(
                    controller: gameCtrl,
                    label: 'Game Name',
                    hint: 'e.g. PUBG Mobile',
                    prefixIcon: Icons.sports_esports_rounded),
                const SizedBox(height: 12),
                GacomTextField(
                    controller: descCtrl,
                    label: 'Description',
                    hint: 'Describe the competition...',
                    prefixIcon: Icons.description_rounded,
                    maxLines: 3),
                const SizedBox(height: 12),
                GacomTextField(
                    controller: prizeCtrl,
                    label: 'Prize Pool (₦)',
                    hint: '0',
                    prefixIcon: Icons.monetization_on_rounded,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                // Type toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: GacomColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                        child: GestureDetector(
                      onTap: () => setModal(() => type = 'free'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: type == 'free'
                                ? GacomColors.deepOrange
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('Free',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: type == 'free'
                                    ? Colors.white
                                    : GacomColors.textMuted,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700)),
                      ),
                    )),
                    Expanded(
                        child: GestureDetector(
                      onTap: () => setModal(() => type = 'paid'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: type == 'paid'
                                ? GacomColors.deepOrange
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('Paid',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: type == 'paid'
                                    ? Colors.white
                                    : GacomColors.textMuted,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700)),
                      ),
                    )),
                  ]),
                ),
                if (type == 'paid') ...[
                  const SizedBox(height: 12),
                  GacomTextField(
                      controller: feeCtrl,
                      label: 'Entry Fee (₦)',
                      hint: '500',
                      prefixIcon: Icons.payments_rounded,
                      keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 12),
                // Date pickers
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDateTimePicker(context);
                        if (d != null) setModal(() => startsAt = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: GacomColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: GacomColors.border)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Starts',
                              style: TextStyle(
                                  color: GacomColors.textMuted,
                                  fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                              startsAt != null
                                  ? DateFormat('dd/MM/yy HH:mm')
                                      .format(startsAt!)
                                  : 'Pick date',
                              style: TextStyle(
                                  color: startsAt != null
                                      ? GacomColors.textPrimary
                                      : GacomColors.textMuted,
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDateTimePicker(context);
                        if (d != null) setModal(() => endsAt = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: GacomColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: GacomColors.border)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Ends',
                              style: TextStyle(
                                  color: GacomColors.textMuted,
                                  fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                              endsAt != null
                                  ? DateFormat('dd/MM/yy HH:mm')
                                      .format(endsAt!)
                                  : 'Pick date',
                              style: TextStyle(
                                  color: endsAt != null
                                      ? GacomColors.textPrimary
                                      : GacomColors.textMuted,
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                GacomButton(
                  label: 'CREATE COMPETITION',
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty ||
                        gameCtrl.text.trim().isEmpty) {
                      GacomSnackbar.show(
                          ctx, 'Title and game are required',
                          isError: true);
                      return;
                    }
                    try {
                      await SupabaseService.client
                          .from('competitions')
                          .insert({
                        'title': titleCtrl.text.trim(),
                        'game_name': gameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'prize_pool':
                            double.tryParse(prizeCtrl.text) ?? 0,
                        'competition_type': type,
                        'entry_fee':
                            type == 'paid'
                                ? double.tryParse(feeCtrl.text) ?? 0
                                : 0,
                        'status': 'upcoming',
                        'created_by': SupabaseService.currentUserId,
                        'is_admin_created': false,
                        'starts_at': startsAt?.toIso8601String(),
                        'ends_at': endsAt?.toIso8601String(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        GacomSnackbar.show(context,
                            'Competition created! 🏆',
                            isSuccess: true);
                        setState(() => _loading = true);
                        await _loadCompetitions();
                      }
                    } catch (e) {
                      GacomSnackbar.show(
                          ctx, 'Failed to create competition',
                          isError: true);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> showDateTimePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: GacomColors.deepOrange,
              surface: GacomColors.cardDark),
        ),
        child: child!,
      ),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _CompetitionCard extends StatelessWidget {
  final Map<String, dynamic> competition;
  const _CompetitionCard({required this.competition});

  @override
  Widget build(BuildContext context) {
    final status = competition['status'] as String? ?? 'upcoming';
    final isLive = status == 'live';
    final prizePool =
        (competition['prize_pool'] as num?)?.toDouble() ?? 0;
    final entryFee =
        (competition['entry_fee'] as num?)?.toDouble() ?? 0;
    final type =
        competition['competition_type'] as String? ?? 'free';
    final startsAt =
        DateTime.tryParse(competition['starts_at'] ?? '');

    Color statusColor = isLive
        ? GacomColors.success
        : status == 'upcoming'
            ? GacomColors.warning
            : GacomColors.textMuted;

    return GestureDetector(
      onTap: () => context.push('/competitions/${competition['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isLive
                  ? GacomColors.success.withOpacity(0.3)
                  : GacomColors.border,
              width: isLive ? 1.5 : 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Banner / header
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [
                  GacomColors.darkOrange.withOpacity(0.6),
                  GacomColors.obsidian
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: [
              if (competition['banner_url'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: competition['banner_url'],
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.darken,
                    errorWidget: (_, __, ___) => const SizedBox(),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: statusColor.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isLive)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                            color: GacomColors.success,
                            shape: BoxShape.circle),
                      ),
                    Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(competition['title'] ?? '',
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(competition['game_name'] ?? '',
                  style: const TextStyle(
                      color: GacomColors.deepOrange,
                      fontSize: 13,
                      fontFamily: 'Rajdhani')),
              const SizedBox(height: 12),
              Row(children: [
                _InfoChip(
                    icon: Icons.emoji_events_rounded,
                    label: '₦${prizePool.toStringAsFixed(0)}',
                    color: GacomColors.gold),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: type == 'free'
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    label: type == 'free'
                        ? 'Free'
                        : '₦${entryFee.toStringAsFixed(0)}',
                    color: type == 'free'
                        ? GacomColors.success
                        : GacomColors.warning),
                if (startsAt != null) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: DateFormat('dd MMM').format(startsAt),
                      color: GacomColors.textMuted),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(50),
            border:
                Border.all(color: color.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
