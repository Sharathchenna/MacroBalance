import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:macrotracker/screens/intro/intro_clock.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// The two intro stories (mock: StorySnap, StoryLearn). Each auto-advances
/// after 6 seconds; tap or Continue goes on, Skip jumps to the quiz.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, this.next});

  /// Where the stories end. Defaults to the quiz; tests swap it.
  final WidgetBuilder? next;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  static const _storyTime = Duration(seconds: 6);

  late final AnimationController _bar =
      AnimationController(vsync: this, duration: _storyTime)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _advance();
        })
        ..forward();
  int _index = 0;
  bool _leaving = false;

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _advance() {
    if (_leaving || !mounted) return;
    if (_index == 0) {
      setState(() => _index = 1);
      _bar.forward(from: 0);
    } else {
      _finish();
    }
  }

  /// Opens the quiz on top, so Back from its first step returns here.
  Future<void> _finish() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _bar.stop();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: widget.next ?? (_) => const OnboardingScreen()),
    );
    if (!mounted) return;
    _leaving = false;
    _bar.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 0; i < 2; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(child: _Segment(index: i, current: _index, bar: _bar)),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: c.text2,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text('Skip',
                            style: ObText.body(c.text2, weight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: still ? Duration.zero : const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: SingleChildScrollView(
                        child: _index == 0
                            ? _SnapStory(still: still)
                            : _LearnStory(still: still),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ObRise(
                  index: 3,
                  child: ObPrimaryButton(
                    label: _index == 0 ? 'Continue' : 'Build my plan',
                    onPressed: _advance,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One progress bar: full when passed, filling while current.
class _Segment extends StatelessWidget {
  const _Segment({required this.index, required this.current, required this.bar});

  final int index, current;
  final Animation<double> bar;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      height: 4,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
      alignment: Alignment.centerLeft,
      child: index < current
          ? Container(color: c.text)
          : index > current
              ? null
              : AnimatedBuilder(
                  animation: bar,
                  builder: (context, _) => FractionallySizedBox(
                    widthFactor: bar.value,
                    child: Container(color: c.text),
                  ),
                ),
    );
  }
}

/// Two-line headline with the second line in green.
class _Headline extends StatelessWidget {
  const _Headline(this.first, this.second, {required this.size});

  final String first, second;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Text.rich(
      TextSpan(
        text: '$first\n',
        children: [TextSpan(text: second, style: TextStyle(color: c.leafText))],
      ),
      style: ObText.display(size, color: c.text, height: 1.1).copyWith(letterSpacing: -1.2),
    );
  }
}

// ---------------------------------------------------------------- story 1

const _snapLoop = 6.0;

class _Food {
  const _Food(this.n, this.name, this.amount, this.cals, this.start, this.skelWidth);
  final int n;
  final String name, amount;
  final int cals;

  /// Where in the loop (0..1) this food's marker lands.
  final double start;
  final double skelWidth;
}

const _foods = [
  _Food(1, 'Salmon fillet', '120 g', 312, .41, 140),
  _Food(2, 'White rice', '1 cup', 206, .45, 120),
  _Food(3, 'Avocado', '½ fruit', 120, .49, 104),
];

/// Marker positions on the plate, in the plate drawing's own coordinates.
const _markerAt = [Offset(177, 126), Offset(122, 180), Offset(194, 178)];

const _pop = Cubic(.2, .9, .3, 1.4);

class _SnapStory extends StatelessWidget {
  const _SnapStory({required this.still});

  final bool still;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return IntroClock(
      animate: !still,
      builder: (context, s) {
        // At rest (reduced motion) everything shows, fully read.
        final p = still ? .7 : (s % _snapLoop) / _snapLoop;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            _Scene(p: p, still: still),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(22)),
              child: Column(
                children: [
                  for (var i = 0; i < _foods.length; i++)
                    _FoodRow(food: _foods[i], p: p, seconds: s, last: i == _foods.length - 1),
                  const SizedBox(height: 8),
                  _Total(p: p, seconds: s),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ObRise(
              index: 2,
              child: const _Headline('Snap it, scan it,', 'or just say it.', size: 32),
            ),
            ObRise(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 12),
                child: Text(
                  'Photograph your plate, scan a barcode, or type “burrito bowl, no rice”. Each food is logged on its own, so you can fix any amount.',
                  style: ObText.body(c.text2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({required this.p, required this.still});

  final double p;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      label: 'A plate of salmon, rice and avocado being scanned',
      child: Container(
        height: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(28)),
        child: LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, 220);
          final map = _PlateMap(size);
          final scan = still ? 0.0 : seg(p, 0, .06) * (1 - seg(p, .36, .40));
          final scanY = 196 * seg(p, 0, .36, const Cubic(.45, 0, .55, 1));
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PlatePainter(c, map))),
              Positioned.fill(child: CustomPaint(painter: _ScanPainter(c, scan, scanY))),
              for (var i = 0; i < _foods.length; i++) _marker(c, i, map),
            ],
          );
        }),
      ),
    );
  }

  Widget _marker(ObColors c, int i, _PlateMap map) {
    final start = _foods[i].start;
    final appear = seg(p, start, start + .04, _pop);
    final linear = seg(p, start, start + .04);
    final opacity = linear * (1 - seg(p, .92, .97));
    final at = map.toCard(_markerAt[i]);
    return Positioned(
      left: at.dx - 13,
      top: at.dy - 13,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: .3 + .7 * appear,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.leaf,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.bg.withValues(alpha: .55), spreadRadius: 4)],
            ),
            child: Text('${_foods[i].n}',
                style: ObText.body(c.onLeaf, size: 13, weight: FontWeight.w700).copyWith(height: 1)),
          ),
        ),
      ),
    );
  }
}

