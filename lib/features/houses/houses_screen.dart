import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/gacom_snackbar.dart';
import '../edu/edu_subscription_service.dart';
import 'house_service.dart';
import 'widgets/house_actions.dart';
import 'widgets/house_visuals.dart';

class HousesScreen extends StatefulWidget {
  const HousesScreen({super.key});
  @override
  State<HousesScreen> createState() => _HousesScreenState();
}

class _HousesScreenState extends State<HousesScreen> {
  bool _loading = true;
  String? _error;
  bool _week = false;
  bool _isPro = false;
  List<HouseSummary> _all = [];
  List<HouseSummary> _weekRows = [];
  UserHouse? _mine;
  String _query = '';
  String? _busyId;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final uid = SupabaseService.currentUserId;
      final results = await Future.wait([
        HouseService.leaderboard(week: false),
        HouseService.leaderboard(week: true),
        uid == null ? Future<UserHouse?>.value(null) : HouseService.userHouse(uid),
        EduSubscriptionService.isPro(),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<HouseSummary>;
        _weekRows = results[1] as List<HouseSummary>;
        _mine = results[2] as UserHouse?;
        _isPro = results[3] as bool;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = HouseService.friendlyError(e); });
    }
  }

  List<HouseSummary> get _rows {
    final base = _week ? _weekRows : _all;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((h) => h.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _join(HouseSummary h) async {
    if (_mine != null) {
      GacomSnackbar.show(context, 'Leave your current house before joining another', isError: true);
      return;
    }
    setState(() => _busyId = h.id);
    final changed = await houseJoinFlow(context, houseId: h.id, houseName: h.name, isOpen: h.isOpen);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (changed) _load(silent: true);
  }

  void _openFound() {
    if (_mine != null) {
      GacomSnackbar.show(context, 'Leave your current house before founding a new one', isError: true);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.elevatedCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FoundHouseSheet(
        isPro: _isPro,
        onFounded: (id) {
          if (!mounted) return;
          context.push('/houses/$id').then((_) { if (mounted) _load(silent: true); });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('HOUSES')),
      floatingActionButton: (_loading || _error != null || _mine != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: _openFound,
              backgroundColor: GacomColors.deepOrange,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('FOUND A HOUSE', style: houseHeading(size: 14, color: Colors.white)),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: _buildList(),
                ),
    );
  }

  Widget _buildList() {
    final rows = _rows;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (_mine != null) _myHouseCard(_mine!),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: GacomColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search houses',
            hintStyle: const TextStyle(color: GacomColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: GacomColors.textMuted, size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                  ),
            filled: true,
            fillColor: GacomColors.cardDark,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _tab('ALL TIME', !_week, () => setState(() => _week = false)),
          const SizedBox(width: 8),
          _tab('THIS WEEK', _week, () => setState(() => _week = true)),
        ]),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                _query.isNotEmpty ? 'No house matches "$_query".' : 'No houses yet. Be the first to found one.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GacomColors.textMuted),
              ),
            ),
          )
        else
          ...rows.map(_houseCard),
      ],
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? GacomColors.deepOrange : GacomColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? GacomColors.deepOrange : GacomColors.border),
            ),
            child: Text(label, style: houseHeading(size: 14, color: active ? Colors.white : GacomColors.textSecondary)),
          ),
        ),
      );

  Widget _myHouseCard(UserHouse m) {
    HouseSummary? row;
    for (final h in _all) {
      if (h.id == m.houseId) { row = h; break; }
    }
    final color = houseColor(m.colorHex);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: houseBannerGradient(row?.banner, m.colorHex),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/houses/${m.houseId}').then((_) { if (mounted) _load(silent: true); }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MY HOUSE', style: houseHeading(size: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            Row(children: [
              HouseEmblem(emblem: row?.emblem ?? m.emblem, colorHex: m.colorHex, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: houseHeading(size: 20, color: Colors.white)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    HouseRoleChip(role: m.role),
                    if (row != null) HouseChip(label: 'LEVEL ${row.level}', color: Colors.white),
                    if (row != null) HouseChip(label: 'RANK #${row.rank}', color: Colors.white),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/houses/chat', extra: {'houseId': m.houseId, 'houseName': m.name}),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                label: Text('HOUSE CHAT', style: houseHeading(size: 14, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.35)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _houseCard(HouseSummary h) {
    final color = houseColor(h.colorHex);
    final isMine = _mine?.houseId == h.id;
    final pts = _week ? h.weekPoints : h.points;
    final busy = _busyId == h.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMine ? color : GacomColors.border, width: isMine ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/houses/${h.id}').then((_) { if (mounted) _load(silent: true); }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(
                width: 34,
                child: Text('#${h.rank}', style: houseHeading(size: 16, color: h.rank <= 3 ? GacomColors.gold : GacomColors.textMuted)),
              ),
              HouseEmblem(emblem: h.emblem, colorHex: h.colorHex, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: houseHeading(size: 17)),
                  if (h.motto != null && h.motto!.isNotEmpty)
                    Text(h.motto!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatPoints(pts), style: houseHeading(size: 18, color: color)),
                Text(_week ? 'this week' : 'points', style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              HouseChip(label: 'LEVEL ${h.level}', color: GacomColors.accentCyan),
              const SizedBox(width: 6),
              HouseChip(
                label: h.isOpen ? 'OPEN' : 'CLOSED',
                color: h.isOpen ? GacomColors.success : GacomColors.warning,
                icon: h.isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
              ),
              const SizedBox(width: 6),
              Icon(Icons.groups_rounded, size: 14, color: GacomColors.textMuted),
              const SizedBox(width: 3),
              Text('${h.members}/${h.memberLimit}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
              const Spacer(),
              if (isMine)
                const HouseChip(label: 'YOUR HOUSE', color: GacomColors.deepOrange)
              else if (_mine == null)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: busy ? null : () => _join(h),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(h.isOpen ? 'JOIN' : 'REQUEST', style: houseHeading(size: 13, color: Colors.white)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.groups_rounded, size: 40, color: GacomColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
              child: Text('TRY AGAIN', style: houseHeading(size: 14, color: Colors.white)),
            ),
          ]),
        ),
      );
}

class _FoundHouseSheet extends StatefulWidget {
  final bool isPro;
  final void Function(String houseId) onFounded;
  const _FoundHouseSheet({required this.isPro, required this.onFounded});
  @override
  State<_FoundHouseSheet> createState() => _FoundHouseSheetState();
}

class _FoundHouseSheetState extends State<_FoundHouseSheet> {
  final _name = TextEditingController();
  final _motto = TextEditingController();
  String _color = kHouseColors.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _motto.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 3 || name.length > 24) {
      setState(() => _error = 'House names need 3 to 24 characters');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final res = await HouseService.foundHouse(name: name, colorHex: _color, motto: _motto.text);
    if (!mounted) return;
    if (res.success && res.houseId != null) {
      final id = res.houseId!;
      final cb = widget.onFounded;
      Navigator.pop(context);
      cb(id);
    } else {
      setState(() { _busy = false; _error = res.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Found a House', style: houseHeading(size: 22)),
          const SizedBox(height: 6),
          Text(
            widget.isPro
                ? 'Founding a house is free with your premium membership.'
                : 'Founding a house costs ₦${HouseService.foundingFee} from your wallet. Premium members found houses for free.',
            style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 24,
            style: const TextStyle(color: GacomColors.textPrimary),
            decoration: const InputDecoration(labelText: 'House name', labelStyle: TextStyle(color: GacomColors.textMuted)),
          ),
          TextField(
            controller: _motto,
            maxLength: 80,
            style: const TextStyle(color: GacomColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Motto (optional)', labelStyle: TextStyle(color: GacomColors.textMuted)),
          ),
          const SizedBox(height: 8),
          Text('House colour', style: houseHeading(size: 13, color: GacomColors.textSecondary)),
          const SizedBox(height: 8),
          HouseColorPicker(selected: _color, onChanged: (c) => setState(() => _color = c)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: GacomColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.isPro ? 'FOUND HOUSE' : 'FOUND HOUSE (₦${HouseService.foundingFee})', style: houseHeading(size: 15, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
