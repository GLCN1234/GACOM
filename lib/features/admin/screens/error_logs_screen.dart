import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Real error descriptions from real crashes, not screenshots relayed
/// secondhand — every crash the friendly error screen catches also
/// lands here automatically.
class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});
  @override State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client.from('error_logs')
          .select('*, user:profiles!user_id(display_name)')
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) setState(() { _logs = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('ERROR LOGS'), actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
    ]),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _logs.isEmpty
        ? const Center(child: Text('No errors logged — clean so far.', style: TextStyle(color: GacomColors.textMuted)))
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _logs.length, itemBuilder: (_, i) {
            final log = _logs[i];
            final user = log['user'] as Map<String, dynamic>?;
            final when = DateTime.tryParse(log['created_at'] as String? ?? '');
            return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.error.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(log['route'] as String? ?? 'Unknown screen', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.accentCyan))),
                  if (when != null) Text(DateFormat('MMM d, h:mm a').format(when), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                ]),
                const SizedBox(height: 6),
                Text(log['error'] as String? ?? '', style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, fontFamily: 'monospace'), maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('User: ${user?['display_name'] ?? 'Not signed in'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                if ((log['stack'] as String? ?? '').isNotEmpty)
                  ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Stack trace', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
                    children: [Container(width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: GacomColors.obsidian, borderRadius: BorderRadius.circular(8)),
                      child: Text(log['stack'] as String? ?? '', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 10, fontFamily: 'monospace')))]),
              ]));
          }),
  );
}
