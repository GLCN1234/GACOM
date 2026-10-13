import 'dart:async';
import 'package:flutter/material.dart';
import '../../houses/house_service.dart';
import '../darkom_service.dart';
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

  /// Host only: switch between the arena match and the City Patrol.
  Future<void> setMode(String mode) async {
    final DarkomSquad? s = mine;
    if (s == null || busy || s.hostId != myId || s.status != 'open' || s.mode == mode) return;
    busy = true;
    message = null;
    _n();
    try {
      final DarkomSquad? u = await DarkomHubService.setSquadMode(s.id, mode);
      if (u != null) {
        _setMine(u);
      } else {
        message = 'Could not change the mode right now.';
      }
    } catch (_) {
      message = 'Could not change the mode right now.';
    }
    busy = false;
    _n();
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
  bool _board = false;

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
      _modeRow(s, host),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        _btn('SQUAD CHAT', Icons.chat_bubble_rounded, kHubCyan, widget.onSquadChat, filled: false),
        _btn('SQUAD VOICE', Icons.headset_mic_rounded, kHubViolet, widget.onSquadVoice, filled: false),
        _btn('SQUAD BOARD', Icons.leaderboard_rounded, kHubAmber, () => setState(() => _board = true), filled: false),
      ]),
      const SizedBox(height: 10),
      Row(children: <Widget>[
        Expanded(child: _btn('LEAVE', Icons.logout_rounded, kHubMagenta, c.busy ? null : c.leave, filled: false)),
        if (host) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(child: _btn(started ? 'STARTING' : 'START', Icons.play_arrow_rounded, kHubGreen, (c.busy || started) ? null : c.start)),
        ],
      ]),
      if (!host) const Padding(padding: EdgeInsets.only(top: 8), child: Text('The host starts the game.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 12))),
    ]);
  }

  Widget _modeRow(DarkomSquad s, bool host) {
    final HubSquadController c = widget.squads;
    final bool city = s.mode == 'city';
    final bool contract = s.mode.startsWith('contract_');
    final bool canEdit = host && !c.busy && s.status == 'open';
    Widget chip(String label, String sub, String mode, bool on) {
      return Expanded(
        child: GestureDetector(
          onTap: canEdit ? () => c.setMode(mode) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: on ? kHubGreen.withOpacity(0.18) : const Color(0xFF121A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? kHubGreen : const Color(0xFF263050), width: on ? 1.6 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(label, style: TextStyle(color: on ? kHubGreen : Colors.white70, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 10, height: 1.2)),
            ]),
          ),
        ),
      );
    }

    Widget small(String label, String mode) {
      final bool on = s.mode == mode;
      return GestureDetector(
        onTap: canEdit ? () => c.setMode(mode) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: on ? kHubAmber.withOpacity(0.2) : const Color(0xFF121A2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? kHubAmber : const Color(0xFF263050)),
          ),
          child: Text(label, style: TextStyle(color: on ? kHubAmber : Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
      );
    }

    const Map<String, String> briefs = <String, String>{
      'contract_clear': 'Block Sweep: clear a set number of hostiles before time runs out.',
      'contract_hold': 'Hold the Line: survive four minutes as the waves grow.',
      'contract_bounty': 'Bounty Run: hunt down one tough target together.',
      'contract_data': 'Data Run: collect every data node across the city.',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        chip('ARENA', 'Free for all', 'arena', !city && !contract),
        const SizedBox(width: 6),
        chip('PATROL', 'Co-op, shared city', 'city', city),
        const SizedBox(width: 6),
        chip('CONTRACT', 'Co-op mission', contract ? s.mode : 'contract_clear', contract),
      ]),
      if (contract) ...<Widget>[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
          small('Block Sweep', 'contract_clear'),
          small('Hold the Line', 'contract_hold'),
          small('Bounty Run', 'contract_bounty'),
          small('Data Run', 'contract_data'),
        ]),
        const SizedBox(height: 6),
        Text(briefs[s.mode] ?? '', style: const TextStyle(color: Color(0xFFD5DCEC), fontSize: 11.5, height: 1.3)),
        const Text('A won contract gives each player Season Pass XP (up to 3 a day). It never changes solo points or rankings.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 10.5, height: 1.3)),
      ],
      if (!host) const Padding(padding: EdgeInsets.only(top: 6), child: Text('The host picks the mode.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 11))),
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
                Text('${s.hostName}\'s ${s.mode == 'city' ? 'city patrol' : (s.mode.startsWith('contract_') ? 'contract' : 'squad')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text('${s.memberIds.length}/${s.maxPlayers} players', style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 12)),
              ]),
            ),
            _btn('JOIN', Icons.add_rounded, kHubGreen, (c.busy || s.memberIds.length >= s.maxPlayers) ? null : () => c.join(s)),
          ]),
        ),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        _btn('CREATE SQUAD', Icons.add_rounded, kHubGreen, c.busy ? null : c.create),
        _btn('SQUAD BOARD', Icons.leaderboard_rounded, kHubAmber, () => setState(() => _board = true), filled: false),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.squads,
      builder: (BuildContext ctx, Widget? w) {
        final HubSquadController c = widget.squads;
        if (_board) return SingleChildScrollView(child: _SquadBoard(onBack: () => setState(() => _board = false)));
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


/// Squad Contracts board. Separate from every solo ranking: it only shows
/// co-op results.
class _SquadBoard extends StatefulWidget {
  final VoidCallback onBack;
  const _SquadBoard({required this.onBack});

  @override
  State<_SquadBoard> createState() => _SquadBoardState();
}

class _SquadBoardState extends State<_SquadBoard> {
  String _contract = 'clear';
  DarkomCoopBoard? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final DarkomCoopBoard? d = await DarkomService.coopBoard(_contract);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  static String _t(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _tab(String label, String id) {
    final bool on = _contract == id;
    return GestureDetector(
      onTap: () {
        if (_contract == id) return;
        _contract = id;
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: on ? kHubAmber.withOpacity(0.2) : const Color(0xFF121A2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? kHubAmber : const Color(0xFF263050)),
        ),
        child: Text(label, style: TextStyle(color: on ? kHubAmber : Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DarkomCoopBoard? d = _data;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
        const Expanded(child: Text('SQUAD BOARD', style: TextStyle(color: kHubAmber, fontWeight: FontWeight.w900, letterSpacing: 1))),
      ]),
      const Text('Co-op results only. A team time counts once two teammates have reported it, and the server times the run, not the phones. Solo points and rankings never change here.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 11, height: 1.3)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
        _tab('Block Sweep', 'clear'),
        _tab('Bounty Run', 'bounty'),
        _tab('Data Run', 'data'),
      ]),
      const SizedBox(height: 10),
      if (_loading)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: kHubAmber)))
      else if (d == null)
        const Text('The board could not be loaded right now.', style: TextStyle(color: Color(0xFFFFB74D)))
      else ...<Widget>[
        const Text('FASTEST TEAMS', style: TextStyle(color: kHubGreen, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 4),
        if (d.runs.isEmpty) const Text('No team has cleared this one yet. Be the first.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 12)),
        for (int i = 0; i < d.runs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: <Widget>[
              SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900))),
              Expanded(child: Text(d.runs[i].names.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
              Text(_t(d.runs[i].seconds), style: const TextStyle(color: kHubAmber, fontWeight: FontWeight.w900)),
            ]),
          ),
        const SizedBox(height: 12),
        const Text('MOST CONTRACTS CLEARED', style: TextStyle(color: kHubGreen, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 4),
        if (d.players.isEmpty) const Text('Nobody yet.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 12)),
        for (int i = 0; i < d.players.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: <Widget>[
              SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900))),
              Expanded(child: Text(d.players[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
              Text('${d.players[i].cleared}', style: const TextStyle(color: kHubAmber, fontWeight: FontWeight.w900)),
            ]),
          ),
        const SizedBox(height: 10),
        Text('You: ${d.mine} cleared, ${d.kinds} of 4 kinds.', style: const TextStyle(color: Color(0xFFD5DCEC), fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Contract-only unlocks: Contract Crew title (1), Patrol Pulse trail (3), Squad Steel skins for all six weapons (6), Gridlock Gold trail (10), Bounty Brass skins for all six weapons (15), Four Corners trail (all 4 kinds).', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 10.5, height: 1.3)),
      ],
    ]);
  }
}
