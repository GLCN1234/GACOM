import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatDetailScreen({super.key, required this.chatId});
  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _chat;
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() { super.initState(); _load(); _subscribeRealtime(); }

  Future<void> _load() async {
    try {
      final chat = await SupabaseService.client.from('chats').select('*, members:chat_members(user:profiles!user_id(id, username, display_name, avatar_url))').eq('id', widget.chatId).single();
      final msgs = await SupabaseService.client.from('messages').select('*, sender:profiles!sender_id(id, username, display_name, avatar_url)').eq('chat_id', widget.chatId).eq('is_deleted', false).order('created_at').limit(50);
      if (mounted) setState(() { _chat = chat; _messages = List<Map<String, dynamic>>.from(msgs); _loading = false; });
      _scrollToBottom();
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.client.channel('chat_${widget.chatId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: widget.chatId),
        callback: (payload) {
          if (mounted) setState(() => _messages.add(payload.newRecord));
          _scrollToBottom();
        },
      )
      .subscribe();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    await SupabaseService.client.from('messages').insert({'chat_id': widget.chatId, 'sender_id': userId, 'content': text});
    await SupabaseService.client.from('chats').update({'last_message_at': DateTime.now().toIso8601String(), 'last_message_preview': text}).eq('id', widget.chatId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() { _channel?.unsubscribe(); _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.currentUserId;
    final chatName = _chat?['name'] ?? 'Chat';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(chatName),
        actions: [IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {})],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_id'] == userId;
                      final sender = msg['sender'] as Map<String, dynamic>? ?? {};
                      return _MessageBubble(message: msg, isMe: isMe, sender: sender);
                    },
                  ),
                ),
                _buildInput(),
              ],
            ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(color: GacomColors.darkVoid, border: Border(top: BorderSide(color: GacomColors.border, width: 0.5))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.attach_file_rounded, color: GacomColors.textMuted), onPressed: () {}),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(24), border: Border.all(color: GacomColors.border)),
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: GacomColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(hintText: 'Message...', hintStyle: TextStyle(color: GacomColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                  maxLines: null,
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(gradient: GacomColors.orangeGradient, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Map<String, dynamic> sender;
  const _MessageBubble({required this.message, required this.isMe, required this.sender});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(message['created_at'] ?? '') ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: GacomColors.border,
              backgroundImage: sender['avatar_url'] != null ? CachedNetworkImageProvider(sender['avatar_url']) : null,
              child: sender['avatar_url'] == null ? Text((sender['display_name'] ?? 'G')[0], style: const TextStyle(fontSize: 12, color: GacomColors.textPrimary)) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? GacomColors.deepOrange : GacomColors.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: isMe ? null : Border.all(color: GacomColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) Text(sender['display_name'] ?? '', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')),
                  Text(message['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : GacomColors.textPrimary, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 2),
                  Text('${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}', style: TextStyle(color: isMe ? Colors.white60 : GacomColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