/// Maps the plate drawing (an SVG viewBox of 20 50 260 210, "slice" fit)
/// onto the card.
class _PlateMap {
  _PlateMap(Size size)
      : k = math.max(size.width / 260, size.height / 210),
        tx = (size.width - 260 * math.max(size.width / 260, size.height / 210)) / 2,
        ty = (size.height - 210 * math.max(size.width / 260, size.height / 210)) / 2;

  final double k, tx, ty;

  Offset toCard(Offset svg) => Offset(tx + (svg.dx - 20) * k, ty + (svg.dy - 50) * k);
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.c, this.map);

  final ObColors c;
  final _PlateMap map;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(map.tx, map.ty);
    canvas.scale(map.k);
    canvas.translate(-20, -50);
    Paint f(Color col) => Paint()..color = col;
    canvas.drawCircle(const Offset(150, 156), 104, f(c.raised));
    canvas.drawCircle(const Offset(150, 156), 88, f(c.isDark ? const Color(0xFF232925) : Colors.white));

    final rice = f(const Color(0xFFEDEAE0));
    for (final (x, y, r) in [(118.0, 182.0, 22.0), (140.0, 196.0, 20.0), (104.0, 160.0, 16.0), (128.0, 166.0, 18.0)]) {
      canvas.drawCircle(Offset(x, y), r, rice);
    }

    void rotated(Offset pivot, double deg, VoidCallback draw) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(deg * math.pi / 180);
      canvas.translate(-pivot.dx, -pivot.dy);
      draw();
      canvas.restore();
    }

    rotated(const Offset(177, 126), -12, () {
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(138, 104, 78, 44), const Radius.circular(14)),
          f(const Color(0xFFFF8A6B)));
    });
    rotated(const Offset(177, 126), -2, () {
      final stripe = Paint()
        ..color = const Color(0xFFFFC1AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(150, 110), const Offset(200, 100), stripe);
      canvas.drawLine(const Offset(152, 122), const Offset(204, 111), stripe);
      canvas.drawLine(const Offset(154, 134), const Offset(206, 123), stripe);
    });

    void oval(double cx, double cy, double rx, double ry, double deg, Color col) {
      rotated(Offset(cx, cy), deg, () {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), f(col));
      });
    }

    oval(188, 186, 20, 11, 30, const Color(0xFF7FCF6A));
    oval(198, 168, 20, 11, 14, const Color(0xFF7FCF6A));
    oval(190, 186, 10, 5, 30, const Color(0xFFC9E7A8));
    oval(199, 168, 10, 5, 14, const Color(0xFFC9E7A8));

    final seed = f(const Color(0xFFF4F6F4));
    for (final o in const [Offset(164, 210), Offset(174, 204), Offset(158, 200)]) {
      canvas.drawCircle(o, 2.5, seed);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.c != c || old.map.k != map.k;
}

/// The viewfinder corners and the sweeping scan line.
class _ScanPainter extends CustomPainter {
  _ScanPainter(this.c, this.opacity, this.y);

