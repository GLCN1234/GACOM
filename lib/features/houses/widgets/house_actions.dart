import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../house_service.dart';
import 'house_visuals.dart';

class _RequestDialog extends StatefulWidget {
  final String houseName;
  const _RequestDialog({required this.houseName});
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Request to join', style: houseHeading(size: 20)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.houseName} is closed. The captain or an officer will review your request.',
              style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLength: 200,
            maxLines: 3,
            style: const TextStyle(color: GacomColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Message (optional)', labelStyle: TextStyle(color: GacomColors.textMuted)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: GacomColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange),
            child: Text('SEND REQUEST', style: houseHeading(size: 14, color: Colors.white)),
          ),
        ],
      );
}

/// Shows the request dialog and sends the request. Returns true if a request was sent.
Future<bool> houseRequestFlow(BuildContext context, {required String houseId, required String houseName}) async {
  final msg = await showDialog<String>(context: context, builder: (_) => _RequestDialog(houseName: houseName));
  if (msg == null) return false;
  final res = await HouseService.requestJoin(houseId, message: msg);
  if (!context.mounted) return false;
  if (res.success) {
    GacomSnackbar.show(context, 'Request sent. You will be added when it is accepted.', isSuccess: true);
    return true;
  }
  GacomSnackbar.show(context, res.message, isError: true);
  return false;
}

/// Joins an open house, or falls back to a join request for closed houses.
/// Returns true if anything changed (joined or requested).
Future<bool> houseJoinFlow(BuildContext context, {required String houseId, required String houseName, bool isOpen = true}) async {
  if (!isOpen) return houseRequestFlow(context, houseId: houseId, houseName: houseName);
  final res = await HouseService.joinHouse(houseId);
  if (!context.mounted) return false;
  if (res.success) {
    GacomSnackbar.show(context, 'Welcome to $houseName', isSuccess: true);
    return true;
  }
  if (res.needsRequest) return houseRequestFlow(context, houseId: houseId, houseName: houseName);
  GacomSnackbar.show(context, res.message, isError: true);
  return false;
}
