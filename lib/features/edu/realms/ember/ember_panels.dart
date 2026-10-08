import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'ember_jobs.dart';
import 'ember_logic.dart';

const Color _accent = Color(0xFF2ED3E6);
const Color _ink = Color(0xFF04202A);
const Color _good = Color(0xFF69F0AE);
const Color _bad = Color(0xFFFF8A80);
const Color _ember = Color(0xFFFFB74D);
const List<Color> _partColors = <Color>[Color(0xFFFFB74D), Color(0xFF4DD0E1), Color(0xFFBA68C8)];
const List<Color> _pieceColors = <Color>[Color(0xFFEF6C00), Color(0xFF00897B), Color(0xFF3949AB), Color(0xFFC2185B), Color(0xFF7CB342)];

/// The full-screen panel for the current modal phase, or an empty box.
Widget emberPanels(EmberLogic g, VoidCallback refresh) {
  switch (g.phase) {
    case emJob:
      return _jobPanel(g, refresh);
    case emMaster:
      return _masterPanel(g, refresh);
    case emBossIntro:
      return _bossIntro(g, refresh);
    case emBoss:
      return _bossPanel(g, refresh);
    default:
      return const SizedBox.shrink();
  }
}

// ---- shared pieces --------------------------------------------------------

Widget _barrier() => Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.66)));

BoxDecoration _cardDeco(Color border) => BoxDecoration(
      color: const Color(0xF2081824),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border, width: 1.4),
    );

Widget _centered(Widget card) => Positioned.fill(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 56, 14, 16),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: card),
        ),
      ),
    );

Widget _card(Color border, List<Widget> kids) => Positioned.fill(
      child: Stack(children: <Widget>[
        _barrier(),
        _centered(Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(border),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
        )),
      ]),
    );

Widget _btn(String label, VoidCallback? onTap, {Color color = _accent, Color text = _ink}) {
  return SizedBox(
    height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.white12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      onPressed: onTap,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: onTap == null ? Colors.white38 : text, letterSpacing: 1)),
    ),
  );
}

Widget _stepBtn(String label, VoidCallback onTap, {double? width, Color color = Colors.white12}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: width,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
    ),
  );
}

Widget _heading(String t, {double size = 22, Color color = Colors.white}) =>
    Text(t, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, color: color, letterSpacing: 1.1));

Widget _note(String t, {Color color = Colors.white70, double size = 13.5, TextAlign align = TextAlign.left}) =>
    Text(t, textAlign: align, style: TextStyle(color: color, fontSize: size, height: 1.35, fontWeight: FontWeight.w600));

Widget _feedback(String t, Color c) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.8))),
      child: Text(t, style: TextStyle(color: c, fontSize: 13, height: 1.35, fontWeight: FontWeight.w700)),
    );

Color _kindColor(int kind) {
  switch (kind) {
    case emberJobCargo:
      return const Color(0xFFFFB74D);
    case emberJobSail:
      return const Color(0xFFF48FB1);
    case emberJobLamp:
      return const Color(0xFFFFE082);
    default:
      return const Color(0xFF81C784);
  }
}

IconData _kindIcon(int kind) {
  switch (kind) {
    case emberJobCargo:
      return Icons.layers_rounded;
    case emberJobSail:
      return Icons.content_cut_rounded;
    case emberJobLamp:
      return Icons.flare_rounded;
    default:
      return Icons.storefront_rounded;
  }
}

void _paintText(Canvas canvas, String s, Offset at, double size, Color color, {TextAlign align = TextAlign.center, double maxWidth = 300}) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani', height: 1.0)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: maxWidth);
  double dx = at.dx - tp.width / 2;
  if (align == TextAlign.left) dx = at.dx;
  if (align == TextAlign.right) dx = at.dx - tp.width;
  tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
}

// ---- harbour job panel ----------------------------------------------------

