import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  String _selectedType = 'text';
  List<XFile> _selectedMedia = [];
  bool _loading = false;
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  @override
  void dispose() {
    _captionCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({bool video = false}) async {
    final picker = ImagePicker();
    try {
      if (video) {
        final file = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );
        if (file != null && mounted) {
          setState(() { _selectedMedia = [file]; _selectedType = 'video'; });
        }
      } else {
        final files = await picker.pickMultiImage(limit: 4);
        if (files.isNotEmpty && mounted) {
          setState(() { _selectedMedia = files; _selectedType = 'image'; });
        }
      }
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Could not access media: ${e.toString()}', isError: true);
    }
  }

  Future<void> _publish() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) { GacomSnackbar.show(context, 'Please log in first', isError: true); return; }
    if (_captionCtrl.text.trim().isEmpty && _selectedMedia.isEmpty) {
      GacomSnackbar.show(context, 'Add a caption or media', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      List<String> mediaUrls = [];

      // Upload each media file — if any single upload fails, skip it (don't block the whole post)
      for (final file in _selectedMedia) {
        try {
          final bytes = await file.readAsBytes();
          final ext = file.name.split('.').last.toLowerCase();
          final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
          final contentType = _selectedType == 'video'
              ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
              : (ext == 'png' ? 'image/png' : ext == 'gif' ? 'image/gif' : 'image/jpeg');

          final url = await SupabaseService.uploadFile(
            bucket: AppConstants.postMediaBucket,
            path: path,
            bytes: bytes,
            contentType: contentType,
          );
          mediaUrls.add(url);
        } catch (uploadErr) {
          // Individual file failed — continue with others
          debugPrint('Media upload skipped: $uploadErr');
        }
      }

      // If user chose media but ALL failed, still allow text-only post
      final actualType = mediaUrls.isEmpty ? 'text' : _selectedType;

      await SupabaseService.client.from('posts').insert({
        'author_id': userId,
        'post_type': actualType,
        'caption': _captionCtrl.text.trim(),
        'media_urls': mediaUrls,
        'tags': _tags,
      });

      // Increment count — non-fatal
      try {
        await SupabaseService.client.rpc('increment_posts_count', params: {'user_id': userId});
      } catch (_) {}

      if (mounted) {
        GacomSnackbar.show(context, 'Post published! 🔥', isSuccess: true);
        context.go(AppConstants.homeRoute);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Friendly error messages
        String msg = 'Failed to publish.';
        final err = e.toString().toLowerCase();
        if (err.contains('storage') || err.contains('bucket') || err.contains('400')) {
          msg = 'Media upload failed. Try a text-only post or contact admin to set up storage.';
        } else if (err.contains('403') || err.contains('forbidden')) {
          msg = 'Permission denied. Make sure you are logged in properly.';
        } else if (err.contains('network') || err.contains('connection')) {
          msg = 'No internet connection. Check your connection and retry.';
        }
        GacomSnackbar.show(context, msg, isError: true);
      }
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().replaceAll('#', '').replaceAll(' ', '_').toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 5) {
      setState(() { _tags.add(tag); _tagCtrl.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('CREATE POST'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _loading ? null : _publish,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _loading ? null : GacomColors.orangeGradient,
                  color: _loading ? GacomColors.border : null,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('POST', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User info row
          FutureBuilder(
            future: SupabaseService.client
                .from('profiles')
                .select('display_name, avatar_url')
                .eq('id', SupabaseService.currentUserId ?? '')
                .maybeSingle(),
            builder: (ctx, snap) {
              final name = (snap.data as Map?)?['display_name'] as String? ?? 'You';
              final avatar = (snap.data as Map?)?['avatar_url'] as String?;
              return Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  backgroundColor: GacomColors.deepOrange,
                  child: avatar == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'G', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 12),
                Text(name, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              ]);
            },
          ),

          const SizedBox(height: 16),

          // Caption input
          TextField(
            controller: _captionCtrl,
            maxLines: 6,
            style: const TextStyle(color: GacomColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "What's on your mind, gamer? 🎮",
              hintStyle: TextStyle(color: GacomColors.textMuted, fontSize: 16),
              border: InputBorder.none,
            ),
          ),

          // Media previews
          if (_selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMedia.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FutureBuilder<Uint8List>(
                        future: _selectedMedia[i].readAsBytes(),
                        builder: (_, snap) {
                          if (snap.hasData && _selectedType == 'image') {
                            return Image.memory(snap.data!, width: 110, height: 110, fit: BoxFit.cover);
                          }
                          return Container(
                            width: 110, height: 110,
                            color: GacomColors.cardDark,
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(_selectedType == 'video' ? Icons.videocam_rounded : Icons.image_rounded, color: GacomColors.deepOrange, size: 32),
                              const SizedBox(height: 4),
                              Text(_selectedMedia[i].name.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
                            ]),
                          );
                        },
                      ),
                    ),
                    Positioned(top: 4, right: 4, child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedMedia.removeAt(i);
                        if (_selectedMedia.isEmpty) _selectedType = 'text';
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    )),
                  ]),
                ),
              ),
            ),
          ],

          const Divider(color: GacomColors.border, height: 32),

          // Tags
          Row(children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Add tag (e.g. PUBG)',
                  hintStyle: TextStyle(color: GacomColors.textMuted),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.tag_rounded, color: GacomColors.textMuted),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            TextButton(onPressed: _addTag, child: const Text('ADD', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
          ]),

          if (_tags.isNotEmpty)
            Wrap(spacing: 8, children: _tags.map((t) => Chip(
              label: Text('#$t', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 12)),
              backgroundColor: GacomColors.deepOrange.withOpacity(0.1),
              deleteIconColor: GacomColors.textMuted,
              onDeleted: () => setState(() => _tags.remove(t)),
              side: const BorderSide(color: GacomColors.borderOrange),
            )).toList()),

          const Divider(color: GacomColors.border, height: 32),

          // Media action row
          Row(children: [
            _MediaBtn(icon: Icons.image_rounded, label: 'Photo', onTap: () => _pickMedia()),
            const SizedBox(width: 12),
            _MediaBtn(icon: Icons.videocam_rounded, label: 'Video', onTap: () => _pickMedia(video: true)),
          ]),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _MediaBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border)),
      child: Row(children: [
        Icon(icon, color: GacomColors.deepOrange, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}
