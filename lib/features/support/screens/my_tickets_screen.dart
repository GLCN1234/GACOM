import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../support_service.dart';
import '../support_ui.dart';
import 'support_chat_screen.dart';

/// One existing request, shown in the same conversation view as the help center.
class TicketScreen extends StatelessWidget {
  final String ticketId;
  const TicketScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) => SupportChatScreen(ticketId: ticketId);
}

/// List of the signed-in user's own support requests.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<SupportTicket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await SupportService.myTickets();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _loading = false;
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppConstants.supportRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text('MY REQUESTS', style: SupportUi.heading(size: 20)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GacomColors.deepOrange,
        foregroundColor: Colors.white,
        onPressed: () => context.push(AppConstants.supportRoute),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      body: _loading
          ? const SupportLoading()
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: _load,
              child: _tickets.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const SupportEmpty(
                          icon: Icons.inbox_outlined,
                          title: 'No requests yet',
                          subtitle:
                              'When you contact support, your conversations will show up here.',
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _tile(_tickets[i]),
                    ),
            ),
    );
  }

  Widget _tile(SupportTicket t) {
    final color = SupportUi.statusColor(t.status);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await context.push('/support/ticket/${t.id}');
        if (mounted) _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: SupportUi.card(
            border: t.unreadForUser
                ? GacomColors.deepOrange.withOpacity(0.5)
                : null),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (t.unreadForUser)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                        color: GacomColors.deepOrange, shape: BoxShape.circle),
                  ),
                Expanded(
                  child: Text(
                    t.subject.isEmpty ? 'Support request' : t.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SupportUi.heading(size: 16),
                  ),
                ),
              ]),
              if (t.lastPreview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(t.lastPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: GacomColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                SupportChip(SupportUi.statusLabel(t.status), color),
                const SizedBox(width: 8),
                if (t.teamName.isNotEmpty)
                  Flexible(
                    child: Text(t.teamName,
                        overflow: TextOverflow.ellipsis, style: SupportUi.muted),
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Text(SupportUi.ago(t.updatedAt), style: SupportUi.muted),
        ]),
      ),
    );
  }
}
