import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/rarity.dart';
import 'player_card_service.dart';
import 'player_card_widget.dart';

/// A shareable player card. Route: '/card/:id'.
class PlayerCardScreen extends StatefulWidget {
  final String userId;
  const PlayerCardScreen({super.key, required this.userId});

  @override
  State<PlayerCardScreen> createState() => _PlayerCardScreenState();
}

class _PlayerCardScreenState extends State<PlayerCardScreen> {
  final GlobalKey _boundary = GlobalKey();
  PlayerCardData? _d;
  bool _loading = true;
  bool _busy = false;

  bool get _own => SupabaseService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PlayerCardData? d = await PlayerCardService.load(widget.userId);
    if (!mounted) return;
    setState(() {
      _d = d;
      _loading = false;
    });
  }

  String get _link => 'https://gamicom.net/#/profile/${widget.userId}';

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? Tac.danger : const Color(0xFF1B2A44)));
  }

  Future<Uint8List?> _png() async {
    try {
      final RenderObject? ro = _boundary.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return null;
      final ui.Image img = await ro.toImage(pixelRatio: 3.0);
      final ByteData? bd = await img.toByteData(format: ui.ImageByteFormat.png);
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    final PlayerCardData? d = _d;
    if (d == null || _busy) return;
    setState(() => _busy = true);
    final String text = _own
        ? 'My GACOM player card: ${d.rank} rank, ${d.points} points. Come and beat me: $_link'
        : '${d.name} on GACOM: ${d.rank} rank, ${d.points} points. $_link';
    try {
      final Uint8List? bytes = await _png();
      if (bytes != null) {
        await SharePlus.instance.share(ShareParams(
          text: text,
          files: <XFile>[XFile.fromData(bytes, mimeType: 'image/png', name: 'gacom-player-card.png')],
        ));
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      // Browsers that cannot share a picture still share the words and the link.
      try {
        await SharePlus.instance.share(ShareParams(text: text));
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: text));
        _toast('Link copied');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link));
    _toast('Profile link copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tac.bg,
      appBar: AppBar(
        backgroundColor: Tac.bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        title: Text('PLAYER CARD', style: Tac.display(size: 16, letter: 1.4)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Tac.gold))
          : (_d == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('This card is not available. The account may be private, or you are offline.', textAlign: TextAlign.center, style: Tac.body(size: 15, color: Tac.textDim)),
                  ),
                )
              : _content(_d!)),
    );
  }

  Widget _content(PlayerCardData d) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(key: _boundary, child: PlayerCardWidget(d: d)),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tac.gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(_busy ? 'PREPARING...' : 'SHARE CARD'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: _copy, icon: const Icon(Icons.link_rounded, size: 18), label: const Text('COPY PROFILE LINK')),
            ),
            const SizedBox(height: 10),
            Text('Share it to WhatsApp, X or anywhere your phone lets you. The picture is made on your device.', textAlign: TextAlign.center, style: Tac.body(size: 12, color: Tac.textDim)),
          ]),
        ),
      ]),
    );
  }
}
