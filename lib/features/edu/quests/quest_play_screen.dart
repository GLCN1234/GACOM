import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../edu_progress_recorder.dart';
import 'quest_models.dart';
import 'quest_runner.dart';
import 'quest_service.dart';

/// Loads a quest by id and plays it.
class QuestPlayScreen extends StatefulWidget {
  final String questId;
  const QuestPlayScreen({super.key, required this.questId});
  @override
  State<QuestPlayScreen> createState() => _QuestPlayScreenState();
}

class _QuestPlayScreenState extends State<QuestPlayScreen> {
  Quest? _quest;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    QuestService.loadOne(widget.questId).then((Quest? q) {
      if (mounted) setState(() { _quest = q; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    }
    final Quest? q = _quest;
    if (q == null) {
      return Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('Life Quest')),
        body: const Center(child: Text('This quest is not available.', style: TextStyle(color: GacomColors.textSecondary))),
      );
    }
    return _QuestPlayer(quest: q);
  }
}

class _QuestPlayer extends StatefulWidget {
  final Quest quest;
  const _QuestPlayer({required this.quest});
  @override
  State<_QuestPlayer> createState() => _QuestPlayerState();
}

class _QuestPlayerState extends State<_QuestPlayer> {
  late QuestRunner _r;
  final TextEditingController _input = TextEditingController();
  bool _saved = false;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _newRun();
  }

  void _newRun() {
    _r = QuestRunner(widget.quest)..addListener(_changed);
    _saved = false;
    _inputError = null;
    _input.clear();
  }

  void _changed() {
    if (!mounted) return;
    if (_r.finished && !_r.hasFeedback && !_saved) {
      _saved = true;
      EduProgressRecorder.recordSession(
        subject: widget.quest.subject,
        xpEarned: _r.xpEarned,
        questionsAnswered: _r.asked,
        correctAnswers: _r.correct,
      );
      QuestService.saveResult(widget.quest, _r);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _r.removeListener(_changed);
    _r.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    if (_r.finished) return true;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Leave this quest?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
        content: const Text('Your progress in this story will be lost.', style: TextStyle(color: GacomColors.textSecondary)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: GacomColors.error))),
        ],
      ),
    );
    return ok == true;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final bool ok = _r.submitAnswer(_input.text);
    if (!ok) {
      setState(() => _inputError = 'Type a number to answer.');
    } else {
      _input.clear();
      _inputError = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final QuestScene s = _r.scene;
    final _Backdrop bd = _backdropFor(s.bg ?? widget.quest.scenes[widget.quest.start]?.bg);
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: bd.colors.last,
        body: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bd.colors)),
          child: SafeArea(
            child: Stack(children: <Widget>[
              Positioned(
                right: -30,
                top: 70,
                child: Icon(bd.icon, size: 230, color: Colors.white.withValues(alpha: 0.07)),
              ),
              Column(children: <Widget>[
                _topBar(),
                _hud(),
                Expanded(child: _stage(s)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
        child: Row(children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () async {
              if (await _confirmExit() && mounted) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/edu/quests');
                }
              }
            },
          ),
          Expanded(child: Text(widget.quest.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 0.5))),
        ]),
      );

  Widget _hud() {
    if (widget.quest.stats.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: widget.quest.stats.map(_statChip).toList()),
    );
  }

  Widget _statChip(QuestStat st) {
    final int v = _r.stats[st.id] ?? 0;
    final int? d = _r.lastDelta[st.id];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(questIcon(st.icon), size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(st.show(v), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
        if (d != null && d != 0) ...<Widget>[
          const SizedBox(width: 6),
          Text(d > 0 ? '+${st.format == 'naira' ? st.show(d) : d}' : (st.format == 'naira' ? '-${st.show(-d)}' : '$d'),
              style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: d > 0 ? const Color(0xFF7CFFB2) : const Color(0xFFFF8A80))),
        ],
      ]),
    );
  }

  Widget _stage(QuestScene s) {
    if (_r.finished) return _endPanel(s);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: child)),
      child: KeyedSubtree(
        key: ValueKey<String>('${s.id}|${_r.hasFeedback}'),
        child: _sceneBody(s),
      ),
    );
  }

  Widget _sceneBody(QuestScene s) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints cons) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cons.maxHeight - 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            _speakerRow(s),
            const SizedBox(height: 10),
            _bubble(s),
            const SizedBox(height: 14),
            if (_r.hasFeedback) _feedbackCard() else _interaction(s),
          ]),
        ),
      );
    });
  }

  Widget _speakerRow(QuestScene s) {
    final QuestCast? who = s.speaker == null ? null : widget.quest.cast[s.speaker];
    final Color color = who?.color ?? const Color(0xFF455A64);
    final String name = who?.name ?? 'Narrator';
    final String role = who?.role ?? '';
    return Row(children: <Widget>[
      Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white, width: 2), boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)]),
        child: Center(
          child: who == null
              ? const Icon(Icons.menu_book_rounded, color: Colors.white)
              : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(name, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          if (role.isNotEmpty) Text(role, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ]),
      ),
    ]);
  }

  Widget _bubble(QuestScene s) {
    final bool tappable = s.kind == SceneKind.say && !_r.hasFeedback;
    return GestureDetector(
      onTap: tappable ? () { HapticFeedback.selectionClick(); _r.advance(); } : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(_r.text, style: const TextStyle(fontSize: 15.5, height: 1.45, color: Color(0xFF1B1B1F))),
          if (tappable) ...<Widget>[
            const SizedBox(height: 10),
            const Align(alignment: Alignment.centerRight, child: Text('TAP TO CONTINUE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFFF6A00), letterSpacing: 1))),
          ],
        ]),
      ),
    );
  }

  Widget _interaction(QuestScene s) {
    switch (s.kind) {
      case SceneKind.choice:
        final List<QuestChoice> list = _r.visibleChoices;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: list.map((QuestChoice c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                ),
                onPressed: () { HapticFeedback.selectionClick(); _r.choose(c); },
                child: Align(alignment: Alignment.centerLeft, child: Text(c.text, style: const TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600))),
              ),
            )).toList());
      case SceneKind.input:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Row(children: <Widget>[
            if (s.unit != null && s.unit!.length <= 2 && s.unit != 'L' && s.unit != 'min')
              Padding(padding: const EdgeInsets.only(right: 8), child: Text(s.unit!, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white))),
            Expanded(
              child: TextField(
                controller: _input,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: 'Your answer',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.45),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  suffixText: (s.unit == 'L' || s.unit == 'min') ? s.unit : null,
                  suffixStyle: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ]),
          if (s.hint != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Hint: ${s.hint}', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75)))),
          if (_inputError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_inputError!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF8A80)))),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: _submit,
            child: const Text('SUBMIT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]);
      case SceneKind.say:
      case SceneKind.branch:
      case SceneKind.end:
        return const SizedBox.shrink();
    }
  }

  Widget _feedbackCard() {
    final bool? good = _r.feedbackGood;
    final Color tint = good == true ? const Color(0xFF2E7D32) : (good == false ? const Color(0xFFC62828) : const Color(0xFF37474F));
    final String label = good == true ? 'WELL DONE' : (good == false ? 'LEARN THIS' : 'NOTE');
    final IconData icon = good == true ? Icons.check_circle_rounded : (good == false ? Icons.lightbulb_rounded : Icons.info_rounded);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white, letterSpacing: 1)),
        ]),
        const SizedBox(height: 8),
        Text(_r.feedback ?? '', style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.white)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: () { HapticFeedback.selectionClick(); _r.dismissFeedback(); },
            child: Text('CONTINUE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: tint)),
          ),
        ),
      ]),
    );
  }

  Widget _endPanel(QuestScene s) {
    final int stars = _r.stars;
    final Color accent = s.outcome == 'good' ? const Color(0xFF7CFFB2) : (s.outcome == 'bad' ? const Color(0xFFFF8A80) : const Color(0xFFFFE082));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List<Widget>.generate(3, (int i) => Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 44, color: i < stars ? GacomColors.gold : Colors.white38))),
            const SizedBox(height: 10),
            Text(s.title.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: accent)),
            const SizedBox(height: 10),
            Text(s.summary, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
              _endStat('Correct', '${_r.correct}/${_r.asked}'),
              _endStat('XP earned', '+${_r.xpEarned}'),
            ]),
            const SizedBox(height: 20),
            Row(children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                  onPressed: () { _r.removeListener(_changed); _r.dispose(); setState(_newRun); },
                  child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/edu/quests');
                    }
                  },
                  child: const Text('ALL QUESTS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _endStat(String label, String value) => Column(children: <Widget>[
        Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
      ]);
}

