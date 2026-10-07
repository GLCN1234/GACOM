import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../house_service.dart';
import 'house_visuals.dart';

/// Shows the house a user belongs to. On your own profile with no house it
/// becomes a prompt to join or found one. Self-contained: just pass the user id.
class HouseProfileCard extends StatefulWidget {
  final String userId;
  const HouseProfileCard({super.key, required this.userId});
  @override
  State<HouseProfileCard> createState() => _HouseProfileCardState();
}

class _HouseProfileCardState extends State<HouseProfileCard> {
  bool _loading = true;
  UserHouse? _house;
  HouseDetails? _details;

  bool get _isOwn => SupabaseService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HouseProfileCard old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final requested = widget.userId;
    if (!_loading) setState(() => _loading = true);
    UserHouse? house;
    HouseDetails? details;
    try {
      house = await HouseService.userHouse(requested);
      if (house != null) {
        try { details = await HouseService.details(house.houseId); } catch (_) {}
      }
    } catch (_) {}
    if (!mounted || requested != widget.userId) return;
    setState(() { _house = house; _details = details; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 72,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
      );
    }
    final h = _house;
    if (h == null) {
      if (!_isOwn) return const SizedBox.shrink();
      return _shell(
        color: GacomColors.deepOrange,
        onTap: () => context.push('/houses').then((_) { if (mounted) _load(); }),
        child: Row(children: [
          const HouseEmblem(colorHex: '#FF6A00', size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Join or found a house', style: houseHeading(size: 17)),
              const Text('Team up, climb the weekly ranks and win trophies.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
        ]),
      );
    }
    final color = houseColor(h.colorHex);
    final d = _details;
    return _shell(
      color: color,
      onTap: () => context.push('/houses/${h.houseId}').then((_) { if (mounted) _load(); }),
      child: Row(children: [
        HouseEmblem(emblem: h.emblem, colorHex: h.colorHex, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: houseHeading(size: 17)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              HouseRoleChip(role: h.role),
              if (d != null) HouseChip(label: 'LEVEL ${d.level}', color: GacomColors.accentCyan),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
      ]),
    );
  }

  Widget _shell({required Color color, required VoidCallback onTap, required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.6))),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      );
}
