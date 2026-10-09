import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../darkom_look.dart';
import '../darkom_look_paint.dart';
import 'darkom_hub_service.dart';
import 'darkom_hub_world.dart';

const List<String> kHubQuickPhrases = <String>['Hello', 'Good game', 'Need a squad', 'Thank you', 'Follow me', 'Well played'];

/// Shared frame for every bottom sheet in the plaza.
class HubSheetFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final bool fill;
  const HubSheetFrame({super.key, required this.title, required this.icon, required this.color, required this.child, this.fill = false});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxH = mq.size.height * 0.78;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: kHubPanel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: color, width: 2)),
          boxShadow: <BoxShadow>[BoxShadow(color: color.withOpacity(0.3), blurRadius: 20)],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 4),
                child: Row(children: <Widget>[
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2))),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                ]),
              ),
              Flexible(fit: fill ? FlexFit.tight : FlexFit.loose, child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reason picker for reports. Returns abuse, spam, cheating or other.
Future<String?> hubPickReason(BuildContext context, String name) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext c) => SimpleDialog(
      backgroundColor: kHubPanel,
      title: Text('Report $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      children: <Widget>[
        for (final List<String> r in const <List<String>>[
          <String>['abuse', 'Abuse or bullying'],
          <String>['spam', 'Spam'],
          <String>['cheating', 'Cheating'],
          <String>['other', 'Something else'],
        ])
          SimpleDialogOption(onPressed: () => Navigator.of(c).pop(r[0]), child: Text(r[1], style: const TextStyle(color: Colors.white, fontSize: 15))),
        SimpleDialogOption(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel', style: TextStyle(color: Color(0xFF9AA6C2)))),
      ],
    ),
  );
}

// ------------------------------------------------------------------- chat

/// Keeps the recent messages of every room the player is in.
class HubChatController extends ChangeNotifier {
  final String myId;
  HubChatController(this.myId);

  final Map<String, List<DarkomChatMessage>> _msgs = <String, List<DarkomChatMessage>>{};
  final Map<String, StreamSubscription<DarkomChatMessage>> _subs = <String, StreamSubscription<DarkomChatMessage>>{};
  final Map<String, int> unread = <String, int>{};
  Set<String> _blocked = <String>{};
  String? visibleRoom;
  bool _disposed = false;

  /// Called for each new live message in a public hub room (for speech bubbles).
  void Function(DarkomChatMessage m)? onHubMessage;

  int get totalUnread {
    int n = 0;
    for (final int v in unread.values) {
      n += v;
    }
    return n;
  }

  List<DarkomChatMessage> messages(String room) => _msgs[room] ?? const <DarkomChatMessage>[];

  void _n() {
    if (!_disposed) notifyListeners();
  }

  Future<void> openRoom(String room) async {
    if (_subs.containsKey(room) || _disposed) return;
    _msgs[room] = <DarkomChatMessage>[];
    _subs[room] = DarkomHubService.messageStream(room).listen((DarkomChatMessage m) => _add(room, m, true), onError: (Object e) {});
    try {
      final List<DarkomChatMessage> list = await DarkomHubService.recentMessages(room, limit: 40);
      for (final DarkomChatMessage m in list) {
        _add(room, m, false);
      }
    } catch (_) {}
  }

  void closeRoom(String room) {
    _subs.remove(room)?.cancel();
    _msgs.remove(room);
    unread.remove(room);
    _n();
  }

  void _add(String room, DarkomChatMessage m, bool live) {
    if (_disposed || _blocked.contains(m.userId)) return;
    final List<DarkomChatMessage>? list = _msgs[room];
    if (list == null) return;
    for (final DarkomChatMessage x in list) {
      if (x.id == m.id) return;
    }
    list.add(m);
    list.sort((DarkomChatMessage a, DarkomChatMessage b) => a.at.compareTo(b.at));
    while (list.length > 80) {
      list.removeAt(0);
    }
    if (live) {
      if (room.startsWith('hub:')) {
        final void Function(DarkomChatMessage)? cb = onHubMessage;
        if (cb != null) cb(m);
      }
      if (room != visibleRoom && m.userId != myId) unread[room] = (unread[room] ?? 0) + 1;
    }
    _n();
  }

