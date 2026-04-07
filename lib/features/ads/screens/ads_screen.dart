import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('PROMOTIONS'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: TabBar(
            controller: _tab,
            tabs: const [Tab(text: 'CREATE AD'), Tab(text: 'MY CAMPAIGNS')],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CreateAdTab(),
          _CampaignsTab(),
        ],
      ),
    );
  }
}

class _CreateAdTab extends StatefulWidget {
  @override
  State<_CreateAdTab> createState() => _CreateAdTabState();
}

class _CreateAdTabState extends State<_CreateAdTab> {
  String _adType = 'profile';
  String _objective = 'awareness';
  String _budget = '₦1,000';
  int _duration = 3;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero info
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(color: GacomColors.deepOrange.withOpacity(0.1), blurRadius: 20),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: GacomColors.orangeGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promote Your Content',
                        style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: GacomColors.textPrimary)),
                    Text('Reach thousands of gamers across Nigeria',
                        style: TextStyle(
                            color: GacomColors.textMuted,
                            fontSize: 12,
                            height: 1.4)),
                  ]),
            ),
          ]),
        ).animate().fadeIn().slideY(begin: 0.1, end: 0),

        const SizedBox(height: 24),

        _Label('What to promote'),
        const SizedBox(height: 12),
        Row(children: [
          _AdTypeCard(
              icon: Icons.person_rounded,
              label: 'Profile',
              sub: 'Gain followers',
              selected: _adType == 'profile',
              onTap: () => setState(() => _adType = 'profile')),
          const SizedBox(width: 10),
          _AdTypeCard(
              icon: Icons.image_rounded,
              label: 'Post',
              sub: 'Boost reach',
              selected: _adType == 'post',
              onTap: () => setState(() => _adType = 'post')),
          const SizedBox(width: 10),
          _AdTypeCard(
              icon: Icons.play_circle_rounded,
              label: 'Clip',
              sub: 'Get views',
              selected: _adType == 'clip',
              onTap: () => setState(() => _adType = 'clip')),
        ]).animate(delay: 80.ms).fadeIn(),

        const SizedBox(height: 24),

        _Label('Campaign objective'),
        const SizedBox(height: 12),
        Column(children: [
          _ObjectiveRow(
              icon: Icons.visibility_rounded,
              label: 'Awareness',
              sub: 'Maximize impressions and visibility',
              selected: _objective == 'awareness',
              onTap: () => setState(() => _objective = 'awareness')),
          const SizedBox(height: 8),
          _ObjectiveRow(
              icon: Icons.person_add_rounded,
              label: 'Followers',
              sub: 'Grow your follower count',
              selected: _objective == 'followers',
              onTap: () => setState(() => _objective = 'followers')),
          const SizedBox(height: 8),
          _ObjectiveRow(
              icon: Icons.thumb_up_rounded,
              label: 'Engagement',
              sub: 'Drive likes, comments & shares',
              selected: _objective == 'engagement',
              onTap: () => setState(() => _objective = 'engagement')),
        ]).animate(delay: 120.ms).fadeIn(),

        const SizedBox(height: 24),

        _Label('Daily budget'),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['₦500', '₦1,000', '₦2,500', '₦5,000', '₦10,000']
                .map((b) => GestureDetector(
                      onTap: () => setState(() => _budget = b),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _budget == b
                              ? GacomColors.deepOrange.withOpacity(0.1)
                              : GacomColors.cardDark,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: _budget == b
                                  ? GacomColors.deepOrange
                                  : GacomColors.border,
                              width: _budget == b ? 1.5 : 0.8),
                        ),
                        child: Text(b,
                            style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _budget == b
                                    ? GacomColors.deepOrange
                                    : GacomColors.textSecondary)),
                      ),
                    ))
                .toList()).animate(delay: 160.ms).fadeIn(),

        const SizedBox(height: 24),

        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Expanded(child: _Label('Duration (days)')),
          _DurationPicker(
            value: _duration,
            onDecrement: () {
              if (_duration > 1) setState(() => _duration--);
            },
            onIncrement: () {
              if (_duration < 30) setState(() => _duration++);
            },
          ),
        ]).animate(delay: 200.ms).fadeIn(),

        const SizedBox(height: 24),

        _CampaignSummary(
                adType: _adType,
                objective: _objective,
                budget: _budget,
                duration: _duration)
            .animate(delay: 240.ms)
            .fadeIn(),

        const SizedBox(height: 24),

        _BigButton(
          label: 'LAUNCH CAMPAIGN',
          loading: _loading,
          onTap: () async {
            setState(() => _loading = true);
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) {
              setState(() => _loading = false);
              GacomSnackbar.show(context, '🚀 Campaign submitted for review!',
                  isError: false);
            }
          },
        ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.1, end: 0),
      ]),
    );
  }
}

