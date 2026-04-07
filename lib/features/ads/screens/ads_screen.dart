import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});
  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('PROMOTIONS'),
      bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'CREATE AD'), Tab(text: 'MY CAMPAIGNS')]),
    ),
    body: TabBarView(controller: _tab, children: [_CreateAdTab(), _CampaignsTab()]),
  );
}

class _CreateAdTab extends StatefulWidget {
  @override State<_CreateAdTab> createState() => _CreateAdTabState();
}

class _CreateAdTabState extends State<_CreateAdTab> {
  String _adType = 'profile', _objective = 'awareness', _budget = '₦1,000';
  int _duration = 3;
  bool _loading = false;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Hero
      Container(
        padding: const EdgeInsets.all(20),
        decoration: GacomDecorations.neonCard(radius: 20),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Promote Your Content', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
            SizedBox(height: 2),
            Text('Reach thousands of gamers across Nigeria', style: TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
          ])),
        ]),
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),

      const SizedBox(height: 24),
      _L('What to promote'),
      const SizedBox(height: 12),
      Row(children: [
        _TypeCard(icon: Icons.person_rounded, label: 'Profile', sub: 'Gain followers', sel: _adType == 'profile', onTap: () => setState(() => _adType = 'profile')),
        const SizedBox(width: 10),
        _TypeCard(icon: Icons.image_rounded, label: 'Post', sub: 'Boost reach', sel: _adType == 'post', onTap: () => setState(() => _adType = 'post')),
        const SizedBox(width: 10),
        _TypeCard(icon: Icons.play_circle_rounded, label: 'Clip', sub: 'Get views', sel: _adType == 'clip', onTap: () => setState(() => _adType = 'clip')),
      ]).animate(delay: 80.ms).fadeIn(),

      const SizedBox(height: 24),
      _L('Campaign objective'),
      const SizedBox(height: 12),
      Column(children: [
        _ObjRow(icon: Icons.visibility_rounded, label: 'Awareness', sub: 'Maximize impressions and visibility', sel: _objective == 'awareness', onTap: () => setState(() => _objective = 'awareness')),
        const SizedBox(height: 8),
        _ObjRow(icon: Icons.person_add_rounded, label: 'Followers', sub: 'Grow your follower count', sel: _objective == 'followers', onTap: () => setState(() => _objective = 'followers')),
        const SizedBox(height: 8),
        _ObjRow(icon: Icons.thumb_up_rounded, label: 'Engagement', sub: 'Drive likes, comments & shares', sel: _objective == 'engagement', onTap: () => setState(() => _objective = 'engagement')),
      ]).animate(delay: 120.ms).fadeIn(),

      const SizedBox(height: 24),
      _L('Daily budget'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: ['₦500','₦1,000','₦2,500','₦5,000','₦10,000'].map((b) =>
        GestureDetector(onTap: () => setState(() => _budget = b),
          child: AnimatedContainer(duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _budget == b ? GacomColors.deepOrange.withOpacity(0.1) : GacomColors.cardDark,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: _budget == b ? GacomColors.deepOrange : GacomColors.border, width: _budget == b ? 1.5 : 0.7),
            ),
            child: Text(b, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: _budget == b ? GacomColors.deepOrange : GacomColors.textSecondary)),
          ))).toList()).animate(delay: 160.ms).fadeIn(),

      const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Expanded(child: _L('Duration (days)')),
        _DurPicker(value: _duration,
          onDec: () { if (_duration > 1) setState(() => _duration--); },
          onInc: () { if (_duration < 30) setState(() => _duration++); }),
      ]).animate(delay: 200.ms).fadeIn(),

      const SizedBox(height: 24),
      _Summary(adType: _adType, objective: _objective, budget: _budget, duration: _duration)
          .animate(delay: 240.ms).fadeIn(),

      const SizedBox(height: 24),
      _LaunchBtn(loading: _loading, onTap: () async {
        setState(() => _loading = true);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          setState(() => _loading = false);
          GacomSnackbar.show(context, '🚀 Campaign submitted for review!', isError: false);
        }
      }).animate(delay: 280.ms).fadeIn().slideY(begin: 0.1, end: 0),
    ]),
  );
}

class _CampaignsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final campaigns = [
      {'type': 'Profile Boost', 'status': 'active', 'budget': '₦1,000/day', 'reach': '4,820', 'days': '2 days left'},
      {'type': 'Post Promotion', 'status': 'ended', 'budget': '₦500/day', 'reach': '1,230', 'days': 'Ended'},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: campaigns.length,
      itemBuilder: (_, i) {
        final c = campaigns[i];
        final active = c['status'] == 'active';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: GacomDecorations.glassCard(radius: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: active ? GacomColors.success.withOpacity(0.1) : GacomColors.border, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? GacomColors.success : GacomColors.textMuted)),
                  const SizedBox(width: 5),
                  Text(active ? 'ACTIVE' : 'ENDED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.8, color: active ? GacomColors.success : GacomColors.textMuted)),
                ]),
              ),
              const Spacer(),
              Text(c['days']!, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Text(c['type']!, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary)),
            const SizedBox(height: 10),
            Row(children: [
              _Pill(icon: Icons.attach_money_rounded, label: c['budget']!),
              const SizedBox(width: 8),
              _Pill(icon: Icons.people_rounded, label: '${c['reach']} reached'),
            ]),
          ]),
        ).animate(delay: (i * 80).ms).fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }
}

