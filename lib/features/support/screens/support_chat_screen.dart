import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../support_service.dart';
import '../support_ui.dart';

/// Help center. Starts with Ryan, GACOM's support assistant, and hands over to
/// the support team when needed. Also used to show one existing ticket.
class SupportChatScreen extends StatefulWidget {
  final String? ticketId;
  const SupportChatScreen({super.key, this.ticketId});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _Item {
  final String id;
  final String sender; // user | agent | assistant | system
  final String name;
  final String body;
  final DateTime at;
  final List<String> attachments;
  final bool local;
  const _Item(this.id, this.sender, this.name, this.body, this.at,
      this.attachments, this.local);

  factory _Item.from(SupportMessage m) =>
      _Item(m.id, m.senderType, m.senderName, m.body, m.at, m.attachments,
          false);
}

class _Topic {
  final String label;
  final String category;
  const _Topic(this.label, this.category);
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const _topics = [
    _Topic('Wallet and payments', 'wallet_funding'),
    _Topic('Withdrawal', 'withdrawal'),
    _Topic('Account and login', 'account_access'),
    _Topic('Shop order', 'shop_order'),
    _Topic('Competition prize', 'competition_prize'),
    _Topic('Report a player', 'report_abuse'),
    _Topic('Technical problem', 'gameplay_bug'),
    _Topic('Something else', 'other'),
  ];