  void setBlocked(Set<String> blocked) {
    _blocked = Set<String>.from(blocked);
    for (final List<DarkomChatMessage> l in _msgs.values) {
      l.removeWhere((DarkomChatMessage m) => _blocked.contains(m.userId));
    }
    _n();
  }

  void markRead(String room) {
    visibleRoom = room;
    unread.remove(room);
  }

  /// Returns null on success, or a friendly message.
  Future<String?> send(String room, String body) async {
    final String text = body.trim();
    if (text.isEmpty) return null;
    try {
      final DarkomChatResult r = await DarkomHubService.sendMessage(room, text.length > 140 ? text.substring(0, 140) : text);
      if (!r.ok) return r.error ?? 'Your message could not be sent. Please try again.';
      final DarkomChatMessage? m = r.message;
      if (m != null) _add(room, m, true);
      return null;
    } catch (_) {
      return 'Your message could not be sent. Please try again.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final StreamSubscription<DarkomChatMessage> s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}

class HubChatTab {
  final String label;
  final String room;
  const HubChatTab(this.label, this.room);
}

class HubChatPanel extends StatefulWidget {
  final HubChatController chat;
  final Listenable listenable;
  final List<HubChatTab> Function() tabs;
  final String initialRoom;
  final void Function(DarkomChatMessage m) onReport;
  final void Function(DarkomChatMessage m) onBlock;
  const HubChatPanel({
    super.key,
    required this.chat,
    required this.listenable,
    required this.tabs,
    required this.initialRoom,
    required this.onReport,
    required this.onBlock,
  });

  @override
  State<HubChatPanel> createState() => _HubChatPanelState();
}

class _HubChatPanelState extends State<HubChatPanel> {
  final TextEditingController _text = TextEditingController();
  late String _room;
  bool _sending = false;
  String? _error;

  static const List<Color> _nameColors = <Color>[Color(0xFF00E5FF), Color(0xFFFF80AB), Color(0xFFFFD54F), Color(0xFF69F0AE), Color(0xFFB388FF), Color(0xFFFF9E80)];

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    widget.chat.markRead(_room);
    widget.chat.openRoom(_room);
  }

  @override
  void dispose() {
    widget.chat.visibleRoom = null;
    _text.dispose();
    super.dispose();
  }

  void _pick(String room) {
    setState(() {
      _room = room;
      _error = null;
    });
    widget.chat.markRead(room);
    widget.chat.openRoom(room);
  }

  Future<void> _send(String body, {bool fromField = false}) async {
    if (_sending || body.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final String room = _room;
    final String? err = await widget.chat.send(room, body);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = err;
      if (err == null && fromField) _text.clear();
    });
  }

  void _menu(DarkomChatMessage m) {
    showDialog<void>(
      context: context,
      builder: (BuildContext c) => SimpleDialog(
        backgroundColor: kHubPanel,
        title: Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(c).pop();
              widget.onReport(m);
            },
            child: const Row(children: <Widget>[Icon(Icons.flag_rounded, color: kHubAmber, size: 20), SizedBox(width: 10), Text('Report this message', style: TextStyle(color: Colors.white))]),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(c).pop();
              widget.onBlock(m);
            },
            child: const Row(children: <Widget>[Icon(Icons.block_rounded, color: kHubMagenta, size: 20), SizedBox(width: 10), Text('Block this player', style: TextStyle(color: Colors.white))]),
          ),
          SimpleDialogOption(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel', style: TextStyle(color: Color(0xFF9AA6C2)))),
        ],
      ),
    );
  }

  Widget _tile(DarkomChatMessage m) {
    final bool mine = m.userId == widget.chat.myId;
    final Color nc = mine ? kHubCyan : _nameColors[m.userId.hashCode.abs() % _nameColors.length];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: mine ? null : () => _menu(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(
            child: Text.rich(TextSpan(children: <InlineSpan>[
              TextSpan(text: '${mine ? 'You' : m.name}  ', style: TextStyle(color: nc, fontWeight: FontWeight.w900, fontSize: 14)),
              TextSpan(text: m.body, style: const TextStyle(color: Color(0xFFE6ECF8), fontSize: 14)),
            ])),
          ),
          if (!mine)
            InkWell(
              onTap: () => _menu(m),
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.more_horiz_rounded, size: 18, color: Colors.white38)),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.listenable,
      builder: (BuildContext ctx, Widget? w) {
        final List<HubChatTab> tabs = widget.tabs();
        if (!tabs.any((HubChatTab t) => t.room == _room) && tabs.isNotEmpty) {
          _room = tabs.first.room;
          widget.chat.markRead(_room);
          widget.chat.openRoom(_room);
        }
        final List<DarkomChatMessage> msgs = widget.chat.messages(_room);
        return Column(children: <Widget>[
          if (tabs.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: <Widget>[
                for (final HubChatTab t in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.label + ((widget.chat.unread[t.room] ?? 0) > 0 && t.room != _room ? '  (${widget.chat.unread[t.room]})' : ''), style: TextStyle(color: t.room == _room ? Colors.black : Colors.white, fontWeight: FontWeight.w900)),
                      selected: t.room == _room,
                      selectedColor: kHubCyan,
                      backgroundColor: const Color(0xFF151B2E),
                      onSelected: (bool v) => _pick(t.room),
                    ),
                  ),
              ]),
            ),
          Expanded(
            child: msgs.isEmpty
                ? const Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: Color(0xFF9AA6C2))))
                : ListView.builder(
                    reverse: true,
                    itemCount: msgs.length,
                    itemBuilder: (BuildContext c, int i) => _tile(msgs[msgs.length - 1 - i]),
                  ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final String ph in kHubQuickPhrases)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(ph, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF1A2340),
                      side: const BorderSide(color: Color(0xFF2E3A66)),
                      onPressed: _sending ? null : () => _send(ph),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(children: <Widget>[
            Expanded(
              child: TextField(
                controller: _text,
                maxLength: 140,
                inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(140)],
                textInputAction: TextInputAction.send,
                onSubmitted: (String v) => _send(v, fromField: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Say something nice...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF121A2E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: kHubCyan, foregroundColor: Colors.black),
              tooltip: 'Send',
              onPressed: _sending ? null : () => _send(_text.text, fromField: true),
              icon: const Icon(Icons.send_rounded),
            ),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerLeft, child: Text(_error!, style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700, fontSize: 13)))),
          const Padding(padding: EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerLeft, child: Text('Be kind. Abuse gets you muted.', style: TextStyle(color: Color(0xFF7F8BA8), fontSize: 12)))),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------ player card

