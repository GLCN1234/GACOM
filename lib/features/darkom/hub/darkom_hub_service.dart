import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

// Darkom City hub: open hub instances, filtered chat, blocks and reports,
// challenges and house squads. Every call talks to a server RPC, never throws
// and falls back to a safe default when offline or signed out.

int _hbInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

String _hbStr(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

Map<String, dynamic> _hbMap(dynamic v) {
  if (v is Map) {
    return v.map((dynamic k, dynamic val) => MapEntry<String, dynamic>(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<String> _hbStrings(dynamic v) {
  if (v is! List) return <String>[];
  return v.where((dynamic e) => e != null).map((dynamic e) => e.toString()).toList();
}

DateTime _hbTime(dynamic v) {
  if (v is String) {
    final DateTime? t = DateTime.tryParse(v);
    if (t != null) return t.toLocal();
  }
  return DateTime.now();
}

class DarkomChatMessage {
  final String id;
  final String room;
  final String userId;
  final String name;
  final String body;
  final DateTime at;

  const DarkomChatMessage({
    required this.id,
    required this.room,
    required this.userId,
    required this.name,
    required this.body,
    required this.at,
  });

  factory DarkomChatMessage.fromJson(Map<String, dynamic> j) {
    final String n = _hbStr(j['name']);
    return DarkomChatMessage(
      id: _hbStr(j['id']),
      room: _hbStr(j['room']),
      userId: _hbStr(j['user_id']),
      name: n.isEmpty ? 'Player' : n,
      body: _hbStr(j['body']),
      at: _hbTime(j['created_at']),
    );
  }
}

class DarkomChatResult {
  final bool ok;
  final String? error;
  final DarkomChatMessage? message;

  const DarkomChatResult({required this.ok, this.error, this.message});
}

class DarkomChallenge {
  final String id;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final String status; // pending|accepted|declined|expired|done
  final String code;
  final DateTime at;

  const DarkomChallenge({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.status,
    required this.code,
    required this.at,
  });

  factory DarkomChallenge.fromJson(Map<String, dynamic> j) {
    return DarkomChallenge(
      id: _hbStr(j['id']),
      fromId: _hbStr(j['from_id']),
      fromName: _hbStr(j['from_name'], 'Player'),
      toId: _hbStr(j['to_id']),
      toName: _hbStr(j['to_name'], 'Player'),
      status: _hbStr(j['status'], 'pending'),
      code: _hbStr(j['code']),
      at: _hbTime(j['created_at']),
    );
  }
}

class DarkomSquad {
  final String id;
  final String houseId;
  final String hostId;
  final String hostName;
  final String mode; // 'arena'
  final int maxPlayers;
  final String status; // open|started|closed
  final List<String> memberIds;
  final List<String> memberNames;

  const DarkomSquad({
    required this.id,
    required this.houseId,
    required this.hostId,
    required this.hostName,
    required this.mode,
    required this.maxPlayers,
    required this.status,
    required this.memberIds,
    required this.memberNames,
  });

  factory DarkomSquad.fromJson(Map<String, dynamic> j) {
    final int mp = _hbInt(j['max_players'], 4);
    return DarkomSquad(
      id: _hbStr(j['id']),
      houseId: _hbStr(j['house_id']),
      hostId: _hbStr(j['host_id']),
      hostName: _hbStr(j['host_name'], 'Player'),
      mode: _hbStr(j['mode'], 'arena'),
      maxPlayers: mp < 2 ? 4 : mp,
      status: _hbStr(j['status'], 'open'),
      memberIds: _hbStrings(j['member_ids']),
      memberNames: _hbStrings(j['member_names']),
    );
  }
}

class DarkomDuelResult {
  final bool accepted;
  final int xp;
  final String? error;

  const DarkomDuelResult({required this.accepted, required this.xp, this.error});
}

class DarkomHubService {
  DarkomHubService._();

  static int _channelSeq = 0;
  static Set<String> _blockedCache = <String>{};

  static String _channelName(String base) {
    _channelSeq++;
    return '$base:${DateTime.now().millisecondsSinceEpoch}:$_channelSeq';
  }

  /// Calls an RPC and returns its jsonb map, or null on any failure.
  static Future<Map<String, dynamic>?> _rpc(String fn, [Map<String, dynamic>? params]) async {
    try {
      if (SupabaseService.currentUserId == null) return null;
      final dynamic r = await SupabaseService.client.rpc(fn, params: params);
      if (r is! Map) return null;
      return _hbMap(r);
    } catch (_) {
      return null;
    }
  }

  static String _friendly(Map<String, dynamic>? j, String fallback) {
    if (j == null) return fallback;
    final String e = _hbStr(j['error']);
    return e.isEmpty ? fallback : e;
  }

  // ---------------------------------------------------------------- hub

  /// Returns the hub instance id (room is 'hub:<id>'). Falls back to '1' offline.
  static Future<String> joinHub() async {
    final Map<String, dynamic>? j = await _rpc('darkom_join_hub');
    if (j == null || j['success'] != true) return '1';
    final String inst = _hbStr(j['instance']);
    return inst.isEmpty ? '1' : inst;
  }

  static Future<void> heartbeat(String instance) async {
    await _rpc('darkom_hub_heartbeat', <String, dynamic>{'p_instance': instance});
  }

  static Future<void> leaveHub(String instance) async {
    await _rpc('darkom_leave_hub', <String, dynamic>{'p_instance': instance});
  }

  // --------------------------------------------------------------- chat

  static Future<List<DarkomChatMessage>> recentMessages(String room, {int limit = 40}) async {
    final Map<String, dynamic>? j = await _rpc(
      'darkom_recent_messages',
      <String, dynamic>{'p_room': room, 'p_limit': limit},
    );
    if (j == null || j['success'] != true) return <DarkomChatMessage>[];
    final dynamic list = j['messages'];
    if (list is! List) return <DarkomChatMessage>[];
    final List<DarkomChatMessage> out = <DarkomChatMessage>[];
    for (final dynamic m in list) {
      if (m is Map) out.add(DarkomChatMessage.fromJson(_hbMap(m)));
    }
    return out;
  }

  /// Realtime inserts for one room. Messages from players I blocked are dropped.
  static Stream<DarkomChatMessage> messageStream(String room) {
    late StreamController<DarkomChatMessage> ctrl;
    RealtimeChannel? channel;
    bool closed = false;

    Future<void> start() async {
      try {
        _blockedCache = await blockedIds();
        if (closed) return;
        channel = SupabaseService.client
            .channel(_channelName('darkom_chat'))
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'darkom_chat_messages',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room', value: room),
              callback: (PostgresChangePayload payload) {
                if (closed) return;
                try {
                  final DarkomChatMessage m = DarkomChatMessage.fromJson(_hbMap(payload.newRecord));
                  if (m.id.isEmpty || _blockedCache.contains(m.userId)) return;
                  if (!ctrl.isClosed) ctrl.add(m);
                } catch (_) {}
              },
            )
            .subscribe();
      } catch (_) {}
    }

    ctrl = StreamController<DarkomChatMessage>(
      onListen: () {
        start();
      },
      onCancel: () async {
        closed = true;
        final RealtimeChannel? c = channel;
        channel = null;
        if (c != null) {
          try {
            await SupabaseService.client.removeChannel(c);
          } catch (_) {}
        }
      },
    );
    return ctrl.stream;
  }

  static Future<DarkomChatResult> sendMessage(String room, String body) async {
    if (SupabaseService.currentUserId == null) {
      return const DarkomChatResult(ok: false, error: 'Please sign in to chat');
    }
    final Map<String, dynamic>? j = await _rpc(
      'darkom_send_message',
      <String, dynamic>{'p_room': room, 'p_body': body},
    );
    if (j == null) {
      return const DarkomChatResult(ok: false, error: 'Could not send. Check your connection and try again');
    }
    if (j['success'] != true) {
      return DarkomChatResult(ok: false, error: _friendly(j, 'Could not send your message'));
    }
    final dynamic m = j['message'];
    return DarkomChatResult(ok: true, message: m is Map ? DarkomChatMessage.fromJson(_hbMap(m)) : null);
  }

  // ------------------------------------------------------ blocks, reports

  static Future<Set<String>> blockedIds() async {
    final Map<String, dynamic>? j = await _rpc('darkom_blocked_ids');
    if (j == null || j['success'] != true) return _blockedCache;
    final Set<String> ids = _hbStrings(j['ids']).toSet();
    _blockedCache = ids;
    return ids;
  }

  static Future<bool> blockUser(String userId) async {
    final Map<String, dynamic>? j = await _rpc('darkom_block_user', <String, dynamic>{'p_user': userId});
    final bool ok = j != null && j['success'] == true;
    if (ok) _blockedCache = <String>{..._blockedCache, userId};
    return ok;
  }

  static Future<bool> unblockUser(String userId) async {
    final Map<String, dynamic>? j = await _rpc('darkom_unblock_user', <String, dynamic>{'p_user': userId});
    final bool ok = j != null && j['success'] == true;
    if (ok) {
      _blockedCache = _blockedCache.where((String e) => e != userId).toSet();
    }
    return ok;
  }

  static Future<bool> reportUser({
    required String userId,
    required String reason,
    String room = '',
    String? messageId,
  }) async {
    final String mid = (messageId ?? '').trim();
    final Map<String, dynamic>? j = await _rpc('darkom_report_user', <String, dynamic>{
      'p_user': userId,
      'p_reason': reason,
      'p_room': room,
      'p_message_id': mid.isEmpty ? null : mid,
    });
    return j != null && j['success'] == true;
  }

  // ------------------------------------------------------------ challenges

  static DarkomChallenge? _challengeFrom(Map<String, dynamic>? j) {
    if (j == null || j['success'] != true) return null;
    final dynamic c = j['challenge'];
    if (c is! Map) return null;
    final DarkomChallenge ch = DarkomChallenge.fromJson(_hbMap(c));
    return ch.id.isEmpty ? null : ch;
  }

  static Future<DarkomChallenge?> challenge(String toUserId) async {
    return _challengeFrom(await _rpc('darkom_challenge', <String, dynamic>{'p_to': toUserId}));
  }

  static Future<DarkomChallenge?> respondChallenge(String id, bool accept) async {
    return _challengeFrom(
      await _rpc('darkom_respond_challenge', <String, dynamic>{'p_id': id, 'p_accept': accept}),
    );
  }

  /// Realtime: challenges where I am the sender or the receiver.
  static Stream<DarkomChallenge> myChallengeStream() {
    late StreamController<DarkomChallenge> ctrl;
    RealtimeChannel? channel;
    bool closed = false;

    void emit(PostgresChangePayload payload) {
      if (closed) return;
      try {
        final DarkomChallenge c = DarkomChallenge.fromJson(_hbMap(payload.newRecord));
        if (c.id.isEmpty) return;
        if (_blockedCache.contains(c.fromId)) return;
        if (!ctrl.isClosed) ctrl.add(c);
      } catch (_) {}
    }

    ctrl = StreamController<DarkomChallenge>(
      onListen: () {
        try {
          final String? uid = SupabaseService.currentUserId;
          if (uid == null) return;
          channel = SupabaseService.client
              .channel(_channelName('darkom_challenges'))
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'darkom_challenges',
                filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'to_id', value: uid),
                callback: emit,
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'darkom_challenges',
                filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'from_id', value: uid),
                callback: emit,
              )
              .subscribe();
        } catch (_) {}
      },
      onCancel: () async {
        closed = true;
        final RealtimeChannel? c = channel;
        channel = null;
        if (c != null) {
          try {
            await SupabaseService.client.removeChannel(c);
          } catch (_) {}
        }
      },
    );
    return ctrl.stream;
  }

  /// Both players report; the server rewards only when both agree. If the other
  /// player has not reported yet, this waits a few seconds for them.
  static Future<DarkomDuelResult> reportDuel({required String challengeId, required bool iWon}) async {
    Map<String, dynamic>? j;
    for (int attempt = 0; attempt < 6; attempt++) {
      j = await _rpc('darkom_report_duel', <String, dynamic>{'p_challenge': challengeId, 'p_won': iWon});
      if (j == null) break;
      if (j['success'] == true && j['pending'] == true) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      break;
    }
    if (j == null) {
      return const DarkomDuelResult(
          accepted: false, xp: 0, error: 'Could not reach the server. Your result was not counted');
    }
    if (j['success'] != true) {
      return DarkomDuelResult(accepted: false, xp: 0, error: _friendly(j, 'Your result was not counted'));
    }
    final String err = _hbStr(j['error']);
    return DarkomDuelResult(
      accepted: j['accepted'] == true,
      xp: _hbInt(j['xp']),
      error: err.isEmpty ? null : err,
    );
  }

  // ---------------------------------------------------------------- squads

  static DarkomSquad? _squadFrom(Map<String, dynamic>? j) {
    if (j == null || j['success'] != true) return null;
    final dynamic s = j['squad'];
    if (s is! Map) return null;
    final DarkomSquad sq = DarkomSquad.fromJson(_hbMap(s));
    return sq.id.isEmpty ? null : sq;
  }

  static Future<DarkomSquad?> createSquad(String houseId) async {
    return _squadFrom(await _rpc('darkom_create_squad', <String, dynamic>{'p_house': houseId}));
  }

  static Future<DarkomSquad?> joinSquad(String squadId) async {
    return _squadFrom(await _rpc('darkom_join_squad', <String, dynamic>{'p_squad': squadId}));
  }

  static Future<void> leaveSquad(String squadId) async {
    await _rpc('darkom_leave_squad', <String, dynamic>{'p_squad': squadId});
  }

  static Future<DarkomSquad?> startSquad(String squadId) async {
    return _squadFrom(await _rpc('darkom_start_squad', <String, dynamic>{'p_squad': squadId}));
  }

  static Future<List<DarkomSquad>> openSquads(String houseId) async {
    final Map<String, dynamic>? j = await _rpc('darkom_open_squads', <String, dynamic>{'p_house': houseId});
    if (j == null || j['success'] != true) return <DarkomSquad>[];
    final dynamic list = j['squads'];
    if (list is! List) return <DarkomSquad>[];
    final List<DarkomSquad> out = <DarkomSquad>[];
    for (final dynamic s in list) {
      if (s is Map) {
        final DarkomSquad sq = DarkomSquad.fromJson(_hbMap(s));
        if (sq.id.isNotEmpty) out.add(sq);
      }
    }
    return out;
  }

  /// Emits the current squad first, then every realtime update of it.
  static Stream<DarkomSquad> squadStream(String squadId) {
    late StreamController<DarkomSquad> ctrl;
    RealtimeChannel? channel;
    bool closed = false;

    ctrl = StreamController<DarkomSquad>(
      onListen: () {
        try {
          channel = SupabaseService.client
              .channel(_channelName('darkom_squad'))
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'darkom_squads',
                filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: squadId),
                callback: (PostgresChangePayload payload) {
                  if (closed) return;
                  try {
                    final DarkomSquad s = DarkomSquad.fromJson(_hbMap(payload.newRecord));
                    if (s.id.isNotEmpty && !ctrl.isClosed) ctrl.add(s);
                  } catch (_) {}
                },
              )
              .subscribe();
        } catch (_) {}
        // current state, so a listener that joins late is in sync
        () async {
          try {
            if (SupabaseService.currentUserId == null) return;
            final dynamic row = await SupabaseService.client
                .from('darkom_squads')
                .select()
                .eq('id', squadId)
                .maybeSingle();
            if (closed || row is! Map) return;
            final DarkomSquad s = DarkomSquad.fromJson(_hbMap(row));
            if (s.id.isNotEmpty && !ctrl.isClosed) ctrl.add(s);
          } catch (_) {}
        }();
      },
      onCancel: () async {
        closed = true;
        final RealtimeChannel? c = channel;
        channel = null;
        if (c != null) {
          try {
            await SupabaseService.client.removeChannel(c);
          } catch (_) {}
        }
      },
    );
    return ctrl.stream;
  }

  static Future<DarkomDuelResult> reportSquadMatch({
    required String squadId,
    required int placement,
    required int players,
  }) async {
    final Map<String, dynamic>? j = await _rpc('darkom_report_squad_match', <String, dynamic>{
      'p_squad': squadId,
      'p_placement': placement,
      'p_players': players,
    });
    if (j == null) {
      return const DarkomDuelResult(
          accepted: false, xp: 0, error: 'Could not reach the server. Your result was not counted');
    }
    if (j['success'] != true) {
      return DarkomDuelResult(accepted: false, xp: 0, error: _friendly(j, 'Your result was not counted'));
    }
    final String err = _hbStr(j['error']);
    return DarkomDuelResult(
      accepted: j['accepted'] == true,
      xp: _hbInt(j['xp']),
      error: err.isEmpty ? null : err,
    );
  }
}
