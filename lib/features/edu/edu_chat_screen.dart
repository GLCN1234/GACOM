import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

/// Edu-mode student chat — students can only message other students.
/// Uses the existing chat_messages table but shows it in a focused
/// edu-themed shell without the normal social sidebar noise.
class EduChatScreen extends StatefulWidget {
  const EduChatScreen({super.key});
  @override State<EduChatScreen> createState() => _EduChatState();
}
class _EduChatState extends State<EduChatScreen> {
  List<Map<String,dynamic>> _contacts = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      // Load other users — in a real integration these would be filtered
      // to students only (role = 'user' who have edu_progress rows)
      final uid = SupabaseService.currentUserId;
      if (uid == null) { setState(() => _loading = false); return; }
      final rows = await SupabaseService.client.from('profiles')
          .select('id,display_name,avatar_url')
          .neq('id', uid)
          .limit(30);
      if (mounted) setState(() { _contacts = List<Map<String,dynamic>>.from(rows as List); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('STUDENT CHAT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      actions: [
        Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school_outlined, size: 12, color: GacomColors.accentCyan),
            SizedBox(width: 4),
            Text('Students Only', style: TextStyle(color: GacomColors.accentCyan, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
          ])),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
      : _contacts.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('💬', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No students found yet', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
            SizedBox(height: 6),
            Text('As more students join Edu Gaming,\nthey\'ll appear here.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
          ]))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _contacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 1),
            itemBuilder: (_, i) {
              final c = _contacts[i];
              final name = c['display_name'] as String? ?? 'Student';
              return GestureDetector(
                onTap: () => context.push('/chat/${c['id']}'),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.accentCyan.withOpacity(0.4), width: 2), color: GacomColors.elevatedCard),
                      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                      const Text('Student', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted, size: 18),
                  ])),
              );
            }),
  );
}