// ── Sub widgets ───────────────────────────────────────────────────────────────

class _L extends StatelessWidget {
  final String t; const _L(this.t);
  @override Widget build(BuildContext context) => Text(t, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary, letterSpacing: 0.3));
}

class _TypeCard extends StatelessWidget {
  final IconData icon; final String label, sub; final bool sel; final VoidCallback onTap;
  const _TypeCard({required this.icon, required this.label, required this.sub, required this.sel, required this.onTap});
  @override Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), decoration: BoxDecoration(color: sel ? GacomColors.deepOrange.withOpacity(0.08) : GacomColors.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border, width: sel ? 1.5 : 0.7)), child: Column(children: [Icon(icon, color: sel ? GacomColors.deepOrange : GacomColors.textSecondary, size: 24), const SizedBox(height: 6), Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: sel ? GacomColors.deepOrange : GacomColors.textPrimary)), const SideOffset(2), Text(sub, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10), textAlign: TextAlign.center)]))));
}

class SideOffset extends StatelessWidget {
  final double h; const SideOffset(this.h);
  @override Widget build(BuildContext context) => SizedBox(height: h);
}

class _ObjRow extends StatelessWidget {
  final IconData icon; final String label, sub; final bool sel; final VoidCallback onTap;
  const _ObjRow({required this.icon, required this.label, required this.sub, required this.sel, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: sel ? GacomColors.deepOrange.withOpacity(0.06) : GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border, width: sel ? 1.5 : 0.7)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: sel ? GacomColors.deepOrange.withOpacity(0.12) : GacomColors.surfaceDark, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: sel ? GacomColors.deepOrange : GacomColors.textSecondary, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: sel ? GacomColors.textPrimary : GacomColors.textSecondary)), Text(sub, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))])), if (sel) const Icon(Icons.check_circle_rounded, color: GacomColors.deepOrange, size: 18)])));
}

class _DurPicker extends StatelessWidget {
  final int value; final VoidCallback onDec, onInc;
  const _DurPicker({required this.value, required this.onDec, required this.onInc});
  @override Widget build(BuildContext context) => Row(children: [GestureDetector(onTap: onDec, child: Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.border), color: GacomColors.surfaceDark), child: const Icon(Icons.remove_rounded, color: GacomColors.textSecondary, size: 16))), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AnimatedSwitcher(duration: const Duration(milliseconds: 150), child: Text('$value', key: ValueKey(value), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary)))), GestureDetector(onTap: onInc, child: Container(width: 34, height: 34, decoration: BoxDecoration(gradient: GacomColors.orangeGradient, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 16)))]);
}

class _Summary extends StatelessWidget {
  final String adType, objective, budget; final int duration;
  const _Summary({required this.adType, required this.objective, required this.budget, required this.duration});
  @override Widget build(BuildContext context) {
    final num = double.tryParse(budget.replaceAll(RegExp(r'[₦,]'), '')) ?? 0;
    final total = num * duration;
    final rMin = (num * duration * 2).toInt(); final rMax = (num * duration * 8).toInt();
    String fmt(int n) => n >= 1000 ? '${(n/1000).toStringAsFixed(1)}K' : '$n';
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: GacomColors.border, width: 0.7)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Campaign Summary', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
      const SizedBox(height: 14),
      _Row('Type', adType[0].toUpperCase() + adType.substring(1)),
      const SizedBox(height: 8), _Row('Objective', objective[0].toUpperCase() + objective.substring(1)),
      const SizedBox(height: 8), _Row('Duration', '$duration days'),
      const SizedBox(height: 8), _Row('Daily Budget', budget),
      const Divider(height: 20, color: GacomColors.border),
      Row(children: [const Expanded(child: Text('Estimated Reach', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))), Text('${fmt(rMin)} – ${fmt(rMax)} gamers', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary))]),
      const SizedBox(height: 8),
      Row(children: [const Expanded(child: Text('Total Cost', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary))), Text('₦${total.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.deepOrange))]),
    ]));
  }
}

class _Row extends StatelessWidget {
  final String k, v; const _Row(this.k, this.v);
  @override Widget build(BuildContext context) => Row(children: [Text(k, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)), const Spacer(), Text(v, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13, color: GacomColors.textPrimary))]);
}

class _Pill extends StatelessWidget {
  final IconData icon; final String label; const _Pill({required this.icon, required this.label});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: GacomColors.border, width: 0.7)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: GacomColors.textMuted, size: 14), const SizedBox(width: 5), Text(label, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12))]));
}

class _LaunchBtn extends StatelessWidget {
  final bool loading; final VoidCallback onTap;
  const _LaunchBtn({required this.loading, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: loading ? null : onTap, child: Container(height: 56, width: double.infinity, decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]), child: Center(child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('LAUNCH CAMPAIGN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.5, color: Colors.white)))));
}
