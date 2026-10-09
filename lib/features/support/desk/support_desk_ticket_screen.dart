import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../support_service.dart';
import '../support_ui.dart';

/// One request as seen by support staff.
class SupportDeskTicketScreen extends StatefulWidget {
  final String ticketId;
  final SupportTicket? initial;
  const SupportDeskTicketScreen(
      {super.key, required this.ticketId, this.initial});

  @override
  State<SupportDeskTicketScreen> createState() =>
      _SupportDeskTicketScreenState();
}

class _SupportDeskTicketScreenState extends State<SupportDeskTicketScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<SupportMessage> _msgs = [];
  final Map<String, bool> _rated = {};
  StreamSubscription<SupportMessage>? _sub;
  SupportTicket? _ticket;
  SupportUserContext? _ctx;
  bool _ctxLoading = false;
  bool _ctxTried = false;
  bool _loading = true;
  bool _notMissing = true;
  bool _busy = false;
  bool _noteMode = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initial;
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<SupportTicket?> _findTicket() async {
    final direct = await SupportService.ticketById(widget.ticketId);
    if (direct != null) return direct;
    // Fallback: look in the queues of the teams this person works in.
    final teams = await SupportService.myTeams();
    for (final team in teams) {
      final list = await SupportService.deskQueue(teamKey: team.key, limit: 200);
      for (final t in list) {
        if (t.id == widget.ticketId) return t;
      }
    }
    return null;
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final msgsF = SupportService.messages(widget.ticketId);
    SupportTicket? t = _ticket;
    if (quiet || t == null) {
      final found = await _findTicket();
      t = found ?? t;
    }
    final msgs = await msgsF;
    if (!mounted) return;
    setState(() {
      _ticket = t;
      _notMissing = t != null;
      _msgs
        ..clear()
        ..addAll(msgs);
      _loading = false;
    });
    if (_sub == null) _subscribe();
    _scrollDown();
  }

  void _subscribe() {
    _sub = SupportService.messageStream(widget.ticketId).listen((m) {
      if (!mounted || _msgs.any((x) => x.id == m.id)) return;
      setState(() {
        _msgs.add(m);
        _msgs.sort((a, b) => a.at.compareTo(b.at));
      });
      _scrollDown();
    }, onError: (_) {});
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _toast(bool ok, String good, String bad) {
    if (!mounted) return;
    GacomSnackbar.show(context, ok ? good : bad,
        isSuccess: ok, isError: !ok);
  }

  Future<void> _run(Future<bool> Function() job, String good, String bad) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await job();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(ok, good, bad);
    if (ok) _load(quiet: true);
  }

  bool get _done => _ticket != null && SupportUi.isDone(_ticket!.status);

  // ---------- actions ----------

  Future<void> _send() async {
    final t = _ticket;
    final text = _input.text.trim();
    if (t == null || text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = _noteMode
        ? await SupportService.addNote(t.id, text)
        : await SupportService.reply(t.id, text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _input.clear();
      _load(quiet: true);
    } else {
      _toast(false, '',
          _noteMode ? 'Could not save the note' : 'Could not send the reply');
    }
  }

  Future<void> _pickMacro() async {
    final t = _ticket;
    if (t == null) return;
    final list = await SupportService.macros(categoryKey: t.category);
    if (!mounted) return;
    final all = list.isEmpty ? await SupportService.macros() : list;
    if (!mounted) return;
    final picked = await showModalBottomSheet<SupportMacro>(
      context: context,
      backgroundColor: GacomColors.surfaceDark,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: all.isEmpty
              ? const SizedBox(
                  height: 220,
                  child: SupportEmpty(
                      icon: Icons.bolt_rounded,
                      title: 'No saved replies yet',
                      subtitle: 'Saved replies set up by your team show here.'))
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('SAVED REPLIES', style: SupportUi.heading()),
                    ),
                    for (final m in all)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: SupportUi.card(),
                        child: ListTile(
                          title: Text(m.title, style: SupportUi.heading(size: 15)),
                          subtitle: Text(m.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: GacomColors.textSecondary)),
                          onTap: () => Navigator.pop(ctx, m),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _noteMode = false;
      _input.text = picked.body;
      _input.selection = TextSelection.collapsed(offset: picked.body.length);
    });
  }

  Future<void> _assign() async {
    final t = _ticket;
    if (t == null) return;
    final members = await SupportService.teamMembers(t.teamKey);
    if (!mounted) return;
    if (members.isEmpty) {
      _toast(false, '', 'Could not load the team. Only team leads can assign.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: GacomColors.surfaceDark,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('ASSIGN TO', style: SupportUi.heading()),
            ),
            for (final m in members)
              ListTile(
                enabled: m['active'] != false,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(m['name']?.toString() ?? 'Member'),
                subtitle: Text(
                    '${SupportUi.pretty(m['role']?.toString() ?? 'agent')}  |  ${m['open'] ?? 0} open',
                    style: SupportUi.muted),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final uid = picked['userId']?.toString() ?? '';
    if (uid.isEmpty) return;
    _run(() => SupportService.assign(t.id, uid), 'Assigned',
        'Could not assign this request');
  }

  Future<void> _changeRouting() async {
    final t = _ticket;
    if (t == null) return;
    final cats = await SupportService.categories();
    var teams = await SupportService.allTeams();
    if (teams.isEmpty) teams = await SupportService.myTeams();
    if (!mounted) return;
    String? cat = cats.any((c) => c.key == t.category) ? t.category : null;
    String? team = teams.any((x) => x.key == t.teamKey) ? t.teamKey : null;
    String prio = t.priority;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: GacomColors.elevatedCard,
          title: Text('Change routing', style: SupportUi.heading(size: 18)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: cat,
                isExpanded: true,
                dropdownColor: GacomColors.elevatedCard,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(value: c.key, child: Text(c.label)),
                ],
                onChanged: (v) => setD(() => cat = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: team,
                isExpanded: true,
                dropdownColor: GacomColors.elevatedCard,
                decoration: const InputDecoration(labelText: 'Team'),
                items: [
                  for (final x in teams)
                    DropdownMenuItem(value: x.key, child: Text(x.name)),
                ],
                onChanged: (v) => setD(() => team = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: prio,
                isExpanded: true,
                dropdownColor: GacomColors.elevatedCard,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final p in ['low', 'normal', 'high', 'urgent'])
                    DropdownMenuItem(value: p, child: Text(SupportUi.pretty(p))),
                ],
                onChanged: (v) => setD(() => prio = v ?? prio),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (go != true) return;
    _run(
        () => SupportService.setRouting(t.id,
            categoryKey: cat == t.category ? null : cat,
            teamKey: team == t.teamKey ? null : team,
            priority: prio == t.priority ? null : prio),
        'Routing updated',
        'Could not change the routing');
  }

  Future<void> _escalate() async {
    final t = _ticket;
    if (t == null) return;
    final note = await supportTextDialog(context,
        title: 'Escalate to Technical',
        hint: 'What have you checked, and what should Technical look at?',
        confirm: 'Escalate',
        required: true);
    if (note == null || note.isEmpty) return;
    _run(() => SupportService.escalateToTechnical(t.id, note), 'Escalated',
        'Could not escalate this request');
  }

  Future<void> _resolve() async {
    final t = _ticket;
    if (t == null) return;
    final note = await supportTextDialog(context,
        title: 'Resolve request',
        hint: 'Closing note (optional). The user is told it is resolved.',
        confirm: 'Resolve');
    if (note == null) return;
    _run(() => SupportService.resolve(t.id, note: note), 'Marked as resolved',
        'Could not resolve this request');
  }

  Future<void> _saveKnowledge() async {
    final t = _ticket;
    if (t == null) return;
    String lastAnswer = '';
    for (final m in _msgs.reversed) {
      if (m.senderType == 'agent' && !m.internal) {
        lastAnswer = m.body;
        break;
      }
    }
    final titleCtrl = TextEditingController(text: t.subject);
    final answerCtrl = TextEditingController(text: lastAnswer);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GacomColors.elevatedCard,
        title:
            Text('Save to knowledge base', style: SupportUi.heading(size: 18)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'This creates a draft article. An admin reviews it before it is used to answer users.',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Question or title')),
            const SizedBox(height: 12),
            TextField(
                controller: answerCtrl,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(labelText: 'Answer')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save draft')),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final answer = answerCtrl.text.trim();
    // Controllers are left to the garbage collector: the dialog's exit animation still reads them.
    if (go != true) return;
    if (title.isEmpty || answer.isEmpty) {
      _toast(false, '', 'Add both a title and an answer');
      return;
    }
    _run(
        () => SupportService.saveAsKnowledge(t.id,
            title: title, answer: answer, categoryKey: t.category),
        'Saved as a draft',
        'Could not save the article');
  }

  Future<void> _rateAssistant(SupportMessage m, bool helpful) async {
    String correction = '';
    if (!helpful) {
      final c = await supportTextDialog(context,
          title: 'What should the answer have been?',
          hint: 'Optional. Your correction helps improve future answers.',
          confirm: 'Send');
      if (c == null) return;
      correction = c;
    }
    final ok = await SupportService.rateAssistantMessage(m.id, helpful,
        correction: correction);
    if (!mounted) return;
    if (ok) setState(() => _rated[m.id] = helpful);
    _toast(ok, 'Thanks, noted', 'Could not save your feedback');
  }

  Future<void> _loadContext() async {
    final t = _ticket;
    if (t == null || _ctxLoading) return;
    setState(() {
      _ctxLoading = true;
      _ctxTried = true;
    });
    final c = await SupportService.userContext(t.id);
    if (!mounted) return;
    setState(() {
      _ctx = c;
      _ctxLoading = false;
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/support/desk');
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text('REQUEST', style: SupportUi.heading(size: 20)),
        actions: [
          if (t != null)
            IconButton(
              tooltip: 'User details',
              icon: const Icon(Icons.badge_outlined),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          if (t != null) _menu(t),
        ],
      ),
      endDrawer: t == null ? null : _drawer(t),
      onEndDrawerChanged: (open) {
        if (open && !_ctxTried) _loadContext();
      },
      body: _body(),
    );
  }

  Widget _menu(SupportTicket t) {
    return PopupMenuButton<String>(
      color: GacomColors.elevatedCard,
      tooltip: 'Actions',
      enabled: !_busy,
      onSelected: (v) {
        switch (v) {
          case 'claim':
            _run(() => SupportService.claim(t.id), 'This request is yours',
                'Could not claim this request');
            break;
          case 'assign':
            _assign();
            break;
          case 'routing':
            _changeRouting();
            break;
          case 'escalate':
            _escalate();
            break;
          case 'resolve':
            _resolve();
            break;
          case 'kb':
            _saveKnowledge();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'claim', child: Text('Claim')),
        const PopupMenuItem(value: 'assign', child: Text('Assign (leads)')),
        const PopupMenuItem(
            value: 'routing', child: Text('Change category, team or priority')),
        const PopupMenuItem(
            value: 'escalate', child: Text('Escalate to Technical')),
        const PopupMenuItem(value: 'resolve', child: Text('Resolve')),
        const PopupMenuItem(
            value: 'kb', child: Text('Save answer to knowledge base')),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const SupportLoading();
    final t = _ticket;
    if (t == null || !_notMissing) {
      return SupportEmpty(
        icon: Icons.lock_outline_rounded,
        title: 'Request not available',
        subtitle:
            'It may not belong to your team, or you are not on a support team. Pull back and try the queue again.',
      );
    }
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          color: GacomColors.deepOrange,
          onRefresh: () => _load(quiet: true),
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: [
              _header(t),
              if ((t.summary ?? '').isNotEmpty) _summaryCard(t.summary!),
              const SizedBox(height: 6),
              if (_msgs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('No messages yet',
                          style: TextStyle(color: GacomColors.textMuted))),
                ),
              for (final m in _msgs) _message(m),
            ],
          ),
        ),
      ),
      _composer(t),
    ]);
  }

  Widget _header(SupportTicket t) {
    final pc = SupportUi.priorityColor(t.priority);
    final due = t.firstResponseAt == null ? t.firstResponseDue : t.resolutionDue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: SupportUi.card(border: pc.withOpacity(0.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.subject.isEmpty ? 'Support request' : t.subject,
            style: SupportUi.heading(size: 18)),
        const SizedBox(height: 4),
        Text(
            '${t.userName}  |  opened ${SupportUi.ago(t.createdAt)}  |  ${t.teamName}',
            style: SupportUi.muted),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          SupportChip(SupportUi.pretty(t.priority), pc),
          SupportChip(SupportUi.statusLabel(t.status, staff: true),
              SupportUi.statusColor(t.status)),
          SupportChip(SupportUi.pretty(t.category), GacomColors.textSecondary),
          SupportChip(t.assigneeName ?? 'Unassigned',
              t.assigneeId == null ? GacomColors.warning : GacomColors.success,
              icon: Icons.person_outline_rounded),
          if (due != null && !SupportUi.isDone(t.status))
            SupportChip(
                SupportUi.dueText(due),
                due.isBefore(DateTime.now()) || t.breached
                    ? GacomColors.error
                    : GacomColors.info,
                icon: Icons.schedule_rounded),
          if (t.csat != null)
            SupportChip('${t.csat} / 5 rating', GacomColors.gold,
                icon: Icons.star_rounded),
        ]),
      ]),
    );
  }

  Widget _summaryCard(String s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: SupportUi.card(border: GacomColors.accentCyan.withOpacity(0.35)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("RYAN'S SUMMARY",
            style: SupportUi.heading(size: 12, color: GacomColors.accentCyan)),
        const SizedBox(height: 4),
        Text(s, style: SupportUi.body),
      ]),
    );
  }

  Widget _message(SupportMessage m) {
    if (m.senderType == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
            child: Text(m.body,
                textAlign: TextAlign.center, style: SupportUi.muted)),
      );
    }
    final isNote = m.internal || m.senderType == 'note';
    final mine = m.senderType == 'user';
    final ryan = m.senderType == 'assistant';
    final width = MediaQuery.of(context).size.width * 0.86;
    BoxDecoration deco;
    String label;
    Color labelColor;
    if (isNote) {
      deco = SupportUi.card(
          border: GacomColors.warning.withOpacity(0.7),
          fill: GacomColors.warning.withOpacity(0.10));
      label = 'INTERNAL NOTE  |  ${m.senderName}  |  not visible to the user';
      labelColor = GacomColors.warning;
    } else if (mine) {
      deco = SupportUi.card(
          border: GacomColors.deepOrange.withOpacity(0.4),
          fill: GacomColors.deepOrange.withOpacity(0.14));
      label = m.senderName.isEmpty ? 'User' : m.senderName;
      labelColor = GacomColors.deepOrange;
    } else if (ryan) {
      deco = SupportUi.card();
      label = "Ryan, GACOM's support assistant";
      labelColor = GacomColors.accentCyan;
    } else {
      deco = SupportUi.card();
      label = m.senderName;
      labelColor = GacomColors.success;
    }
    final conf = m.meta['confidence'];
    final rated = _rated[m.id];
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: width),
        decoration: deco,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: SupportUi.heading(size: 12, color: labelColor)),
          const SizedBox(height: 4),
          Text(m.body, style: SupportUi.body),
          for (final a in m.attachments) SupportAttachmentLink(a),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(SupportUi.clock(m.at), style: SupportUi.muted),
            if (ryan && conf is num) ...[
              const SizedBox(width: 8),
              Text('confidence ${(conf * 100).round()}%',
                  style: SupportUi.muted),
            ],
            if (ryan) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: rated == null ? () => _rateAssistant(m, true) : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.thumb_up_alt_outlined,
                      size: 16,
                      color: rated == true
                          ? GacomColors.success
                          : GacomColors.textMuted),
                ),
              ),
              InkWell(
                onTap: rated == null ? () => _rateAssistant(m, false) : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.thumb_down_alt_outlined,
                      size: 16,
                      color: rated == false
                          ? GacomColors.error
                          : GacomColors.textMuted),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _composer(SupportTicket t) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: _noteMode
              ? GacomColors.warning.withOpacity(0.08)
              : GacomColors.surfaceDark,
          border: Border(
              top: BorderSide(
                  color: _noteMode ? GacomColors.warning : GacomColors.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('REPLY')),
                ButtonSegment(value: true, label: Text('INTERNAL NOTE')),
              ],
              selected: {_noteMode},
              onSelectionChanged: (s) => setState(() => _noteMode = s.first),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _noteMode ? null : _pickMacro,
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: const Text('Saved replies'),
            ),
          ]),
          if (_noteMode)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Only your team will see this note.',
                    style: TextStyle(fontSize: 11, color: GacomColors.warning)),
              ),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: _noteMode
                      ? 'Write an internal note'
                      : (_done ? 'Reply (this reopens the request)' : 'Reply to the user'),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _busy ? null : _send,
              style: IconButton.styleFrom(
                  backgroundColor:
                      _noteMode ? GacomColors.warning : GacomColors.deepOrange,
                  disabledBackgroundColor: GacomColors.elevatedCard),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ]),
        ]),
      ),
    );
  }

  // ---------- user context drawer ----------

  Widget _drawer(SupportTicket t) {
    return Drawer(
      backgroundColor: GacomColors.surfaceDark,
      width: 340,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('USER DETAILS', style: SupportUi.heading(size: 18)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: const [
              Icon(Icons.visibility_outlined,
                  size: 14, color: GacomColors.warning),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Access is logged. Only open this when it helps with the request.',
                    style: TextStyle(fontSize: 11, color: GacomColors.warning)),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: _drawerBody()),
        ]),
      ),
    );
  }

  Widget _drawerBody() {
    if (_ctxLoading) return const SupportLoading();
    final c = _ctx;
    if (c == null) {
      return SupportEmpty(
        icon: Icons.error_outline_rounded,
        title: 'Could not load details',
        subtitle: 'You may not have access to this user, or the connection failed.',
      );
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      _ctxBlock('Profile', [c.profile]),
      _ctxBlock('Recent wallet activity', c.recentWallet),
      _ctxBlock('Recent shop orders', c.recentOrders),
      _ctxBlock('Recent app errors', c.recentErrors),
      _ctxBlock('Earlier requests', c.recentTickets),
    ]);
  }

  Widget _ctxBlock(String title, List<Map<String, dynamic>> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: SupportUi.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: SupportUi.heading(size: 12, color: GacomColors.textMuted)),
        const SizedBox(height: 6),
        if (rows.isEmpty || (rows.length == 1 && rows.first.isEmpty))
          const Text('Nothing to show', style: SupportUi.muted)
        else
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 14),
            for (final e in rows[i].entries)
              if (e.value != null && e.value.toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, height: 1.35),
                      children: [
                        TextSpan(
                            text: '${SupportUi.pretty(e.key)}: ',
                            style:
                                const TextStyle(color: GacomColors.textMuted)),
                        TextSpan(
                            text: _short(e.value.toString()),
                            style: const TextStyle(
                                color: GacomColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
          ],
      ]),
    );
  }

  String _short(String s) => s.length > 140 ? '${s.substring(0, 140)}...' : s;
}