class _Backdrop {
  final List<Color> colors;
  final IconData icon;
  const _Backdrop(this.colors, this.icon);
}

_Backdrop _backdropFor(String? bg) {
  switch (bg) {
    case 'market':
      return const _Backdrop(<Color>[Color(0xFFBF360C), Color(0xFF4E1A07)], Icons.storefront_rounded);
    case 'road':
      return const _Backdrop(<Color>[Color(0xFF37474F), Color(0xFF11181C)], Icons.directions_bus_rounded);
    case 'school':
      return const _Backdrop(<Color>[Color(0xFF1565C0), Color(0xFF0A2A52)], Icons.school_rounded);
    case 'street':
      return const _Backdrop(<Color>[Color(0xFF6A1B9A), Color(0xFF260A3A)], Icons.local_fire_department_rounded);
    case 'clinic':
      return const _Backdrop(<Color>[Color(0xFF00796B), Color(0xFF053D36)], Icons.health_and_safety_rounded);
    case 'well':
      return const _Backdrop(<Color>[Color(0xFF0277BD), Color(0xFF05324F)], Icons.water_drop_rounded);
    default:
      return const _Backdrop(<Color>[Color(0xFF263238), Color(0xFF0B0B0F)], Icons.auto_stories_rounded);
  }
}
