import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await NotificationService.list();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  IconData _iconFor(String type) => switch (type) {
    'house' => Icons.groups_rounded,
    'competition' => Icons.emoji_events_rounded,
    'chat' => Icons.chat_bubble_rounded,
    'subscription' => Icons.school_rounded,
    _ => Icons.notifications_rounded,
  };

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('NOTIFICATIONS'), actions: [
      if (_items.any((n) => n['read'] != true))
        TextButton(
          onPressed: () async { await NotificationService.markAllRead(); _load(); },
          child: const Text('Mark all read', style: TextStyle(color: GacomColors.deepOrange, fontSize: 12)),
        ),
    ]),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _items.isEmpty
        ? const Center(child: Text('No notifications yet.', style: TextStyle(color: GacomColors.textMuted)))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = _items[i];
                final unread = n['read'] != true;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    if (unread) await NotificationService.markRead(n['id'] as String);
                    final route = n['link_route'] as String?;
                    if (route != null && mounted) context.go(route);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: unread ? GacomColors.deepOrange.withOpacity(0.08) : GacomColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: unread ? GacomColors.deepOrange.withOpacity(0.3) : GacomColors.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(_iconFor(n['type'] as String? ?? 'general'), color: GacomColors.deepOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title'] as String? ?? '', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 14, color: GacomColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(n['body'] as String? ?? '', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_timeAgo(n['created_at'] as String? ?? ''), style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
                        if (unread) Container(margin: const EdgeInsets.only(top: 6), width: 8, height: 8, decoration: const BoxDecoration(color: GacomColors.deepOrange, shape: BoxShape.circle)),
                      ]),
                    ]),
                  ),
                );
              },
            ),
          ),
  );
}
