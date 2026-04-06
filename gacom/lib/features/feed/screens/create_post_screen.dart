import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  List<Map<String, dynamic>> _tags = [];
  final _tagCtrl = TextEditingController();

  Future<void> _pickMedia({bool video = false}) async {
    final picker = ImagePicker();
    if (video) {
      final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
      if (file != null) setState(() { _selectedMedia = [file]; _selectedType = 'video'; });
    } else {
      final files = await picker.pickMultiImage(limit: 4);
      if (files.isNotEmpty) setState(() { _selectedMedia = files; _selectedType = 'image'; });
    }
  }

  Future<void> _publish() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (_captionCtrl.text.trim().isEmpty && _selectedMedia.isEmpty) {
      GacomSnackbar.show(context, 'Add a caption or media to post', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      List<String> mediaUrls = [];
      for (final file in _selectedMedia) {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last;
        final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final url = await SupabaseService.uploadFile(bucket: AppConstants.postMediaBucket, path: path, bytes: bytes, contentType: _selectedType == 'video' ? 'video/mp4' : 'image/jpeg');
        mediaUrls.add(url);
      }
      await SupabaseService.client.from('posts').insert({
        'author_id': userId,
        'post_type': _selectedType,
        'caption': _captionCtrl.text.trim(),
        'media_urls': mediaUrls,
        'tags': _tags.map((t) => t['tag']).toList(),
      });
      await SupabaseService.client.from('profiles').update({'posts_count': SupabaseService.client.rpc('increment')}).eq('id', userId);
      if (mounted) {
        GacomSnackbar.show(context, 'Post published! 🔥', isSuccess: true);
        context.go(AppConstants.homeRoute);
      }
    } catch (e) {
      if (mounted) { setState(() => _loading = false); GacomSnackbar.show(context, 'Failed to publish post', isError: true); }
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: GacomColors.deepOrange, strokeWidth: 2))
                : const Text('PUBLISH', style: TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post type selector
            Row(
              children: [
                _TypeButton(icon: Icons.text_fields_rounded, label: 'Text', selected: _selectedType == 'text', onTap: () => setState(() => _selectedType = 'text')),
                const SizedBox(width: 10),
                _TypeButton(icon: Icons.image_outlined, label: 'Photo', selected: _selectedType == 'image', onTap: () => _pickMedia()),
                const SizedBox(width: 10),
                _TypeButton(icon: Icons.play_circle_outline_rounded, label: 'Video', selected: _selectedType == 'video', onTap: () => _pickMedia(video: true)),
                const SizedBox(width: 10),
                _TypeButton(icon: Icons.movie_filter_rounded, label: 'Clip', selected: _selectedType == 'clip', onTap: () => _pickMedia(video: true)),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 24),

            // Media preview
            if (_selectedMedia.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedia.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _selectedMedia.length) {
                      return GestureDetector(
                        onTap: () => _pickMedia(),
                        child: Container(
                          width: 120, margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, style: BorderStyle.solid)),
                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, color: GacomColors.deepOrange, size: 32), Text('Add More', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))]),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_selectedMedia[i].path), width: 140, height: 200, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMedia.removeAt(i)),
                            child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: GacomColors.error, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Caption
            GacomTextField(
              controller: _captionCtrl,
              hint: 'What\'s happening in your gaming world? 🎮',
              maxLines: 5,
              maxLength: 500,
            ),
            const SizedBox(height: 20),

            // Tags
            const Text('Add Tags', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GacomTextField(
                    controller: _tagCtrl,
                    hint: 'e.g. callofduty, fps',
                    prefixIcon: Icons.tag_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final tag = _tagCtrl.text.trim().replaceAll(' ', '').replaceAll('#', '');
                    if (tag.isNotEmpty && !_tags.any((t) => t['tag'] == tag)) {
                      setState(() { _tags.add({'tag': tag}); _tagCtrl.clear(); });
                    }
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
                  child: const Text('ADD'),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _tags.map((t) => Chip(
                  label: Text('#${t['tag']}', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                  backgroundColor: GacomColors.cardDark,
                  side: const BorderSide(color: GacomColors.border),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: GacomColors.textMuted),
                  onDeleted: () => setState(() => _tags.remove(t)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeButton({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GacomColors.deepOrange : GacomColors.cardDark,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: selected ? GacomColors.deepOrange : GacomColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : GacomColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: selected ? Colors.white : GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}
