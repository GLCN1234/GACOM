import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
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
  Map<String, dynamic>? _otherUser;
  bool _loading = true;
  RealtimeChannel? _channel;

  // For reply-to feature
  Map<String, dynamic>? _replyTo;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    final myId = SupabaseService.currentUserId;
    try {
      final chat = await SupabaseService.client
          .from('chats')
          .select('*')
          .eq('id', widget.chatId)
          .single();

      final msgs = await SupabaseService.client
          .from('messages')
          .select('*, sender:profiles!sender_id(id, username, display_name, avatar_url)')
          .eq('chat_id', widget.chatId)
          .eq('is_deleted', false)
          .order('created_at')
          .limit(80);

      // Get other user for DM
      Map<String, dynamic>? otherUser;
      if (chat['type'] == 'direct') {
        final members = await SupabaseService.client
            .from('chat_members')
            .select('user_id')
            .eq('chat_id', widget.chatId);
        final otherId = (members as List)
            .map((m) => m['user_id'] as String)
            .where((id) => id != myId)
            .firstOrNull;
        if (otherId != null) {
          try {
            otherUser = await SupabaseService.client
                .from('profiles')
                .select('id, display_name, username, avatar_url, is_online, verification_status')
                .eq('id', otherId)
                .single();
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _chat = chat;
          _otherUser = otherUser;
          _messages = List<Map<String, dynamic>>.from(msgs);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.client
        .channel('chat_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_id',
              value: widget.chatId),
          callback: (payload) {
            if (mounted) {
              setState(() => _messages.add(payload.newRecord));
              _scrollToBottom();
            }
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

    final payload = <String, dynamic>{
      'chat_id': widget.chatId,
      'sender_id': userId,
      'content': text,
    };
    if (_replyTo != null) {
      payload['reply_to_id'] = _replyTo!['id'];
    }

    setState(() => _replyTo = null);

    await SupabaseService.client.from('messages').insert(payload);
    await SupabaseService.client.from('chats').update({
      'last_message_at': DateTime.now().toIso8601String(),
      'last_message_preview': text,
    }).eq('id', widget.chatId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessageActions(Map<String, dynamic> msg, bool isMe) {
    HapticFeedback.mediumImpact();
    final content = msg['content'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: GacomColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // Reaction row — matches reference
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['🔥', '🙌', '😂', '🐐', '🙏', '😡'].map((e) =>
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      // React to message (future feature)
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: GacomColors.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: GacomColors.border)),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: GacomColors.border, height: 1),

            // Actions — matching reference (Copy, Reply, Forward, Delete)
            _ActionTile(
              icon: Icons.copy_outlined,
              label: 'Copy',
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ));
              },
            ),
            _ActionTile(
              icon: Icons.reply_outlined,
              label: 'Reply',
              onTap: () {
                setState(() => _replyTo = msg);
                Navigator.pop(context);
              },
            ),
            _ActionTile(
              icon: Icons.forward_outlined,
              label: 'Forward',
              onTap: () => Navigator.pop(context),
            ),
            if (isMe)
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: GacomColors.error,
                onTap: () async {
                  Navigator.pop(context);
                  await SupabaseService.client
                      .from('messages')
                      .update({'is_deleted': true}).eq('id', msg['id']);
                  setState(() =>
                      _messages.removeWhere((m) => m['id'] == msg['id']));
                },
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUserId;
    final isGroup = _chat?['type'] == 'group';
    final name = isGroup
        ? (_chat?['name'] ?? 'Group')
        : (_otherUser?['display_name'] ?? 'Chat');
    final avatar = isGroup ? _chat?['icon_url'] : _otherUser?['avatar_url'];
    final isOnline = _otherUser?['is_online'] == true;
    final isVerified = _otherUser?['verification_status'] == 'verified';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        backgroundColor: GacomColors.darkVoid,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/chat');
          },
        ),
        title: GestureDetector(
          onTap: () {
            // Tap header to view profile
            if (_otherUser != null) {
              context.push('/profile/${_otherUser!['id']}');
            }
          },
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: GacomColors.border,
                backgroundImage: avatar != null
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: GacomColors.textPrimary,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                        color: GacomColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: GacomColors.darkVoid, width: 2)),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name,
                    style: const TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: GacomColors.textPrimary)),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded,
                      size: 13, color: GacomColors.deepOrange),
                ],
              ]),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                    fontSize: 11,
                    color: isOnline
                        ? GacomColors.success
                        : GacomColors.textMuted),
              ),
            ]),
          ]),
        ),
        // Video + call icons matching the reference UI
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined,
                color: GacomColors.textSecondary, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined,
                color: GacomColors.textSecondary, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    final isMe = msg['sender_id'] == myId;
                    final sender =
                        msg['sender'] as Map<String, dynamic>? ?? {};

                    // Date separator
                    final showDate = i == 0 ||
                        !_sameDay(
                          DateTime.tryParse(_messages[i - 1]['created_at'] ?? '') ?? DateTime.now(),
                          DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now(),
                        );

                    return Column(children: [
                      if (showDate) _DateDivider(msg['created_at']),
                      GestureDetector(
                        onLongPress: () => _showMessageActions(msg, isMe),
                        child: _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          sender: sender,
                          replyTo: null, // future: resolve reply_to_id
                        ),
                      ),
                    ]);
                  },
                ),
              ),

              // Reply preview bar
              if (_replyTo != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  color: GacomColors.surfaceDark,
                  child: Row(children: [
                    Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                            color: GacomColors.deepOrange,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Replying to',
                          style: TextStyle(
                              color: GacomColors.deepOrange,
                              fontSize: 11,
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w700)),
                      Text(_replyTo!['content'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: GacomColors.textMuted, fontSize: 12)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: GacomColors.textMuted, size: 18),
                      onPressed: () => setState(() => _replyTo = null),
                    ),
                  ]),
                ),

              _buildInput(),
            ]),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
          color: GacomColors.darkVoid,
          border:
              Border(top: BorderSide(color: GacomColors.border, width: 0.5))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Attach button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: GacomColors.surfaceDark,
                shape: BoxShape.circle,
                border: Border.all(color: GacomColors.border)),
            child: const Icon(Icons.add_rounded,
                color: GacomColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 10),

          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: GacomColors.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GacomColors.border)),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(
                    color: GacomColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: GacomColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  gradient: GacomColors.orangeGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Date divider ───────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String? dateStr;
  const _DateDivider(this.dateStr);

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Today';
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider(color: GacomColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  color: GacomColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: GacomColors.border, height: 1)),
      ]),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Map<String, dynamic> sender;
  final Map<String, dynamic>? replyTo;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.sender,
    this.replyTo,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt =
        DateTime.tryParse(message['created_at'] ?? '') ?? DateTime.now();
    final content = message['content'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(
          bottom: 6,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: GacomColors.border,
              backgroundImage: sender['avatar_url'] != null
                  ? CachedNetworkImageProvider(sender['avatar_url'])
                  : null,
              child: sender['avatar_url'] == null
                  ? Text(
                      (sender['display_name'] ?? 'G')[0],
                      style: const TextStyle(
                          fontSize: 11,
                          color: GacomColors.textPrimary,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name (groups only)
                if (!isMe && (message['chat_type'] == 'group'))
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(sender['display_name'] ?? '',
                        style: const TextStyle(
                            color: GacomColors.deepOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Rajdhani')),
                  ),

                // Reply preview inside bubble
                if (replyTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: isMe
                            ? Colors.black26
                            : GacomColors.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                            left: BorderSide(
                                color: GacomColors.deepOrange, width: 3))),
                    child: Text(replyTo!['content'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isMe
                                ? Colors.white60
                                : GacomColors.textMuted,
                            fontSize: 12)),
                  ),

                // Main bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? GacomColors.deepOrange
                        : GacomColors.cardDark,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: isMe
                        ? null
                        : Border.all(
                            color: GacomColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content,
                          style: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : GacomColors.textPrimary,
                              fontSize: 15,
                              height: 1.4)),
                    ],
                  ),
                ),

                // Timestamp below bubble
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: GacomColors.textMuted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action tile in context menu ────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? GacomColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c, size: 20),
      title: Text(label,
          style: TextStyle(
              color: c,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      trailing: Icon(
        icon == Icons.copy_outlined
            ? Icons.copy_all_rounded
            : icon == Icons.reply_outlined
                ? Icons.reply_rounded
                : icon == Icons.forward_outlined
                    ? Icons.forward_rounded
                    : Icons.delete_outline_rounded,
        color: GacomColors.textMuted,
        size: 18,
      ),
    );
  }
}