Widget _jobPanel(EmberLogic g, VoidCallback refresh) {
  final EmberJob? j = g.job;
  if (j == null) return const SizedBox.shrink();
  final Color kc = _kindColor(j.kind);
  final List<Widget> kids = <Widget>[
    Row(children: <Widget>[
      Icon(_kindIcon(j.kind), color: kc, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('HARBOUR OF ${g.currentIslandName.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
          Text(j.title.toUpperCase(), style: TextStyle(color: kc, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 21, letterSpacing: 1)),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
        Text('TANK ${g.fuel.toStringAsFixed(0)}/${EmberLogic.fuelCap.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12)),
        Text(g.jobStage == 2 ? 'DONE' : 'TRY ${g.jobAttempts + 1} OF 2', style: const TextStyle(color: Colors.white38, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11)),
      ]),
    ]),
    const SizedBox(height: 10),
  ];
  if (g.jobStage == 2) {
    kids.addAll(_doneBody(g, j, kc, refresh));
  } else {
    kids.add(_note(j.statement, color: Colors.white, size: 14));
    kids.add(const SizedBox(height: 10));
    kids.add(_jobBody(g, j, kc, refresh));
    if (g.jobStage == 1) kids.add(_feedback(g.jobFeedback, _bad));
    kids.add(const SizedBox(height: 12));
    if (g.jobStage == 1) {
      kids.add(_btn('TRY AGAIN', () {
        g.jobRetry();
        refresh();
      }, color: kc));
    } else {
      kids.add(_btn('SUBMIT', j.canSubmit
          ? () {
              g.jobSubmit();
              refresh();
            }
          : null, color: kc));
    }
  }
  return _card(kc, kids);
}

Widget _jobBody(EmberLogic g, EmberJob j, Color kc, VoidCallback refresh) {
  if (j is CargoJob) return _cargoBody(g, j, refresh);
  if (j is SailJob) return _sailBody(g, j, kc, refresh);
  if (j is LampJob) return _lampBody(g, j, refresh);
  if (j is BarterJob) return _barterBody(g, j, kc, refresh);
  return const SizedBox.shrink();
}

List<Widget> _doneBody(EmberLogic g, EmberJob j, Color kc, VoidCallback refresh) {
  final bool last = g.litCount >= EmberLogic.islandCount;
  return <Widget>[
    const SizedBox(height: 4),
    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFE082), size: 54),
    _heading(g.jobSolved ? 'BEACON LIT' : 'BEACON LIT WITH HELP', size: 26, color: g.jobSolved ? const Color(0xFFFFE082) : _ember),
    const SizedBox(height: 6),
    _note(
      g.jobFirstTry
          ? 'First try. The islanders cheer, and your tank is full again.'
          : (g.jobSolved ? 'Solved on the second try. Your tank is full again.' : 'Study the working below. The islanders finish the job with you, and your tank is full again.'),
      align: TextAlign.center,
    ),
    if (!g.jobSolved) _feedback(g.jobFeedback, _ember),
    const SizedBox(height: 14),
    if (!g.masterUsed)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _btn('HARBOUR MASTER: BONUS QUESTION', () {
          g.openMaster();
          refresh();
        }, color: Colors.white12, text: Colors.white),
      ),
    _btn(last ? 'TO THE NIGHT TIDE' : 'SET SAIL AGAIN', () {
      g.closeJob();
      refresh();
    }, color: kc),
  ];
}

// ---- cargo ratio ----------------------------------------------------------

Widget _cargoBody(EmberLogic g, CargoJob j, VoidCallback refresh) {
  final int n = j.parts.length;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    SizedBox(height: 64, child: CustomPaint(painter: _MixPainter(j))),
    const SizedBox(height: 8),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      for (int i = 0; i < n; i++)
        Expanded(
          child: Column(children: <Widget>[
            Text(j.names[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _partColors[i % 3], fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(height: 4),
            SizedBox(width: 58, height: 62, child: CustomPaint(painter: _BarrelPainter(j.counts[i], j.total, _partColors[i % 3]))),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              _stepBtn('-1', () {
                g.cargoAdjust(i, -1);
                refresh();
              }, width: 44),
              const SizedBox(width: 4),
              _stepBtn('+1', () {
                g.cargoAdjust(i, 1);
                refresh();
              }, width: 44),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              _stepBtn('-5', () {
                g.cargoAdjust(i, -5);
                refresh();
              }, width: 44),
              const SizedBox(width: 4),
              _stepBtn('+5', () {
                g.cargoAdjust(i, 5);
                refresh();
              }, width: 44),
            ]),
          ]),
        ),
    ]),
    const SizedBox(height: 8),
    Text('Hold: ${j.held} of ${j.total} units', textAlign: TextAlign.center, style: TextStyle(color: j.held == j.total ? _good : Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)),
  ]);
}

