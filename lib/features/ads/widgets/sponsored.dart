import 'package:flutter/material.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/theme/app_theme.dart';

/// The in-feed ad card. Also used (with [preview]) in the campaign builder.
class SponsoredCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final bool preview;
  const SponsoredCard({super.key, required this.ad, this.preview = false});

  @override
  Widget build(BuildContext context) {
    final image = ad['image'] as String?;
    final body = (ad['body'] as String?) ?? '';
    return GestureDetector(
      onTap: preview ? null : () => AdsService.click(ad),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: preview ? 0 : 12, vertical: 8),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 0.5)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                child: const Text('SPONSORED', style: TextStyle(color: GacomColors.deepOrange, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ]),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: image == null
                ? Container(color: GacomColors.surfaceDark, child: const Icon(Icons.image_rounded, color: GacomColors.border, size: 40))
                : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: GacomColors.surfaceDark)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${ad['headline'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
                ],
              ])),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(10)),
                child: Text('${ad['cta'] ?? 'Learn more'}', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A slot that asks for one in-feed ad when it first appears. Shows nothing when no ad fits.
class SponsoredFeedSlot extends StatefulWidget {
  const SponsoredFeedSlot({super.key});
  @override
  State<SponsoredFeedSlot> createState() => _SponsoredFeedSlotState();
}

class _SponsoredFeedSlotState extends State<SponsoredFeedSlot> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _ad;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AdsService.serve('feed').then((a) {
      if (mounted && a != null) setState(() => _ad = a);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final a = _ad;
    if (a == null) return const SizedBox.shrink();
    return SponsoredCard(ad: a);
  }
}

/// Slim banner for the top of the home screen.
class SponsoredBanner extends StatefulWidget {
  const SponsoredBanner({super.key});
  @override
  State<SponsoredBanner> createState() => _SponsoredBannerState();
}

class _SponsoredBannerState extends State<SponsoredBanner> {
  static Map<String, dynamic>? _shown; // one banner per app session, not one per tab switch
  Map<String, dynamic>? _ad;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    if (_shown != null) {
      _ad = _shown;
    } else {
      AdsService.serve('banner').then((a) {
        if (a != null) _shown = a;
        if (mounted && a != null) setState(() => _ad = a);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _ad;
    if (a == null || _closed) return const SizedBox.shrink();
    final image = a['image'] as String?;
    return GestureDetector(
      onTap: () => AdsService.click(a),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        height: 56,
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border, width: 0.5)),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          if (image != null) AspectRatio(aspectRatio: 1, child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: GacomColors.surfaceDark))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SPONSORED', style: TextStyle(color: GacomColors.deepOrange, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            Text('${a['headline'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          ])),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(gradient: GacomColors.orangeGradient, borderRadius: BorderRadius.circular(8)),
            child: Text('${a['cta'] ?? 'Learn more'}', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          GestureDetector(
            onTap: () => setState(() => _closed = true),
            child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.close_rounded, size: 16, color: GacomColors.textMuted)),
          ),
        ]),
      ),
    );
  }
}

/// One full-screen ad per app session, shown shortly after the app opens.
Future<void> maybeShowFullscreenAd(BuildContext context) async {
  if (AdsService.fullscreenShown) return;
  AdsService.fullscreenShown = true;
  final ad = await AdsService.serve('fullscreen');
  if (ad == null || !context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    pageBuilder: (ctx, _, __) => _FullscreenAd(ad: ad),
  );
}

class _FullscreenAd extends StatefulWidget {
  final Map<String, dynamic> ad;
  const _FullscreenAd({required this.ad});
  @override
  State<_FullscreenAd> createState() => _FullscreenAdState();
}

class _FullscreenAdState extends State<_FullscreenAd> {
  int _left = 4;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (_left > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _left--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ad;
    final image = a['image'] as String?;
    final body = (a['body'] as String?) ?? '';
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              const Text('SPONSORED', style: TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              _left > 0
                  ? Padding(padding: const EdgeInsets.all(12), child: Text('Skip in $_left', style: const TextStyle(color: Colors.white54, fontSize: 12)))
                  : IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => AdsService.click(a),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: image == null ? Container(color: GacomColors.surfaceDark) : Image.network(image, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: GacomColors.surfaceDark)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(children: [
              Text('${a['headline'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(body, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => AdsService.click(a),
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('${a['cta'] ?? 'Learn more'}'.toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