class _CampaignsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final campaigns = [
      {
        'type': 'Profile Boost',
        'status': 'active',
        'budget': '₦1,000/day',
        'reach': '4,820',
        'days': '2 days left'
      },
      {
        'type': 'Post Promotion',
        'status': 'ended',
        'budget': '₦500/day',
        'reach': '1,230',
        'days': 'Ended'
      },
    ];

    if (campaigns.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.campaign_outlined, size: 64, color: GacomColors.border),
        SizedBox(height: 16),
        Text('No campaigns yet',
            style: TextStyle(color: GacomColors.textMuted, fontSize: 15)),
        Text('Create your first ad to reach more gamers',
            style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: campaigns.length,
      itemBuilder: (_, i) {
        final c = campaigns[i];
        final isActive = c['status'] == 'active';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GacomColors.border, width: 0.8),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? GacomColors.success.withOpacity(0.1)
                      : GacomColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? GacomColors.success
                              : GacomColors.textMuted)),
                  const SizedBox(width: 5),
                  Text(isActive ? 'ACTIVE' : 'ENDED',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: isActive
                              ? GacomColors.success
                              : GacomColors.textMuted)),
                ]),
              ),
              const Spacer(),
              Text(c['days']!,
                  style: const TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Text(c['type']!,
                style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: GacomColors.textPrimary)),
            const SizedBox(height: 10),
            Row(children: [
              _StatPill(icon: Icons.attach_money_rounded, label: c['budget']!),
              const SizedBox(width: 8),
              _StatPill(
                  icon: Icons.people_rounded,
                  label: '${c['reach']} reached'),
            ]),
          ]),
        ).animate(delay: (i * 80).ms).fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }
}

// ─── Sub Widgets ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: GacomColors.textPrimary,
            letterSpacing: 0.3));
  }
}

class _AdTypeCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _AdTypeCard(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? GacomColors.deepOrange.withOpacity(0.08)
                : GacomColors.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color:
                    selected ? GacomColors.deepOrange : GacomColors.border,
                width: selected ? 1.5 : 0.8),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected
                    ? GacomColors.deepOrange
                    : GacomColors.textSecondary,
                size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected
                        ? GacomColors.deepOrange
                        : GacomColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub,
                style:
                    const TextStyle(color: GacomColors.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _ObjectiveRow(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? GacomColors.deepOrange.withOpacity(0.06)
              : GacomColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? GacomColors.deepOrange : GacomColors.border,
              width: selected ? 1.5 : 0.8),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? GacomColors.deepOrange.withOpacity(0.12)
                  : GacomColors.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: selected
                    ? GacomColors.deepOrange
                    : GacomColors.textSecondary,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: selected
                            ? GacomColors.textPrimary
                            : GacomColors.textSecondary)),
                Text(sub,
                    style: const TextStyle(
                        color: GacomColors.textMuted, fontSize: 12)),
              ])),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: GacomColors.deepOrange, size: 18),
        ]),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement, onIncrement;
  const _DurationPicker(
      {required this.value,
      required this.onDecrement,
      required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      GestureDetector(
        onTap: onDecrement,
        child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GacomColors.border),
                color: GacomColors.surfaceDark),
            child: const Icon(Icons.remove_rounded,
                color: GacomColors.textSecondary, size: 16)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text('$value',
              key: ValueKey(value),
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: GacomColors.textPrimary)),
        ),
      ),
      GestureDetector(
        onTap: onIncrement,
        child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                gradient: GacomColors.orangeGradient, shape: BoxShape.circle),
            child:
                const Icon(Icons.add_rounded, color: Colors.white, size: 16)),
      ),
    ]);
  }
}

class _CampaignSummary extends StatelessWidget {
  final String adType, objective, budget;
  final int duration;
  const _CampaignSummary(
      {required this.adType,
      required this.objective,
      required this.budget,
      required this.duration});

  @override
  Widget build(BuildContext context) {
    final budgetNum =
        double.tryParse(budget.replaceAll(RegExp(r'[₦,]'), '')) ?? 0;
    final total = budgetNum * duration;
    final reachMin = (budgetNum * duration * 2).toInt();
    final reachMax = (budgetNum * duration * 8).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GacomColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GacomColors.border, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Campaign Summary',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: GacomColors.textPrimary)),
        const SizedBox(height: 14),
        _SummaryRow('Type', adType[0].toUpperCase() + adType.substring(1)),
        const SizedBox(height: 8),
        _SummaryRow(
            'Objective', objective[0].toUpperCase() + objective.substring(1)),
        const SizedBox(height: 8),
        _SummaryRow('Duration', '$duration days'),
        const SizedBox(height: 8),
        _SummaryRow('Daily Budget', budget),
        const Divider(height: 20, color: GacomColors.border),
        Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Estimated Reach',
                    style:
                        TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
          Text('${_fmt(reachMin)} – ${_fmt(reachMax)} gamers',
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: GacomColors.textPrimary)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(
              child: Text('Total Cost',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: GacomColors.textPrimary))),
          Text('₦${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: GacomColors.deepOrange)),
        ]),
      ]),
    );
  }

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : n.toString();
}

class _SummaryRow extends StatelessWidget {
  final String key_, value;
  const _SummaryRow(this.key_, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(key_,
          style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: GacomColors.textPrimary)),
    ]);
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: GacomColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GacomColors.border, width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: GacomColors.textMuted, size: 14),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: GacomColors.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _BigButton(
      {required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: GacomColors.orangeGradient,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
                color: GacomColors.deepOrange.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1.5,
                      color: Colors.white)),
        ),
      ),
    );
  }
}
