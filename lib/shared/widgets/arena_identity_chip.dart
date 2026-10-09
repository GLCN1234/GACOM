import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/services/supabase_service.dart';
import 'cosmetic_avatar.dart';

/// A small, non-interactive badge for the corner of any game: the player's
/// equipped avatar frame and title, so what they bought shows in every game.
class ArenaIdentityChip extends StatefulWidget {
  const ArenaIdentityChip({super.key});

  @override
  State<ArenaIdentityChip> createState() => _ArenaIdentityChipState();
}

class _ArenaIdentityChipState extends State<ArenaIdentityChip> {
  @override
  void initState() {
    super.initState();
    try {
      CosmeticsService.ensureLoaded();
    } catch (_) {}
  }

  String _name() {
    try {
      final user = SupabaseService.client.auth.currentUser;
      final meta = user?.userMetadata;
      final String? n = (meta?['username'] ?? meta?['full_name'] ?? meta?['name'])?.toString();
      if (n != null && n.trim().isNotEmpty) return n.trim();
      final String? mail = user?.email;
      if (mail != null && mail.contains('@')) return mail.split('@').first;
    } catch (_) {}
    return 'Player';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: CosmeticsService.myLoadout,
      builder: (BuildContext context, Map<String, dynamic>? loadout, Widget? _) {
        if (loadout == null || loadout.isEmpty) return const SizedBox.shrink();
        final bool hasFrame = cosmeticFrameColors(equipped: loadout) != null;
        final String? title = cosmeticTitleFor(loadout);
        if (!hasFrame && title == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(color: const Color(0xAA0B0B0F), borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            CosmeticAvatar(name: _name(), radius: 12, equipped: loadout),
            if (title != null) ...<Widget>[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        );
      },
    );
  }
}
