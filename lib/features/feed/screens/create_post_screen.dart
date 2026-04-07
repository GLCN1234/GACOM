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
import '../../../shared/widgets/gacom_text_field.dart';

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
  final _tagCtrl = TextEditingController();
  final List<String> _tags = [];

  Future<void> _pickMedia({bool video = false}) async {
    final picker = ImagePicker();
    if (video) {
      final file = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 60));
      if (file != null) {
        setState(() {
          _selectedMedia = [file];
          _selectedType = 'video';
        });
      }
    } else {
      final files = await picker.pickMultiImage(limit: 4);
      if (files.isNotEmpty) {
        setState(() {
          _selectedMedia = files;
          _selectedType = 'image';
        });
      }
    }
  }

  Future<void> _publish() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (_captionCtrl.text.trim().isEmpty && _selectedMedia.isEmpty) {
      GacomSnackbar.show(context, 'Add a caption or media to post',
          isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      List<String> mediaUrls = [];
      for (final file in _selectedMedia) {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last;
        final path =
            '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final url = await SupabaseService.uploadFile(
          bucket: AppConstants.postMediaBucket,
          path: path,
          bytes: bytes,
          contentType: _selectedType == 'video' ? 'video/mp4' : 'image/jpeg',
        );
        mediaUrls.add(url);
      }

      await SupabaseService.client.from('posts').insert({
        'author_id': userId,
        'post_type': _selectedType,
        'caption': _captionCtrl.text.trim(),
        'media_urls': mediaUrls,
        'tags': _tags,
      });

      // Increment posts_count safely
      await SupabaseService.client.rpc('increment_posts_count',
          params: {'user_id': userId});

      if (mounted) {
        GacomSnackbar.show(context, 'Post published! 🔥', isSuccess: true);
        context.go(AppConstants.homeRoute);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GacomSnackbar.show(context, 'Failed to publish. Check your connection.',
            isError: true);
      }
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('CREATE POST'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _publish,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GacomColors.deepOrange))
                : const Text('POST',
                    style: TextStyle(
                        color: GacomColors.deepOrange,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User info
          FutureBuilder(
            future: SupabaseService.client
                .from('profiles')
                .select('display_name, avatar_url')
                .eq('id', SupabaseService.currentUserId ?? '')
                .maybeSingle(),
            builder: (ctx, snap) {
              final name =
                  (snap.data as Map?)?['display_name'] ?? 'You';
              final avatar = (snap.data as Map?)?['avatar_url'];
              return Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      avatar != null ? NetworkImage(avatar) : null,
                  backgroundColor: GacomColors.deepOrange,
                  child: avatar == null
                      ? Text(name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 12),
                Text(name,
                    style: const TextStyle(
                        color: GacomColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ]);
            },
          ),

          const SizedBox(height: 16),

          // Caption
          TextField(
            controller: _captionCtrl,
            maxLines: 6,
            style: const TextStyle(
                color: GacomColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "What's on your mind, gamer? 🎮",
              hintStyle:
                  TextStyle(color: GacomColors.textMuted, fontSize: 16),
              border: InputBorder.none,
            ),
          ),

          // Media preview
          if (_selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMedia.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FutureBuilder<Uint8List>(
                        future: _selectedMedia[i].readAsBytes(),
                        builder: (_, snap) {
                          if (snap.hasData) {
                            return Image.memory(snap.data!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover);
                          }
                          return Container(
                              width: 100,
                              height: 100,
                              color: GacomColors.cardDark);
                        },
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() =>
                            _selectedMedia.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
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
                style: const TextStyle(
                    color: GacomColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Add tag (e.g. PUBG)',
                  hintStyle: TextStyle(color: GacomColors.textMuted),
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.tag_rounded, color: GacomColors.textMuted),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            TextButton(onPressed: _addTag, child: const Text('ADD')),
          ]),
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _tags
                  .map((t) => Chip(
                        label: Text('#$t',
                            style: const TextStyle(
                                color: GacomColors.deepOrange,
                                fontSize: 12)),
                        backgroundColor:
                            GacomColors.deepOrange.withOpacity(0.1),
                        deleteIconColor: GacomColors.textMuted,
                        onDeleted: () =>
                            setState(() => _tags.remove(t)),
                        side: const BorderSide(
                            color: GacomColors.borderOrange),
                      ))
                  .toList(),
            ),

          const Divider(color: GacomColors.border, height: 32),

          // Media action row
          Row(children: [
            _MediaButton(
              icon: Icons.image_rounded,
              label: 'Photo',
              onTap: () => _pickMedia(),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: Icons.videocam_rounded,
              label: 'Video',
              onTap: () => _pickMedia(video: true),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaButton(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: GacomColors.border)),
          child: Row(children: [
            Icon(icon, color: GacomColors.deepOrange, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: GacomColors.textPrimary,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        ),
      );
}
