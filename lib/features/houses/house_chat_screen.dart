import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/gacom_snackbar.dart';

class HouseChatScreen extends StatefulWidget {
  final String houseId;
  final String houseName;
  const HouseChatScreen({super.key, required this.houseId, required this.houseName});
  @override State<HouseChatScreen> createState() => _HouseChatScreenState();
}

class _HouseChatScreenState extends State<HouseChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, dynamic>> _profiles = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() { super.initState(); _subscribe(); }

  @override
  void dispose() { _sub?.cancel(); _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _subscribe() {
    _sub = SupabaseService.client.from('house_messages').stream(primaryKey: ['id'])
        .eq('house_id', widget.houseId)
        .order('created_at')
        .listen((rows) async {
      final list = List<Map<String, dynamic>>.from(rows);
      // Resolve any not-yet-seen senders' profile info — kept small and
      // cumulative rather than re-fetching everyone on every message.
      final missing = list.map((m) => m['user_id'] as String).toSet().difference(_profiles.keys.toSet());
      if (missing.isNotEmpty) {
        try {
          final profs = await SupabaseService.client.from('profiles').select('id, display_name, avatar_url').filter('id', 'in', '(${missing.join(',')})');
          for (final p in List<Map<String, dynamic>>.from(profs)) { _profiles[p['id'] as String] = p; }
        } catch (_) {}
      }
      if (mounted) {
        setState(() { _messages = list; _loading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        });
      }
    }, onError: (_) { if (mounted) setState(() => _loading = false); });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await SupabaseService.client.from('house_messages').insert({'house_id': widget.houseId, 'user_id': uid, 'message': text});
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Message failed to send: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = SupabaseService.currentUserId;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text('${widget.houseName} CHAT')),
      body: Column(children: [
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
            ? const Center(child: Text('No messages yet — say hello to your house.', style: TextStyle(color: GacomColors.textMuted)))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final isMe = m['user_id'] == myUid;
                  final profile = _profiles[m['user_id']];
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? GacomColors.deepOrange.withOpacity(0.2) : GacomColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isMe ? GacomColors.deepOrange.withOpacity(0.4) : GacomColors.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4),
                          child: Text(profile?['display_name'] as String? ?? 'Member', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.accentCyan))),
                        Text(m['message'] as String? ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14)),
                      ]),
                    ),
                  );
                })),
        SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _ctrl, style: const TextStyle(color: GacomColors.textPrimary),
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(hintText: 'Message your house...', hintStyle: const TextStyle(color: GacomColors.textMuted),
              filled: true, fillColor: GacomColors.cardDark, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          _sending
            ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: GacomColors.deepOrange)),
        ]))),
      ]),
    );
  }
}
