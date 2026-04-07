import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../../../shared/widgets/gacom_text_field.dart';

class AdsScreen extends ConsumerStatefulWidget {
  const AdsScreen({super.key});
  @override
  ConsumerState<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends ConsumerState<AdsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _myCampaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final data = await SupabaseService.client
          .from('ad_campaigns')
          .select('*')
          .eq('advertiser_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _myCampaigns = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('ADVERTISE'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelStyle: const TextStyle(
              fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'MY CAMPAIGNS')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(onLaunch: () => _showCreateCampaign(context)),
          _CampaignsTab(
              campaigns: _myCampaigns,
              loading: _loading,
              onCreate: () => _showCreateCampaign(context)),
        ],
      ),
    );
  }

  void _showCreateCampaign(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    String selectedType = 'banner';
    String selectedAudience = 'all_gamers';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
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
                  child: const Icon(Icons.campaign_rounded,
                      color: GacomColors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Launch Campaign',
                        style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: GacomColors.textPrimary)),
                    Text('Reach competitive gamers across Africa',
                        style: TextStyle(
                            color: GacomColors.textMuted, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),

              GacomTextField(
                  controller: titleCtrl,
                  label: 'Campaign Name',
                  hint: 'e.g. GACOM Pro Controller Launch',
                  prefixIcon: Icons.title_rounded),
              const SizedBox(height: 12),
              GacomTextField(
                  controller: descCtrl,
                  label: 'Ad Copy',
                  hint: 'What do you want gamers to know?',
                  prefixIcon: Icons.description_rounded,
                  maxLines: 3),
              const SizedBox(height: 12),
              GacomTextField(
                  controller: linkCtrl,
                  label: 'Destination URL',
                  hint: 'https://yoursite.com',
                  prefixIcon: Icons.link_rounded,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 16),

              // Ad Type
              const Text('Ad Format',
                  style: TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                for (final t in [
                  ('banner', 'Banner', Icons.view_agenda_rounded),
                  ('interstitial', 'Full Screen', Icons.fullscreen_rounded),
                  ('feed', 'In-Feed', Icons.view_stream_rounded),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => selectedType = t.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                            color: selectedType == t.$1
                                ? GacomColors.deepOrange.withOpacity(0.15)
                                : GacomColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: selectedType == t.$1
                                    ? GacomColors.deepOrange
                                    : GacomColors.border)),
                        child: Column(children: [
                          Icon(t.$3,
                              size: 20,
                              color: selectedType == t.$1
                                  ? GacomColors.deepOrange
                                  : GacomColors.textMuted),
                          const SizedBox(height: 4),
                          Text(t.$2,
                              style: TextStyle(
                                  color: selectedType == t.$1
                                      ? GacomColors.deepOrange
                                      : GacomColors.textMuted,
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11),
                              textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ),
              ]),

              const SizedBox(height: 16),

              // Audience
              const Text('Target Audience',
                  style: TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ('all_gamers', 'All Gamers'),
                  ('competitive', 'Competitive Players'),
                  ('mobile', 'Mobile Gamers'),
                  ('pc', 'PC Gamers'),
                  ('nigeria', 'Nigeria'),
                  ('africa', 'Africa'),
                ].map((a) {
                  final isSel = selectedAudience == a.$1;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedAudience = a.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: isSel
                              ? GacomColors.deepOrange.withOpacity(0.15)
                              : GacomColors.surfaceDark,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: isSel
                                  ? GacomColors.deepOrange
                                  : GacomColors.border)),
                      child: Text(a.$2,
                          style: TextStyle(
                              color: isSel
                                  ? GacomColors.deepOrange
                                  : GacomColors.textMuted,
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              GacomTextField(
                  controller: budgetCtrl,
                  label: 'Daily Budget (₦)',
                  hint: 'Min ₦1,000/day',
                  prefixIcon: Icons.account_balance_wallet_rounded,
                  keyboardType: TextInputType.number),

              const SizedBox(height: 12),

              // Pricing info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: GacomColors.info.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: GacomColors.info.withOpacity(0.2))),
                child: Column(children: [
                  _PriceRow('CPM (per 1,000 impressions)', '₦200'),
                  _PriceRow('CPC (per click)', '₦50'),
                  _PriceRow('Min budget', '₦1,000/day'),
                  _PriceRow('Min duration', '3 days'),
                ]),
              ),

              const SizedBox(height: 24),
              GacomButton(
                label: 'LAUNCH CAMPAIGN',
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    GacomSnackbar.show(ctx, 'Campaign name required',
                        isError: true);
                    return;
                  }
                  final budget = double.tryParse(budgetCtrl.text) ?? 0;
                  if (budget < 1000) {
                    GacomSnackbar.show(
                        ctx, 'Minimum budget is ₦1,000/day',
                        isError: true);
                    return;
                  }
                  try {
                    await SupabaseService.client
                        .from('ad_campaigns')
                        .insert({
                      'advertiser_id': SupabaseService.currentUserId,
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'destination_url': linkCtrl.text.trim(),
                      'ad_type': selectedType,
                      'target_audience': selectedAudience,
                      'daily_budget': budget,
                      'status': 'pending_review',
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      GacomSnackbar.show(context,
                          'Campaign submitted for review! 🚀',
                          isSuccess: true);
                      setState(() => _loading = true);
                      await _loadCampaigns();
                    }
                  } catch (_) {
                    GacomSnackbar.show(
                        ctx, 'Failed to submit campaign',
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

class _OverviewTab extends StatelessWidget {
  final VoidCallback onLaunch;
  const _OverviewTab({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Hero card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: GacomColors.orangeGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: GacomColors.deepOrange.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 36),
            const SizedBox(height: 12),
            const Text('Reach 50,000+\nActive Gamers',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    height: 1.2)),
            const SizedBox(height: 8),
            const Text(
                'Target competitive gamers across Nigeria and Africa. Get your brand in front of the right audience.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onLaunch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50)),
                child: const Text('LAUNCH CAMPAIGN',
                    style: TextStyle(
                        color: GacomColors.deepOrange,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1)),
              ),
            ),
          ]),
        ).animate().fadeIn(),

        const SizedBox(height: 28),
        const Text('WHY ADVERTISE ON GACOM?',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: GacomColors.textPrimary,
                letterSpacing: 1)),
        const SizedBox(height: 16),

        ...[
          (Icons.people_rounded, 'Engaged Audience',
              'Gamers who are actively competing and spending money on gear.'),
          (Icons.location_on_rounded, 'African Focus',
              'Hyper-local targeting for Nigeria, Ghana, Kenya, and all African markets.'),
          (Icons.bar_chart_rounded, 'Real Analytics',
              'Track impressions, clicks, and conversions in real time.'),
          (Icons.attach_money_rounded, 'Affordable Rates',
              'Starting from just ₦200 CPM. No minimum contract.'),
        ]
            .asMap()
            .entries
            .map((e) => _FeatureCard(
                  icon: e.value.$1,
                  title: e.value.$2,
                  desc: e.value.$3,
                ).animate(delay: (e.key * 80).ms).fadeIn()),

        const SizedBox(height: 28),
        const Text('AD FORMATS',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: GacomColors.textPrimary,
                letterSpacing: 1)),
        const SizedBox(height: 16),

        ...[
          ('Banner Ads', 'Sticky top/bottom banners', '₦200 CPM'),
          ('In-Feed Ads', 'Native ads in the activity feed', '₦300 CPM'),
          ('Full Screen', 'High-impact interstitials', '₦500 CPM'),
        ].map((f) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: GacomColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: GacomColors.border, width: 0.5)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Text(f.$1,
                      style: const TextStyle(
                          color: GacomColors.textPrimary,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text(f.$2,
                      style: const TextStyle(
                          color: GacomColors.textMuted,
                          fontSize: 12)),
                ])),
                Text(f.$3,
                    style: const TextStyle(
                        color: GacomColors.deepOrange,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
            )),

        const SizedBox(height: 24),
        GacomButton(
          label: 'LAUNCH YOUR FIRST CAMPAIGN',
          onPressed: onLaunch,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _FeatureCard(
      {required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: GacomColors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: GacomColors.deepOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(title,
                style: const TextStyle(
                    color: GacomColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(desc,
                style: const TextStyle(
                    color: GacomColors.textMuted,
                    fontSize: 12,
                    height: 1.4)),
          ])),
        ]),
      );
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  const _PriceRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: GacomColors.textMuted, fontSize: 12))),
          Text(value,
              style: const TextStyle(
                  color: GacomColors.info,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
      );
}