class _MixPainter extends CustomPainter {
  final CargoJob j;
  _MixPainter(this.j);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final Paint p = Paint();
    _paintText(canvas, 'TARGET MIX  ${j.parts.join(' : ')}', Offset(0, 6), 11.5, Colors.white60, align: TextAlign.left);
    _bar(canvas, Rect.fromLTWH(0, 14, w, 16), j.parts, p);
    _paintText(canvas, 'YOUR HOLD  ${j.counts.join(' : ')}', Offset(0, 40), 11.5, Colors.white60, align: TextAlign.left);
    _bar(canvas, Rect.fromLTWH(0, 48, w, 16), j.counts, p);
  }

  void _bar(Canvas canvas, Rect r, List<int> vals, Paint p) {
    final RRect rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
    p.color = Colors.white10;
    canvas.drawRRect(rr, p);
    int tot = 0;
    for (final int v in vals) {
      tot += v;
    }
    if (tot > 0) {
      canvas.save();
      canvas.clipRRect(rr);
      double x = r.left;
      for (int i = 0; i < vals.length; i++) {
        final double sw = r.width * vals[i] / tot;
        p.color = _partColors[i % 3];
        canvas.drawRect(Rect.fromLTWH(x, r.top, sw, r.height), p);
        x += sw;
      }
      canvas.restore();
    }
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white38;
    canvas.drawRRect(rr, s);
  }

  @override
  bool shouldRepaint(_MixPainter old) => true;
}

class _BarrelPainter extends CustomPainter {
  final int count;
  final int total;
  final Color color;
  _BarrelPainter(this.count, this.total, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Rect.fromLTWH(6, 2, size.width - 12, size.height - 4);
    final RRect body = RRect.fromRectAndRadius(r, const Radius.circular(14));
    final Paint p = Paint()..color = const Color(0xFF5D4037);
    canvas.drawRRect(body, p);
    final double f = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0).toDouble();
    canvas.save();
    canvas.clipRRect(body.deflate(3));
    p.color = color.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - r.height * f, r.width, r.height * f), p);
    canvas.restore();
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFA1887F);
    canvas.drawLine(Offset(r.left, r.top + r.height * 0.25), Offset(r.right, r.top + r.height * 0.25), s);
    canvas.drawLine(Offset(r.left, r.top + r.height * 0.75), Offset(r.right, r.top + r.height * 0.75), s);
    canvas.drawRRect(body, s);
    _paintText(canvas, '$count', r.center, 20, Colors.white);
  }

  @override
  bool shouldRepaint(_BarrelPainter old) => old.count != count || old.total != total;
}

// ---- mend the sail --------------------------------------------------------

const double _wallRow = 36;

Widget _sailBody(EmberLogic g, SailJob j, Color kc, VoidCallback refresh) {
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    SizedBox(height: 42, child: CustomPaint(painter: _SailPicturePainter(j.twelfths, j.fractionText))),
    const SizedBox(height: 6),
    SizedBox(height: 42, child: CustomPaint(painter: _TrayPainter(j))),
    const SizedBox(height: 8),
    const Text('FRACTION WALL: tap a brick to add that piece', style: TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8)),
    const SizedBox(height: 4),
    LayoutBuilder(builder: (BuildContext ctx, BoxConstraints cons) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails d) {
          final int row = (d.localPosition.dy / _wallRow).floor();
          if (row >= 0 && row < emberPieceTwelfths.length) {
            g.sailAdd(row);
            refresh();
          }
        },
        child: SizedBox(width: cons.maxWidth, height: _wallRow * emberPieceTwelfths.length, child: CustomPaint(painter: _WallPainter())),
      );
    }),
    const SizedBox(height: 8),
    Row(children: <Widget>[
      Expanded(
        child: _stepBtn('UNDO PIECE', () {
          g.sailUndo();
          refresh();
        }),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _stepBtn('CLEAR', () {
          g.sailClear();
          refresh();
        }),
      ),
    ]),
  ]);
}

