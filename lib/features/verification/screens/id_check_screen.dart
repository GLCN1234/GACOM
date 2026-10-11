import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/hosting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pick_upload.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// Sends an ID photo and a selfie for review. The pictures go to a private store, only staff can
/// open them, and they are deleted as soon as the check is decided.
class IdCheckScreen extends StatefulWidget {
  const IdCheckScreen({super.key});
  @override
  State<IdCheckScreen> createState() => _IdCheckScreenState();
}

class _IdCheckScreenState extends State<IdCheckScreen> {
  static const _types = {
    'nin': 'NIN slip or national ID',
    'drivers_licence': "Driver's licence",
    'passport': 'International passport',
    'voters_card': "Voter's card",
  };
  String _type = 'nin';
  final _name = TextEditingController();
  String? _docPath, _selfiePath;
  bool _upDoc = false, _upSelfie = false, _busy = false, _loading = true;
  Map<String, dynamic> _state = {};

  @override
  void initState() {
    super.initState();
    HostingService.idState().then((s) {
      if (mounted) setState(() { _state = s; _loading = false; });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool selfie) async {
    setState(() => selfie ? _upSelfie = true : _upDoc = true);
    try {
      final p = await pickAndUploadPath(bucket: 'id-checks', source: selfie ? ImageSource.camera : ImageSource.gallery);
      if (p != null && mounted) setState(() => selfie ? _selfiePath = p : _docPath = p);
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, '$e', isError: true);
    }
    if (mounted) setState(() => selfie ? _upSelfie = false : _upDoc = false);
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 3) {
      GacomSnackbar.show(context, 'Enter your full name as it appears on the ID', isError: true);
      return;
    }
    if (_docPath == null || _selfiePath == null) {
      GacomSnackbar.show(context, 'Add the ID photo and the selfie', isError: true);
      return;
    }
    setState(() => _busy = true);
    final r = await HostingService.idSubmit(docType: _type, fullName: _name.text.trim(), docPath: _docPath!, selfiePath: _selfiePath!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.success) {
      GacomSnackbar.show(context, r.error ?? 'Could not send', isError: true);
      return;
    }
    GacomSnackbar.show(context, 'Sent. We will let you know once it is checked.', isSuccess: true);
    Navigator.of(context).pop();
  }

  Widget _tile(String label, String hint, String? path, bool uploading, bool selfie) => GestureDetector(
        onTap: uploading ? null : () => _pick(selfie),
        child: Container(
          height: 110,
          decoration: BoxDecoration(color: GacomColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: path != null ? GacomColors.success : GacomColors.border)),
          child: Center(
            child: uploading
                ? const CircularProgressIndicator(color: GacomColors.deepOrange)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(path != null ? Icons.check_circle_rounded : (selfie ? Icons.face_rounded : Icons.badge_outlined), color: path != null ? GacomColors.success : GacomColors.deepOrange, size: 30),
                    const SizedBox(height: 6),
                    Text(path != null ? '$label added. Tap to replace.' : label, style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(hint, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                  ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final status = (_state['status'] as String?) ?? 'none';
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('ID CHECK')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : status == 'pending' || status == 'approved'
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(status == 'approved' ? Icons.verified_user_rounded : Icons.hourglass_top_rounded, color: status == 'approved' ? GacomColors.success : GacomColors.warning, size: 54),
                      const SizedBox(height: 14),
                      Text(status == 'approved' ? 'Your ID is verified' : 'Your ID is being reviewed', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(status == 'approved' ? 'Every verification level and paid competitions are open to you.' : 'This usually takes a day. You will get a notification.',
                          textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted)),
                    ]),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(20), children: [
                  if (status == 'rejected' && (_state['note'] as String?) != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('Last time: ${_state['note']}', style: const TextStyle(color: GacomColors.error, fontSize: 12)),
                    ),
                  const Text('Your ID type', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in _types.entries)
                      GestureDetector(
                        onTap: () => setState(() => _type = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: _type == e.key ? GacomColors.deepOrange.withOpacity(0.15) : GacomColors.surfaceDark,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _type == e.key ? GacomColors.deepOrange : GacomColors.border)),
                          child: Text(e.value, style: TextStyle(color: _type == e.key ? GacomColors.deepOrange : GacomColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    style: const TextStyle(color: GacomColors.textPrimary),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                        labelText: 'Full name on the ID',
                        labelStyle: const TextStyle(color: GacomColors.textMuted),
                        filled: true,
                        fillColor: GacomColors.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.border))),
                  ),
                  const SizedBox(height: 14),
                  _tile('Photo of your ID', 'All four corners visible, text readable', _docPath, _upDoc, false),
                  const SizedBox(height: 12),
                  _tile('A selfie', 'Your face, clearly lit', _selfiePath, _upSelfie, true),
                  const SizedBox(height: 20),
                  GacomButton(label: _busy ? 'SENDING...' : 'SEND FOR REVIEW', onPressed: _busy ? null : _submit),
                  const SizedBox(height: 10),
                  const Text(
                      'Only GACOM staff can open these pictures, and they are deleted as soon as the check is decided. We keep only the result and the name you typed. Nothing is shared with other members.',
                      style: TextStyle(color: GacomColors.textMuted, fontSize: 11, height: 1.5)),
                ]),
    );
  }
}
