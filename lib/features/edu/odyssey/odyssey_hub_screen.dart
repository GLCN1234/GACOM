import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'odyssey_questions.dart';
import 'odyssey_screen.dart';

/// Pick what to explore in Odyssey: every subject at once, or just one, and
/// whether to use the student's own school curriculum.
class OdysseyHubScreen extends StatefulWidget {
  const OdysseyHubScreen({super.key});
  @override
  State<OdysseyHubScreen> createState() => _OdysseyHubScreenState();
}

class _OdysseyHubScreenState extends State<OdysseyHubScreen> {
  String _subject = 'mix';
  bool _useSchool = true;
  bool _loading = true;
  SchoolContent? _school;

  @override
  void initState() {
    super.initState();
    _loadSchool();
  }

  Future<void> _loadSchool() async {
    SchoolContent? s;
    try {
      s = await OdysseyData.loadSchool();
    } catch (e) {
      s = null;
    }
    if (!mounted) return;
    setState(() {
      _school = s;
      _loading = false;
    });
  }

  int get _schoolCount {
    final SchoolContent? s = _school;
    if (s == null) return 0;
    int n = 0;
    for (final List<Map<String, dynamic>> l in s.bySubject.values) {
      n += l.length;
    }
    return n;
  }

  void _start() {
    context.push('/edu/odyssey/play', extra: OdysseyConfig(subjectId: _subject, useSchool: _useSchool));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSchool = _schoolCount > 0;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('ODYSSEY')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF00897B)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AN OPEN WORLD MADE OF SUBJECTS',
                    style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: 1)),
                SizedBox(height: 6),
                Text(
                  'Roam a living map. Every region is a subject. Walk into glowing orbs to face a question, dash past hunters, grab crystals and keep your hearts. The world never stops and it gets wilder the longer you last.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('WHAT DO YOU WANT TO EXPLORE?',
                style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip('mix', 'All subjects', const Color(0xFFFF6A00)),
              for (final OdySubject s in odySubjects) _chip(s.id, s.label, s.color),
            ]),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
              child: Row(children: [
                const Icon(Icons.school_rounded, color: GacomColors.accentCyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Use my school\'s curriculum',
                        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      _loading
                          ? 'Checking your school...'
                          : hasSchool
                              ? '$_schoolCount questions from your school are mixed into the world.'
                              : 'No school content found yet. The built-in question bank is used.',
                      style: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
                    ),
                  ]),
                ),
                Switch(value: _useSchool, onChanged: (bool v) => setState(() => _useSchool = v)),
              ]),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.explore_rounded),
                label: const Text('ENTER THE WORLD', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/edu/quests'),
              icon: const Icon(Icons.auto_stories_rounded, size: 18),
              label: const Text('Story missions (Life Quests)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String id, String label, Color color) {
    final bool on = _subject == id;
    return GestureDetector(
      onTap: () => setState(() => _subject = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: on ? 1.0 : 0.4)),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: on ? Colors.white : GacomColors.textPrimary)),
      ),
    );
  }
}