  final _input = TextEditingController();
  final _comment = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<_Item> _items = [];
  final List<String> _pending = [];
  StreamSubscription<SupportMessage>? _sub;
  SupportTicket? _ticket;
  bool _loading = false;
  bool _waiting = false;
  bool _uploading = false;
  bool _ratingBusy = false;
  _Topic? _topic;
  int _stars = 0;
  int _localSeq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.ticketId != null) _openTicket(widget.ticketId!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _comment.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _done => _ticket != null && SupportUi.isDone(_ticket!.status);

  Future<void> _openTicket(String id) async {
    setState(() => _loading = true);
    final tickets = await SupportService.myTickets();
    SupportTicket? found;
    for (final t in tickets) {
      if (t.id == id) found = t;
    }
    final msgs = await SupportService.messages(id);
    if (!mounted) return;
    setState(() {
      _ticket = found;
      _items
        ..clear()
        ..addAll(msgs.where((m) => !m.internal).map(_Item.from));
      _loading = false;
    });
    _subscribe(id);
    _scrollDown();
  }

  void _subscribe(String id) {
    _sub?.cancel();
    _sub = SupportService.messageStream(id).listen((m) {
      if (!mounted || m.internal) return;
      _addMessage(m);
      if (m.senderType != 'user') {
        if (_waiting) setState(() => _waiting = false);
        _refreshTicket();
      }
    }, onError: (_) {});
  }

  void _addMessage(SupportMessage m) {
    if (_items.any((i) => i.id == m.id)) return;
    setState(() {
      if (m.senderType == 'user') {
        _items.removeWhere((i) => i.local && i.body == m.body);
      }
      _items.add(_Item.from(m));
      _items.sort((a, b) => a.at.compareTo(b.at));
    });
    _scrollDown();
  }

  Future<void> _refreshTicket() async {
    final id = _ticket?.id;
    if (id == null) return;
    final tickets = await SupportService.myTickets();
    for (final t in tickets) {
      if (t.id == id && mounted) {
        setState(() => _ticket = t);
        return;
      }
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _waiting) return;
    final attachments = List<String>.from(_pending);
    _input.clear();
    final localId = 'local-${_localSeq++}';
    setState(() {
      _items.add(_Item(localId, 'user', '', text, DateTime.now(),
          attachments, true));
      _pending.clear();
      _waiting = true;
    });
    _scrollDown();

    SupportTurn turn;
    if (_ticket == null) {
      turn = await SupportService.startTicket(text,
          categoryHint: _topic?.category,
          deviceInfo: SupportUi.deviceInfo());
    } else {
      turn = await SupportService.sendMessage(_ticket!.id, text,
          attachments: attachments);
    }
    if (!mounted) return;

    final t = turn.ticket ?? _ticket;
    if (t == null) {
      // Nothing was created. Put the text back so it is not lost.
      setState(() {
        _items.removeWhere((i) => i.id == localId);
        _waiting = false;
        _input.text = text;
      });
      GacomSnackbar.show(
          context, turn.error ?? 'Could not send your message. Please try again.',
          isError: true);
      return;
    }
    if (turn.error != null) {
      GacomSnackbar.show(context, turn.error!, isError: true);
    }
    final firstTime = _ticket == null || _ticket!.id != t.id;
    setState(() => _ticket = t);
    if (firstTime || _sub == null) _subscribe(t.id);

    final all = await SupportService.messages(t.id);
    if (!mounted) return;
    setState(() {
      if (all.isNotEmpty) {
        _items
          ..clear()
          ..addAll(all.where((m) => !m.internal).map(_Item.from));
      } else {
        _items.removeWhere((i) => i.id == localId);
        _items.add(_Item(localId, 'user', '', text, DateTime.now(),
            attachments, false));
        for (final m in turn.newMessages) {
          if (!_items.any((i) => i.id == m.id)) _items.add(_Item.from(m));
        }
      }
      _waiting = false;
    });
    _scrollDown();
  }

  Future<void> _attach() async {
    if (_uploading || _pending.length >= 3) return;
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          GacomSnackbar.show(context, 'That picture is over 5 MB', isError: true);
        }
        return;
      }
      setState(() => _uploading = true);
      final path = await SupportService.uploadAttachment(bytes, x.name);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (path != null) _pending.add(path);
      });
      if (path == null) {
        GacomSnackbar.show(context, 'Upload failed. Use a png, jpg, webp or pdf file',
            isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        GacomSnackbar.show(context, 'Could not pick a picture', isError: true);
      }
    }
  }

  Future<void> _talkToPerson() async {
    final t = _ticket;
    if (t == null) {
      GacomSnackbar.show(
          context, 'Tell us what is wrong first, then we will pass it to a person');
      _focus.requestFocus();
      return;
    }
    final ok = await SupportService.requestHuman(t.id);
    if (!mounted) return;
    GacomSnackbar.show(
        context,
        ok
            ? 'Done. A member of the team will pick this up.'
            : 'Could not reach the team right now. Please try again.',
        isSuccess: ok,
        isError: !ok);
    if (ok) _refreshTicket();
  }

  Future<void> _rate() async {
    final t = _ticket;
    if (t == null || _stars < 1 || _ratingBusy) return;
    setState(() => _ratingBusy = true);
    final ok = await SupportService.rateTicket(t.id, _stars,
        comment: _comment.text.trim());
    if (!mounted) return;
    setState(() => _ratingBusy = false);
    GacomSnackbar.show(context,
        ok ? 'Thank you for the feedback' : 'Could not save your rating',
        isSuccess: ok, isError: !ok);
    if (ok) _refreshTicket();
  }

  Future<void> _reopen() async {
    final t = _ticket;
    if (t == null) return;
    final ok = await SupportService.reopenTicket(t.id);
    if (!mounted) return;
    GacomSnackbar.show(context,
        ok ? 'Request reopened. Tell us what is still wrong.' : 'Could not reopen this request',
        isSuccess: ok, isError: !ok);
    if (ok) {
      setState(() => _stars = 0);
      _refreshTicket();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppConstants.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text('HELP CENTER', style: SupportUi.heading(size: 20)),
        actions: [
          if (widget.ticketId == null)
            IconButton(
              tooltip: 'My requests',
              icon: const Icon(Icons.receipt_long_rounded),
              onPressed: () => context.push('/support/tickets'),
            ),
        ],
      ),
      body: _loading
          ? const SupportLoading()
          : Column(children: [
              if (_ticket != null) _banner(_ticket!),
              Expanded(child: _list()),
              _bottom(),
            ]),
    );
  }

  Widget _banner(SupportTicket t) {
    final color = SupportUi.statusColor(t.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: SupportUi.card(border: color.withOpacity(0.35)),
      child: Row(children: [
        Icon(Icons.support_agent_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.teamName.isEmpty ? 'GACOM support' : t.teamName,
                style: SupportUi.heading(size: 15)),
            const SizedBox(height: 2),
            Text(_expected(t), style: SupportUi.muted),
          ]),
        ),
        SupportChip(SupportUi.statusLabel(t.status), color),
      ]),
    );
  }

  String _expected(SupportTicket t) {
    if (SupportUi.isDone(t.status)) return 'This request is closed';
    final now = DateTime.now();
    final due = (t.firstResponseAt == null && t.firstResponseDue != null)
        ? t.firstResponseDue
        : t.resolutionDue;
    final first = t.firstResponseAt == null && t.firstResponseDue != null;
    if (due == null) return 'We will get back to you soon';
    if (due.isBefore(now)) {
      return first
          ? 'Taking a bit longer than usual. We are on it.'
          : 'We are still working on this';
    }
    final d = SupportUi.duration(due.difference(now));
    return first ? 'Expect a reply in about $d' : 'We aim to sort this out within $d';
  }

  Widget _list() {
    final showWelcome = _ticket == null && _items.isEmpty;
    final extra = (showWelcome ? 1 : 0) + (_waiting ? 1 : 0);
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: () async {
        final id = _ticket?.id;
        if (id != null) await _openTicket(id);
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: _items.length + extra + (_ticket == null ? 1 : 0),
        itemBuilder: (_, i) {
          var idx = i;
          if (showWelcome) {
            if (idx == 0) return _welcome();
            idx -= 1;
          }
          if (idx < _items.length) return _bubble(_items[idx]);
          idx -= _items.length;
          if (_waiting && idx == 0) return _typing();
          if (_waiting) idx -= 1;
          return _topicChips();
        },
      ),
    );
  }

  Widget _welcome() {
    return _ryanBubble(
        "Hi, I'm Ryan, GACOM's support assistant. Tell me what is going on and I will help. "
        'If it needs a person, I will pass it to the right team.');
  }

  Widget _ryanBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: SupportUi.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Ryan, GACOM's support assistant",
              style: SupportUi.heading(size: 12, color: GacomColors.accentCyan)),
          const SizedBox(height: 4),
          Text(text, style: SupportUi.body),
        ]),
      ),
    );
  }

  Widget _topicChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PICK A TOPIC (OPTIONAL)', style: SupportUi.heading(size: 12, color: GacomColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _topics)
            ChoiceChip(
              label: Text(t.label),
              selected: _topic == t,
              selectedColor: GacomColors.deepOrange.withOpacity(0.25),
              backgroundColor: GacomColors.cardDark,
              side: BorderSide(
                  color: _topic == t
                      ? GacomColors.deepOrange
                      : GacomColors.borderBright),
              labelStyle: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  color: _topic == t
                      ? GacomColors.deepOrange
                      : GacomColors.textSecondary),
              onSelected: (v) {
                setState(() => _topic = v ? t : null);
                if (v) _focus.requestFocus();
              },
            ),
        ]),
      ]),
    );
  }

  Widget _typing() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: SupportUi.card(),
        child: const Text('Ryan is typing...',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 13))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.4, end: 1, duration: 700.ms),
      ),
    );
  }

  Widget _bubble(_Item m) {
    if (m.sender == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(m.body,
              textAlign: TextAlign.center, style: SupportUi.muted),
        ),
      );
    }
    final mine = m.sender == 'user';
    final ryan = m.sender == 'assistant';
    final label = mine
        ? ''
        : ryan
            ? "Ryan, GACOM's support assistant"
            : '${m.name.isEmpty ? 'GACOM support' : m.name}  |  GACOM support';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: mine
            ? SupportUi.card(
                border: GacomColors.deepOrange.withOpacity(0.4),
                fill: GacomColors.deepOrange.withOpacity(0.14))
            : SupportUi.card(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty) ...[
                Text(label,
                    style: SupportUi.heading(
                        size: 12,
                        color: ryan
                            ? GacomColors.accentCyan
                            : GacomColors.success)),
                const SizedBox(height: 4),
              ],
              Text(m.body, style: SupportUi.body),
              for (final a in m.attachments) SupportAttachmentLink(a),
              const SizedBox(height: 4),
              Text(SupportUi.clock(m.at), style: SupportUi.muted),
            ]),
      ),
    );
  }

  Widget _bottom() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: GacomColors.surfaceDark,
          border: Border(top: BorderSide(color: GacomColors.border)),
        ),
        child: _done ? _resolvedPanel() : _composer(),
      ),
    );
  }

  Widget _composer() {
    final t = _ticket;
    final canHuman = t == null || t.assigneeId == null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.shield_outlined, size: 14, color: GacomColors.success),
        const SizedBox(width: 6),
        const Expanded(
          child: Text('GACOM staff will never ask for your password or OTP',
              style: TextStyle(fontSize: 11, color: GacomColors.textMuted)),
        ),
        if (canHuman)
          TextButton.icon(
            onPressed: _waiting ? null : _talkToPerson,
            icon: const Icon(Icons.support_agent_rounded, size: 16),
            label: const Text('Talk to a person'),
          ),
      ]),
      if (_pending.isNotEmpty || _uploading)
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 6, children: [
            for (final p in _pending)
              InputChip(
                label: Text(p.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                onDeleted: () => setState(() => _pending.remove(p)),
              ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: GacomColors.deepOrange)),
              ),
          ]),
        ),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (t != null)
          IconButton(
            tooltip: 'Attach a screenshot',
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: _attach,
          ),
        Expanded(
          child: TextField(
            controller: _input,
            focusNode: _focus,
            minLines: 1,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              counterText: '',
              hintText: t != null
                  ? 'Write a message'
                  : (_topic != null
                      ? 'Tell Ryan what happened (${_topic!.label})'
                      : 'Describe what happened'),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _waiting ? null : _send,
          style: IconButton.styleFrom(
              backgroundColor: GacomColors.deepOrange,
              disabledBackgroundColor: GacomColors.elevatedCard),
          icon: const Icon(Icons.send_rounded, color: Colors.white),
        ),
      ]),
    ]);
  }

  Widget _resolvedPanel() {
    final t = _ticket!;
    final rated = t.csat != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(rated ? 'THANKS FOR RATING US' : 'HOW DID WE DO?',
          style: SupportUi.heading(size: 14)),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: rated ? null : () => setState(() => _stars = i),
            icon: Icon(
              i <= (rated ? t.csat! : _stars)
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: GacomColors.gold,
              size: 30,
            ),
          ),
      ]),
      if (!rated) ...[
        TextField(
          controller: _comment,
          maxLines: 2,
          maxLength: 500,
          decoration: const InputDecoration(
              counterText: '', hintText: 'Anything we should know? (optional)'),
        ),
        const SizedBox(height: 8),
      ],
      Row(children: [
        if (!rated)
          Expanded(
            child: ElevatedButton(
              onPressed: (_stars < 1 || _ratingBusy) ? null : _rate,
              child: const Text('Send rating'),
            ),
          ),
        if (!rated) const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: _reopen,
            child: const Text('Reopen this request'),
          ),
        ),
      ]),
    ]);
  }
}