  final ObColors c;
  final double opacity, y;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final corner = Paint()
      ..color = c.leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(16, 46)..lineTo(16, 22)..arcToPoint(const Offset(22, 16), radius: const Radius.circular(6))..lineTo(46, 16)
      ..moveTo(w - 46, 16)..lineTo(w - 22, 16)..arcToPoint(Offset(w - 16, 22), radius: const Radius.circular(6))..lineTo(w - 16, 46)
      ..moveTo(w - 16, h - 46)..lineTo(w - 16, h - 22)..arcToPoint(Offset(w - 22, h - 16), radius: const Radius.circular(6))..lineTo(w - 46, h - 16)
      ..moveTo(46, h - 16)..lineTo(22, h - 16)..arcToPoint(Offset(16, h - 22), radius: const Radius.circular(6))..lineTo(16, h - 46);
    canvas.drawPath(path, corner);
    if (opacity <= 0) return;
    canvas.save();
    canvas.translate(0, y);
    canvas.drawRect(Rect.fromLTWH(12, 12, w - 24, 22),
        Paint()..color = c.leaf.withValues(alpha: .08 * opacity));
    canvas.drawRect(Rect.fromLTWH(12, 10, w - 24, 2),
        Paint()..color = c.leaf.withValues(alpha: opacity));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanPainter old) =>
      old.opacity != opacity || old.y != y || old.c != c;
}

/// Shifts a repeating gradient sideways to make the shimmer.
class _Slide extends GradientTransform {
  const _Slide(this.fraction);
  final double fraction;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

class _Bar extends StatelessWidget {
  const _Bar(this.width, this.seconds, {this.height = 10, this.radius = 5});

