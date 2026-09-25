import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/cosmetics_service.dart';
import '../../features/edu/edu_subscription_service.dart';
import '../widgets/gacom_snackbar.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});
  @override State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  bool _loading = true;
  bool _isPro = false;
  Map<String, List<Map<String, dynamic>>> _catalogs = {};
  Map<String, dynamic>? _equipped;

  static const _categories = ['name_color', 'badge', 'avatar_frame'];
  static const _labels = {'name_color': 'Name Color', 'badge': 'Badge', 'avatar_frame': 'Avatar Frame'};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) { setState(() => _loading = false); return; }
    final isPro = await EduSubscriptionService.isPro();
    final catalogs = <String, List<Map<String, dynamic>>>{};
    for (final cat in _categories) { catalogs[cat] = await CosmeticsService.catalog(cat); }
    final equipped = await CosmeticsService.equipped(uid);
    if (mounted) setState(() { _isPro = isPro; _catalogs = catalogs; _equipped = equipped; _loading = false; });
  }

  Future<void> _equip(String category, Map<String, dynamic> item) async {
    if (item['requires_premium'] == true && !_isPro) {
      GacomSnackbar.show(context, 'This one\'s premium-only — upgrade to unlock it', isError: true);
      return;
    }
    final ok = await CosmeticsService.equip(category: category, itemId: item['id']);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('CUSTOMIZATION')),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(16), children: [
          if (!_isPro) Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
            child: const Text('Purely cosmetic — none of this affects scoring or matchmaking. Premium items are marked with a lock.',
              style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4))),
          for (final cat in _categories) ..._section(cat),
        ]),
  );

  List<Widget> _section(String category) {
    final items = _catalogs[category] ?? [];
    final equippedId = switch (category) {
      'name_color' => _equipped?['equipped_name_color'],
      'badge' => _equipped?['equipped_badge'],
      'avatar_frame' => _equipped?['equipped_avatar_frame'],
      _ => null,
    };
    return [
      Text(_labels[category] ?? category, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: items.map((item) {
        final locked = item['requires_premium'] == true && !_isPro;
        final selected = item['id'] == equippedId;
        return GestureDetector(
          onTap: () => _equip(category, item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? GacomColors.deepOrange : GacomColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (category == 'name_color' && (item['value'] as String).isNotEmpty)
                Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(int.tryParse((item['value'] as String).replaceFirst('#', '0xFF')) ?? 0xFFFFFFFF))),
              Text(item['name'] as String? ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? GacomColors.deepOrange : GacomColors.textSecondary)),
              if (locked) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.lock_rounded, size: 12, color: GacomColors.textMuted)),
            ]),
          ),
        );
      }).toList()),
      const SizedBox(height: 24),
    ];
  }
}
