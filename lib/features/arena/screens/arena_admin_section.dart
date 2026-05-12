import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../services/arena_service.dart';

class ArenaAdminSection extends StatefulWidget {
  const ArenaAdminSection({super.key});
  @override
  State<ArenaAdminSection> createState() => _ArenaAdminSectionState();
}

class _ArenaAdminSectionState extends State<ArenaAdminSection> {
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _disputes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ArenaService.getSettings(),
      ArenaService.getAdminStats(),
      ArenaService.getOpenDisputes(),
    ]);
    if (mounted) setState(() {
      _settings = results[0] as Map<String, dynamic>;
      _stats = results[1] as Map<String, dynamic>;
      _disputes = results[2] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _settings[key] = value);
    await ArenaService.updateSettings({key: value});
  }

  Future<void> _updateFee(int fee) async {
    if (fee < 1 || fee > 50) return;
    await _updateSetting('platform_fee_percent', fee);
  }

  Future<void> _updateStakeLimits(int min, int max) async {
    await ArenaService.updateSettings({'min_stake': min, 'max_stake': max});
    setState(() { _settings['min_stake'] = min; _settings['max_stake'] = max; });
  }

  Future<void> _resolveDispute(Map<String, dynamic> dispute, String? winnerId) async {
    await ArenaService.resolveDispute(dispute['id'] as String, dispute['match_id'] as String, winnerId);
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(winnerId != null ? 'Winner awarded ✅' : 'Both players refunded ✅'), backgroundColor: GacomColors.success),
    );
  }

  Future<void> _banPlayer(String userId) async {
    final reason = await _showBanDialog();
    if (reason == null || reason.isEmpty) return;
    await ArenaService.banUser(userId, reason);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player banned from Arena'), backgroundColor: GacomColors.error));
  }

  Future<String?> _showBanDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      title: const Text('Ban from Arena', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
      content: TextField(controller: ctrl, style: const TextStyle(color: GacomColors.textPrimary), decoration: const InputDecoration(hintText: 'Reason for ban...', hintStyle: TextStyle(color: GacomColors.textMuted), filled: true, fillColor: GacomColors.surfaceDark)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: GacomColors.error), child: const Text('BAN', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    return ListView(padding: const EdgeInsets.all(20), children: [
      // Stats grid
      _AdminTitle('Arena Overview'),
      const SizedBox(height: 12),
      GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4, children: [
        _StatCard('Today\'s Fees', '₦${(_stats['today_fees'] ?? 0).toString()}', GacomColors.success),
        _StatCard('Active Matches', '${_stats['active'] ?? 0}', GacomColors.deepOrange),
        _StatCard('Total Matches', '${_stats['total_matches'] ?? 0}', GacomColors.info),
        _StatCard('Platform Fee', '${_settings['platform_fee_percent'] ?? 15}%', GacomColors.warning),
        _StatCard('Open Disputes', '${_stats['open_disputes'] ?? 0}', (_stats['open_disputes'] ?? 0) > 0 ? GacomColors.error : GacomColors.success),
        _StatCard('Completed', '${_stats['total_completed'] ?? 0}', GacomColors.textSecondary),
      ]),
      const SizedBox(height: 24),

      // Master toggles
      _AdminTitle('Arena Controls'),
      const SizedBox(height: 10),
      _ToggleCard('Arena Enabled', 'Turn entire arena on/off', _settings['arena_enabled'] as bool? ?? true, Icons.sports_esports_rounded, (v) => _updateSetting('arena_enabled', v)),
      _ToggleCard('Voice Chat', 'Live voice during matches', _settings['voice_enabled'] as bool? ?? true, Icons.mic_rounded, (v) => _updateSetting('voice_enabled', v)),
      const SizedBox(height: 16),

      // Per-game toggles
      _AdminTitle('Game Controls'),
      const SizedBox(height: 10),
      _ToggleCard('Chess', 'Strategic chess matches', _settings['chess_enabled'] as bool? ?? true, Icons.grid_4x4_rounded, (v) => _updateSetting('chess_enabled', v)),
      _ToggleCard('Tic-Tac-Toe', 'Classic 3x3 grid game', _settings['tictactoe_enabled'] as bool? ?? true, Icons.close_rounded, (v) => _updateSetting('tictactoe_enabled', v)),
      _ToggleCard('RPS Battle', 'Rock Paper Scissors', _settings['rps_enabled'] as bool? ?? true, Icons.back_hand_rounded, (v) => _updateSetting('rps_enabled', v)),
      _ToggleCard('Trivia Quiz', 'Knowledge battle', _settings['trivia_enabled'] as bool? ?? true, Icons.quiz_rounded, (v) => _updateSetting('trivia_enabled', v)),
      _ToggleCard('Reaction Tap', 'Reflex speed game', _settings['reaction_enabled'] as bool? ?? true, Icons.flash_on_rounded, (v) => _updateSetting('reaction_enabled', v)),
      const SizedBox(height: 16),

      // Fee & stake settings
      _AdminTitle('Fee & Stake Settings'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Platform Fee %', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Percentage taken from each match pot', style: TextStyle(fontSize: 12, color: GacomColors.textMuted)),
          const SizedBox(height: 12),
          Row(children: [
            for (final fee in [5, 10, 15, 20, 25]) ...[
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); _updateFee(fee); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_settings['platform_fee_percent'] ?? 15) == fee ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (_settings['platform_fee_percent'] ?? 15) == fee ? GacomColors.deepOrange : GacomColors.border),
                  ),
                  child: Text('$fee%', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: (_settings['platform_fee_percent'] ?? 15) == fee ? GacomColors.deepOrange : GacomColors.textMuted)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          const Text('Stake Limits (₦)', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StakeInput('Min', _settings['min_stake']?.toString() ?? '200', (v) { final n = int.tryParse(v); if (n != null) _updateStakeLimits(n, _settings['max_stake'] as int? ?? 50000); })),
            const SizedBox(width: 12),
            Expanded(child: _StakeInput('Max', _settings['max_stake']?.toString() ?? '50000', (v) { final n = int.tryParse(v); if (n != null) _updateStakeLimits(_settings['min_stake'] as int? ?? 200, n); })),
          ]),
        ]),
      ),
      const SizedBox(height: 24),

      // Disputes
      _AdminTitle('Open Disputes (${_disputes.length})'),
      const SizedBox(height: 10),
      if (_disputes.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
          child: const Center(child: Text('No open disputes 🎉', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontSize: 16))),
        )
      else
        ..._disputes.map((d) {
          final match = d['match'] as Map? ?? {};
          final raiser = d['raiser'] as Map? ?? {};
          final raiserName = raiser['username'] ?? raiser['display_name'] ?? 'Unknown';
          final gameType = match['game_type'] as String? ?? 'unknown';
          final stake = match['stake_amount'] as int? ?? 0;
          final creatorId = match['creator_id'] as String?;
          final opponentId = match['opponent_id'] as String?;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.error.withOpacity(0.3), width: 0.8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: GacomColors.warning, size: 16),
                const SizedBox(width: 8),
                Text('$raiserName · $gameType · ₦$stake', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
              ]),
              const SizedBox(height: 4),
              Text(d['reason'] as String? ?? '', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _DisputeBtn('Award Creator', GacomColors.info, () => _resolveDispute(d, creatorId))),
                const SizedBox(width: 8),
                Expanded(child: _DisputeBtn('Award Opponent', GacomColors.info, () => _resolveDispute(d, opponentId))),
                const SizedBox(width: 8),
                Expanded(child: _DisputeBtn('Refund Both', GacomColors.warning, () => _resolveDispute(d, null))),
              ]),
              if (creatorId != null || opponentId != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  if (creatorId != null) TextButton(onPressed: () => _banPlayer(creatorId), child: const Text('Ban Creator', style: TextStyle(color: GacomColors.error, fontSize: 11))),
                  if (opponentId != null) TextButton(onPressed: () => _banPlayer(opponentId), child: const Text('Ban Opponent', style: TextStyle(color: GacomColors.error, fontSize: 11))),
                ]),
              ],
            ]),
          );
        }),
      const SizedBox(height: 40),
    ]);
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _AdminTitle extends StatelessWidget {
  final String text;
  const _AdminTitle(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 16, decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
  ]);
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: GacomColors.textMuted)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: color)),
    ]),
  );
}

class _ToggleCard extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final IconData icon;
  final Function(bool) onChanged;
  const _ToggleCard(this.title, this.subtitle, this.value, this.icon, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 0.5)),
    child: Row(children: [
      Icon(icon, color: value ? GacomColors.deepOrange : GacomColors.textMuted, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: GacomColors.deepOrange),
    ]),
  );
}

class _DisputeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DisputeBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
      child: Center(child: Text(label, style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11))),
    ),
  );
}

class _StakeInput extends StatelessWidget {
  final String label, initial;
  final Function(String) onSubmit;
  const _StakeInput(this.label, this.initial, this.onSubmit);
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initial);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
        onSubmitted: onSubmit,
        decoration: InputDecoration(prefixText: '₦ ', prefixStyle: const TextStyle(color: GacomColors.deepOrange), filled: true, fillColor: GacomColors.surfaceDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GacomColors.border)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      ),
    ]);
  }
}
