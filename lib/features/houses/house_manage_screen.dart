import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/gacom_snackbar.dart';
import 'house_service.dart';
import 'widgets/house_visuals.dart';

class HouseManageScreen extends StatefulWidget {
  final String houseId;
  const HouseManageScreen({super.key, required this.houseId});
  @override
  State<HouseManageScreen> createState() => _HouseManageScreenState();
}

class _HouseManageScreenState extends State<HouseManageScreen> {
  bool _loading = true;
  String? _error;
  HouseDetails? _d;
  List<HouseShopItem> _items = [];
  double _balance = 0.0;
  bool _busy = false;
  bool _saving = false;
  bool _formReady = false;

  final _motto = TextEditingController();
  final _desc = TextEditingController();
  String _color = kHouseColors.first;
  bool _isOpen = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motto.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final d = await HouseService.details(widget.houseId);
      var items = _items;
      var balance = _balance;
      if (d != null && d.isCaptain) {
        try { items = await HouseService.shopItems(); } catch (_) {}
        try { balance = await HouseService.walletBalance(); } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _d = d;
        _items = items;
        _balance = balance;
        _loading = false;
        _error = null;
        if (d != null && !_formReady) {
          _motto.text = d.motto ?? '';
          _desc.text = d.description ?? '';
          _color = (d.colorHex ?? kHouseColors.first).toUpperCase();
          _isOpen = d.isOpen;
          _formReady = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = HouseService.friendlyError(e); });
    }
  }

  Future<void> _refreshBalance() async {
    try {
      final b = await HouseService.walletBalance();
      if (mounted) setState(() => _balance = b);
    } catch (_) {}
  }

  Future<bool> _confirm(String title, String body, String confirmLabel, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: houseHeading(size: 20)),
        content: Text(body, style: const TextStyle(color: GacomColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: TextStyle(color: danger ? GacomColors.error : GacomColors.deepOrange)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(Future<HouseResult> Function() action, String successText) async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    GacomSnackbar.show(context, res.success ? successText : res.message, isSuccess: res.success, isError: !res.success);
    if (res.success) _load(silent: true);
  }

  Future<void> _save(HouseDetails d) async {
    setState(() => _saving = true);
    final res = await HouseService.updateHouse(
      houseId: d.id,
      motto: _motto.text,
      description: _desc.text,
      colorHex: _color,
      isOpen: _isOpen,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    GacomSnackbar.show(context, res.success ? 'House updated' : res.message, isSuccess: res.success, isError: !res.success);
    if (res.success) _load(silent: true);
  }

  Future<void> _memberAction(HouseDetails d, HouseMember m, String action) async {
    switch (action) {
      case 'promote':
        await _run(() => HouseService.setRole(d.id, m.userId, 'officer'), '${m.name} is now an officer');
        break;
      case 'demote':
        await _run(() => HouseService.setRole(d.id, m.userId, 'member'), '${m.name} is now a member');
        break;
      case 'kick':
        if (await _confirm('Remove ${m.name}?', 'They will be removed from the house.', 'Remove', danger: true)) {
          await _run(() => HouseService.kickMember(d.id, m.userId), '${m.name} was removed');
        }
        break;
      case 'transfer':
        if (await _confirm('Make ${m.name} captain?',
            'They become the captain and you become an officer. Only the new captain can change this back.', 'Transfer', danger: true)) {
          await _run(() => HouseService.transferCaptain(d.id, m.userId), '${m.name} is the new captain');
        }
        break;
    }
  }

  Future<void> _leave(HouseDetails d) async {
    final last = d.memberCount <= 1;
    final ok = await _confirm(
      last ? 'Close ${d.name}?' : 'Leave ${d.name}?',
      last
          ? 'You are the last member, so the house will be closed for good.'
          : (d.isCaptain ? 'Leadership will pass to the next officer or longest-serving member.' : 'You can join again later.'),
      last ? 'Close house' : 'Leave',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final res = await HouseService.leaveHouse(d.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      GacomSnackbar.show(context, res.houseClosed ? 'The house has been closed' : 'You left ${d.name}', isSuccess: true);
      context.go('/houses');
    } else {
      GacomSnackbar.show(context, res.message, isError: true);
    }
  }

  Future<void> _pickItem(HouseDetails d, HouseShopItem item) async {
    final owned = item.price <= 0 || d.ownedItemIds.contains(item.id);
    if (!owned) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final short = _balance < item.price;
          return AlertDialog(
            backgroundColor: GacomColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Buy ${item.name}?', style: houseHeading(size: 20)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Price: ₦${formatPoints(item.price)}', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Your wallet: ₦${formatPoints(_balance.round())}', style: const TextStyle(color: GacomColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                short
                    ? 'You need ₦${formatPoints((item.price - _balance).ceil())} more. Add funds to your wallet first.'
                    : 'The house keeps this ${item.isEmblem ? 'emblem' : 'banner'} and it is equipped right away.',
                style: TextStyle(color: short ? GacomColors.warning : GacomColors.textSecondary, fontSize: 13),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
              if (short)
                TextButton(onPressed: () => Navigator.pop(ctx, 'wallet'), child: const Text('Add funds', style: TextStyle(color: GacomColors.deepOrange)))
              else
                TextButton(onPressed: () => Navigator.pop(ctx, 'buy'), child: const Text('Buy', style: TextStyle(color: GacomColors.deepOrange))),
            ],
          );
        },
      );
      if (!mounted) return;
      if (choice == 'wallet') {
        context.push('/wallet').then((_) => _refreshBalance());
        return;
      }
      if (choice != 'buy') return;
    }
    await _run(() async {
      final res = await HouseService.purchaseItem(d.id, item.id);
      if (res.success && res.balance != null && mounted) setState(() => _balance = res.balance!);
      return res;
    }, owned ? '${item.name} equipped' : '${item.name} purchased and equipped');
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('MANAGE HOUSE')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _centerMessage(_error!, 'TRY AGAIN', () => _load())
              : d == null
                  ? _centerMessage('This house no longer exists.', 'BACK TO HOUSES', () => context.go('/houses'))
                  : !d.canManage
                      ? _centerMessage('Only the captain and officers can manage this house.', 'BACK', () => context.pop())
                      : RefreshIndicator(onRefresh: () => _load(silent: true), child: _body(d)),
    );
  }

  Widget _centerMessage(String text, String button, VoidCallback onTap) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
              child: Text(button, style: houseHeading(size: 14, color: Colors.white)),
            ),
          ]),
        ),
      );

  Widget _section(String title, Widget child, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: houseHeading(size: 14, color: GacomColors.textSecondary)),
            const Spacer(),
            if (trailing != null) Text(trailing, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
        child: child,
      );

  Widget _body(HouseDetails d) {
    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _section('JOIN REQUESTS', _requests(d), trailing: '${d.requests.length} pending'),
          if (d.isCaptain) _section('HOUSE DETAILS', _form(d)),
          _section('MEMBERS', _memberList(d), trailing: '${d.memberCount}/${d.memberLimit}'),
          if (d.isCaptain) _section('EMBLEMS AND BANNERS', _shop(d), trailing: 'Wallet ₦${formatPoints(_balance.round())}'),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _leave(d),
              icon: const Icon(Icons.logout_rounded, color: GacomColors.error, size: 18),
              label: Text(d.memberCount <= 1 ? 'CLOSE HOUSE' : 'LEAVE HOUSE', style: houseHeading(size: 14, color: GacomColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.error), padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requests(HouseDetails d) {
    if (d.requests.isEmpty) {
      return _card(const Text('No pending requests.', style: TextStyle(color: GacomColors.textMuted)));
    }
    return Column(
      children: d.requests
          .map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    houseAvatar(r.avatarUrl, r.name),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600))),
                    IconButton(
                      tooltip: 'Decline',
                      onPressed: () => _run(() => HouseService.reviewRequest(r.id, false), 'Request declined'),
                      icon: const Icon(Icons.close_rounded, color: GacomColors.error),
                    ),
                    IconButton(
                      tooltip: 'Accept',
                      onPressed: () => _run(() => HouseService.reviewRequest(r.id, true), '${r.name} joined the house'),
                      icon: const Icon(Icons.check_rounded, color: GacomColors.success),
                    ),
                  ]),
                  if (r.message != null && r.message!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(r.message!, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
                    ),
                ]),
              ))
          .toList(),
    );
  }

  Widget _form(HouseDetails d) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _motto,
        maxLength: 80,
        style: const TextStyle(color: GacomColors.textPrimary),
        decoration: const InputDecoration(labelText: 'Motto', labelStyle: TextStyle(color: GacomColors.textMuted)),
      ),
      TextField(
        controller: _desc,
        maxLength: 400,
        maxLines: 4,
        minLines: 2,
        style: const TextStyle(color: GacomColors.textPrimary),
        decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: GacomColors.textMuted)),
      ),
      const SizedBox(height: 8),
      Text('House colour', style: houseHeading(size: 13, color: GacomColors.textSecondary)),
      const SizedBox(height: 8),
      HouseColorPicker(selected: _color, onChanged: (c) => setState(() => _color = c)),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: GacomColors.deepOrange,
        title: Text(_isOpen ? 'Open house' : 'Closed house', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(
          _isOpen ? 'Anyone can join straight away.' : 'Players must send a request that you approve.',
          style: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
        ),
        value: _isOpen,
        onChanged: (v) => setState(() => _isOpen = v),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : () => _save(d),
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('SAVE CHANGES', style: houseHeading(size: 15, color: Colors.white)),
        ),
      ),
    ]));
  }

  List<PopupMenuEntry<String>> _menuFor(HouseDetails d, HouseMember m) {
    final me = SupabaseService.currentUserId;
    if (m.isCaptain || m.userId == me) return [];
    if (d.isCaptain) {
      return [
        PopupMenuItem<String>(value: m.isOfficer ? 'demote' : 'promote', child: Text(m.isOfficer ? 'Make member' : 'Make officer')),
        const PopupMenuItem<String>(value: 'transfer', child: Text('Make captain')),
        const PopupMenuItem<String>(value: 'kick', child: Text('Remove from house')),
      ];
    }
    if (d.myRole == 'officer' && m.role == 'member') {
      return [const PopupMenuItem<String>(value: 'kick', child: Text('Remove from house'))];
    }
    return [];
  }

  Widget _memberList(HouseDetails d) {
    return Column(
      children: d.members.map((m) {
        final entries = _menuFor(d, m);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 4),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            houseAvatar(m.avatarUrl, m.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                HouseRoleChip(role: m.role),
              ]),
            ),
            Text(formatPoints(m.points), style: houseHeading(size: 14, color: GacomColors.textSecondary)),
            if (entries.isEmpty)
              const SizedBox(width: 48)
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: GacomColors.textSecondary),
                color: GacomColors.elevatedCard,
                onSelected: (a) => _memberAction(d, m, a),
                itemBuilder: (_) => entries,
              ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _shop(HouseDetails d) {
    final emblems = _items.where((i) => i.isEmblem).toList();
    final banners = _items.where((i) => i.isBanner).toList();
    if (emblems.isEmpty && banners.isEmpty) {
      return _card(const Text('The house shop is empty right now.', style: TextStyle(color: GacomColors.textMuted)));
    }
    final w = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    Widget grid(List<HouseShopItem> list) => Wrap(spacing: 10, runSpacing: 10, children: list.map((i) => _shopCard(d, i, w)).toList());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (emblems.isNotEmpty) ...[
        Text('Emblems', style: houseHeading(size: 15)),
        const SizedBox(height: 8),
        grid(emblems),
        const SizedBox(height: 16),
      ],
      if (banners.isNotEmpty) ...[
        Text('Banners', style: houseHeading(size: 15)),
        const SizedBox(height: 8),
        grid(banners),
      ],
    ]);
  }

  Widget _shopCard(HouseDetails d, HouseShopItem item, double width) {
    final equipped = item.isEmblem ? d.emblemItemId == item.id : d.bannerItemId == item.id;
    final owned = item.price <= 0 || d.ownedItemIds.contains(item.id);
    final String label;
    if (equipped) {
      label = 'EQUIPPED';
    } else if (owned) {
      label = 'USE';
    } else {
      label = '₦${formatPoints(item.price)}';
    }
    final preview = item.isEmblem
        ? HouseEmblem(emblem: item.value, colorHex: d.colorHex, size: 48)
        : Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(gradient: houseBannerGradient(item.asset, d.colorHex), borderRadius: BorderRadius.circular(10)),
          );
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: equipped ? GacomColors.deepOrange : GacomColors.border, width: equipped ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: preview),
        const SizedBox(height: 10),
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: houseHeading(size: 15)),
        Text(item.rarity.toUpperCase(), style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, letterSpacing: 0.6)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 34,
          child: ElevatedButton(
            onPressed: equipped ? null : () => _pickItem(d, item),
            style: ElevatedButton.styleFrom(
              backgroundColor: owned ? GacomColors.elevatedCard : GacomColors.deepOrange,
              disabledBackgroundColor: GacomColors.elevatedCard,
              padding: EdgeInsets.zero,
            ),
            child: Text(label, style: houseHeading(size: 13, color: equipped ? GacomColors.deepOrange : Colors.white)),
          ),
        ),
      ]),
    );
  }
}
