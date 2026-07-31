import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import 'edu_compete_screen.dart';

class EduCompeteLobbyScreen extends StatefulWidget {
  const EduCompeteLobbyScreen({super.key});
  @override State<EduCompeteLobbyScreen> createState() => _EduCompeteLobbyState();
}

class _EduCompeteLobbyState extends State<EduCompeteLobbyScreen> {
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _inviteChannel;
  List<Map<String,dynamic>> _onlineStudents = [];
  bool _loading = true;
  String _mySubjectInterest = 'Mathematics';
  final Set<String> _pendingSentInvites = {};
  bool _navigatingAway = false;

  static const _subjects = ['Mathematics', 'Science', 'English', 'Logic', 'Geography', 'History'];

  @override void initState() { super.initState(); _joinLobby(); _listenForIncomingInvites(); }

  @override void dispose() {
    _presenceChannel?.untrack()?.catchError((_) => null);
    _presenceChannel?.unsubscribe()?.catchError((_) => null);
    _inviteChannel?.unsubscribe()?.catchError((_) => null);
    super.dispose();
  }

  Future<void> _joinLobby() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    String myName = 'Student', myInstitution = 'Self-study';
    try {
      final p = await SupabaseService.client.from('profiles').select('display_name').eq('id', uid).single();
      myName = p['display_name'] as String? ?? 'Student';
    } catch (_) {}
    try {
      final si = await SupabaseService.client.from('student_institutions').select('institution:institutions(name)').eq('student_id', uid).maybeSingle();
      if (si != null && si['institution'] != null) myInstitution = si['institution']['name'] as String? ?? 'Self-study';
    } catch (_) {}

