import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

/// The verification tick. Its colour follows the member's level (Verified, Plus, Pro, Elite, Legend).
/// Colours are read once from the server so a change made in the admin screen shows up everywhere.
class VerifiedTick extends StatelessWidget {
  final String? tier;
  final double size;
  const VerifiedTick({super.key, this.tier, this.size = 14});

  static const Map<String, Color> _defaults = {
    'verified': Color(0xFF3B82F6),
    'plus': Color(0xFF14B8A6),
    'pro': Color(0xFFF59E0B),
    'elite': Color(0xFF8B5CF6),
    'legend': Color(0xFFEF4444),
  };
  static final Map<String, Color> _loaded = {};
  static final ValueNotifier<int> _rev = ValueNotifier<int>(0);
  static bool _loading = false;

  static Color colorOf(String? tier) => _loaded[tier] ?? _defaults[tier] ?? _defaults['verified']!;

  static Future<void> _load() async {
    if (_loading || _loaded.isNotEmpty) return;
    _loading = true;
    try {
      final rows = await SupabaseService.client.from('verification_tiers').select('code, color');
      for (final r in (rows as List)) {
        final hex = (r['color'] as String? ?? '').replaceAll('#', '');
        final v = int.tryParse(hex, radix: 16);
        if (v != null && hex.length == 6) _loaded['${r['code']}'] = Color(0xFF000000 | v);
      }
      _rev.value++;
    } catch (_) {}
    _loading = false;
  }

  @override
  Widget build(BuildContext context) {
    _load();
    return ValueListenableBuilder<int>(
      valueListenable: _rev,
      builder: (_, __, ___) => Icon(Icons.verified_rounded, size: size, color: colorOf(tier)),
    );
  }
}
