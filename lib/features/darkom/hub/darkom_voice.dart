import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../core/services/supabase_service.dart';
import 'darkom_hub_world.dart';

const String kVoiceUnavailable = 'Voice is not available right now';

class DarkomVoicePerson {
  final String id;
  final bool local;
  final bool speaking;
  final bool muted;
  const DarkomVoicePerson(this.id, this.local, this.speaking, this.muted);
}

/// Optional voice chat through LiveKit. Off until the player joins, joins with
/// the microphone muted, and never throws: any problem becomes a friendly
/// message and the game stays usable.
class DarkomVoice extends ChangeNotifier {
  lk.Room? _room;
  String state = 'idle'; // idle, connecting, live
  String channelLabel = '';
  String? notice;
  bool micOn = false;
  bool _disposed = false;
  bool _applying = false;
  bool _again = false;
  final Set<String> _muted = <String>{};
  Set<String> _blocked = <String>{};

  bool get live => state == 'live';
  bool isMuted(String id) => _muted.contains(id) || _blocked.contains(id);

  void _n() {
    if (!_disposed) notifyListeners();
  }

  Future<void> join(String roomName, String label) async {
    if (state != 'idle' || _disposed) return;
    state = 'connecting';
    notice = null;
    channelLabel = label;
    _n();
    lk.Room? room;
    try {
      const String url = String.fromEnvironment('LIVEKIT_URL', defaultValue: '');
      if (url.isEmpty) {
        _fail(kVoiceUnavailable);
        return;
      }
      final String auth = 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken ?? ''}';
      final dynamic res = await SupabaseService.client.functions.invoke(
        'livekit-token',
        body: <String, dynamic>{'roomName': roomName},
        headers: <String, String>{'Authorization': auth},
      );
      final dynamic data = res.data;
      final String token = (data is Map ? data['token']?.toString() : null) ?? '';
      if (token.isEmpty) {
        _fail(kVoiceUnavailable);
        return;
      }
      room = lk.Room();
      room.addListener(_onRoom);
      await room.connect(url, token).timeout(const Duration(seconds: 15));
      if (_disposed) {
        room.removeListener(_onRoom);
        await room.disconnect();
        return;
      }
      _room = room;
      state = 'live';
      micOn = false;
      _n();
      _enforceMutes();
    } catch (_) {
      final lk.Room? r = room;
      if (r != null) {
        try {
          r.removeListener(_onRoom);
          await r.disconnect();
        } catch (_) {}
      }
      _fail(kVoiceUnavailable);
    }
  }

  void _fail(String msg) {
    state = 'idle';
    micOn = false;
    notice = msg;
    _room = null;
    _n();
  }

  void _onRoom() {
    _n();
    _enforceMutes();
  }

  Future<void> setMic(bool on) async {
    final lk.Room? r = _room;
    if (r == null || !live) return;
    try {
      await r.localParticipant?.setMicrophoneEnabled(on);
      micOn = on;
      notice = null;
    } catch (_) {
      micOn = false;
      notice = 'We could not use your microphone. Please allow it in your browser or device settings.';
    }
    _n();
  }

  Future<void> leave() async {
    final lk.Room? r = _room;
    _room = null;
    state = 'idle';
    micOn = false;
    notice = null;
    _n();
    if (r != null) {
      try {
        r.removeListener(_onRoom);
        await r.disconnect();
      } catch (_) {}
      unawaited(_disposeRoom(r));
    }
  }

  Future<void> _disposeRoom(lk.Room r) async {
    try {
      await (r as dynamic).dispose();
    } catch (_) {}
  }

  void setBlocked(Set<String> blocked) {
    _blocked = Set<String>.from(blocked);
    _n();
    _enforceMutes();
  }

  void toggleMute(String id) {
    if (_muted.contains(id)) {
      _muted.remove(id);
    } else {
      _muted.add(id);
    }
    _n();
    _enforceMutes();
  }

  /// Local only: stops receiving the audio of people the player muted or blocked.
  Future<void> _enforceMutes() async {
    if (_applying) {
      _again = true;
      return;
    }
    if (_room == null || _disposed) return;
    _applying = true;
    try {
      do {
        _again = false;
        final lk.Room? r = _room;
        if (r == null || _disposed) break;
        for (final lk.RemoteParticipant p in r.remoteParticipants.values.toList()) {
          final bool mute = isMuted(p.identity);
          final List<dynamic> pubs = List<dynamic>.from((p as dynamic).audioTrackPublications as Iterable<dynamic>);
          for (final dynamic pub in pubs) {
            try {
              if (mute && pub.track != null) {
                await pub.unsubscribe();
              } else if (!mute && pub.track == null) {
                await pub.subscribe();
              }
            } catch (_) {}
          }
        }
      } while (_again && !_disposed);
    } catch (_) {}
    _applying = false;
  }

  List<DarkomVoicePerson> people() {
    final lk.Room? r = _room;
    if (r == null) return const <DarkomVoicePerson>[];
    final List<DarkomVoicePerson> out = <DarkomVoicePerson>[];
    try {
      final lk.LocalParticipant? me = r.localParticipant;
      if (me != null) out.add(DarkomVoicePerson(me.identity, true, me.isSpeaking && micOn, false));
      final List<lk.RemoteParticipant> rest = r.remoteParticipants.values.toList();
      rest.sort((lk.RemoteParticipant a, lk.RemoteParticipant b) => a.identity.compareTo(b.identity));
      for (final lk.RemoteParticipant p in rest) {
        if (_blocked.contains(p.identity)) continue;
        out.add(DarkomVoicePerson(p.identity, false, p.isSpeaking, _muted.contains(p.identity)));
      }
    } catch (_) {}
    return out;
  }

  @override
  void dispose() {
    _disposed = true;
    final lk.Room? r = _room;
    _room = null;
    if (r != null) {
      unawaited(() async {
        try {
          r.removeListener(_onRoom);
          await r.disconnect();
        } catch (_) {}
        await _disposeRoom(r);
      }());
    }
    super.dispose();
  }
}

