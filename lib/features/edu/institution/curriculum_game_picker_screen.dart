import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../edu_progress_recorder.dart';
import '../../arena/games/topic_block.dart';
import '../../arena/screens/games/endless_runner_screen.dart';
import '../../arena/screens/games/drone_breach_screen.dart';
import '../../arena/screens/games/signal_match_screen.dart';
import '../../arena/screens/games/vault_break_screen.dart';

/// Replaces the old CurriculumGameScreen popup-quiz flow. Fetches the
/// exact same institution_curricula row (same query, same data — nothing
/// about the fetch changes), but instead of rendering the old quiz-card
/// UI, lets the student pick which game engine to play that topic's real
/// content through. Works for ANY subject or topic in ANY institution
/// already in the system, since every engine takes the same TopicBlock
/// shape this screen builds once here.
class CurriculumGamePickerScreen extends StatefulWidget {
  const CurriculumGamePickerScreen({super.key, required this.curriculumId});
  final String curriculumId;

  @override
  State<CurriculumGamePickerScreen> createState() => _CurriculumGamePickerScreenState();
}

class _CurriculumGamePickerScreenState extends State<CurriculumGamePickerScreen> {
  bool _loading = true;
  String? _error;
  String _topic = '';
  String _subjectLabel = '';
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final row = await SupabaseService.client
          .from('institution_curricula')
          .select('topic,subject,generated_questions')
          .eq('id', widget.curriculumId)
          .single();
      final qs = List<Map<String, dynamic>>.from(row['generated_questions'] as List? ?? const []);
      if (mounted) setState(() {
        _topic = row['topic'] as String? ?? 'This Topic';
        _subjectLabel = row['subject'] as String? ?? '';
        _questions = qs;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load this topic.'; _loading = false; });
    }
  }

  void _launch(BuildContext context, Widget Function(String subject, List<TopicBlock> topics) build) {
    final subjectId = EduProgressRecorder.subjectIdFromLabel(_subjectLabel);
    final topics = [TopicBlock(topicName: _topic, questions: _questions)];
    Navigator.push(context, MaterialPageRoute(builder: (_) => build(subjectId, topics)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text(_topic.isEmpty ? 'CHOOSE A GAME' : _topic.toUpperCase())),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: GacomColors.textMuted)))
          : _questions.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No questions generated for this topic yet.', textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted))))
            : SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_questions.length} questions ready — pick how you want to play them.',
                  style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 20),
                Expanded(child: ListView(children: [
                  _gameCard(context, 'Signal Run', 'Swipe to switch lanes, dodge obstacles, catch the right answer.', Icons.directions_run_rounded, GacomColors.deepOrange,
                    (subject, topics) => EndlessRunnerScreen(subject: subject, topics: topics)),
                  _gameCard(context, 'Drone Breach', 'Tap to shoot down the drone carrying the correct answer.', Icons.gps_fixed_rounded, GacomColors.accentCyan,
                    (subject, topics) => DroneBreachScreen(subject: subject, topics: topics)),
                  _gameCard(context, 'Signal Match', 'Swipe through the correct answer as it arcs across the screen.', Icons.gesture_rounded, const Color(0xFFFF6B9D),
                    (subject, topics) => SignalMatchScreen(subject: subject, topics: topics)),
                  _gameCard(context, 'Vault Break', 'Rotate the dial to line up the correct answer, then confirm.', Icons.rotate_right_rounded, const Color(0xFFC9A24B),
                    (subject, topics) => VaultBreakScreen(subject: subject, topics: topics)),
                ])),
              ]))),
    );
  }

  Widget _gameCard(BuildContext context, String name, String desc, IconData icon, Color color, Widget Function(String, List<TopicBlock>) build) => GestureDetector(
    onTap: () => _launch(context, build),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.35))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
      ]),
    ),
  );
}
