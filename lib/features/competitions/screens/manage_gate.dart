import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import 'tournament_manager_screen.dart';

/// Opens the tournament manager with admin controls only for staff (admin, super admin, moderator).
/// Everyone else gets the read-only view. The database enforces the same rule on every write.
class ManageGate extends StatefulWidget {
  final String competitionId;
  const ManageGate({super.key, required this.competitionId});
  @override
  State<ManageGate> createState() => _ManageGateState();
}

class _ManageGateState extends State<ManageGate> {
  bool? _staff;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    bool staff = false;
    try {
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        final p = await SupabaseService.client.from('profiles').select('role').eq('id', uid).single();
        staff = ['admin', 'super_admin', 'moderator'].contains(p['role']);
      }
    } catch (_) {}
    if (mounted) setState(() => _staff = staff);
  }

  @override
  Widget build(BuildContext context) {
    if (_staff == null) {
      return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    }
    return TournamentManagerScreen(competitionId: widget.competitionId, isAdmin: _staff!);
  }
}