class _LookPreview extends CustomPainter {
  final DarkomLook look;
  _LookPreview(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.86), width: 70, height: 16), Paint()..color = const Color(0x66000000));
    paintDarkomLook(canvas, look, size.width / 2, size.height * 0.84, scale: 1.9, moving: false, facing: 1, showWeapon: true, aim: 0.35, weaponLen: 46);
  }

  @override
  bool shouldRepaint(covariant _LookPreview old) => old.look != look;
}

class HubPlayerCard extends StatelessWidget {
  final DarkomLook look;
  final bool blocked;
  final String? challengeNote;
  final bool canChallenge;
  final VoidCallback onChallenge;
  final VoidCallback onBlockToggle;
  final VoidCallback onReport;
  const HubPlayerCard({
    super.key,
    required this.look,
    required this.blocked,
    required this.challengeNote,
    required this.canChallenge,
    required this.onChallenge,
    required this.onBlockToggle,
    required this.onReport,
  });

  Widget _btn(String label, IconData icon, Color color, VoidCallback? onTap, {bool filled = false}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? color : const Color(0xFF151B2E),
          foregroundColor: filled ? Colors.black : color,
          side: BorderSide(color: color.withOpacity(0.7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Container(
            width: 116,
            height: 150,
            decoration: BoxDecoration(color: const Color(0xFF0A1020), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF263050))),
            child: CustomPaint(painter: _LookPreview(look)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(look.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(look.title ?? 'Darkom Citizen', style: const TextStyle(color: kHubAmber, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Weapon: ${look.weaponKind}', style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _btn('CHALLENGE 1v1', Icons.sports_martial_arts_rounded, kHubMagenta, (canChallenge && !blocked) ? onChallenge : null, filled: true),
        if (challengeNote != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(challengeNote!, style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 13))),
        const SizedBox(height: 8),
        Row(children: <Widget>[
          Expanded(child: _btn(blocked ? 'UNBLOCK' : 'BLOCK', Icons.block_rounded, kHubCyan, onBlockToggle)),
          const SizedBox(width: 10),
          Expanded(child: _btn('REPORT', Icons.flag_rounded, kHubAmber, onReport)),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------- duel panel

class HubDuelPanel extends StatelessWidget {
  final List<DarkomLook> players;
  final bool canChallenge;
  final String? note;
  final void Function(DarkomLook look) onChallenge;
  final void Function(DarkomLook look) onCard;
  const HubDuelPanel({super.key, required this.players, required this.canChallenge, required this.note, required this.onChallenge, required this.onCard});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      const Text('Pick a player in the plaza for a best of 3 duel. You can also tap any player you see. Only cosmetics are at stake, so play fair.',
          style: TextStyle(color: Color(0xFFD5DCEC), fontSize: 13, height: 1.4)),
      if (note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note!, style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700))),
      const SizedBox(height: 10),
      if (players.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('Nobody else is in the plaza right now.', style: TextStyle(color: Color(0xFF9AA6C2)))))
      else
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final DarkomLook p in players)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  decoration: BoxDecoration(color: const Color(0xFF121A2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF263050))),
                  child: Row(children: <Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: () => onCard(p),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          Text(p.title ?? 'Darkom Citizen', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kHubAmber, fontSize: 12)),
                        ]),
                      ),
                    ),
                    TextButton(
                      onPressed: canChallenge ? () => onChallenge(p) : null,
                      child: const Text('CHALLENGE', style: TextStyle(color: kHubMagenta, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
            ],
          ),
        ),
    ]);
  }
}

