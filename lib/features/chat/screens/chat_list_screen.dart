import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _activeUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final memberRows = await SupabaseService.client
          .from('chat_members')
          .select('chat_id, joined_at')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(30);

      final chatIds = (memberRows as List)
          .map((r) => r['chat_id'] as String)
          .toList();

      if (chatIds.isEmpty) {
        if (mounted) setState(() { _chats = []; _loading = false; });
        return;
      }

      final chats = await SupabaseService.client
          .from('chats')
          .select('*')
          .inFilter('id', chatIds)
          .order('last_message_at', ascending: false);

      final enriched = <Map<String, dynamic>>[];
      for (final chat in chats as List) {
        final chatId = chat['id'] as String;
        final members = await SupabaseService.client
            .from('chat_members')
            .select('user_id')
            .eq('chat_id', chatId);

        final otherIds = (members as List)
            .map((m) => m['user_id'] as String)
            .where((id) => id != userId)
            .toList();

        Map<String, dynamic>? otherUser;
        if (otherIds.isNotEmpty && chat['type'] == 'direct') {
          try {
            final p = await SupabaseService.client
                .from('profiles')
                .select('id, username, display_name, avatar_url, is_online, verification_status')
                .eq('id', otherIds.first)
                .single();
            otherUser = p;
          } catch (_) {}
        }
        enriched.add({...chat as Map<String, dynamic>, '_other_user': otherUser});
      }

      // Active users (story row) — people you follow
      final following = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId)
          .limit(20);

      final followingIds = (following as List)
          .map((f) => f['following_id'] as String)
          .toList();

      List<Map<String, dynamic>> activeUsers = [];
      if (followingIds.isNotEmpty) {
        activeUsers = await SupabaseService.client
            .from('profiles')
            .select('id, username, display_name, avatar_url, is_online')
            .inFilter('id', followingIds)
            .order('is_online', ascending: false)
            .limit(12);
      }

      if (mounted) setState(() {
        _chats = enriched;
        _activeUsers = List<Map<String, dynamic>>.from(activeUsers);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startDm(String otherUserId) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null || myId == otherUserId) return;

    try {
      final result = await SupabaseService.client
          .rpc('get_direct_chats_for_user', params: {'uid': myId});

      String? existingChatId;
      for (final row in result as List) {
        if (row['other_user_id'] == otherUserId) {
          existingChatId = row['chat_id'] as String;
          break;
        }
      }

      if (existingChatId != null) {
        if (mounted) context.go('/chat/$existingChatId');
        return;
      }

      final newChatId = const Uuid().v4();
      await SupabaseService.client.from('chats').insert({
        'id': newChatId,
        'type': 'direct',
        'created_by': myId,
        'last_message_at': DateTime.now().toIso8601String(),
      });
      await SupabaseService.client.from('chat_members').insert([
        {'chat_id': newChatId, 'user_id': myId},
        {'chat_id': newChatId, 'user_id': otherUserId},
      ]);

      if (mounted) context.go('/chat/$newChatId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not start chat: $e'),
          backgroundColor: GacomColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showNewChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(
        onNewMessage: (uid) { Navigator.pop(context); _startDm(uid); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              const Expanded(
                child: Text('Messages',
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: GacomColors.textPrimary)),
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded,
                    color: GacomColors.textSecondary, size: 24),
                onPressed: () => context.go('/search'),
              ),
              // Three-dot menu matching the reference UI
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: GacomColors.textSecondary, size: 24),
                color: GacomColors.cardDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onSelected: (v) {
                  if (v == 'new_chat') _showNewChatSheet();
                },
                itemBuilder: (_) => [
                  _menuItem('new_chat', Icons.chat_outlined, 'New Chat'),
                  _menuItem('new_community', Icons.group_add_outlined,
                      'New Community'),
                ],
              ),
            ]),
          ),

          // ── Story-style active users row ─────────────────────────────────
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activeUsers.length + 1, // +1 for "Add story" button
              itemBuilder: (_, i) {
                if (i == 0) {
                  // "Add story" / new chat button — first item
                  return GestureDetector(
                    onTap: _showNewChatSheet,
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 14),
                      child: Column(children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: GacomColors.surfaceDark,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: GacomColors.border, width: 1.5),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: GacomColors.deepOrange, size: 26),
                        ),
                        const SizedBox(height: 6),
                        const Text('New',
                            style: TextStyle(
                                color: GacomColors.textMuted,
                                fontSize: 11,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  );
                }
                final u = _activeUsers[i - 1];
                final isOnline = u['is_online'] == true;
                final name = (u['display_name'] as String? ?? '')
                    .split(' ')
                    .first;
                return GestureDetector(
                  onTap: () => _startDm(u['id']),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 14),
                    child: Column(children: [
                      Stack(children: [
                        // Orange ring when online, grey when offline
                        Container(
                          width: 54,
                          height: 54,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isOnline
                                ? GacomColors.orangeGradient
                                : null,
                            color: isOnline
                                ? null
                                : GacomColors.border,
                          ),
                          child: CircleAvatar(
                            backgroundColor: GacomColors.cardDark,
                            backgroundImage: u['avatar_url'] != null
                                ? CachedNetworkImageProvider(u['avatar_url'])
                                : null,
                            child: u['avatar_url'] == null
                                ? Text(
                                    name.isNotEmpty ? name[0] : '?',
                                    style: const TextStyle(
                                        color: GacomColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18))
                                : null,
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: GacomColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: GacomColors.obsidian, width: 2),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      Text(name,
                          style: const TextStyle(
                              color: GacomColors.textSecondary,
                              fontSize: 11,
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ]),
                  ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.2),
                );
              },
            ),
          ),

          // ── "Chats" label ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              const Text('Chats',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GacomColors.textPrimary)),
              const Spacer(),
              // Three dots on the Chats section
              Icon(Icons.more_horiz_rounded,
                  color: GacomColors.textMuted, size: 20),
            ]),
          ),

          // ── Chat list ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: GacomColors.deepOrange))
                : _chats.isEmpty
                    ? _EmptyState(onNewChat: _showNewChatSheet)
                    : RefreshIndicator(
                        color: GacomColors.deepOrange,
                        backgroundColor: GacomColors.cardDark,
                        onRefresh: () async {
                          setState(() => _loading = true);
                          await _load();
                        },
                        child: ListView.builder(
                          itemCount: _chats.length,
                          itemBuilder: (_, i) => _ChatTile(
                            chat: _chats[i],
                            onTap: () =>
                                context.go('/chat/${_chats[i]['id']}'),
                          ).animate(delay: (i * 35).ms).fadeIn(),
                        ),
                      ),
          ),
        ]),
      ),

      // ── "+ New Chat" FAB — matches reference bottom centre button ────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewChatSheet,
        backgroundColor: GacomColors.deepOrange,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Chat',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, color: GacomColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: GacomColors.textPrimary,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ]),
      );
}