  final double width, height, radius, seconds;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [c.raised, c.line, c.raised],
          stops: const [0, .5, 1],
          tileMode: TileMode.repeated,
          transform: _Slide(-((seconds / 1.4) % 1)),
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.p, required this.seconds, required this.last});

  final _Food food;
  final double p, seconds;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final a = food.start + .01;
    final shown = seg(p, a, a + .05);
    final real = shown * (1 - seg(p, .92, .97));
    final skel = ((1 - seg(p, a, a + .04)) + seg(p, .95, 1)).clamp(0.0, 1.0);
    return Container(
      height: 41,
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.raised)),
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: real.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(-8 * (1 - shown), 0),
              child: Row(
                children: [
                  _Num(food.n),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: food.name,
                        style: ObText.title(c.text, size: 14),
                        children: [
                          TextSpan(
                              text: ' · ${food.amount}',
                              style: ObText.body(c.muted, size: 13, weight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  Text.rich(TextSpan(
                    text: '${food.cals} ',
                    style: ObText.title(c.text, size: 14),
                    children: [
                      TextSpan(
                          text: 'cals',
                          style: ObText.body(c.text2, size: 12, weight: FontWeight.w500)),
                    ],
                  )),
                ],
              ),
            ),
          ),
          if (skel > 0)
            Opacity(
              opacity: skel,
              child: Row(
                children: [
                  _Bar(22, seconds, height: 22, radius: 11),
                  const SizedBox(width: 12),
                  _Bar(food.skelWidth, seconds),
                  const Spacer(),
                  _Bar(48, seconds),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.leafText, width: 1.5),
      ),
      child: Text('$n',
          style: ObText.body(c.leafText, size: 12, weight: FontWeight.w700).copyWith(height: 1)),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.p, required this.seconds});

  final double p, seconds;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final real = seg(p, .56, .61) * (1 - seg(p, .92, .97));
    final skel = ((1 - seg(p, .56, .60)) + seg(p, .95, 1)).clamp(0.0, 1.0);
    Widget dot(Color col, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(t, style: ObText.body(c.text2, size: 12).copyWith(height: 1.2)),
          ],
        );
    return Stack(
      children: [
        Opacity(
          opacity: real.clamp(0, 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.leaf.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3 foods added to Lunch', style: ObText.title(c.text, size: 14)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        children: [
                          dot(c.protein, 'P 42 g'),
                          dot(c.carbs, 'C 61 g'),
                          dot(c.fat, 'F 24 g'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('638', style: ObText.title(c.leafText, size: 20).copyWith(height: 1.15)),
                    Text('cals in all', style: ObText.body(c.text2, size: 11, weight: FontWeight.w500).copyWith(height: 1.2)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (skel > 0)
          Positioned.fill(
            child: Opacity(
              opacity: skel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.leaf.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bar(150, seconds),
                        const SizedBox(height: 8),
                        _Bar(110, seconds, height: 8, radius: 4),
                      ],
                    ),
                    _Bar(44, seconds, height: 18, radius: 6),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- story 2

const _learnLoop = 6.0;

class _LearnStory extends StatelessWidget {
  const _LearnStory({required this.still});

  final bool still;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return IntroClock(
      animate: !still,
      builder: (context, s) {
        final p = still ? .8 : (s % _learnLoop) / _learnLoop;
        final toast = seg(p, .52, .60, const Cubic(.2, .8, .2, 1)) * (1 - seg(p, .92, 1));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  // Room at the bottom so the check-in card never covers
                  // the week labels.
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 44),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('What you burn a day',
                              style: ObText.body(c.text2, size: 13, weight: FontWeight.w500)),
                          Text('First 4 weeks',
                              style: ObText.body(c.muted, size: 12, weight: FontWeight.w500)),
                        ],
                      ),
                      Semantics(
                        label:
                            'A dashed formula guess stays flat at 2,400 cals while your learned burn settles at 2,550 cals',
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: CustomPaint(painter: _ChartPainter(c, p)),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: -26,
                  child: Opacity(
                    opacity: toast.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - seg(p, .52, .60, const Cubic(.2, .8, .2, 1)))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.raised,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c.leaf.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(Icons.sync_rounded, size: 18, color: c.leafText),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Weekly check-in', style: ObText.title(c.text, size: 14)),
                                  const SizedBox(height: 2),
                                  Text('Target raised to 2,234 cals. Here’s why.',
                                      style: ObText.body(c.text2, size: 12).copyWith(height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 58),
            ObRise(
              index: 2,
              child: const _Headline('Learns what you', 'really burn.', size: 34),
            ),
            ObRise(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: Text(
                  'Most apps give you one number and leave it there. MacroBalance checks in every week and adjusts your target from what you log and how your weight moves.',
                  style: ObText.body(c.text2, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.c, this.p);

  final ObColors c;
  final double p;

  static const _pts = [Offset(76, 112), Offset(152, 92), Offset(230, 76)];
  static const _popStart = [.20, .33, .46];

  void _text(Canvas canvas, String s, TextStyle style, double x, double baseline,
      {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => x - tp.width,
      TextAlign.center => x - tp.width / 2,
      _ => x,
    };
    tp.paint(canvas, Offset(dx, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 306;
    double x(double v) => v * sx;

    final grid = Paint()..color = c.line..strokeWidth = 1;
    for (final y in [40.0, 100.0, 160.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final dash = Paint()
      ..color = c.muted
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var d = 0.0; d < size.width; d += 11) {
      canvas.drawLine(Offset(d, 128), Offset(math.min(d + 5, size.width), 128), dash);
    }
    _text(canvas, 'Formula guess · 2,400',
        ObText.body(c.text2, size: 12, weight: FontWeight.w500), 0, 150);

    final line = Path()
      ..moveTo(0, 128)
      ..cubicTo(30, 126, 48, 104, 76, 112)
      ..cubicTo(104, 120, 120, 80, 152, 92)
      ..cubicTo(184, 104, 200, 70, 230, 76)
      ..cubicTo(260, 82, 280, 72, 306, 72);
    final scaled = line.transform(Matrix4.diagonal3Values(sx, 1, 1).storage);
    final draw = seg(p, 0, .55, const Cubic(.4, 0, .2, 1));
    final fade = 1 - seg(p, .92, 1);
    if (draw > 0 && fade > 0) {
      final metric = scaled.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..color = c.leaf.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < _pts.length; i++) {
      final a = _popStart[i];
      final scale = seg(p, a, a + .05, const Cubic(.2, .9, .3, 1.4));
      final alpha = seg(p, a, a + .05) * fade;
      if (alpha <= 0) continue;
      final o = Offset(x(_pts[i].dx), _pts[i].dy);
      canvas.drawCircle(o, 6 * scale, Paint()..color = c.bg.withValues(alpha: alpha));
      canvas.drawCircle(
        o,
        6 * scale,
        Paint()
          ..color = c.leaf.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * scale,
      );
    }

    _text(canvas, 'Your real burn · 2,550',
        ObText.body(c.leafText, size: 13, weight: FontWeight.w600), size.width, 56,
        align: TextAlign.right);
    final wk = ObText.body(c.muted, size: 11, weight: FontWeight.w500);
    _text(canvas, 'Wk 1', wk, 0, 214);
    _text(canvas, 'Wk 2', wk, x(76), 214, align: TextAlign.center);
    _text(canvas, 'Wk 3', wk, x(152), 214, align: TextAlign.center);
    _text(canvas, 'Wk 4', wk, x(230), 214, align: TextAlign.center);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.p != p || old.c != c;
}