/// The voice sheet: notice first, then channel choice, then the controls.
class HubVoiceSheet extends StatefulWidget {
  final DarkomVoice voice;
  final String hubRoom;
  final String? houseId;
  final String? squadId;
  final String Function(String id) nameOf;
  final void Function(String id, String name) onReport;
  final void Function(String id, String name) onBlock;
  const HubVoiceSheet({
    super.key,
    required this.voice,
    required this.hubRoom,
    required this.houseId,
    required this.squadId,
    required this.nameOf,
    required this.onReport,
    required this.onBlock,
  });

  @override
  State<HubVoiceSheet> createState() => _HubVoiceSheetState();
}

class _HubVoiceSheetState extends State<HubVoiceSheet> {
  bool _understood = false;

  @override
  void initState() {
    super.initState();
    _understood = widget.voice.live || widget.voice.state == 'connecting';
  }

  Widget _title(String t) => Text(t, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1));

  Widget _btn(String label, IconData icon, Color color, VoidCallback? onTap, {bool filled = true}) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? color : const Color(0xFF151B2E),
          foregroundColor: filled ? Colors.black : color,
          side: BorderSide(color: color.withOpacity(0.7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _notice() {
    const TextStyle st = TextStyle(color: Color(0xFFD5DCEC), fontSize: 14, height: 1.4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      _title('BEFORE YOU USE VOICE'),
      const SizedBox(height: 10),
      const Text('Voice is optional. You can play the whole game without it.', style: st),
      const SizedBox(height: 6),
      const Text('Anyone in the channel you join can hear you when your microphone is on.', style: st),
      const SizedBox(height: 6),
      const Text('Be kind. Do not share your real name, address, school or phone number.', style: st),
      const SizedBox(height: 6),
      const Text('You join with the microphone muted. You can mute, or leave, at any time.', style: st),
      const SizedBox(height: 6),
      const Text('You can mute, report or block any player from this panel.', style: st),
      const SizedBox(height: 16),
      Row(children: <Widget>[
        Expanded(child: _btn('NOT NOW', Icons.close_rounded, kHubMagenta, () => Navigator.of(context).pop(), filled: false)),
        const SizedBox(width: 10),
        Expanded(child: _btn('I UNDERSTAND', Icons.check_circle_rounded, kHubCyan, () => setState(() => _understood = true))),
      ]),
    ]);
  }

  Widget _channel(String label, String sub, IconData icon, Color color, String room) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF121A2E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.voice.join(room, label),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.6))),
            child: Row(children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(sub, style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 12)),
                ]),
              ),
              Text('JOIN', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _choose() {
    final DarkomVoice v = widget.voice;
    final String? hid = widget.houseId;
    final String? sid = widget.squadId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      _title('CHOOSE A VOICE CHANNEL'),
      const SizedBox(height: 4),
      const Text('You will join with your microphone muted.', style: TextStyle(color: Color(0xFF9AA6C2), fontSize: 13)),
      const SizedBox(height: 12),
      if (v.notice != null)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(v.notice!, style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700))),
      _channel('Hub', 'Everyone in this plaza instance', Icons.public_rounded, kHubCyan, 'darkom-hub-${widget.hubRoom}'),
      if (hid != null && hid.isNotEmpty) _channel('House', 'Only members of your house', Icons.house_rounded, kHubAmber, 'darkom-house-$hid'),
      if (sid != null && sid.isNotEmpty) _channel('Squad', 'Only your squad', Icons.groups_rounded, kHubGreen, 'darkom-squad-$sid'),
    ]);
  }

  Widget _connecting() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[CircularProgressIndicator(color: kHubCyan), SizedBox(height: 12), Text('Connecting...', style: TextStyle(color: Colors.white70))])),
    );
  }

  Widget _live() {
    final DarkomVoice v = widget.voice;
    final List<DarkomVoicePerson> people = v.people();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Expanded(child: _title('VOICE: ${v.channelLabel.toUpperCase()}')),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: (v.micOn ? kHubGreen : kHubMagenta).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text(v.micOn ? 'MIC ON' : 'MUTED', style: TextStyle(color: v.micOn ? kHubGreen : kHubMagenta, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 14),
      Center(
        child: GestureDetector(
          onTap: () => v.setMic(!v.micOn),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (v.micOn ? kHubGreen : const Color(0xFF1B2238)),
              border: Border.all(color: v.micOn ? kHubGreen : kHubMagenta, width: 3),
              boxShadow: <BoxShadow>[BoxShadow(color: (v.micOn ? kHubGreen : kHubMagenta).withOpacity(0.35), blurRadius: 18)],
            ),
            child: Icon(v.micOn ? Icons.mic_rounded : Icons.mic_off_rounded, size: 44, color: v.micOn ? Colors.black : Colors.white),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Center(child: Text(v.micOn ? 'Tap to mute' : 'Tap to talk', style: const TextStyle(color: Color(0xFF9AA6C2), fontSize: 12))),
      if (v.notice != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(v.notice!, style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final DarkomVoicePerson p in people) _person(p),
            if (people.length <= 1) const Padding(padding: EdgeInsets.all(8), child: Text('Nobody else is here yet.', style: TextStyle(color: Color(0xFF9AA6C2)))),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _btn('LEAVE VOICE', Icons.call_end_rounded, kHubMagenta, () async {
        await v.leave();
        if (mounted) setState(() => _understood = true);
      }),
    ]);
  }

  Widget _person(DarkomVoicePerson p) {
    final String name = p.local ? 'You' : widget.nameOf(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.speaking ? kHubGreen : const Color(0xFF263050), width: p.speaking ? 2 : 1),
      ),
      child: Row(children: <Widget>[
        Icon(p.speaking ? Icons.volume_up_rounded : Icons.person_rounded, size: 20, color: p.speaking ? kHubGreen : const Color(0xFF9AA6C2)),
        const SizedBox(width: 10),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        if (!p.local) ...<Widget>[
          IconButton(
            tooltip: p.muted ? 'Unmute this player' : 'Mute this player',
            visualDensity: VisualDensity.compact,
            icon: Icon(p.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: p.muted ? kHubMagenta : Colors.white70, size: 20),
            onPressed: () => widget.voice.toggleMute(p.id),
          ),
          PopupMenuButton<String>(
            tooltip: 'Report or block',
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
            color: const Color(0xFF151B2E),
            onSelected: (String k) {
              if (k == 'report') widget.onReport(p.id, name);
              if (k == 'block') widget.onBlock(p.id, name);
            },
            itemBuilder: (BuildContext c) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'report', child: Text('Report')),
              PopupMenuItem<String>(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.voice,
      builder: (BuildContext c, Widget? w) {
        final DarkomVoice v = widget.voice;
        Widget body;
        if (v.state == 'connecting') {
          body = _connecting();
        } else if (v.live) {
          body = _live();
        } else if (!_understood) {
          body = _notice();
        } else {
          body = _choose();
        }
        return v.live ? body : SingleChildScrollView(child: body);
      },
    );
  }
}