// ── Chat tile ──────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGroup = chat['type'] == 'group';
    final lastAt =
        DateTime.tryParse(chat['last_message_at'] ?? '') ?? DateTime.now();
    final other = chat['_other_user'] as Map<String, dynamic>?;
    final name = isGroup
        ? (chat['name'] ?? 'Group Chat')
        : (other?['display_name'] ?? 'User');
    final avatar = isGroup ? chat['icon_url'] : other?['avatar_url'];
    final isOnline = other?['is_online'] == true;
    final isVerified = other?['verification_status'] == 'verified';
    final preview = chat['last_message_preview'] as String?;
    final unread = (chat['unread_count'] as int?) ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: GacomColors.deepOrange.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            // Avatar + online dot
            Stack(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: GacomColors.border,
                backgroundImage: avatar != null
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: GacomColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20))
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: GacomColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: GacomColors.obsidian, width: 2.5),
                    ),
                  ),
                ),
            ]),

            const SizedBox(width: 14),

            // Name + preview
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: GacomColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: GacomColors.deepOrange),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(
                  preview ?? 'Start a conversation',
                  style: TextStyle(
                      color: preview != null
                          ? GacomColors.textSecondary
                          : GacomColors.textMuted,
                      fontSize: 13,
                      height: 1.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),

            const SizedBox(width: 10),

            // Time + unread badge — right side like reference
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Text(
                timeago.format(lastAt, allowFromNow: true),
                style: TextStyle(
                    color: unread > 0
                        ? GacomColors.deepOrange
                        : GacomColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'Rajdhani',
                    fontWeight: unread > 0
                        ? FontWeight.w700
                        : FontWeight.w500),
              ),
              const SizedBox(height: 4),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: GacomColors.deepOrange,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                )
              else
                const SizedBox(height: 18),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onNewChat;
  const _EmptyState({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: GacomColors.deepOrange.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
                color: GacomColors.deepOrange.withOpacity(0.2), width: 1.5),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 44, color: GacomColors.deepOrange),
        ).animate().scale(curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text('No messages yet',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: GacomColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Find a gamer and start a conversation',
            style: TextStyle(color: GacomColors.textMuted, fontSize: 14)),
      ]),
    );
  }
}