class _WallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const List<int> counts = <int>[2, 3, 4, 6, 12];
    final Paint p = Paint();
    for (int r = 0; r < counts.length; r++) {
      final int n = counts[r];
      final double bw = size.width / n;
      for (int i = 0; i < n; i++) {
        final Rect b = Rect.fromLTWH(i * bw, r * _wallRow, bw, _wallRow).deflate(1.6);
        p.color = _pieceColors[r];
        canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(6)), p);
        _paintText(canvas, emberPieceLabels[r], b.center, n >= 12 ? 9.5 : 13, Colors.white, maxWidth: bw);
      }
    }
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

class _SailPicturePainter extends CustomPainter {
  final int twelfths;
  final String label;
  _SailPicturePainter(this.twelfths, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint p = Paint()..color = const Color(0xFFE9DFC8);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), p);
    final double tw = size.width * twelfths / 12;
    final Path torn = Path()..moveTo(0, 0);
    torn.lineTo(tw, 0);
    const int zig = 6;
    for (int i = 1; i <= zig; i++) {
      final double y = size.height * i / zig;
      torn.lineTo(tw + (i.isOdd ? 6 : -4), y);
    }
    torn.lineTo(0, size.height);
    torn.close();
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)));
    p.color = const Color(0xFF4A2326);
    canvas.drawPath(torn, p);
    canvas.restore();
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black26;
    for (int i = 1; i < 12; i++) {
      canvas.drawLine(Offset(size.width * i / 12, 0), Offset(size.width * i / 12, size.height), s);
    }
    s.color = Colors.white54;
    s.strokeWidth = 1.6;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), s);
    _paintText(canvas, 'THE SAIL.  TORN PART = $label OF IT', r.center, 12.5, Colors.white);
  }

  @override
  bool shouldRepaint(_SailPicturePainter old) => old.twelfths != twelfths;
}

class _TrayPainter extends CustomPainter {
  final SailJob j;
  _TrayPainter(this.j);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
    final Paint p = Paint()..color = Colors.white10;
    canvas.drawRRect(rr, p);
    canvas.save();
    canvas.clipRRect(rr);
    double x = 0;
    for (final int idx in j.placed) {
      final double w = size.width * emberPieceTwelfths[idx] / 12;
      final Rect b = Rect.fromLTWH(x, 0, w, size.height);
      p.color = _pieceColors[idx];
      canvas.drawRect(b.deflate(1), p);
      if (w > 26) _paintText(canvas, emberPieceLabels[idx], b.center, 11.5, Colors.white, maxWidth: w);
      x += w;
    }
    canvas.restore();
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white24;
    for (int i = 1; i < 12; i++) {
      canvas.drawLine(Offset(size.width * i / 12, size.height - 7), Offset(size.width * i / 12, size.height), s);
    }
    s.color = j.patched > 12 ? _bad : Colors.white54;
    s.strokeWidth = 1.6;
    canvas.drawRRect(rr, s);
    if (j.placed.isEmpty) _paintText(canvas, 'YOUR PATCHES GO HERE', r.center, 12, Colors.white38);
    if (j.patched > 12) _paintText(canvas, 'MORE THAN THE WHOLE SAIL', Offset(size.width - 8, 9), 10.5, _bad, align: TextAlign.right);
  }

  @override
  bool shouldRepaint(_TrayPainter old) => true;
}

