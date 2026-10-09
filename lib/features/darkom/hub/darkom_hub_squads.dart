import 'dart:async';
import 'package:flutter/material.dart';
import '../../houses/house_service.dart';
import 'darkom_hub_service.dart';
import 'darkom_hub_world.dart';

/// House squads: find my house, list open squads, create, join, leave and start.
class HubSquadController extends ChangeNotifier {
  final String myId;
  HubSquadController(this.myId);

  UserHouse? house;
  bool loading = true;
  bool busy = false;
  List<DarkomSquad> open = <DarkomSquad>[];
  DarkomSquad? mine;
  String? message;
  void Function(DarkomSquad squad)? onStarted;

  StreamSubscription<DarkomSquad>? _sub;
  Timer? _timer;
  int _watchers = 0;
  bool _disposed = false;
  final Set<String> _fired = <String>{};

  String? get houseId => (house == null || house!.houseId.isEmpty) ? null : house!.houseId;

  void _n() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    try {
      house = await HouseService.userHouse(myId);
    } catch (_) {
      house = null;
    }
    loading = false;
    _n();
    await refresh();
  }

  /// Called while the Squad Hall is on screen: refresh every 10 seconds.
  void watch() {
    _watchers++;
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) => refresh());
    refresh();
  }

  void unwatch() {
    _watchers--;
    if (_watchers <= 0) {
      _watchers = 0;
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refresh() async {
    final String? hid = houseId;
    if (hid == null || _disposed) return;
    try {
      final List<DarkomSquad> list = await DarkomHubService.openSquads(hid);
      if (_disposed) return;
      open = list.where((DarkomSquad s) => s.status == 'open' || s.status == 'started').toList();
      if (mine == null) {
        for (final DarkomSquad s in list) {
          if (s.status == 'open' && s.memberIds.contains(myId)) {
            _setMine(s);
            break;
          }
        }
      }
    } catch (_) {}
    _n();
  }

  void _setMine(DarkomSquad? s) {
    if (s == null) {
      _sub?.cancel();
      _sub = null;
      mine = null;
      return;
    }
    final bool sameId = mine != null && mine!.id == s.id;
    mine = s;
    if (!sameId) {
      _sub?.cancel();
      _sub = DarkomHubService.squadStream(s.id).listen(_onSquad, onError: (Object e) {});
    }
  }

  void _onSquad(DarkomSquad s) {
    if (_disposed) return;
    if (s.status == 'started') {
      if (s.memberIds.contains(myId)) {
        mine = s;
        _n();
        _fire(s);
      }
      return;
    }
    if (s.status == 'closed' || !s.memberIds.contains(myId)) {
      _setMine(null);
      message = 'The squad was closed.';
      _n();
      return;
    }
    mine = s;
    _n();
  }

  void _fire(DarkomSquad s) {
    if (_fired.contains(s.id)) return;
    _fired.add(s.id);
    final void Function(DarkomSquad)? cb = onStarted;
    if (cb != null) cb(s);
  }

  Future<void> create() async {
    final String? hid = houseId;
    if (hid == null || busy || mine != null) return;
    busy = true;
    message = null;
    _n();
    try {
      final DarkomSquad? s = await DarkomHubService.createSquad(hid);
      if (s == null) {
        message = 'Could not create a squad right now.';
      } else {
        _setMine(s);
      }
    } catch (_) {
      message = 'Could not create a squad right now.';
    }
    busy = false;
    _n();
    refresh();
  }

  Future<void> join(DarkomSquad squad) async {
    if (busy || mine != null) return;
    busy = true;
    message = null;
    _n();
    try {
      final DarkomSquad? s = await DarkomHubService.joinSquad(squad.id);
      if (s == null) {
        message = 'That squad is full or closed.';
      } else {
        _setMine(s);
      }
    } catch (_) {
      message = 'That squad is full or closed.';
    }
    busy = false;
    _n();
    refresh();
  }

  Future<void> leave() async {
    final DarkomSquad? s = mine;
    if (s == null || busy) return;
    busy = true;
    _n();
    try {
      await DarkomHubService.leaveSquad(s.id);
    } catch (_) {}
    _setMine(null);
    busy = false;
    message = null;
    _n();
    refresh();
  }

  Future<void> start() async {
    final DarkomSquad? s = mine;
    if (s == null || busy || s.hostId != myId) return;
    if (s.memberIds.length < 2) {
      message = 'You need at least 2 players to start.';
      _n();
      return;
    }
    busy = true;
    message = null;
    _n();
    try {
      final DarkomSquad? u = await DarkomHubService.startSquad(s.id);
      if (u == null) {
        message = 'Could not start the squad right now.';
      } else if (u.status == 'started') {
        mine = u;
        _fire(u);
      }
    } catch (_) {
      message = 'Could not start the squad right now.';
    }
    busy = false;
    _n();
  }

  /// After a squad match is over the player is no longer in that squad.
  void afterMatch() {
    _setMine(null);
    _n();
    refresh();
  }

  /// Leaves quietly when the player walks out of the plaza.
  void leaveIfOpen() {
    final DarkomSquad? s = mine;
    if (s != null && s.status == 'open') {
      unawaited(() async {
        try {
          await DarkomHubService.leaveSquad(s.id);
        } catch (_) {}
      }());
    }
  }

  String nameOf(String userId) {
    final DarkomSquad? s = mine;
    if (s == null) return '';
    final int i = s.memberIds.indexOf(userId);
    if (i >= 0 && i < s.memberNames.length) return s.memberNames[i];
    return '';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

/// The Squad Hall sheet content.
class HubSquadPanel extends StatefulWidget {
  final HubSquadController squads;
  final VoidCallback onOpenHouses;
  final VoidCallback onSquadChat;
  final VoidCallback onSquadVoice;
  const HubSquadPanel({super.key, required this.squads, required this.onOpenHouses, required this.onSquadChat, required this.onSquadVoice});

  @override
  State<HubSquadPanel> createState() => _HubSquadPanelState();
}

class _HubSquadPanelState extends State<HubSquadPanel> {
  @override
  void initState() {
    super.initState();
    widget.squads.watch();
  }

  @override
  void dispose() {
    widget.squads.unwatch();
    super.dispose();
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback? onTap, {bool filled = true}) {
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

  Widget _noHouse() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      const Text('Squads are made inside a house. A squad is up to 4 friends from your house who fight together in a free for all match.',
          style: TextStyle(color: Color(0xFFD5DCEC), fontSize: 14, height: 1.4)),
      const SizedBox(height: 8),
      const Text('You are not in a house yet. Join or start one, then come back here.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 13, height: 1.4)),
      const SizedBox(height: 14),
      _btn('OPEN HOUSES', Icons.house_rounded, kHubGreen, widget.onOpenHouses),
    ]);
  }

  Widget _mine(DarkomSquad s) {
    final HubSquadController c = widget.squads;
    final bool host = s.hostId == c.myId;
    final bool started = s.status == 'started';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('YOUR SQUAD  ${s.memberIds.length}/${s.maxPlayers}', style: const TextStyle(color: kHubGreen, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 8),
      for (int i = 0; i < s.memberIds.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF121A2E), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF263050))),
          child: Row(children: <Widget>[
            Icon(s.memberIds[i] == s.hostId ? Icons.star_rounded : Icons.person_rounded, size: 18, color: s.memberIds[i] == s.hostId ? kHubAmber : Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (i < s.memberNames.length ? s.memberNames[i] : 'Player') + (s.memberIds[i] == c.myId ? '  (you)' : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            if (s.memberIds[i] == s.hostId) const Text('HOST', style: TextStyle(color: kHubAmber, fontWeight: FontWeight.w900, fontSize: 11)),
          ]),
        ),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        _btn('SQUAD CHAT', Icons.chat_bubble_rounded, kHubCyan, widget.onSquadChat, filled: false),
        _btn('SQUAD VOICE', Icons.headset_mic_rounded, kHubViolet, widget.onSquadVoice, filled: false),
      ]),
      const SizedBox(height: 10),
      Row(children: <Widget>[
        Expanded(child: _btn('LEAVE', Icons.logout_rounded, kHubMagenta, c.busy ? null : c.leave, filled: false)),
        if (host) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(child: _btn(started ? 'STARTING' : 'START', Icons.play_arrow_rounded, kHubGreen, (c.busy || started) ? null : c.start)),
        ],
      ]),
      if (!host) const Padding(padding: EdgeInsets.only(top: 8), child: Text('The host starts the match.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 12))),
    ]);
  }

  Widget _list() {
    final HubSquadController c = widget.squads;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Expanded(child: Text('OPEN SQUADS', style: TextStyle(color: kHubGreen.withOpacity(0.9), fontWeight: FontWeight.w900, letterSpacing: 1))),
        IconButton(tooltip: 'Refresh', onPressed: c.refresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white70)),
      ]),
      if (c.open.where((DarkomSquad s) => s.status == 'open').isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No open squads in your house right now. Create one and invite friends.', style: TextStyle(color: Color(0xFF9AA6C2)))),
      for (final DarkomSquad s in c.open.where((DarkomSquad s) => s.status == 'open'))
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF121A2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: kHubGreen.withOpacity(0.4))),
          child: Row(children: <Widget>[
            const Icon(Icons.groups_rounded, color: kHubGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text('${s.hostName}\'s squad', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text('${s.memberIds.length}/${s.maxPlayers} players', style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 12)),
              ]),
            ),
            _btn('JOIN', Icons.add_rounded, kHubGreen, (c.busy || s.memberIds.length >= s.maxPlayers) ? null : () => c.join(s)),
          ]),
        ),
      const SizedBox(height: 6),
      _btn('CREATE SQUAD', Icons.add_rounded, kHubGreen, c.busy ? null : c.create),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.squads,
      builder: (BuildContext ctx, Widget? w) {
        final HubSquadController c = widget.squads;
        Widget body;
        if (c.loading) {
          body = const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: kHubGreen)));
        } else if (c.houseId == null) {
          body = _noHouse();
        } else {
          final DarkomSquad? m = c.mine;
          body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              const Icon(Icons.house_rounded, size: 18, color: kHubAmber),
              const SizedBox(width: 8),
              Expanded(child: Text(c.house?.name ?? 'Your house', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kHubAmber, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 10),
            if (m != null) _mine(m) else _list(),
            if (c.message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(c.message!, style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700))),
          ]);
        }
        return SingleChildScrollView(child: body);
      },
    );
  }
}
