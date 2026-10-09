import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../darkom_look.dart';
import '../arena/darkom_arena_args.dart';
import 'darkom_hub_net.dart';
import 'darkom_hub_painter.dart';
import 'darkom_hub_panels.dart';
import 'darkom_hub_service.dart';
import 'darkom_hub_squads.dart';
import 'darkom_hub_world.dart';
import 'darkom_voice.dart';

/// Neon Plaza: the open world where Darkom players meet.
/// Route: '/darkom/hub'.
class DarkomHubScreen extends StatefulWidget {
  const DarkomHubScreen({super.key});

  /// Opens the plaza from anywhere.
  static Future<void> open(BuildContext context) => context.push<void>('/darkom/hub');

  @override
  State<DarkomHubScreen> createState() => _DarkomHubScreenState();
}

class _DarkomHubScreenState extends State<DarkomHubScreen> with SingleTickerProviderStateMixin {
  final HubScene _scene = HubScene();
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  final ValueNotifier<HubPortal?> _near = ValueNotifier<HubPortal?>(null);
  final ValueNotifier<String?> _banner = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _emoteOpen = ValueNotifier<bool>(false);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _pruneAcc = 0;

  DarkomHubNet? _net;
  late final HubChatController _chat;
  late final HubSquadController _squads;
  final DarkomVoice _voice = DarkomVoice();
  String _myId = '';
  String _instance = '1';
  bool _ready = false;
  String? _fatal;
  DarkomLook? _myLook;

  Set<String> _blocked = <String>{};
  final Map<String, String> _blockedNames = <String, String>{};

  bool _paused = false;
  int _sheets = 0;
  Size _viewSize = Size.zero;
  int _lastEmoteMs = 0;
  String? _openedHouse;
  String? _openedSquad;

  StreamSubscription<DarkomChallenge>? _chSub;
  DarkomChallenge? _outgoing;
  bool _sendingChallenge = false;
  Timer? _outTimer;
  Timer? _bannerTimer;
  Timer? _lookTimer;
  String? _incomingId;
  BuildContext? _dialogCtx;
  Timer? _incomingTimer;
  final Set<String> _launched = <String>{};

  @override
  void initState() {
    super.initState();
    _myId = SupabaseService.currentUserId ?? '';
    _scene.myId = _myId;
    _chat = HubChatController(_myId)..onHubMessage = _onHubMessage;
    _squads = HubSquadController(_myId)..onStarted = _launchSquad;
    _squads.addListener(_onSquadsChanged);
    _ticker = createTicker(_onTick)..start();
    _boot();
  }