// ---- lamp angles ----------------------------------------------------------

Widget _lampBody(EmberLogic g, LampJob j, VoidCallback refresh) {
  Widget step(String label, int d) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _stepBtn(label, () {
            g.lampAdjust(d);
            refresh();
          }),
        ),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Center(child: SizedBox(width: 230, height: 230, child: CustomPaint(painter: _DialPainter(j)))),
    const SizedBox(height: 6),
    Text('Beam sweep: ${j.sweep} degrees', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFE082), fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 21)),
    const SizedBox(height: 6),
    Row(children: <Widget>[step('-15', -15), step('-5', -5), step('+5', 5), step('+15', 15)]),
  ]);
}

class _DialPainter extends CustomPainter {
  final LampJob j;
  _DialPainter(this.j);

  static double _rad(num bearing) => (bearing - 90) * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double R = min(size.width, size.height) / 2 - 14;
    final Paint p = Paint();
    p.color = const Color(0xFF071826);
    canvas.drawCircle(c, R + 10, p);
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF9C7A45);
    canvas.drawCircle(c, R + 10, s);
    // ticks and bearing numbers
    for (int b = 0; b < 360; b += 10) {
      final bool major = b % 30 == 0;
      final double a = _rad(b);
      final double r0 = R + (major ? 0 : 4);
      s.strokeWidth = major ? 1.6 : 1;
      s.color = Colors.white.withValues(alpha: major ? 0.6 : 0.3);
      canvas.drawLine(c + Offset(cos(a), sin(a)) * r0, c + Offset(cos(a), sin(a)) * (R + 9), s);
      if (major) {
        final String t = b == 0 ? 'N' : b.toString().padLeft(3, '0');
        _paintText(canvas, t, c + Offset(cos(a), sin(a)) * (R - 11), 10, b == 0 ? const Color(0xFFFF8A80) : Colors.white70);
      }
    }
    final Rect arcR = Rect.fromCircle(center: c, radius: R * 0.74);
    // given sectors
    for (final LampSector sec in j.given) {
      p.color = const Color(0xFF4DD0E1).withValues(alpha: 0.26);
      canvas.drawArc(arcR, _rad(sec.start), sec.sweep * pi / 180, true, p);
      s.strokeWidth = 1.4;
      s.color = const Color(0xFF4DD0E1).withValues(alpha: 0.9);
      canvas.drawArc(arcR, _rad(sec.start), sec.sweep * pi / 180, true, s);
      final double mid = _rad(sec.start + sec.sweep / 2);
      _paintText(canvas, '${sec.sweep}°', c + Offset(cos(mid), sin(mid)) * (R * 0.5), 12, const Color(0xFFB2EBF2));
    }
    // guide rays (a shore line)
    for (final int b in j.guides) {
      final double a = _rad(b);
      s.strokeWidth = 2.4;
      s.color = Colors.white.withValues(alpha: 0.75);
      canvas.drawLine(c, c + Offset(cos(a), sin(a)) * (R + 2), s);
    }
    // the beam
    final double base = _rad(j.baseBearing);
    final double sw = j.sweep * pi / 180;
    if (j.sweep > 0) {
      final Paint beam = Paint()
        ..shader = const RadialGradient(colors: <Color>[Color(0xCCFFE082), Color(0x44FFE082)]).createShader(arcR);
      canvas.drawArc(arcR, base, sw, true, beam);
      s.strokeWidth = 2;
      s.color = const Color(0xFFFFE082);
      canvas.drawArc(arcR, base, sw, true, s);
      final double mid = base + sw / 2;
      if (j.sweep >= 20) {
        _paintText(canvas, '${j.sweep}°', c + Offset(cos(mid), sin(mid)) * (R * 0.42), 15, const Color(0xFF3A2A00));
      }
    }
    s.strokeWidth = 3;
    s.color = const Color(0xFFFFB74D);
    canvas.drawLine(c, c + Offset(cos(base), sin(base)) * (R * 0.9), s);
    // the lighthouse
    p.color = const Color(0xFFEDE6D6);
    canvas.drawCircle(c, 9, p);
    p.color = const Color(0xFFD9534F);
    canvas.drawCircle(c, 4.5, p);
  }

  @override
  bool shouldRepaint(_DialPainter old) => true;
}

