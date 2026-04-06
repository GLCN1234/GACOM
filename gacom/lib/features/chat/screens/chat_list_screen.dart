import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

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
      if (mounted) setState(() { _chats = List<Map<String, dynamic>>.from(data.map((e) => e['chat'])); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('MESSAGES'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : _chats.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: GacomColors.border),
                  SizedBox(height: 16),
                  Text('No conversations yet', style: TextStyle(color: GacomColors.textMuted)),
                ]))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (_, i) => _ChatTile(chat: _chats[i]),
                ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final isGroup = chat['type'] == 'group';
    final lastAt = DateTime.tryParse(chat['last_message_at'] ?? '') ?? DateTime.now();
    final members = (chat['members'] as List? ?? []);
    final userId = SupabaseService.currentUserId;
    Map<String, dynamic>? other;
    if (!isGroup) {
      other = members.firstWhere((m) => (m['user'] as Map?)?['id'] != userId, orElse: () => {})['user'] as Map<String, dynamic>?;
    }
    final name = isGroup ? (chat['name'] ?? 'Group Chat') : (other?['display_name'] ?? 'User');
    final avatar = isGroup ? chat['icon_url'] : other?['avatar_url'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => context.go('/chat/${chat['id']}'),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: GacomColors.border,
        backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
        child: avatar == null ? Text(name[0], style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)) : null,
      ),
      title: Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
      subtitle: Text(chat['last_message_preview'] ?? 'Start a conversation', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(timeago.format(lastAt, allowFromNow: true), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
    );
  }
}
