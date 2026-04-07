import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// For Exco customer agents to see & respond to support tickets
class AgentChatScreen extends ConsumerStatefulWidget {
  const AgentChatScreen({super.key});
  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _isAgent = false;

  @override
  void initState() {
    super.initState();
    _checkAgent();
  }

  Future<void> _checkAgent() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final assign = await SupabaseService.client
          .from('exco_assignments')
          .select('exco_role')
          .eq('exco_id', userId)
          .eq('exco_role', 'customer_agent')
          .maybeSingle();
      if (assign != null) {
        _isAgent = true;
        await _loadTickets();
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTickets() async {
    final userId = SupabaseService.currentUserId;
    try {
      final tickets = await SupabaseService.client
          .from('support_tickets')
          .select(
              '*, user:profiles!user_id(display_name, username, avatar_url)')
          .or('assigned_agent_id.eq.$userId,assigned_agent_id.is.null')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(tickets);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAgent && !_loading) {
      return Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('AGENT PANEL')),
        body: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.block_rounded, size: 64, color: GacomColors.error),
            SizedBox(height: 16),
            Text('Access denied. Agents only.',
                style:
                    TextStyle(color: GacomColors.textMuted, fontSize: 16)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AGENT PANEL',
              style: TextStyle(
                  fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
          Text('${_tickets.length} open tickets',
              style: const TextStyle(
                  color: GacomColors.textMuted, fontSize: 12)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _loadTickets();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: GacomColors.deepOrange))
          : _tickets.isEmpty
              ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.check_circle_rounded,
                        size: 64, color: GacomColors.success),
                    SizedBox(height: 16),
                    Text('All clear! No open tickets.',
                        style: TextStyle(
                            color: GacomColors.textMuted, fontSize: 16)),
                  ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tickets.length,
                  itemBuilder: (_, i) =>
                      _TicketCard(ticket: _tickets[i], onRefresh: _loadTickets)
                          .animate(delay: (i * 40).ms)
                          .fadeIn(),
                ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onRefresh;
  const _TicketCard({required this.ticket, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final user = ticket['user'] as Map? ?? {};
    final createdAt = DateTime.tryParse(ticket['created_at'] ?? '');
    final ticketId =
        (ticket['id'] as String?)?.substring(0, 8).toUpperCase() ?? '—';

    return GestureDetector(
      onTap: () => _openTicketDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: GacomColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: GacomColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('#$ticketId',
                  style: const TextStyle(
                      color: GacomColors.warning,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
            const Spacer(),
            if (createdAt != null)
              Text(
                  '${createdAt.day}/${createdAt.month} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: GacomColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              backgroundColor: GacomColors.deepOrange,
              child: user['avatar_url'] == null
                  ? Text(
                      ((user['display_name'] as String?) ?? 'U')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text(user['display_name'] ?? 'Unknown',
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              Text('@${user['username'] ?? ''}',
                  style: const TextStyle(
                      color: GacomColors.textMuted, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(ticket['issue'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: GacomColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openTicketDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('RESPOND',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await SupabaseService.client
                      .from('support_tickets')
                      .update({'status': 'resolved'}).eq(
                          'id', ticket['id']);
                  onRefresh();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: GacomColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: GacomColors.success.withOpacity(0.4))),
                  child: const Text('RESOLVE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: GacomColors.success,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _openTicketDialog(BuildContext context) {
    final replyCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ticket History',
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: GacomColors.surfaceDark,
                borderRadius: BorderRadius.circular(12)),
            child: Text(
                ticket['ai_transcript'] ?? ticket['issue'] ?? '',
                style: const TextStyle(
                    color: GacomColors.textSecondary,
                    fontSize: 12,
                    height: 1.5)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: replyCtrl,
            maxLines: 3,
            style: const TextStyle(
                color: GacomColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type your response...',
              hintStyle: const TextStyle(color: GacomColors.textMuted),
              filled: true,
              fillColor: GacomColors.surfaceDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: GacomColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: GacomColors.border)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  if (replyCtrl.text.trim().isEmpty) return;
                  try {
                    await SupabaseService.client
                        .from('support_messages')
                        .insert({
                      'ticket_id': ticket['id'],
                      'sender_id': SupabaseService.currentUserId,
                      'message': replyCtrl.text.trim(),
                      'is_agent': true,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      GacomSnackbar.show(context, 'Reply sent ✅',
                          isSuccess: true);
                    }
                  } catch (_) {
                    GacomSnackbar.show(ctx, 'Failed to send',
                        isError: true);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('SEND REPLY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