// ── New Chat bottom sheet ──────────────────────────────────────────────────────
class _NewChatSheet extends StatefulWidget {
  final Function(String userId) onNewMessage;
  const _NewChatSheet({required this.onNewMessage});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _searching = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _users = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final myId = SupabaseService.currentUserId;
      final data = await SupabaseService.client
          .from('profiles')
          .select(
              'id, username, display_name, avatar_url, verification_status, is_online')
          .or('username.ilike.%${q.trim()}%,display_name.ilike.%${q.trim()}%')
          .neq('id', myId ?? '')
          .limit(20);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (_, scroll) => Column(children: [
              const SizedBox(height: 10),
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: GacomColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),

              // Sheet title row — matches reference "New Message" style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Text('New Chat',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: GacomColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: GacomColors.surfaceDark,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: GacomColors.textMuted, size: 18),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: _search,
                  style: const TextStyle(
                      color: GacomColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search by name or @username…',
                    hintStyle:
                        const TextStyle(color: GacomColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: GacomColors.textMuted),
                    filled: true,
                    fillColor: GacomColors.surfaceDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: GacomColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: GacomColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: GacomColors.deepOrange, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: _searching
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: GacomColors.deepOrange))
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                              const Icon(Icons.person_search_rounded,
                                  size: 48, color: GacomColors.border),
                              const SizedBox(height: 12),
                              Text(
                                _ctrl.text.isEmpty
                                    ? 'Search for gamers'
                                    : 'No users found',
                                style: const TextStyle(
                                    color: GacomColors.textMuted),
                              ),
                            ]))
                        : ListView.builder(
                            controller: scroll,
                            itemCount: _users.length,
                            itemBuilder: (_, i) {
                              final u = _users[i];
                              final isOnline = u['is_online'] == true;
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 4),
                                leading: Stack(children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: GacomColors.border,
                                    backgroundImage:
                                        u['avatar_url'] != null
                                            ? CachedNetworkImageProvider(
                                                u['avatar_url'])
                                            : null,
                                    child: u['avatar_url'] == null
                                        ? Text(
                                            (u['display_name'] ??
                                                'G')[0],
                                            style: const TextStyle(
                                                color: GacomColors
                                                    .textPrimary))
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
                                                  color: GacomColors
                                                      .cardDark,
                                                  width: 2))),
                                    ),
                                ]),
                                title: Row(children: [
                                  Text(u['display_name'] ?? '',
                                      style: const TextStyle(
                                          fontFamily: 'Rajdhani',
                                          fontWeight: FontWeight.w700,
                                          color: GacomColors.textPrimary,
                                          fontSize: 16)),
                                  if (u['verification_status'] ==
                                      'verified') ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded,
                                        size: 14,
                                        color: GacomColors.deepOrange),
                                  ],
                                ]),
                                subtitle: Text(
                                    '@${u['username'] ?? ''}',
                                    style: const TextStyle(
                                        color: GacomColors.textMuted,
                                        fontSize: 12)),
                                trailing: isOnline
                                    ? Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3),
                                        decoration: BoxDecoration(
                                            color: GacomColors.success
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    50)),
                                        child: const Text('Online',
                                            style: TextStyle(
                                                color: GacomColors.success,
                                                fontSize: 11,
                                                fontFamily: 'Rajdhani',
                                                fontWeight:
                                                    FontWeight.w600)))
                                    : null,
                                onTap: () =>
                                    widget.onNewMessage(u['id'] as String),
                              ).animate(delay: (i * 30).ms).fadeIn();
                            },
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
