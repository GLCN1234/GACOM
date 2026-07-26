import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class EduSubjectsScreen extends StatelessWidget {
  const EduSubjectsScreen({super.key});

  static const _subjects = [
    {'icon': '🧮', 'label': 'Mathematics',       'games': 19, 'skill': 85, 'color': 0xFFFF6A00, 'id': 'math'},
    {'icon': '🔬', 'label': 'Science',            'games': 12, 'skill': 72, 'color': 0xFF00C2A8, 'id': 'science'},
    {'icon': '📖', 'label': 'English',            'games': 8,  'skill': 68, 'color': 0xFF3D8BFF, 'id': 'english'},
    {'icon': '🌍', 'label': 'Geography',          'games': 7,  'skill': 70, 'color': 0xFF34D399, 'id': 'geography'},
    {'icon': '📜', 'label': 'History',            'games': 6,  'skill': 66, 'color': 0xFFFF8A33, 'id': 'history'},
    {'icon': '💻', 'label': 'Coding',             'games': 9,  'skill': 62, 'color': 0xFF8B5CF6, 'id': 'coding'},
    {'icon': '🧠', 'label': 'Logic & IQ',         'games': 10, 'skill': 95, 'color': 0xFFE85B8A, 'id': 'logic'},
    {'icon': '💰', 'label': 'Financial Literacy', 'games': 5,  'skill': 61, 'color': 0xFF34D399, 'id': 'finance'},
    {'icon': '⚙',  'label': 'Engineering',        'games': 4,  'skill': 55, 'color': 0xFF3D8BFF, 'id': 'engineering'},
    {'icon': '🌐', 'label': 'Languages',          'games': 8,  'skill': 58, 'color': 0xFF00E5FF, 'id': 'languages'},
    {'icon': '🎨', 'label': 'Creativity',         'games': 6,  'skill': 74, 'color': 0xFFFF6A00, 'id': 'creativity'},
    {'icon': '🏥', 'label': 'Health Science',     'games': 3,  'skill': 60, 'color': 0xFF00C2A8, 'id': 'science'},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('ALL SUBJECTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
    ),
    body: GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1),
      itemCount: _subjects.length,
      itemBuilder: (_, i) {
        final s = _subjects[i];
        final color = Color(s['color'] as int);
        return GestureDetector(
          onTap: () => context.push('/edu/subject/${s['id']}'),
          child: Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s['icon'] as String, style: const TextStyle(fontSize: 28)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text('${s['skill']}%', style: TextStyle(color: color, fontSize: 10, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              Text(s['label'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary)),
              Text('${s['games']} games', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (s['skill'] as int) / 100, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(color), minHeight: 4)),
            ])),
        );
      },
    ),
  );
}