class _CampaignsTab extends StatelessWidget {
  final List<Map<String, dynamic>> campaigns;
  final bool loading;
  final VoidCallback onCreate;
  const _CampaignsTab(
      {required this.campaigns,
      required this.loading,
      required this.onCreate});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child:
              CircularProgressIndicator(color: GacomColors.deepOrange));
    }
    if (campaigns.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.campaign_rounded,
                size: 64, color: GacomColors.border),
            const SizedBox(height: 16),
            const Text('No campaigns yet',
                style: TextStyle(
                    color: GacomColors.textMuted, fontSize: 16)),
            const SizedBox(height: 24),
            GacomButton(
              label: 'LAUNCH FIRST CAMPAIGN',
              onPressed: onCreate,
            ),
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: campaigns.length,
      itemBuilder: (_, i) {
        final c = campaigns[i];
        final status = c['status'] as String? ?? 'pending_review';
        Color statusColor = status == 'active'
            ? GacomColors.success
            : status == 'pending_review'
                ? GacomColors.warning
                : GacomColors.textMuted;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(c['title'] ?? '',
                      style: const TextStyle(
                          color: GacomColors.textPrimary,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _CampaignStat('Budget',
                  '₦${c['daily_budget']}/day'),
              const SizedBox(width: 16),
              _CampaignStat('Impressions',
                  '${c['impressions'] ?? 0}'),
              const SizedBox(width: 16),
              _CampaignStat('Clicks', '${c['clicks'] ?? 0}'),
            ]),
          ]),
        );
      },
    );
  }
}

class _CampaignStat extends StatelessWidget {
  final String label, value;
  const _CampaignStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: GacomColors.textMuted, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: GacomColors.textPrimary,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      );
}
