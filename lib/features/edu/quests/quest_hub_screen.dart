import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'quest_models.dart';
import 'quest_service.dart';

const Map<String, String> _subjectNames = <String, String>{
  'math': 'Mathematics',
  'physics': 'Physics',
  'chemistry': 'Chemistry',
  'biology': 'Biology',
  'english': 'English',
  'geography': 'Geography',
  'history': 'History',
  'economics': 'Economics',
  'civics': 'Civic Education',
  'bst': 'Basic Science',
  'coding': 'Coding',
};

/// Story-driven lessons: a student plays through a real-life situation and
/// makes choices that use what they have learned.
class QuestHubScreen extends StatefulWidget {
  const QuestHubScreen({super.key});
  @override
  State<QuestHubScreen> createState() => _QuestHubScreenState();
}

class _QuestHubScreenState extends State<QuestHubScreen> {
  List<Quest> _quests = <Quest>[];
  Map<String, int> _stars = <String, int>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Quest> quests = QuestService.builtIn();
    if (mounted) setState(() { _quests = quests; _loading = false; });
    final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[QuestService.loadAll(), QuestService.loadStars()]);
    if (!mounted) return;
    setState(() {
      _quests = res[0] as List<Quest>;
      _stars = res[1] as Map<String, int>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(backgroundColor: GacomColors.obsidian, title: const Text('LIFE QUESTS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
                const Text(
                  'Step into a real situation, meet the people in it and make choices that use what you have learned. Every quest earns XP for its subject.',
                  style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                ..._quests.map(_card),
                const SizedBox(height: 40),
              ]),
            ),
    );
  }

  Widget _card(Quest q) {
    final int stars = _stars[q.id] ?? 0;
    return GestureDetector(
      onTap: () async {
        await context.push('/edu/quest/${q.id}');
        if (mounted) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Container(
            width: 92,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: q.colors)),
            child: Center(child: Icon(questIcon(q.icon), color: Colors.white, size: 42)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(q.title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
                const SizedBox(height: 4),
                Text(q.blurb, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4)),
                const SizedBox(height: 10),
                Row(children: <Widget>[
                  _chip(_subjectNames[q.subject] ?? q.subject),
                  if (q.level.isNotEmpty) ...<Widget>[const SizedBox(width: 6), _chip(q.level)],
                  const Spacer(),
                  ...List<Widget>.generate(3, (int i) => Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: i < stars ? GacomColors.gold : GacomColors.textMuted)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: GacomColors.deepOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11, color: GacomColors.deepOrange)),
      );
}
