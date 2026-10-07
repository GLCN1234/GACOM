import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../duels/duel_registry.dart';
import '../services/duel_service.dart';
import '../widgets/game_logo.dart';

/// Pick any Arena game and race another player on it.
class DuelLobbyScreen extends StatefulWidget {
  const DuelLobbyScreen({super.key});
  @override
  State<DuelLobbyScreen> createState() => _DuelLobbyScreenState();
}

class _DuelLobbyScreenState extends State<DuelLobbyScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final String? _uid = SupabaseService.currentUserId;
  List<DuelMatch> _open = <DuelMatch>[];
  List<DuelMatch> _mine = <DuelMatch>[];
  List<Map<String, dynamic>> _ranks = <Map<String, dynamic>>[];
  Map<String, Map<String, dynamic>> _profiles = <String, Map<String, dynamic>>{};
  String _query = '';
  String? _busyKey;
  bool _loading = true;
  int _stake = 0;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    DuelService.settleMine();
    _reload();
    _refresh = Timer.periodic(const Duration(seconds: 8), (_) => _reload(quiet: true));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _reload({bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _loading = true);
    final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
      DuelService.openDuels(),
      DuelService.myDuels(),
      DuelService.standings(),
    ]);
    final List<DuelMatch> open = res[0] as List<DuelMatch>;
    final List<DuelMatch> mine = res[1] as List<DuelMatch>;
    final List<Map<String, dynamic>> ranks = res[2] as List<Map<String, dynamic>>;
    final Set<String> ids = <String>{};
    for (final DuelMatch m in open) { ids.add(m.creatorId); }
    for (final DuelMatch m in mine) { ids.add(m.creatorId); if (m.opponentId != null) ids.add(m.opponentId!); }
    for (final Map<String, dynamic> r in ranks) { ids.add(r['user_id'] as String); }
    final Map<String, Map<String, dynamic>> profiles = await DuelService.profiles(ids);
    if (!mounted) return;
    setState(() {
      _open = open;
      _mine = mine;
      _ranks = ranks;
      _profiles = <String, Map<String, dynamic>>{..._profiles, ...profiles};
      _loading = false;
    });
  }

  Future<void> _play(DuelGame g) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = g.key);
    try {
      final DuelMatch m = await DuelService.quick(g, stake: _stake);
      if (!mounted) return;
      setState(() => _busyKey = null);
      await context.push('/arena/duel/${m.id}');
      if (mounted) _reload(quiet: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      _toast(DuelService.friendlyError(e));
    }
  }

  Future<void> _joinOpen(DuelMatch d) async {
    try {
      final DuelMatch m = await DuelService.join(d.id);
      if (!mounted) return;
      await context.push('/arena/duel/${m.id}');
      if (mounted) _reload(quiet: true);
    } catch (e) {
      if (!mounted) return;
      _toast(DuelService.friendlyError(e));
      _reload(quiet: true);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _name(String? id) => id == _uid ? 'You' : DuelService.nameOf(_profiles, id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.bg(context),
      appBar: AppBar(
        title: const Text('DUELS'),
        actions: <Widget>[IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _reload)],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: GacomColors.deepOrange,
          labelColor: GacomColors.deepOrange,
          unselectedLabelColor: GacomColors.txtMuted(context),
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13),
          tabs: <Widget>[
            const Tab(text: 'GAMES'),
            Tab(text: _open.isEmpty ? 'OPEN' : 'OPEN (${_open.length})'),
            const Tab(text: 'MY DUELS'),
            const Tab(text: 'RANKS'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: <Widget>[_gamesTab(), _openTab(), _mineTab(), _ranksTab()]),
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: GacomColors.txtMuted(context), height: 1.5)),
        ),
      );

  Widget _gamesTab() {
    final List<DuelGame> list = DuelRegistry.games.where((g) => _query.isEmpty || g.name.toLowerCase().contains(_query)).toList();
    return Column(children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          onChanged: (String v) => setState(() => _query = v.trim().toLowerCase()),
          style: TextStyle(color: GacomColors.txtPrimary(context)),
          decoration: InputDecoration(
            hintText: 'Search ${DuelRegistry.games.length} games',
            hintStyle: TextStyle(color: GacomColors.txtMuted(context)),
            prefixIcon: Icon(Icons.search_rounded, color: GacomColors.txtMuted(context)),
            filled: true,
            fillColor: GacomColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('STAKE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1, color: GacomColors.txtMuted(context))),
        ),
      ),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: DuelService.stakes.map((int s) {
            final bool sel = _stake == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _stake = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? GacomColors.deepOrange : GacomColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.borderColor(context)),
                  ),
                  child: Text(s == 0 ? 'Free' : '₦$s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: sel ? Colors.white : GacomColors.txtPrimary(context))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _stake == 0
                ? 'Free duel. Tap a game to be matched. You both play the same game from the same seed; the better result wins.'
                : 'Each player stakes ₦$_stake. The winner takes the pot minus the platform fee. A draw refunds both. Tap a game to be matched with someone at the same stake.',
            style: TextStyle(color: GacomColors.txtMuted(context), fontSize: 12, height: 1.4),
          ),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? _empty('No game matches that search.')
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25),
                itemCount: list.length,
                itemBuilder: (BuildContext c, int i) => _gameTile(list[i]),
              ),
      ),
    ]);
  }

  Widget _gameTile(DuelGame g) {
    final bool busy = _busyKey == g.key;
    return GestureDetector(
      onTap: () => _play(g),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GacomColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GacomColors.borderColor(context), width: 0.6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            SizedBox(width: 44, height: 44, child: GameLogo(name: g.name, radius: 12, fallback: const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange))),
            const Spacer(),
            if (busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GacomColors.deepOrange.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                child: const Text('1v1', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.deepOrange)),
              ),
          ]),
          const Spacer(),
          Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.txtPrimary(context))),
          const SizedBox(height: 2),
          Text(g.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: GacomColors.txtMuted(context), height: 1.3)),
        ]),
      ),
    );
  }

  Widget _openTab() {
    if (_loading && _open.isEmpty) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_open.isEmpty) return _empty('Nobody is waiting right now.\nPick a game in the GAMES tab and the next player who picks it will be matched with you.');
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _open.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext c, int i) {
          final DuelMatch d = _open[i];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.borderColor(context), width: 0.6)),
            child: Row(children: <Widget>[
              SizedBox(width: 44, height: 44, child: GameLogo(name: d.gameName, radius: 12, fallback: const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(d.gameName, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.txtPrimary(context))),
                  Text('${_name(d.creatorId)} is waiting${d.stake > 0 ? '  /  ₦${d.stake} stake' : ''}', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
                ]),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                onPressed: () => _joinOpen(d),
                child: const Text('JOIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _mineTab() {
    if (_loading && _mine.isEmpty) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_mine.isEmpty) return _empty('You have not played a duel yet.');
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mine.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext c, int i) {
          final DuelMatch d = _mine[i];
          final String uid = _uid ?? '';
          final String? opp = d.otherId(uid);
          String tag;
          Color color;
          if (d.status == 'active') {
            tag = 'LIVE';
            color = GacomColors.info;
          } else if (d.isDraw) {
            tag = 'DRAW';
            color = GacomColors.warning;
          } else if (d.winnerId == uid) {
            tag = 'WON';
            color = GacomColors.success;
          } else {
            tag = 'LOST';
            color = GacomColors.error;
          }
          final int? a = d.scoreOf(uid);
          final int? b = opp == null ? null : d.scoreOf(opp);
          return GestureDetector(
            onTap: () async {
              await context.push('/arena/duel/${d.id}');
              if (mounted) _reload(quiet: true);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.borderColor(context), width: 0.6)),
              child: Row(children: <Widget>[
                SizedBox(width: 40, height: 40, child: GameLogo(name: d.gameName, radius: 11, fallback: const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(d.gameName, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.txtPrimary(context))),
                    Text('vs ${_name(opp)}  -  ${a ?? '-'} : ${b ?? '-'}', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text(tag, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: color)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _ranksTab() {
    if (_loading && _ranks.isEmpty) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_ranks.isEmpty) return _empty('No ranked duels yet. Win one to get on the board.');
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _ranks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext c, int i) {
          final Map<String, dynamic> r = _ranks[i];
          final String id = r['user_id'] as String;
          final int wins = (r['wins'] as num?)?.toInt() ?? 0;
          final int played = (r['played'] as num?)?.toInt() ?? 0;
          final bool me = id == _uid;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: me ? GacomColors.deepOrange.withValues(alpha: 0.10) : GacomColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: me ? GacomColors.deepOrange : GacomColors.borderColor(context), width: me ? 1.2 : 0.6),
            ),
            child: Row(children: <Widget>[
              SizedBox(width: 30, child: Text('${i + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: i < 3 ? GacomColors.gold : GacomColors.txtMuted(context)))),
              Expanded(child: Text(_name(id), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.txtPrimary(context)))),
              Text('$wins W', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.success)),
              const SizedBox(width: 10),
              Text('$played played', style: TextStyle(fontSize: 11, color: GacomColors.txtMuted(context))),
            ]),
          );
        },
      ),
    );
  }
}
