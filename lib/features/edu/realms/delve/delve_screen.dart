import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'delve_logic.dart';
import 'delve_painter.dart';

class DelveScreen extends StatelessWidget {
  const DelveScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Delve',
      title: 'Delve',
      story: 'Far below the hills lies a buried academy of lantern-keepers. Their halls went dark long ago, '
          'and their rune doors answer only to those who know the lessons. Take a torch, keep it fed, and descend.',
      howTo: 'Drag to walk. Your torch shrinks as it burns, so collect fuel flasks. Touch a glowing rune door and '
          'answer its question to open it; a wrong answer fires a trap. Shadows flee the light but hunt you in the dark. '
          'Press SPRINT for a short burst. Reach the stairs to go deeper.',
      icon: Icons.local_fire_department_rounded,
      accent: const Color(0xFFFFB347),
      config: config,
      background: Colors.black,
      actions: const <RealmAction>[RealmAction(0, Icons.bolt_rounded, 'SPRINT')],
      create: (RealmContent content) => DelveLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => DelvePainter(logic as DelveLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final DelveLogic d = logic as DelveLogic;
        if (!d.modal || d.question == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: Container(
            color: const Color(0xAA000000),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 90, 14, 20),
                child: RealmQuestionPanel(
                  question: d.question!,
                  accent: const Color(0xFFFFB347),
                  header: d.panelHeader,
                  chosen: d.chosen,
                  resultLine: d.resultLine,
                  continueLabel: d.chosen != null && d.chosen == d.question!.answerIndex ? 'WALK THROUGH' : 'STEP BACK',
                  onPick: (int i) {
                    d.pickAnswer(i);
                    refresh();
                  },
                  onContinue: () {
                    d.continuePanel();
                    refresh();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
