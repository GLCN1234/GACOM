import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final data = await SupabaseService.client
          .from('chat_members')
          .select('chat:chats(*, members:chat_members(user:profiles!user_id(id, username, display_name, avatar_url)))')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(30);
      if (mounted) setState(() {
        _chats = List<Map<String, dynamic>>.from(data.map((e) => e['chat']).where((c) => c != null));
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  /// Start or resume a DM with another user.
  Future<void> _startDm(String otherUserId) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null || myId == otherUserId) return;

    // Check if DM already exists
    try {
      final existing = await SupabaseService.client
          .from('chats').select('id, members:chat_members(user_id)')
          .eq('type', 'direct').limit(100);

      String? existingChatId;
      for (final chat in existing as List) {
        final members = (chat['members'] as List? ?? []).map((m) => m['user_id'] as String).toSet();
        if (members.contains(myId) && members.contains(otherUserId) && members.length == 2) {
          existingChatId = chat['id'] as String;
          break;
        }
      }

      if (existingChatId != null) {
        if (mounted) context.go('/chat/$existingChatId');
        return;
      }

      // Create new DM
      final chat = await SupabaseService.client.from('chats').insert({
        'type': 'direct',
        'created_by': myId,
        'last_message_at': DateTime.now().toIso8601String(),
      }).select().single();

      final chatId = chat['id'] as String;
      await SupabaseService.client.from('chat_members').insert([
        {'chat_id': chatId, 'user_id': myId},
        {'chat_id': chatId, 'user_id': otherUserId},
      ]);

      if (mounted) context.go('/chat/$chatId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e'), backgroundColor: GacomColors.error));
      }
    }
  }

  void _showNewDmSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NewDmSheet(onSelectUser: (uid) { Navigator.pop(context); _startDm(uid); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('MESSAGES'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, color: GacomColors.deepOrange), tooltip: 'New Message', onPressed: _showNewDmSheet),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _chats.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: GacomColors.cardDark, shape: BoxShape.circle, border: Border.all(color: GacomColors.border)), child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: GacomColors.textMuted)),
                  const SizedBox(height: 20),
                  const Text('No conversations yet', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Tap the edit icon to start a DM', style: TextStyle(color: GacomColors.textMuted)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('NEW MESSAGE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                    onPressed: _showNewDmSheet,
                  ),
                ]))
              : RefreshIndicator(color: GacomColors.deepOrange, onRefresh: () async { setState(() => _loading = true); await _load(); },
                  child: ListView.builder(itemCount: _chats.length, itemBuilder: (_, i) => _ChatTile(chat: _chats[i]))),
    );
  }
}

// ── Chat Tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  const _ChatTile({required this.chat});
  @override
  Widget build(BuildContext context) {
    final isGroup = chat['type'] == 'group';
    final lastAt = DateTime.tryParse(chat['last_message_at'] ?? '') ?? DateTime.now();
    final members = chat['members'] as List? ?? [];
    final userId = SupabaseService.currentUserId;
    Map<String, dynamic>? other;
    if (!isGroup) {
      final m = members.firstWhere((m) => (m['user'] as Map?)?['id'] != userId, orElse: () => {});
      other = (m as Map?)?['user'] as Map<String, dynamic>?;
    }
    final name = isGroup ? (chat['name'] ?? 'Group Chat') : (other?['display_name'] ?? 'User');
    final avatar = isGroup ? chat['icon_url'] : other?['avatar_url'];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => context.go('/chat/${chat['id']}'),
      leading: CircleAvatar(radius: 26, backgroundColor: GacomColors.border, backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
        child: avatar == null ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)) : null),
      title: Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
      subtitle: Text(chat['last_message_preview'] ?? 'Start a conversation', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(timeago.format(lastAt, allowFromNow: true), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
    );
  }
}

// ── New DM Sheet — search users to start a chat ───────────────────────────────
class _NewDmSheet extends StatefulWidget {
  final Function(String userId) onSelectUser;
  const _NewDmSheet({required this.onSelectUser});
  @override State<_NewDmSheet> createState() => _NewDmSheetState();
}

class _NewDmSheetState extends State<_NewDmSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) { setState(() => _users = []); return; }
    setState(() => _searching = true);
    try {
      final myId = SupabaseService.currentUserId;
      final data = await SupabaseService.client.from('profiles')
          .select('id, username, display_name, avatar_url, verification_status')
          .ilike('username', '%${query.trim()}%')
          .neq('id', myId ?? '').limit(20);
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _searching = false; });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
      builder: (_, scroll) => Column(children: [
        Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2)))),
        const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 16), child: Text('New Message', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(controller: _searchCtrl, autofocus: true, onChanged: _search,
            style: const TextStyle(color: GacomColors.textPrimary),
            decoration: InputDecoration(hintText: 'Search by @username...', hintStyle: const TextStyle(color: GacomColors.textMuted), prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted), filled: true, fillColor: GacomColors.surfaceDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border))))),
        Expanded(child: _searching
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _users.isEmpty
            ? Center(child: Text(_searchCtrl.text.isEmpty ? 'Type a username to search' : 'No users found', style: const TextStyle(color: GacomColors.textMuted)))
            : ListView.builder(controller: scroll, itemCount: _users.length, itemBuilder: (_, i) {
                final u = _users[i];
                return ListTile(
                  leading: CircleAvatar(radius: 22, backgroundColor: GacomColors.border, backgroundImage: u['avatar_url'] != null ? CachedNetworkImageProvider(u['avatar_url']) : null, child: u['avatar_url'] == null ? Text((u['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary)) : null),
                  title: Row(children: [Text(u['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary)), if (u['verification_status'] == 'verified') ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 13, color: GacomColors.deepOrange)]]),
                  subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                  onTap: () => widget.onSelectUser(u['id'] as String),
                );
              })),
      ]));
  }
}