// ---- barter ---------------------------------------------------------------

Widget _barterBody(EmberLogic g, BarterJob j, Color kc, VoidCallback refresh) {
  Widget key(String label, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: _stepBtn(label, onTap),
        ),
      );
  Widget row(List<String> keys) => Row(children: <Widget>[
        for (final String k in keys)
          key(k, () {
            g.barterKey(k);
            refresh();
          }),
      ]);
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Row(children: <Widget>[
      for (int i = 0; i < 3; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                g.barterPick(i);
                refresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: j.picked == i ? kc.withValues(alpha: 0.22) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: j.picked == i ? kc : Colors.white24, width: j.picked == i ? 2 : 1),
                ),
                child: Column(children: <Widget>[
                  Text('STALL ${BarterJob.stallNames[i]}', style: TextStyle(color: j.picked == i ? kc : Colors.white60, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('Pack of ${j.packSize[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('${j.packPrice[i]} naira', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)),
                ]),
              ),
            ),
          ),
        ),
    ]),
    const SizedBox(height: 10),
    _note('Total for ${j.need} units at the best price:', color: Colors.white, size: 13.5, align: TextAlign.center),
    const SizedBox(height: 4),
    Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Text(j.entry.isEmpty ? '0 naira' : '${j.entry} naira', style: TextStyle(color: j.entry.isEmpty ? Colors.white38 : Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24)),
    ),
    const SizedBox(height: 4),
    row(const <String>['1', '2', '3', '4', '5']),
    row(const <String>['6', '7', '8', '9', '0']),
    row(const <String>['DEL', 'CLR']),
  ]);
}

// ---- harbour master -------------------------------------------------------

Widget _masterPanel(EmberLogic g, VoidCallback refresh) {
  final q = g.masterQ;
  if (q == null) return const SizedBox.shrink();
  final bool answered = g.masterChosen != null;
  final bool ok = answered && g.masterChosen == q.answerIndex;
  return Positioned.fill(
    child: Stack(children: <Widget>[
      _barrier(),
      _centered(RealmQuestionPanel(
        question: q,
        accent: _accent,
        header: 'Harbour master - bonus question',
        chosen: g.masterChosen,
        resultLine: ok ? 'Correct. +40 points.' : 'Not this time. The right answer is shown in green.',
        onPick: (int i) {
          g.masterPick(i);
          refresh();
        },
        onContinue: () {
          g.masterDone();
          refresh();
        },
        continueLabel: 'BACK TO THE HARBOUR',
      )),
    ]),
  );
}

// ---- boss: the Night Tide -------------------------------------------------

Widget _bossIntro(EmberLogic g, VoidCallback refresh) {
  return _card(_accent, <Widget>[
    const Icon(Icons.waves_rounded, color: _accent, size: 46),
    _heading('THE NIGHT TIDE', size: 28, color: _accent),
    const SizedBox(height: 8),
    _note('All five beacons burn, but the tide is rising. Six tide events will hit the harbour, some raising the water and some lowering it.', align: TextAlign.center),
    const SizedBox(height: 8),
    _note('For each event, choose a counter-move. Add (positive) or remove (negative) ballast so that the water ends exactly on the safe mark.', align: TextAlign.center),
    const SizedBox(height: 8),
    _note('Watch the gauge. You may undo before you check.', color: Colors.white54, align: TextAlign.center, size: 12.5),
    const SizedBox(height: 14),
    _btn('FACE THE TIDE', () {
      g.bossStart();
      refresh();
    }),
  ]);
}

