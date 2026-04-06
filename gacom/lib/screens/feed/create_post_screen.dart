import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gacom_widgets.dart';
import '../../services/supabase_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  List<XFile> _selectedMedia = [];
  String _selectedType = 'text';
  bool _isPosting = false;

  final _picker = ImagePicker();

  Future<void> _pickMedia(bool video) async {
    final files = video
        ? [await _picker.pickVideo(source: ImageSource.gallery)].whereType<XFile>().toList()
        : await _picker.pickMultiImage(limit: 4);
    setState(() {
      _selectedMedia = files;
      _selectedType = video ? 'video' : 'image';
    });
  }

  Future<void> _post() async {
    if (_contentCtrl.text.isEmpty && _selectedMedia.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim().replaceAll('#', '')).where((t) => t.isNotEmpty).toList();
      await SupabaseService.createPost({
        'user_id': userId,
        'content': _contentCtrl.text.isEmpty ? null : _contentCtrl.text,
        'type': _selectedType,
        'media_urls': [],
        'tags': tags,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.background,
      appBar: AppBar(
        backgroundColor: GacomColors.background,
        title: Text('CREATE POST', style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
        leading: IconButton(icon: const Icon(Icons.close, color: GacomColors.textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GlowButton(
              text: 'POST',
              isLoading: _isPosting,
              onPressed: _post,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GacomAvatar(username: 'U', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    minLines: 4,
                    autofocus: true,
                    style: GoogleFonts.outfit(color: GacomColors.textPrimary, fontSize: 16, height: 1.6),
                    decoration: InputDecoration(
                      hintText: "What's your game move? Share a clip, highlight, or thoughts...",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedia.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: GacomColors.surfaceVariant,
                      border: Border.all(color: GacomColors.cardBorder),
                    ),
                    child: Stack(
                      children: [
                        Center(child: Icon(Icons.image, color: GacomColors.textMuted, size: 40)),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMedia.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: GacomColors.error),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: GacomColors.cardBorder),
            const SizedBox(height: 16),

            // Tags
            TextField(
              controller: _tagsCtrl,
              style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '#CallOfDuty, #Gaming, #clip',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                prefixIcon: const Icon(Icons.tag, color: GacomColors.primary, size: 20),
              ),
            ),

            const Divider(color: GacomColors.cardBorder),
            const SizedBox(height: 16),

            // Media Options
            Text('ADD TO YOUR POST', style: GoogleFonts.rajdhani(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                _MediaOption(icon: Icons.image_outlined, label: 'Photo', color: const Color(0xFF00C853), onTap: () => _pickMedia(false)),
                const SizedBox(width: 12),
                _MediaOption(icon: Icons.videocam_outlined, label: 'Video', color: const Color(0xFFE85D04), onTap: () => _pickMedia(true)),
                const SizedBox(width: 12),
                _MediaOption(icon: Icons.poll_outlined, label: 'Poll', color: const Color(0xFF0D6EFD), onTap: () {}),
                const SizedBox(width: 12),
                _MediaOption(icon: Icons.emoji_emotions_outlined, label: 'Feeling', color: const Color(0xFFFFD600), onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MediaOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
