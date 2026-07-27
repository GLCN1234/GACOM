import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

class EduChatScreen extends StatefulWidget {
  const EduChatScreen({super.key});
  @override State<EduChatScreen> createState() => _EduChatState();
}

class _EduChatState extends State<EduChatScreen> {
  List<Map<String,dynamic>> _allContacts = [];
  List<Map<String,dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override void initState() { super.initState(); _load(); _searchCtrl.addListener(_onSearch); }
  @override void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) { setState(() => _loading = false); return; }
      // Load all other users — in production filter to edu_progress users
      final rows = await SupabaseService.client
          .from('profiles').select('id,display_name,username,avatar_url').neq('id', uid).limit(100);
      if (mounted) setState(() {
        _allContacts = List<Map<String,dynamic>>.from(rows as List);
        _filtered = List.from(_allContacts);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty ? List.from(_allContacts) : _allContacts.where((c) {
          final name = (c['display_name'] ?? '').toString().toLowerCase();
          final uname = (c['username'] ?? '').toString().toLowerCase();
          return name.contains(q) || uname.contains(q);
        }).toList();
      });
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('STUDY CHAT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
      actions: [
        Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school_outlined, size: 12, color: GacomColors.accentCyan),
            SizedBox(width: 4),
            Text('Students Only', style: TextStyle(color: GacomColors.accentCyan, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
          ])),
      ],
    ),
    body: Column(children: [
      // Search bar
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: GacomColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _searchCtrl,
              style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontFamily: 'Rajdhani'),
              decoration: const InputDecoration(hintText: 'Search by name or username...', hintStyle: TextStyle(color: GacomColors.textMuted, fontSize: 13), border: InputBorder.none, isCollapsed: true),
            )),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(onTap: () { _searchCtrl.clear(); },
                child: const Icon(Icons.close_rounded, color: GacomColors.textMuted, size: 16)),
          ]))),
      const SizedBox(height: 8),

      // Results
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
        : _filtered.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.search_off_rounded, size: 48, color: GacomColors.textMuted),
              const SizedBox(height: 12),
              Text(_searchCtrl.text.isEmpty ? 'No students found yet' : 'No results for "${_searchCtrl.text}"',
                style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Students who join Edu Gaming will appear here.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final name = c['display_name'] as String? ?? 'Student';
                final username = c['username'] as String? ?? '';
                return GestureDetector(
                  onTap: () => context.push('/chat/${c['id']}'),
                  child: Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                    child: Row(children: [
                      Container(width: 46, height: 46,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GacomColors.accentCyan.withOpacity(0.4), width: 2), color: GacomColors.elevatedCard),
                        child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                        if (username.isNotEmpty)
                          Text('@$username', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                      ])),
                      const Icon(Icons.chat_bubble_outline_rounded, color: GacomColors.textMuted, size: 18),
                    ])),
                );
              })),
    ]),
  );
}