    _presenceChannel = SupabaseService.client.channel('edu_compete_lobby', opts: const RealtimeChannelConfig(self: true));
    _presenceChannel!
      .onPresenceSync((_) => _refreshOnlineList())
      .onPresenceJoin((_) => _refreshOnlineList())
      .onPresenceLeave((_) => _refreshOnlineList())
      .subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed && !_navigatingAway) {
          await _presenceChannel!.track({
            'user_id': uid, 'name': myName, 'institution': myInstitution,
            'subject': _mySubjectInterest, 'online_at': DateTime.now().toIso8601String(),
          });
        }
      });

    if (mounted) setState(() => _loading = false);
  }

  void _refreshOnlineList() {
    if (_presenceChannel == null || _navigatingAway) return;
    final uid = SupabaseService.currentUserId;
    final states = _presenceChannel!.presenceState();
    final students = <Map<String,dynamic>>[];
    for (final s in states) {
      for (final p in s.presences) {
        if (p.payload['user_id'] != uid) students.add(Map<String,dynamic>.from(p.payload));
      }
    }
    if (mounted) setState(() => _onlineStudents = students);
  }

  void _listenForIncomingInvites() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _inviteChannel = SupabaseService.client
        .channel('edu_invites_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'edu_compete_invites',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: uid),
          callback: (payload) {
            if (!_navigatingAway) _showIncomingInviteDialog(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'edu_compete_invites',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'sender_id', value: uid),
          callback: (payload) {
            if (!_navigatingAway) _handleInviteResponse(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleInviteResponse(Map<String,dynamic> invite) {
    if (_navigatingAway) return;
    final receiverId = invite['receiver_id'] as String;
    setState(() => _pendingSentInvites.remove(receiverId));
    if (invite['status'] == 'accepted' && invite['room_id'] != null && mounted) {
      _goToMatch(roomId: invite['room_id'] as String, opponentId: receiverId, subject: invite['subject'] as String);
    } else if (invite['status'] == 'declined' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your invite was declined')));
    }
  }

  void _goToMatch({required String roomId, required String opponentId, required String subject}) {
    if (_navigatingAway || !mounted) return;
    _navigatingAway = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EduCompeteScreen(
      directRoomId: roomId,
      directOpponentId: opponentId,
      directSubject: subject,
    )));
  }

  Future<void> _showIncomingInviteDialog(Map<String,dynamic> invite) async {
    if (!mounted || _navigatingAway) return;
    String senderName = 'A student';
    try {
      final p = await SupabaseService.client.from('profiles').select('display_name').eq('id', invite['sender_id']).single();
      senderName = p['display_name'] as String? ?? 'A student';
    } catch (_) {}
    if (!mounted || _navigatingAway) return;

    HapticFeedback.mediumImpact();
    bool responding = false;

    showDialog(context: context, barrierDismissible: false, builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => Dialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.deepOrange.withOpacity(0.15)),
            child: const Icon(Icons.emoji_events_outlined, color: GacomColors.deepOrange, size: 32)),
          const SizedBox(height: 16),
          Text('$senderName invited you!', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('${invite['subject']} competition', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (responding)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(color: GacomColors.deepOrange))
          else Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () async {
                setDialogState(() => responding = true);
                try {
                  await SupabaseService.client.from('edu_compete_invites').update({'status': 'declined', 'responded_at': DateTime.now().toIso8601String()}).eq('id', invite['id']);
                } catch (_) {}
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Decline', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                setDialogState(() => responding = true);
                try {
                  final res = await SupabaseService.client.rpc('accept_edu_invite', params: {'p_invite_id': invite['id']});
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (res['success'] == true && mounted) {
                    _goToMatch(roomId: res['room_id'] as String, opponentId: res['opponent_id'] as String, subject: invite['subject'] as String);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']?.toString() ?? 'This invite is no longer available')));
                  }
                } catch (e) {
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Accept', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)))),
          ]),
        ])),
      ),
    ));
  }

  Future<void> _sendInvite(Map<String,dynamic> student) async {
    if (_navigatingAway) return;
    final receiverId = student['user_id'] as String?;
    if (receiverId == null) return;
    if (_pendingSentInvites.contains(receiverId)) return;
    setState(() => _pendingSentInvites.add(receiverId));
    try {
      await SupabaseService.client.from('edu_compete_invites').insert({
        'sender_id': SupabaseService.currentUserId,
        'receiver_id': receiverId,
        'subject': _mySubjectInterest,
        'status': 'pending',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite sent to ${student['name'] ?? 'student'}')));
    } catch (e) {
      if (mounted) setState(() => _pendingSentInvites.remove(receiverId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending invite: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('COMPETE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16))),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR SUBJECT INTEREST', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _subjects.map((s) {
          final sel = s == _mySubjectInterest;
          return GestureDetector(
            onTap: () async {
              if (_navigatingAway) return;
              setState(() => _mySubjectInterest = s);
              try {
                await _presenceChannel?.track({'user_id': SupabaseService.currentUserId, 'subject': s, 'online_at': DateTime.now().toIso8601String()});
              } catch (_) {}
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: sel ? GacomColors.deepOrange : GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? GacomColors.deepOrange : GacomColors.border)),
              child: Text(s, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: sel ? Colors.white : GacomColors.textPrimary))));
        }).toList()),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: GacomColors.success, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('${_onlineStudents.length} students online now', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      ])),
      const SizedBox(height: 12),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
        : _onlineStudents.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.people_outline_rounded, size: 48, color: GacomColors.textMuted),
              const SizedBox(height: 12),
              const Text('No students online right now', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Ask a friend to open Compete at the same time as you.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
            ])))
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _onlineStudents.length, itemBuilder: (_, i) {
              final s = _onlineStudents[i];
              final receiverId = s['user_id'] as String?;
              final invited = receiverId != null && _pendingSentInvites.contains(receiverId);
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.elevatedCard, border: Border.all(color: GacomColors.success.withOpacity(0.5), width: 2)),
                    child: Center(child: Text((s['name'] as String? ?? '?').isNotEmpty ? (s['name'] as String)[0].toUpperCase() : '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name'] as String? ?? 'Student', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
                    Row(children: [
                      const Icon(Icons.account_balance_outlined, size: 11, color: GacomColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(child: Text(s['institution'] as String? ?? 'Self-study', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    ]),
                    Text('Interested in: ${s['subject'] ?? 'Any'}', style: const TextStyle(color: GacomColors.accentCyan, fontSize: 11)),
                  ])),
                  GestureDetector(onTap: invited ? null : () => _sendInvite(s),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: invited ? GacomColors.elevatedCard : GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
                      child: Text(invited ? 'Invited' : 'Invite', style: TextStyle(color: invited ? GacomColors.textMuted : Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12)))),
                ]));
            })),
    ]),
  );
}
