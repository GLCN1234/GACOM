import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Parsing helpers. Everything is defensive: missing or wrong typed values
// become safe defaults, nothing throws.
// ---------------------------------------------------------------------------

String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
String? _sn(dynamic v) {
  if (v == null) return null;
  final String t = v.toString();
  return t.isEmpty ? null : t;
}

int _i(dynamic v, [int d = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? d;
  return d;
}

int? _in(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt();
  return null;
}

double _d(dynamic v, [double d = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? d;
  return d;
}

bool _b(dynamic v, [bool d = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == 't' || v == '1';
  return d;
}

DateTime? _dtn(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString())?.toLocal();
}

DateTime _dt(dynamic v) => _dtn(v) ?? DateTime.now();

Map<String, dynamic> _map(dynamic v) {
  if (v is Map) {
    return v.map((dynamic k, dynamic val) => MapEntry<String, dynamic>(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _maps(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((Map e) => _map(e)).toList();
  }
  return <Map<String, dynamic>>[];
}

List<String> _strings(dynamic v) {
  if (v is List) return v.map((dynamic e) => e.toString()).toList();
  return <String>[];
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SupportTicket {
  final String id, userId, userName, subject, category, priority, status, teamKey, teamName;
  final String? assigneeId, assigneeName, summary;
  final DateTime createdAt, updatedAt;
  final DateTime? firstResponseDue, resolutionDue, firstResponseAt, resolvedAt;
  final bool breached, unreadForUser, unreadForStaff;
  final int? csat;
  final String lastPreview;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.teamKey,
    required this.teamName,
    this.assigneeId,
    this.assigneeName,
    this.summary,
    required this.createdAt,
    required this.updatedAt,
    this.firstResponseDue,
    this.resolutionDue,
    this.firstResponseAt,
    this.resolvedAt,
    this.breached = false,
    this.unreadForUser = false,
    this.unreadForStaff = false,
    this.csat,
    this.lastPreview = '',
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) {
    return SupportTicket(
      id: _s(j['id']),
      userId: _s(j['user_id']),
      userName: _s(j['user_name'], 'User'),
      subject: _s(j['subject'], 'Support request'),
      category: _s(j['category'], 'other'),
      priority: _s(j['priority'], 'normal'),
      status: _s(j['status'], 'open'),
      teamKey: _s(j['team_key'], 'care'),
      teamName: _s(j['team_name'], 'General Care'),
      assigneeId: _sn(j['assignee_id']),
      assigneeName: _sn(j['assignee_name']),
      summary: _sn(j['summary']),
      createdAt: _dt(j['created_at']),
      updatedAt: _dt(j['updated_at'] ?? j['created_at']),
      firstResponseDue: _dtn(j['first_response_due']),
      resolutionDue: _dtn(j['resolution_due']),
      firstResponseAt: _dtn(j['first_response_at']),
      resolvedAt: _dtn(j['resolved_at']),
      breached: _b(j['breached']),
      unreadForUser: _b(j['unread_for_user']),
      unreadForStaff: _b(j['unread_for_staff']),
      csat: _in(j['csat']),
      lastPreview: _s(j['last_preview']),
    );
  }
}

class SupportMessage {
  final String id, ticketId, senderType /* user|agent|assistant|system|note */, senderName, body;
  final bool internal;
  final List<String> attachments;
  final DateTime at;
  final Map<String, dynamic> meta;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.senderName,
    required this.body,
    this.internal = false,
    this.attachments = const <String>[],
    required this.at,
    this.meta = const <String, dynamic>{},
  });

  /// Accepts both the RPC shape (`body`) and a raw table row from the realtime stream (`message`).
  factory SupportMessage.fromJson(Map<String, dynamic> j) {
    final String type = _s(j['sender_type'], (_b(j['is_agent']) ? 'agent' : 'user'));
    String name = _s(j['sender_name']);
    if (name.isEmpty) {
      name = type == 'assistant'
          ? 'Ryan'
          : type == 'system'
              ? 'GACOM Support'
              : type == 'agent'
                  ? 'Support'
                  : type == 'note'
                      ? 'Note'
                      : 'You';
    }
    return SupportMessage(
      id: _s(j['id']),
      ticketId: _s(j['ticket_id']),
      senderType: type,
      senderName: name,
      body: _s(j['body'] ?? j['message']),
      internal: _b(j['internal']),
      attachments: _strings(j['attachments']),
      at: _dt(j['created_at'] ?? j['at']),
      meta: _map(j['meta']),
    );
  }
}

class SupportTeam {
  final String key, name, description;
  const SupportTeam({required this.key, required this.name, this.description = ''});

  factory SupportTeam.fromJson(Map<String, dynamic> j) =>
      SupportTeam(key: _s(j['key']), name: _s(j['name']), description: _s(j['description']));
}

class SupportCategory {
  final String key, label, teamKey;
  const SupportCategory({required this.key, required this.label, required this.teamKey});

  factory SupportCategory.fromJson(Map<String, dynamic> j) => SupportCategory(
        key: _s(j['key']),
        label: _s(j['label']),
        teamKey: _s(j['team_key']),
      );
}

class SupportMacro {
  final String id, title, body;
  final String? categoryKey;
  const SupportMacro({required this.id, required this.title, required this.body, this.categoryKey});

  factory SupportMacro.fromJson(Map<String, dynamic> j) => SupportMacro(
        id: _s(j['id']),
        title: _s(j['title']),
        body: _s(j['body']),
        categoryKey: _sn(j['category_key']),
      );
}

class SupportUserContext {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> recentWallet, recentOrders, recentErrors, recentTickets;
  const SupportUserContext({
    this.profile = const <String, dynamic>{},
    this.recentWallet = const <Map<String, dynamic>>[],
    this.recentOrders = const <Map<String, dynamic>>[],
    this.recentErrors = const <Map<String, dynamic>>[],
    this.recentTickets = const <Map<String, dynamic>>[],
  });

  factory SupportUserContext.fromJson(Map<String, dynamic> j) => SupportUserContext(
        profile: _map(j['profile']),
        recentWallet: _maps(j['recent_wallet']),
        recentOrders: _maps(j['recent_orders']),
        recentErrors: _maps(j['recent_errors']),
        recentTickets: _maps(j['recent_tickets']),
      );
}

class SupportTeamStats {
  final int open, breached, unassigned, resolvedToday;
  final double avgFirstResponseMin, csatAvg;
  const SupportTeamStats({
    this.open = 0,
    this.breached = 0,
    this.unassigned = 0,
    this.resolvedToday = 0,
    this.avgFirstResponseMin = 0,
    this.csatAvg = 0,
  });

  factory SupportTeamStats.fromJson(Map<String, dynamic> j) => SupportTeamStats(
        open: _i(j['open']),
        breached: _i(j['breached']),
        unassigned: _i(j['unassigned']),
        resolvedToday: _i(j['resolved_today']),
        avgFirstResponseMin: _d(j['avg_first_response_min']),
        csatAvg: _d(j['csat_avg']),
      );
}

class SupportTurn {
  final SupportTicket? ticket;
  final List<SupportMessage> newMessages;
  final String? error;
  const SupportTurn({this.ticket, this.newMessages = const <SupportMessage>[], this.error});
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class SupportService {
  SupportService._();

  static const String _bucket = 'support-attachments';
  static const int _maxAttachmentBytes = 5 * 1024 * 1024;
  static const String _genericError = 'Something went wrong. Please try again.';

  static SupabaseClient get _db => SupabaseService.client;

  static Future<dynamic> _rpc(String fn, [Map<String, dynamic>? params]) async {
    return await Future<dynamic>(() async => await _db.rpc(fn, params: params)).timeout(const Duration(seconds: 25));
  }

  /// Runs an RPC that returns true on success. Never throws.
  static Future<bool> _ok(String fn, Map<String, dynamic> params) async {
    try {
      final dynamic r = await _rpc(fn, params);
      return r == null ? true : (r is bool ? r : true);
    } catch (e) {
      debugPrint('SupportService.$fn failed: $e');
      return false;
    }
  }

  static String _errorText(Object e) {
    if (e is FunctionException) {
      final dynamic d = e.details;
      if (d is Map && d['error'] != null) return d['error'].toString();
      if (e.status == 429) return 'You are sending messages too quickly. Please wait a minute and try again.';
      if (e.status == 401) return 'Please sign in again.';
    }
    if (e is TimeoutException) return 'This is taking too long. Please check your connection and try again.';
    return _genericError;
  }

  static Future<SupportTicket?> _ticketById(String id) async {
    try {
      final dynamic r = await _rpc('support_ticket_get', <String, dynamic>{'p_ticket': id});
      if (r is Map) return SupportTicket.fromJson(_map(r));
    } catch (e) {
      debugPrint('SupportService.ticket failed: $e');
    }
    return null;
  }

  /// One ticket the caller may see (owner or staff of its team), or null.
  static Future<SupportTicket?> ticketById(String id) => _ticketById(id);

  static Future<SupportTurn> _callAssistant(Map<String, dynamic> body, String? knownTicketId) async {
    try {
      if (SupabaseService.currentUserId == null) {
        return const SupportTurn(error: 'Please sign in to contact support.');
      }
      final FunctionResponse res = await _db.functions
          .invoke('support-assistant', body: body)
          .timeout(const Duration(seconds: 45));
      final dynamic data = res.data;
      if (data is! Map || data['success'] != true) {
        final String msg = (data is Map && data['error'] != null) ? data['error'].toString() : _genericError;
        return SupportTurn(error: msg);
      }
      final String ticketId = _s(data['ticket_id'], knownTicketId ?? '');
      final List<SupportMessage> msgs = _maps(data['messages']).map(SupportMessage.fromJson).toList();
      final SupportTicket? t = ticketId.isEmpty ? null : await _ticketById(ticketId);
      return SupportTurn(ticket: t, newMessages: msgs);
    } catch (e) {
      debugPrint('SupportService assistant call failed: $e');
      return SupportTurn(error: _errorText(e));
    }
  }

  // ----- user side -----

  /// Creates a ticket and runs the assistant. Returns the ticket and the assistant reply.
  static Future<SupportTurn> startTicket(String message, {String? categoryHint, Map<String, dynamic>? deviceInfo}) {
    final Map<String, dynamic> body = <String, dynamic>{
      'action': 'start',
      'message': message,
      'deviceInfo': deviceInfo ?? <String, dynamic>{'platform': defaultTargetPlatform.name, 'is_web': kIsWeb},
    };
    if (categoryHint != null && categoryHint.isNotEmpty) body['categoryHint'] = categoryHint;
    return _callAssistant(body, null);
  }

  /// Adds a user message. The assistant answers only while no person is on the ticket.
  static Future<SupportTurn> sendMessage(String ticketId, String body, {List<String> attachments = const <String>[]}) {
    return _callAssistant(<String, dynamic>{
      'action': 'message',
      'ticketId': ticketId,
      'message': body,
      'attachments': attachments,
    }, ticketId);
  }

  static Future<List<SupportTicket>> myTickets() async {
    try {
      final dynamic r = await _rpc('support_my_tickets');
      return _maps(r).map(SupportTicket.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.myTickets failed: $e');
      return <SupportTicket>[];
    }
  }

  /// Never returns internal notes to a user (the database enforces this too).
  static Future<List<SupportMessage>> messages(String ticketId) async {
    try {
      final dynamic r = await _rpc('support_messages_for', <String, dynamic>{'p_ticket': ticketId});
      return _maps(r).map(SupportMessage.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.messages failed: $e');
      return <SupportMessage>[];
    }
  }

  /// Live messages of a ticket. Row level security hides internal notes from users.
  static Stream<SupportMessage> messageStream(String ticketId) {
    final StreamController<SupportMessage> ctl = StreamController<SupportMessage>();
    final Set<String> seen = <String>{};
    StreamSubscription<List<Map<String, dynamic>>>? sub;
    ctl.onListen = () {
      try {
        sub = _db
            .from('support_messages')
            .stream(primaryKey: <String>['id'])
            .eq('ticket_id', ticketId)
            .listen((List<Map<String, dynamic>> rows) {
          for (final Map<String, dynamic> row in rows) {
            try {
              final SupportMessage m = SupportMessage.fromJson(_map(row));
              if (m.id.isEmpty || !seen.add(m.id)) continue;
              if (!ctl.isClosed) ctl.add(m);
            } catch (_) {}
          }
        }, onError: (Object e) {
          debugPrint('SupportService.messageStream error: $e');
        });
      } catch (e) {
        debugPrint('SupportService.messageStream failed: $e');
      }
    };
    ctl.onCancel = () async {
      await sub?.cancel();
      if (!ctl.isClosed) await ctl.close();
    };
    return ctl.stream;
  }

  static Future<bool> requestHuman(String ticketId) => _ok('support_request_human', <String, dynamic>{'p_ticket': ticketId});

  static Future<bool> rateTicket(String ticketId, int stars, {String comment = ''}) =>
      _ok('support_rate_ticket', <String, dynamic>{'p_ticket': ticketId, 'p_stars': stars, 'p_comment': comment});

  static Future<bool> reopenTicket(String ticketId) => _ok('support_reopen', <String, dynamic>{'p_ticket': ticketId});

  /// Uploads to the private bucket and returns the storage path. 5 MB max, png/jpg/webp/pdf only.
  static Future<String?> uploadAttachment(List<int> bytes, String fileName) async {
    try {
      final String? uid = SupabaseService.currentUserId;
      if (uid == null || bytes.isEmpty || bytes.length > _maxAttachmentBytes) return null;
      final String lower = fileName.toLowerCase();
      final int dot = lower.lastIndexOf('.');
      final String ext = dot >= 0 ? lower.substring(dot + 1) : '';
      const Map<String, String> types = <String, String>{
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'webp': 'image/webp',
        'pdf': 'application/pdf',
      };
      final String? contentType = types[ext];
      if (contentType == null) return null;
      String base = dot > 0 ? fileName.substring(0, dot) : 'file';
      base = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      if (base.length > 40) base = base.substring(0, 40);
      if (base.isEmpty) base = 'file';
      final String path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$base.$ext';
      await _db.storage.from(_bucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      return path;
    } catch (e) {
      debugPrint('SupportService.uploadAttachment failed: $e');
      return null;
    }
  }

  /// Signed link for an attachment, valid for 10 minutes.
  static Future<String?> attachmentUrl(String path) async {
    try {
      if (path.isEmpty) return null;
      return await _db.storage.from(_bucket).createSignedUrl(path, 600);
    } catch (e) {
      debugPrint('SupportService.attachmentUrl failed: $e');
      return null;
    }
  }

  // ----- staff side -----

  /// Teams the signed-in user belongs to. Admins get all. Empty means not staff.
  static Future<List<SupportTeam>> myTeams() async {
    try {
      final dynamic r = await _rpc('support_my_teams');
      return _maps(r).map(SupportTeam.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.myTeams failed: $e');
      return <SupportTeam>[];
    }
  }

  static Future<List<SupportTicket>> deskQueue({
    String? teamKey,
    String? status,
    bool mineOnly = false,
    bool breachedOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final dynamic r = await _rpc('support_desk_queue', <String, dynamic>{
        'p_team': teamKey,
        'p_status': status,
        'p_mine': mineOnly,
        'p_breached': breachedOnly,
        'p_limit': limit,
        'p_offset': offset,
      });
      return _maps(r).map(SupportTicket.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.deskQueue failed: $e');
      return <SupportTicket>[];
    }
  }

  static Future<bool> claim(String ticketId) => _ok('support_claim', <String, dynamic>{'p_ticket': ticketId});

  /// Leads and admins only.
  static Future<bool> assign(String ticketId, String userId) =>
      _ok('support_assign', <String, dynamic>{'p_ticket': ticketId, 'p_user': userId});

  static Future<bool> setRouting(String ticketId, {String? categoryKey, String? teamKey, String? priority}) =>
      _ok('support_set_routing', <String, dynamic>{
        'p_ticket': ticketId,
        'p_category': categoryKey,
        'p_team': teamKey,
        'p_priority': priority,
      });

  static Future<bool> reply(String ticketId, String body,
      {List<String> attachments = const <String>[], String? macroId}) =>
      _ok('support_reply', <String, dynamic>{
        'p_ticket': ticketId,
        'p_body': body,
        'p_attachments': attachments,
        'p_macro': macroId,
      });

  /// Internal note, never shown to the user.
  static Future<bool> addNote(String ticketId, String body) =>
      _ok('support_add_note', <String, dynamic>{'p_ticket': ticketId, 'p_body': body});

  static Future<bool> resolve(String ticketId, {String note = ''}) =>
      _ok('support_resolve', <String, dynamic>{'p_ticket': ticketId, 'p_note': note});

  /// Moves the ticket to team 'technical', status escalated, keeps the note and tells the user.
  static Future<bool> escalateToTechnical(String ticketId, String note) =>
      _ok('support_escalate_technical', <String, dynamic>{'p_ticket': ticketId, 'p_note': note});

  /// Account snapshot for an agent. Every lookup is written to the access log.
  static Future<SupportUserContext?> userContext(String ticketId) async {
    try {
      final dynamic r = await _rpc('support_user_context', <String, dynamic>{'p_ticket': ticketId});
      if (r is Map) return SupportUserContext.fromJson(_map(r));
    } catch (e) {
      debugPrint('SupportService.userContext failed: $e');
    }
    return null;
  }

  static Future<SupportTeamStats?> teamStats(String teamKey) async {
    try {
      final dynamic r = await _rpc('support_team_stats', <String, dynamic>{'p_team': teamKey});
      if (r is Map) return SupportTeamStats.fromJson(_map(r));
    } catch (e) {
      debugPrint('SupportService.teamStats failed: $e');
    }
    return null;
  }

  static Future<List<SupportMacro>> macros({String? categoryKey}) async {
    try {
      final dynamic r = await _rpc('support_macros_list', <String, dynamic>{'p_category': categoryKey});
      return _maps(r).map(SupportMacro.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.macros failed: $e');
      return <SupportMacro>[];
    }
  }

  /// Thumbs up or down on an assistant message; a correction feeds training.
  static Future<bool> rateAssistantMessage(String messageId, bool helpful, {String correction = ''}) =>
      _ok('support_rate_assistant', <String, dynamic>{
        'p_message': messageId,
        'p_helpful': helpful,
        'p_correction': correction,
      });

  /// Creates a draft knowledge article from an agent answer.
  static Future<bool> saveAsKnowledge(String ticketId,
      {required String title, required String answer, String? categoryKey}) =>
      _ok('support_save_kb', <String, dynamic>{
        'p_ticket': ticketId,
        'p_title': title,
        'p_answer': answer,
        'p_category': categoryKey,
      });

  // ----- admin -----

  static Future<List<SupportTeam>> allTeams() async {
    try {
      final dynamic r = await _rpc('support_admin_teams');
      return _maps(r).map(SupportTeam.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.allTeams failed: $e');
      return <SupportTeam>[];
    }
  }

  /// Rows: {userId, name, username, role, active, cap, open}.
  static Future<List<Map<String, dynamic>>> teamMembers(String teamKey) async {
    // Team leads (and admins) first: support_team_members_for_lead. Fall back to the admin RPC.
    try {
      final dynamic r = await _rpc('support_team_members_for_lead', <String, dynamic>{'team_key': teamKey});
      return _maps(r).map((m) => <String, dynamic>{
            'userId': m['user_id'],
            'name': m['name'],
            'username': m['username'],
            'role': m['role'],
            'active': m['active'],
            'cap': m['cap'],
            'open': m['open_ticket_count'],
          }).toList();
    } catch (e) {
      debugPrint('SupportService.teamMembers (lead) failed: $e');
    }
    try {
      final dynamic r = await _rpc('support_admin_team_members', <String, dynamic>{'p_team': teamKey});
      return _maps(r);
    } catch (e) {
      debugPrint('SupportService.teamMembers failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> setTeamMember(String teamKey, String userId, {required String role, bool active = true}) =>
      _ok('support_admin_set_member', <String, dynamic>{
        'p_team': teamKey,
        'p_user': userId,
        'p_role': role,
        'p_active': active,
      });

  static Future<bool> removeTeamMember(String teamKey, String userId) =>
      _ok('support_admin_remove_member', <String, dynamic>{'p_team': teamKey, 'p_user': userId});

  /// Admin only. Rows: {id, name, username}.
  static Future<List<Map<String, dynamic>>> findUsers(String query) async {
    try {
      final dynamic r = await _rpc('support_admin_find_users', <String, dynamic>{'p_query': query});
      return _maps(r);
    } catch (e) {
      debugPrint('SupportService.findUsers failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<SupportCategory>> categories() async {
    try {
      final dynamic r = await _rpc('support_categories_list');
      return _maps(r).map(SupportCategory.fromJson).toList();
    } catch (e) {
      debugPrint('SupportService.categories failed: $e');
      return <SupportCategory>[];
    }
  }

  static Future<bool> setCategoryTeam(String categoryKey, String teamKey) =>
      _ok('support_admin_set_category_team', <String, dynamic>{'p_category': categoryKey, 'p_team': teamKey});

  static Future<List<Map<String, dynamic>>> kbArticles({bool draftsOnly = false}) async {
    try {
      final dynamic r = await _rpc('support_admin_kb_list', <String, dynamic>{'p_drafts_only': draftsOnly});
      return _maps(r);
    } catch (e) {
      debugPrint('SupportService.kbArticles failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> saveKbArticle({
    String? id,
    required String title,
    required String body,
    String? categoryKey,
    required bool published,
  }) =>
      _ok('support_admin_save_kb', <String, dynamic>{
        'p_id': id,
        'p_title': title,
        'p_body': body,
        'p_category': categoryKey,
        'p_published': published,
      });

  /// Admin only. Scrubbed resolved conversations with agent answers, corrections and ratings.
  static Future<List<Map<String, dynamic>>> trainingExport({int limit = 200}) async {
    try {
      final dynamic r = await _rpc('support_admin_training_export', <String, dynamic>{'p_limit': limit});
      return _maps(r);
    } catch (e) {
      debugPrint('SupportService.trainingExport failed: $e');
      return <Map<String, dynamic>>[];
    }
  }
}
