import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      // Use simple query - avoid nested chat_members to prevent recursion
      final memberRows = await SupabaseService.client
          .from('chat_members')
          .select('chat_id, joined_at')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(30);

      final chatIds = (memberRows as List).map((r) => r['chat_id'] as String).toList();

      if (chatIds.isEmpty) {
        if (mounted) setState(() { _chats = []; _loading = false; });
        return;
      }

      // Fetch chats separately
      final chats = await SupabaseService.client
          .from('chats')
          .select('*')
          .inFilter('id', chatIds)
          .order('last_message_at', ascending: false);

      // For each DM, fetch the other user's profile
      final enriched = <Map<String, dynamic>>[];
      for (final chat in chats as List) {
        final chatId = chat['id'] as String;
        // Get members of this chat
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

      // Active users for story-style row (online users the current user follows)
      final following = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId)
          .limit(20);

      final followingIds = (following as List).map((f) => f['following_id'] as String).toList();
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
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startDm(String otherUserId) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null || myId == otherUserId) return;

    try {
      // Use the safe server function to find existing DM
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not start chat: $e'),
          backgroundColor: GacomColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showNewDmSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewDmSheet(onSelectUser: (uid) {
        Navigator.pop(context);
        _startDm(uid);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Expanded(
                child: Text('Messages', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 26, fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_rounded, color: GacomColors.textSecondary),
              ),
              IconButton(
                onPressed: _showNewDmSheet,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),

          // ── Active users row (story-style) ────────────────────────────────
          if (_activeUsers.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _activeUsers.length,
                itemBuilder: (_, i) => _ActiveUserBubble(
                  user: _activeUsers[i],
                  onTap: () => _startDm(_activeUsers[i]['id']),
                ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.3, end: 0),
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 0, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Messages', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textMuted, letterSpacing: 1.5)),
            ),
          ),

          // ── Chat list ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                : _chats.isEmpty
                    ? _EmptyState(onNewMessage: _showNewDmSheet)
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
                          ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.15, end: 0),
                        ),
                      ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewDmSheet,
        backgroundColor: GacomColors.deepOrange,
        elevation: 4,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }
}

// ── Active user bubble (story style) ─────────────────────────────────────────
class _ActiveUserBubble extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _ActiveUserBubble({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline = user['is_online'] == true;
    final name = (user['display_name'] as String? ?? '').split(' ').first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(right: 12),
        child: Column(children: [
          Stack(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isOnline ? GacomColors.orangeGradient : null,
                color: isOnline ? null : GacomColors.border,
              ),
              padding: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                backgroundColor: GacomColors.cardDark,
                backgroundImage: user['avatar_url'] != null ? CachedNetworkImageProvider(user['avatar_url']) : null,
                child: user['avatar_url'] == null
                    ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 2, bottom: 2,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: GacomColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: GacomColors.obsidian, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 5),
          Text(name, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Chat tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final isGroup = chat['type'] == 'group';
    final lastAt = DateTime.tryParse(chat['last_message_at'] ?? '') ?? DateTime.now();
    final other = chat['_other_user'] as Map<String, dynamic>?;
    final name = isGroup ? (chat['name'] ?? 'Group Chat') : (other?['display_name'] ?? 'User');
    final avatar = isGroup ? chat['icon_url'] : other?['avatar_url'];
    final isOnline = other?['is_online'] == true;
    final isVerified = other?['verification_status'] == 'verified';
    final preview = chat['last_message_preview'] as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/chat/${chat['id']}'),
        splashColor: GacomColors.deepOrange.withOpacity(0.05),
        highlightColor: GacomColors.deepOrange.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            // Avatar with online indicator
            Stack(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: GacomColors.border,
                backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                child: avatar == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 1, bottom: 1,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: GacomColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: GacomColors.obsidian, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 14),

            // Name + preview
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary), overflow: TextOverflow.ellipsis)),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 14, color: GacomColors.deepOrange),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                preview ?? 'Start a conversation',
                style: TextStyle(color: preview != null ? GacomColors.textSecondary : GacomColors.textMuted, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ])),
            const SizedBox(width: 8),

            // Time + unread badge placeholder
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                timeago.format(lastAt, allowFromNow: true),
                style: const TextStyle(color: GacomColors.textMuted, fontSize: 11),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onNewMessage;
  const _EmptyState({required this.onNewMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: GacomColors.deepOrange.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: GacomColors.deepOrange.withOpacity(0.2), width: 1.5),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, size: 44, color: GacomColors.deepOrange),
        ).animate().scale(curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text('No messages yet', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Find a gamer and start a conversation', style: TextStyle(color: GacomColors.textMuted, fontSize: 14)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onNewMessage,
          style: ElevatedButton.styleFrom(
            backgroundColor: GacomColors.deepOrange,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('NEW MESSAGE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 1)),
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),
      ]),
    );
  }
}

// ── New DM search sheet ───────────────────────────────────────────────────────
class _NewDmSheet extends StatefulWidget {
  final Function(String userId) onSelectUser;
  const _NewDmSheet({required this.onSelectUser});

  @override
  State<_NewDmSheet> createState() => _NewDmSheetState();
}

class _NewDmSheetState extends State<_NewDmSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) { setState(() => _users = []); return; }
    setState(() => _searching = true);
    try {
      final myId = SupabaseService.currentUserId;
      final data = await SupabaseService.client
          .from('profiles')
          .select('id, username, display_name, avatar_url, verification_status, is_online')
          .or('username.ilike.%${query.trim()}%,display_name.ilike.%${query.trim()}%')
          .neq('id', myId ?? '')
          .limit(20);
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _searching = false; });
    } catch (_) { if (mounted) setState(() => _searching = false); }
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
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(alignment: Alignment.centerLeft, child: Text('New Message', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: _search,
                  style: const TextStyle(color: GacomColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name or @username...',
                    hintStyle: const TextStyle(color: GacomColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted),
                    filled: true,
                    fillColor: GacomColors.surfaceDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
                    : _users.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.person_search_rounded, size: 48, color: GacomColors.border),
                            const SizedBox(height: 12),
                            Text(
                              _ctrl.text.isEmpty ? 'Search for gamers to message' : 'No users found',
                              style: const TextStyle(color: GacomColors.textMuted),
                            ),
                          ]))
                        : ListView.builder(
                            controller: scroll,
                            itemCount: _users.length,
                            itemBuilder: (_, i) {
                              final u = _users[i];
                              final isOnline = u['is_online'] == true;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: Stack(children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: GacomColors.border,
                                    backgroundImage: u['avatar_url'] != null ? CachedNetworkImageProvider(u['avatar_url']) : null,
                                    child: u['avatar_url'] == null ? Text((u['display_name'] ?? 'G')[0], style: const TextStyle(color: GacomColors.textPrimary)) : null,
                                  ),
                                  if (isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: GacomColors.success, shape: BoxShape.circle, border: Border.all(color: GacomColors.cardDark, width: 2)))),
                                ]),
                                title: Row(children: [
                                  Text(u['display_name'] ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: GacomColors.textPrimary, fontSize: 16)),
                                  if (u['verification_status'] == 'verified') ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 14, color: GacomColors.deepOrange)],
                                ]),
                                subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                                trailing: isOnline
                                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(50)), child: const Text('Online', style: TextStyle(color: GacomColors.success, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)))
                                    : null,
                                onTap: () => widget.onSelectUser(u['id'] as String),
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