Widget _bossPanel(EmberLogic g, VoidCallback refresh) {
  final TideBoss? b = g.boss;
  if (b == null) return const SizedBox.shrink();
  final bool working = g.bossStage == 0;
  final int step = b.step;
  final List<Widget> kids = <Widget>[
    Row(children: <Widget>[
      const Icon(Icons.waves_rounded, color: _accent, size: 26),
      const SizedBox(width: 8),
      Expanded(child: Text('NIGHT TIDE', style: const TextStyle(color: _accent, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 1))),
      Text(g.bossStage == 2 ? 'DONE' : 'TRY ${g.bossAttempts + 1} OF 2', style: const TextStyle(color: Colors.white38, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12)),
    ]),
    const SizedBox(height: 8),
    SizedBox(
      height: 92,
      child: CustomPaint(painter: _TidePainter(level: b.level, safe: b.safe, ghost: (working && !b.complete) ? b.level + b.events[step] : null, trail: <int>[for (int i = 0; i <= b.picks.length; i++) b.levelAfter(i)])),
    ),
    const SizedBox(height: 6),
    Row(children: <Widget>[
      for (int i = 0; i < b.events.length; i++)
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _eventChip(b, i, step, working))),
    ]),
    const SizedBox(height: 8),
  ];
  if (g.bossStage == 2) {
    kids.add(_heading(g.bossWon ? 'TIDE CLEARED' : 'THE TIDE PASSES', size: 24, color: g.bossWon ? _good : _ember));
    kids.add(const SizedBox(height: 4));
    kids.add(_note(g.bossWon ? 'The water rests on the safe mark of ${emberSigned(b.safe)}. The archipelago is safe for the night.' : g.bossFeedback, align: TextAlign.center, color: g.bossWon ? Colors.white : _ember));
    kids.add(const SizedBox(height: 12));
    kids.add(_btn('FINISH', () {
      g.bossFinish();
      refresh();
    }, color: g.bossWon ? _good : _ember));
    return _card(g.bossWon ? _good : _ember, kids);
  }
  if (!b.complete) {
    kids.add(_note('Event ${step + 1} of ${b.events.length}: the tide changes by ${emberSigned(b.events[step])}. Water is at ${emberSigned(b.level)} now. Choose your counter-move:', color: Colors.white, size: 13.5));
    kids.add(const SizedBox(height: 8));
    kids.add(Row(children: <Widget>[
      for (int o = 0; o < 3; o++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _counterButton(b.options[step][o], working
                ? () {
                    g.bossPick(o);
                    refresh();
                  }
                : null),
          ),
        ),
    ]));
  } else {
    kids.add(_note('All six moves are chosen. The water would end at ${emberSigned(b.level)}. The safe mark is ${emberSigned(b.safe)}.', color: b.level == b.safe ? _good : Colors.white, size: 14, align: TextAlign.center));
    if (g.bossStage == 1) kids.add(_feedback(g.bossFeedback, _bad));
    kids.add(const SizedBox(height: 10));
    if (g.bossStage == 1) {
      kids.add(_btn('TRY AGAIN', () {
        g.bossRetry();
        refresh();
      }));
    } else {
      kids.add(_btn('CHECK THE TIDE', () {
        g.bossSubmit();
        refresh();
      }));
    }
  }
  if (working && b.picks.isNotEmpty) {
    kids.add(const SizedBox(height: 8));
    kids.add(_btn('UNDO LAST MOVE', () {
      g.bossUndo();
      refresh();
    }, color: Colors.white12, text: Colors.white));
  }
  return _card(_accent, kids);
}