  Future<void> _boot() async {
    if (_myId.isEmpty) {
      _fatal = 'Please sign in to enter the plaza.';
      return;
    }
    try {
      _blocked = await DarkomHubService.blockedIds();
    } catch (_) {}
    if (!mounted) return;
    final DarkomLook look = await DarkomLook.mine();
    if (!mounted) return;
    _myLook = look;
    _scene.myLook = look;
    final String inst = await DarkomHubService.joinHub();
    if (!mounted) {
      DarkomHubService.leaveHub(inst);
      return;
    }
    _instance = inst;
    final DarkomHubNet net = DarkomHubNet(inst, _myId);
    net.setBlocked(_blocked);
    net.onEmote = _onRemoteEmote;
    _net = net;
    _scene.net = net;
    net.online.addListener(_onlineChanged);
    net.status.addListener(_onlineChanged);
    await net.start(look);
    if (!mounted) return;
    _chat.setBlocked(_blocked);
    _voice.setBlocked(_blocked);
    _chat.openRoom('hub:$inst');
    _chSub = DarkomHubService.myChallengeStream().listen(_onChallenge, onError: (Object e) {});
    _lookTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshLook());
    setState(() => _ready = true);
    _squads.init();
  }

  void _onlineChanged() {
    if (mounted) setState(() {});
  }

  void _onSquadsChanged() {
    if (!mounted) return;
    final String? hid = _squads.houseId;
    if (hid != null && _openedHouse != hid) {
      _openedHouse = hid;
      _chat.openRoom('house:$hid');
    }
    final String? sid = _squads.mine?.id;
    if (sid != _openedSquad) {
      final String? old = _openedSquad;
      if (old != null) {
        _chat.closeRoom('squad:$old');
        if (_voice.live && _voice.channelLabel == 'Squad') _voice.leave();
      }
      _openedSquad = sid;
      if (sid != null) _chat.openRoom('squad:$sid');
    }
    setState(() {});
  }

  Future<void> _refreshLook() async {
    final DarkomLook l = await DarkomLook.mine();
    if (!mounted) return;
    _myLook = l;
    _scene.myLook = l;
    await _net?.updateLook(l);
  }

  // ------------------------------------------------------------- game loop

  void _onTick(Duration d) {
    double dt = (d - _last).inMicroseconds / 1000000.0;
    _last = d;
    dt = dt.clamp(0.0, 0.05).toDouble();
    if (_paused) return;
    final HubSim s = _scene.sim;
    s.time += dt;
    double ix = 0;
    double iy = 0;
    if (_sheets == 0) {
      final Set<LogicalKeyboardKey> k = HardwareKeyboard.instance.logicalKeysPressed;
      if (k.contains(LogicalKeyboardKey.keyA) || k.contains(LogicalKeyboardKey.arrowLeft)) ix -= 1;
      if (k.contains(LogicalKeyboardKey.keyD) || k.contains(LogicalKeyboardKey.arrowRight)) ix += 1;
      if (k.contains(LogicalKeyboardKey.keyW) || k.contains(LogicalKeyboardKey.arrowUp)) iy -= 1;
      if (k.contains(LogicalKeyboardKey.keyS) || k.contains(LogicalKeyboardKey.arrowDown)) iy += 1;
      if (s.joyOn) {
        ix += s.joyDelta.dx / 54;
        iy += s.joyDelta.dy / 54;
      }
    }
    s.step(dt, ix, iy);
    final DarkomHubNet? net = _net;
    if (net != null) {
      net.step(dt);
      net.maybeSendPos(s.x, s.y, s.facing, s.moving);
    }
    final HubPortal? p = HubWorld.portalNear(s.x, s.y);
    if (p?.id != _near.value?.id) {
      _near.value = p;
      _scene.near = p;
    }
    _pruneAcc += dt;
    if (_pruneAcc > 0.5) {
      _pruneAcc = 0;
      s.prune(DateTime.now().millisecondsSinceEpoch);
    }
    _tick.value++;
  }

  // --------------------------------------------------------------- helpers

  Future<T?> _sheet<T>(WidgetBuilder builder) async {
    _sheets++;
    _scene.sim.joyOn = false;
    _emoteOpen.value = false;
    try {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: builder,
      );
    } finally {
      _sheets--;
      _scene.selectedId = null;
    }
  }

  Future<void> _goto(Future<dynamic> f, {bool squad = false}) async {
    _paused = true;
    _ticker.muted = true;
    _scene.sim.joyOn = false;
    _scene.sim.moving = false;
    try {
      await f;
    } catch (_) {}
    if (!mounted) return;
    _paused = false;
    _ticker.muted = false;
    if (squad) _squads.afterMatch();
    _refreshLook();
  }

  void _setBanner(String? text, {bool sticky = false}) {
    _bannerTimer?.cancel();
    _banner.value = text;
    if (text != null && !sticky) {
      _bannerTimer = Timer(const Duration(seconds: 5), () => _banner.value = null);
    }
  }

  Future<void> _notice(String title, String text) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: kHubPanel,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(text, style: const TextStyle(color: Color(0xFFD5DCEC))),
        actions: <Widget>[TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(color: kHubCyan, fontWeight: FontWeight.w900)))],
      ),
    );
  }

  String _nameOf(String id) {
    final DarkomLook? l = _net?.looks[id];
    if (l != null) return l.name;
    final String s = _squads.nameOf(id);
    if (s.isNotEmpty) return s;
    return _blockedNames[id] ?? 'Player';
  }

  void _onHubMessage(DarkomChatMessage m) {
    if (_blocked.contains(m.userId)) return;
    final HubSim s = _scene.sim;
    if (s.bubbles.length > 30) s.prune(DateTime.now().millisecondsSinceEpoch);
    final String t = m.body.length > 60 ? '${m.body.substring(0, 60)}..' : m.body;
    s.bubbles[m.userId] = HubBubble(t, DateTime.now().millisecondsSinceEpoch + 5000);
  }

  void _onRemoteEmote(String id, int idx) {
    final HubSim s = _scene.sim;
    if (s.emotes.length > 30) s.prune(DateTime.now().millisecondsSinceEpoch);
    s.emotes[id] = HubEmoteShow(idx, DateTime.now().millisecondsSinceEpoch);
  }

  void _emote(int i) {
    _emoteOpen.value = false;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEmoteMs < 1500) return;
    _lastEmoteMs = now;
    _scene.sim.emotes[_myId] = HubEmoteShow(i, now);
    _net?.sendEmote(i);
  }

  // ------------------------------------------------------ safety: block etc

  void _applyBlocked() {
    _net?.setBlocked(_blocked);
    _chat.setBlocked(_blocked);
    _voice.setBlocked(_blocked);
    _scene.sim.bubbles.removeWhere((String k, HubBubble v) => _blocked.contains(k));
    _scene.sim.emotes.removeWhere((String k, HubEmoteShow v) => _blocked.contains(k));
    if (mounted) setState(() {});
  }

  Future<void> _report(String userId, String name, {String room = '', String? messageId}) async {
    if (userId.isEmpty || userId == _myId) return;
    final String? reason = await hubPickReason(context, name);
    if (reason == null || !mounted) return;
    final bool ok = await DarkomHubService.reportUser(userId: userId, reason: reason, room: room, messageId: messageId);
    if (!mounted) return;
    await _notice(ok ? 'Report sent' : 'Could not send', ok ? 'Thank you for helping keep the plaza kind. Our team will look into it.' : 'We could not send that report. Please try again in a moment.');
  }

  Future<void> _block(String userId, String name) async {
    if (userId.isEmpty || userId == _myId) return;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: kHubPanel,
        title: Text('Block $name?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('You will not see or hear this player, and they cannot challenge you. You can unblock them from the Notice Board.', style: TextStyle(color: Color(0xFFD5DCEC))),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF9AA6C2)))),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('BLOCK', style: TextStyle(color: kHubMagenta, fontWeight: FontWeight.w900))),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final bool ok = await DarkomHubService.blockUser(userId);
    if (!mounted) return;
    if (ok) {
      _blocked.add(userId);
      _blockedNames[userId] = name;
      _applyBlocked();
    } else {
      await _notice('Could not block', 'Please try again in a moment.');
    }
  }

  Future<void> _unblock(String userId) async {
    final bool ok = await DarkomHubService.unblockUser(userId);
    if (ok && mounted) {
      _blocked.remove(userId);
      _applyBlocked();
    }
  }

  // ---------------------------------------------------------------- sheets

  List<HubChatTab> _chatTabs() {
    final String? hid = _squads.houseId;
    final String? sid = _squads.mine?.id;
    return <HubChatTab>[
      HubChatTab('HUB', 'hub:$_instance'),
      if (hid != null) HubChatTab('HOUSE', 'house:$hid'),
      if (sid != null) HubChatTab('SQUAD', 'squad:$sid'),
    ];
  }

  void _openChat({String? room}) {
    if (!_ready) return;
    _sheet<void>((BuildContext c) => HubSheetFrame(
          title: 'CHAT',
          icon: Icons.chat_bubble_rounded,
          color: kHubCyan,
          fill: true,
          child: HubChatPanel(
            chat: _chat,
            listenable: Listenable.merge(<Listenable>[_chat, _squads]),
            tabs: _chatTabs,
            initialRoom: room ?? 'hub:$_instance',
            onReport: (DarkomChatMessage m) => _report(m.userId, m.name, room: m.room, messageId: m.id),
            onBlock: (DarkomChatMessage m) => _block(m.userId, m.name),
          ),
        ));
  }

  void _openVoice() {
    if (!_ready) return;
    _sheet<void>((BuildContext c) => HubSheetFrame(
          title: 'VOICE',
          icon: Icons.headset_mic_rounded,
          color: kHubViolet,
          child: HubVoiceSheet(
            voice: _voice,
            hubRoom: _instance,
            houseId: _squads.houseId,
            squadId: _squads.mine?.id,
            nameOf: _nameOf,
            onReport: (String id, String name) => _report(id, name),
            onBlock: (String id, String name) => _block(id, name),
          ),
        ));
  }

  bool _canChallenge() => _outgoing == null && _incomingId == null && !_sendingChallenge && !_paused;

  void _openPlayerCard(String id) {
    final DarkomLook? look = _net?.looks[id];
    if (look == null) return;
    _scene.selectedId = id;
    final bool busy = !_canChallenge();
    _sheet<void>((BuildContext c) => HubSheetFrame(
          title: 'PLAYER',
          icon: Icons.person_rounded,
          color: kHubCyan,
          child: HubPlayerCard(
            look: look,
            blocked: _blocked.contains(id),
            canChallenge: !busy,
            challengeNote: busy ? 'Finish your current challenge first.' : null,
            onChallenge: () {
              Navigator.of(c).pop();
              _sendChallenge(look);
            },
            onBlockToggle: () {
              Navigator.of(c).pop();
              if (_blocked.contains(id)) {
                _unblock(id);
              } else {
                _block(id, look.name);
              }
            },
            onReport: () {
              Navigator.of(c).pop();
              _report(id, look.name);
            },
          ),
        ));
  }

  void _openDuel() {
    final List<DarkomLook> players = (_net?.looks.values.toList() ?? <DarkomLook>[])..sort((DarkomLook a, DarkomLook b) => a.name.compareTo(b.name));
    final bool busy = !_canChallenge();
    _sheet<void>((BuildContext c) => HubSheetFrame(
          title: 'ARENA GATE',
          icon: Icons.sports_martial_arts_rounded,
          color: kHubMagenta,
          child: HubDuelPanel(
            players: players.length > 40 ? players.sublist(0, 40) : players,
            canChallenge: !busy,
            note: busy ? 'Finish your current challenge first.' : null,
            onChallenge: (DarkomLook l) {
              Navigator.of(c).pop();
              _sendChallenge(l);
            },
            onCard: (DarkomLook l) {
              Navigator.of(c).pop();
              _openPlayerCard(l.userId);
            },
          ),
        ));
  }

  void _openSquadHall() {
    _sheet<void>((BuildContext c) => HubSheetFrame(
          title: 'SQUAD HALL',
          icon: Icons.groups_rounded,
          color: kHubGreen,
          child: HubSquadPanel(
            squads: _squads,
            onOpenHouses: () {
              Navigator.of(c).pop();
              _goto(context.push<void>('/houses'));
            },
            onSquadChat: () {
              final String? sid = _squads.mine?.id;
              Navigator.of(c).pop();
              if (sid != null) _openChat(room: 'squad:$sid');
            },
            onSquadVoice: () {
              Navigator.of(c).pop();
              _openVoice();
            },
          ),
        ));
  }

  void _openNotice() {
    _sheet<void>((BuildContext c) => HubSheetFrame(
          title: 'NOTICE BOARD',
          icon: Icons.campaign_rounded,
          color: kHubAmber,
          child: HubNoticePanel(blocked: _blocked, names: _blockedNames, onUnblock: _unblock),
        ));
  }

  void _interact() {
    final HubPortal? p = _near.value;
    if (p == null || _paused || _sheets > 0) return;
    switch (p.id) {
      case 'story':
        _goto(context.push<void>('/darkom'));
        break;
      case 'arena':
        _openDuel();
        break;
      case 'squad':
        _openSquadHall();
        break;
      case 'locker':
        _goto(context.push<void>('/locker'));
        break;
      case 'notice':
        _openNotice();
        break;
    }
  }

  // ------------------------------------------------------------ challenges

  Future<void> _sendChallenge(DarkomLook look) async {
    if (!_canChallenge() || look.userId.isEmpty) {
      _setBanner('Finish your current challenge first.');
      return;
    }
    _sendingChallenge = true;
    _setBanner('Sending your challenge to ${look.name}...', sticky: true);
    DarkomChallenge? c;
    try {
      c = await DarkomHubService.challenge(look.userId);
    } catch (_) {
      c = null;
    }
    _sendingChallenge = false;
    if (!mounted) return;
    if (c == null) {
      _setBanner('Could not send that challenge right now.');
      return;
    }
    final DarkomChallenge sent = c;
    _outgoing = sent;
    _setBanner('Waiting for ${look.name}...', sticky: true);
    _outTimer?.cancel();
    _outTimer = Timer(const Duration(seconds: 62), () {
      if (_outgoing?.id == sent.id) {
        _outgoing = null;
        _setBanner('${look.name} did not answer. The challenge expired.');
      }
    });
  }

  int _age(DarkomChallenge c) => DateTime.now().difference(c.at).inSeconds.abs();

  void _onChallenge(DarkomChallenge c) {
    if (!mounted || _myId.isEmpty) return;
    final bool toMe = c.toId == _myId;
    final bool fromMe = c.fromId == _myId;
    if (toMe && !fromMe) {
      if (_blocked.contains(c.fromId)) return;
      if (c.status == 'pending') {
        _showIncoming(c);
      } else if (c.status == 'accepted') {
        if (_age(c) < 180) _launchDuel(c);
      } else if (_incomingId == c.id) {
        _closeIncoming();
      }
    } else if (fromMe) {
      if (c.status == 'accepted') {
        if (_age(c) < 180) _launchDuel(c);
        return;
      }
      final DarkomChallenge? o = _outgoing;
      if (o != null && o.id == c.id) {
        if (c.status == 'declined') {
          _clearOutgoing();
          _setBanner('${c.toName} declined your challenge.');
        } else if (c.status == 'expired') {
          _clearOutgoing();
          _setBanner('${c.toName} did not answer. The challenge expired.');
        } else if (c.status == 'done') {
          _clearOutgoing();
        }
      }
    }
  }

  void _clearOutgoing() {
    _outgoing = null;
    _outTimer?.cancel();
  }

  void _closeIncoming() {
    final BuildContext? ctx = _dialogCtx;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
  }

  Future<void> _showIncoming(DarkomChallenge c) async {
    if (_paused || _incomingId != null || _outgoing != null || _sendingChallenge) {
      DarkomHubService.respondChallenge(c.id, false);
      return;
    }
    _incomingId = c.id;
    final int remaining = (60 - _age(c)).clamp(5, 60).toInt();
    _incomingTimer?.cancel();
    _incomingTimer = Timer(Duration(seconds: remaining), _closeIncoming);
    final int? res = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        _dialogCtx = ctx;
        return AlertDialog(
          backgroundColor: kHubPanel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kHubMagenta, width: 2)),
          title: Text('${c.fromName} challenges you', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          content: const Text('A friendly best of 3 duel. Only cosmetics are at stake, so play fair. You have about a minute to answer.', style: TextStyle(color: Color(0xFFD5DCEC))),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(0), child: const Text('DECLINE', style: TextStyle(color: Color(0xFF9AA6C2), fontWeight: FontWeight.w900))),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(1),
              style: ElevatedButton.styleFrom(backgroundColor: kHubMagenta, foregroundColor: Colors.black),
              child: const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
    _incomingTimer?.cancel();
    _dialogCtx = null;
    _incomingId = null;
    if (!mounted) return;
    if (res == 1) {
      final DarkomChallenge? u = await DarkomHubService.respondChallenge(c.id, true);
      if (!mounted) return;
      if (u != null && u.status == 'accepted') {
        _launchDuel(u);
      } else {
        _setBanner('That challenge is no longer available.');
      }
    } else if (res == 0) {
      DarkomHubService.respondChallenge(c.id, false);
    } else {
      _setBanner('The challenge from ${c.fromName} expired.');
    }
  }

  void _launchDuel(DarkomChallenge c) {
    if (_paused || _launched.contains(c.id) || !mounted) return;
    _launched.add(c.id);
    _clearOutgoing();
    _setBanner(null);
    _goto(context.push<void>(
      '/darkom/arena',
      extra: DarkomArenaArgs(code: c.code, mode: 'duel', playerIds: <String>[c.fromId, c.toId], challengeId: c.id),
    ));
  }

  void _launchSquad(DarkomSquad s) {
    if (!mounted) return;
    if (_paused) {
      // Busy in another screen: leave the started squad so nobody stays stuck in it.
      _squads.afterMatch();
      return;
    }
    _goto(
      context.push<void>(
        '/darkom/arena',
        extra: DarkomArenaArgs(code: 'sq_${s.id}', mode: 'squad', playerIds: List<String>.from(s.memberIds), squadId: s.id),
      ),
      squad: true,
    );
  }

  // --------------------------------------------------------------- gestures

  void _onTap(Offset p) {
    final DarkomHubNet? net = _net;
    if (net == null || _sheets > 0) return;
    final HubSim s = _scene.sim;
    final HubCam cam = hubCamera(_viewSize, s.x, s.y);
    final Offset w = cam.toWorld(p);
    HubRemote? best;
    double bd = 46.0 * 46.0;
    for (final HubRemote r in net.visible(s.x, s.y, DateTime.now().millisecondsSinceEpoch)) {
      final double dx = r.x - w.dx;
      final double dy = (r.y - 26) - w.dy;
      final double d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = r;
      }
    }
    _emoteOpen.value = false;
    if (best != null) _openPlayerCard(best.id);
  }

  void _panStart(DragStartDetails d) {
    if (_sheets > 0) return;
    final HubSim s = _scene.sim;
    s.joyOn = true;
    s.joyOrigin = d.localPosition;
    s.joyDelta = Offset.zero;
    if (_emoteOpen.value) _emoteOpen.value = false;
  }

  void _panUpdate(DragUpdateDetails d) {
    final HubSim s = _scene.sim;
    if (s.joyOn) s.joyDelta = d.localPosition - s.joyOrigin;
  }

  void _panEnd() {
    final HubSim s = _scene.sim;
    s.joyOn = false;
    s.joyDelta = Offset.zero;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || _sheets > 0) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = e.logicalKey;
    if (k == LogicalKeyboardKey.keyE || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      _interact();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyT) {
      _openChat();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _leave() {
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _lookTimer?.cancel();
    _outTimer?.cancel();
    _bannerTimer?.cancel();
    _incomingTimer?.cancel();
    _chSub?.cancel();
    _squads.removeListener(_onSquadsChanged);
    _squads.leaveIfOpen();
    _squads.dispose();
    _chat.dispose();
    _voice.dispose();
    final DarkomHubNet? net = _net;
    if (net != null) {
      net.online.removeListener(_onlineChanged);
      net.status.removeListener(_onlineChanged);
      unawaited(net.dispose());
      unawaited(DarkomHubService.leaveHub(_instance));
    }
    _tick.dispose();
    _near.dispose();
    _banner.dispose();
    _emoteOpen.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------- UI

  Widget _hudBtn(IconData icon, String label, Color color, VoidCallback onTap, {int badge = 0, bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Stack(clipBehavior: Clip.none, children: <Widget>[
          Material(
            color: active ? color : const Color(0xE60B0F1C),
            shape: CircleBorder(side: BorderSide(color: color, width: 2)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 52, height: 52, child: Icon(icon, color: active ? Colors.black : color, size: 26)),
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kHubMagenta, borderRadius: BorderRadius.circular(10)),
                child: Text(badge > 9 ? '9+' : '$badge', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 3)])),
      ]),
    );
  }

  Widget _topBar(double inset) {
    final DarkomHubNet? net = _net;
    final bool live = net != null && net.status.value == 'live';
    final int online = net?.online.value ?? 1;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, inset + 6, 8, 0),
        child: Row(children: <Widget>[
          Material(
            color: const Color(0xE60B0F1C),
            shape: const CircleBorder(side: BorderSide(color: kHubCyan, width: 1.5)),
            child: InkWell(customBorder: const CircleBorder(), onTap: _leave, child: const SizedBox(width: 42, height: 42, child: Icon(Icons.arrow_back_rounded, color: kHubCyan))),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xE60B0F1C), borderRadius: BorderRadius.circular(20), border: Border.all(color: kHubMagenta.withOpacity(0.7))),
            child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('NEON PLAZA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13)),
              const SizedBox(width: 8),
              Text(_ready ? 'Hub $_instance  |  $online here' : 'Joining...', style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: live ? kHubGreen : kHubAmber)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    _scene.topInset = mq.padding.top;
    return Scaffold(
      backgroundColor: kHubInk,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(builder: (BuildContext context, BoxConstraints bc) {
          _viewSize = bc.biggest;
          return Stack(children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: (DragEndDetails d) => _panEnd(),
                onPanCancel: _panEnd,
                onTapUp: (TapUpDetails d) => _onTap(d.localPosition),
                child: RepaintBoundary(child: CustomPaint(painter: HubPainter(_scene, repaint: _tick), size: Size.infinite)),
              ),
            ),
            _topBar(mq.padding.top),
            // challenge and info banner
            Positioned(
              top: mq.padding.top + 58,
              left: 124,
              right: 12,
              child: ValueListenableBuilder<String?>(
                valueListenable: _banner,
                builder: (BuildContext c, String? text, Widget? w) {
                  if (text == null) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xEE0B0F1C), borderRadius: BorderRadius.circular(12), border: Border.all(color: kHubMagenta)),
                      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
            // right side buttons
            Positioned(
              right: 10,
              bottom: mq.padding.bottom + 12,
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_chat, _voice, _squads]),
                builder: (BuildContext c, Widget? w) => Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  if (_squads.mine != null) _hudBtn(Icons.groups_rounded, 'SQUAD', kHubGreen, _openSquadHall),
                  _hudBtn(_voice.live ? (_voice.micOn ? Icons.mic_rounded : Icons.mic_off_rounded) : Icons.headset_mic_rounded, 'VOICE', kHubViolet, _openVoice, active: _voice.live),
                  _hudBtn(Icons.emoji_emotions_rounded, 'EMOTE', kHubAmber, () => _emoteOpen.value = !_emoteOpen.value),
                  _hudBtn(Icons.chat_bubble_rounded, 'CHAT', kHubCyan, _openChat, badge: _chat.totalUnread),
                ]),
              ),
            ),
            // emote wheel
            Positioned(
              right: 74,
              bottom: mq.padding.bottom + 12,
              child: ValueListenableBuilder<bool>(
                valueListenable: _emoteOpen,
                builder: (BuildContext c, bool open, Widget? w) => open ? SizedBox(width: 200, child: HubEmoteWheel(onPick: _emote)) : const SizedBox.shrink(),
              ),
            ),
            // enter prompt
            Positioned(
              left: 12,
              right: 84,
              bottom: mq.padding.bottom + 16,
              child: ValueListenableBuilder<HubPortal?>(
                valueListenable: _near,
                builder: (BuildContext c, HubPortal? p, Widget? w) {
                  if (p == null) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      decoration: BoxDecoration(color: const Color(0xF00B0F1C), borderRadius: BorderRadius.circular(16), border: Border.all(color: p.color, width: 2), boxShadow: <BoxShadow>[BoxShadow(color: p.color.withOpacity(0.35), blurRadius: 16)]),
                      child: Row(children: <Widget>[
                        Icon(p.icon, color: p.color, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text(p.label, style: TextStyle(color: p.color, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            Text(p.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D2E6), fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _interact,
                          style: ElevatedButton.styleFrom(backgroundColor: p.color, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ENTER', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            if (_fatal != null)
              Positioned.fill(
                child: Container(
                  color: const Color(0xEE05060A),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(_fatal!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    ElevatedButton(onPressed: _leave, child: const Text('BACK')),
                  ]),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}