// ----------------------------------------------------------- notice board

class HubNoticePanel extends StatefulWidget {
  final Set<String> blocked;
  final Map<String, String> names;
  final Future<void> Function(String id) onUnblock;
  const HubNoticePanel({super.key, required this.blocked, required this.names, required this.onUnblock});

  @override
  State<HubNoticePanel> createState() => _HubNoticePanelState();
}

class _HubNoticePanelState extends State<HubNoticePanel> {
  Widget _rule(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, color: kHubAmber, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: Color(0xFFC9D2E6), fontSize: 13, height: 1.35)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> ids = widget.blocked.toList();
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _rule(Icons.favorite_rounded, 'Be kind', 'Treat everyone the way you want to be treated. Teasing that hurts is bullying.'),
        _rule(Icons.flag_rounded, 'Report abuse', 'Tap a player or hold a message to report it. Players who get reported by several people are muted for a while.'),
        _rule(Icons.mic_rounded, 'Voice is optional', 'Voice starts off. You choose a channel, you join muted, and you can leave any time.'),
        _rule(Icons.lock_rounded, 'Keep private things private', 'Never share your real address, school, phone number or passwords. Nobody here needs them.'),
        _rule(Icons.shield_rounded, 'Fair play', 'Only cosmetics are sold. Nobody can buy a stronger hero, so win by skill.'),
        if (ids.isNotEmpty) ...<Widget>[
          const Divider(color: Color(0xFF263050)),
          const Text('BLOCKED PLAYERS', style: TextStyle(color: kHubCyan, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 6),
          for (final String id in ids)
            Row(children: <Widget>[
              Expanded(child: Text(widget.names[id] ?? 'Player ${id.length > 4 ? id.substring(id.length - 4) : id}', style: const TextStyle(color: Colors.white))),
              TextButton(
                onPressed: () async {
                  await widget.onUnblock(id);
                  if (mounted) setState(() {});
                },
                child: const Text('UNBLOCK', style: TextStyle(color: kHubCyan, fontWeight: FontWeight.w900)),
              ),
            ]),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------ emote wheel

class HubEmoteWheel extends StatelessWidget {
  final void Function(int index) onPick;
  const HubEmoteWheel({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xEE0B0F1C), borderRadius: BorderRadius.circular(16), border: Border.all(color: kHubAmber.withOpacity(0.7))),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (int i = 0; i < kHubEmotes.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPick(i),
              child: SizedBox(
                width: 60,
                height: 56,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Icon(kHubEmotes[i].icon, color: kHubAmber, size: 24),
                  const SizedBox(height: 2),
                  Text(kHubEmotes[i].label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