Widget _counterButton(int v, VoidCallback? onTap) {
  final Color c = v > 0 ? const Color(0xFF4DD0E1) : const Color(0xFFFFB74D);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14), border: Border.all(color: c, width: 1.6)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Text(emberSigned(v), style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24)),
        Text(v > 0 ? 'Add $v ballast' : 'Remove ${-v} ballast', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

Widget _eventChip(TideBoss b, int i, int step, bool working) {
  final bool done = i < b.picks.length;
  final bool current = working && i == step && !b.complete;
  final int e = b.events[i];
  final Color c = e > 0 ? const Color(0xFF4DD0E1) : const Color(0xFFFFB74D);
  return Container(
    height: 58,
    decoration: BoxDecoration(
      color: current ? c.withValues(alpha: 0.22) : Colors.white10,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: current ? c : (done ? Colors.white38 : Colors.white12), width: current ? 2 : 1),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Text('EVENT ${i + 1}', style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.w800)),
      Text(emberSigned(e), style: TextStyle(color: done || current ? c : Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 19)),
      Text(done ? 'then ${emberSigned(b.options[i][b.picks[i]])}' : '...', style: TextStyle(color: done ? Colors.white70 : Colors.white24, fontSize: 10.5, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _TidePainter extends CustomPainter {
  final int level;
  final int safe;
  final int? ghost;
  final List<int> trail;
  _TidePainter({required this.level, required this.safe, required this.ghost, required this.trail});

  static const int lo = -15;
  static const int hi = 15;

  double _x(num v, double w) => 10 + (v.clamp(lo, hi).toDouble() - lo) / (hi - lo) * (w - 20);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    const double barTop = 30;
    const double barH = 22;
    final Paint p = Paint();
    final RRect bar = RRect.fromRectAndRadius(Rect.fromLTWH(10, barTop, w - 20, barH), const Radius.circular(8));
    p.color = Colors.white10;
    canvas.drawRRect(bar, p);
    // water from zero to the current level
    final double x0 = _x(0, w);
    final double x1 = _x(level, w);
    p.color = const Color(0xFF4DD0E1).withValues(alpha: 0.55);
    canvas.save();
    canvas.clipRRect(bar);
    canvas.drawRect(Rect.fromLTRB(min(x0, x1), barTop, max(x0, x1), barTop + barH), p);
    canvas.restore();
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white38;
    canvas.drawRRect(bar, s);
    for (int v = lo; v <= hi; v += 5) {
      final double x = _x(v, w);
      s.strokeWidth = v == 0 ? 2 : 1;
      s.color = Colors.white.withValues(alpha: v == 0 ? 0.8 : 0.35);
      canvas.drawLine(Offset(x, barTop + barH), Offset(x, barTop + barH + 5), s);
      _paintText(canvas, v > 0 ? '+$v' : '$v', Offset(x, barTop + barH + 13), 10.5, v < 0 ? const Color(0xFFFF9E80) : (v > 0 ? const Color(0xFF9AF0FF) : Colors.white));
    }
    // trail of earlier levels
    p.color = Colors.white.withValues(alpha: 0.4);
    for (final int t in trail) {
      canvas.drawCircle(Offset(_x(t, w), barTop + barH / 2), 2.4, p);
    }
    // the safe mark
    final double sx = _x(safe, w);
    final Path tri = Path()
      ..moveTo(sx, barTop - 2)
      ..lineTo(sx - 7, barTop - 12)
      ..lineTo(sx + 7, barTop - 12)
      ..close();
    p.color = _good;
    canvas.drawPath(tri, p);
    s.strokeWidth = 2;
    s.color = _good;
    canvas.drawLine(Offset(sx, barTop), Offset(sx, barTop + barH), s);
    _paintText(canvas, 'SAFE ${emberSigned(safe)}', Offset(sx, 7), 11.5, _good);
    // ghost (after the event, before the counter-move)
    final int? gh = ghost;
    if (gh != null) {
      final double gx = _x(gh, w);
      s.strokeWidth = 2;
      s.color = _ember;
      canvas.drawCircle(Offset(gx, barTop + barH / 2), 8, s);
      _paintText(canvas, 'after event ${emberSigned(gh)}', Offset(gx, barTop + barH + 30), 10.5, _ember);
    }
    // the level marker
    final double lx = _x(level, w);
    p.color = const Color(0xFFE0F7FA);
    canvas.drawCircle(Offset(lx, barTop + barH / 2), 7, p);
    p.color = _accent;
    canvas.drawCircle(Offset(lx, barTop + barH / 2), 4.5, p);
  }

  @override
  bool shouldRepaint(_TidePainter old) => true;
}
