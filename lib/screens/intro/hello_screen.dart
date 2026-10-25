import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:macrotracker/screens/intro/intro_clock.dart';
import 'package:macrotracker/screens/intro/story_screen.dart';
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/brand/mb_logo.dart';

/// First launch screen (mock: Main): a day's cals ring that food chips fill,
/// then "Build my plan" or sign in.
class HelloScreen extends StatefulWidget {
  const HelloScreen({super.key});

  @override
  State<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends State<HelloScreen> {
  @override
  void initState() {
    super.initState();
    PostHogService.trackScreen('welcome_screen');
  }

  void _build() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoryScreen()));
  }

  void _login() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    final compact = MediaQuery.of(context).size.height < 700;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ObRise(child: _Brand()),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: compact ? 250 : 316,
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 300,
                            height: 316,
                            child: IntroClock(
                              animate: !still,
                              builder: (context, s) =>
                                  _RingScene(seconds: s, still: still),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ObRise(
                        index: 2,
                        child: Text.rich(
                          TextSpan(
                            text: 'Eat like you normally do.\n',
                            children: [
                              TextSpan(
                                text: 'We’ll do the math.',
                                style: TextStyle(color: c.leafText),
                              ),
                            ],
                          ),
                          style: ObText.display(38, color: c.text, height: 1.08)
                              .copyWith(letterSpacing: -1.4),
                        ),
                      ),
                      ObRise(
                        index: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            'Take a photo of your plate and it’s logged. Every week, your target adjusts to how your body is actually responding.',
                            style: ObText.body(c.text2, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ObRise(
                index: 6,
                child: ObPrimaryButton(
                  label: 'Build my plan',
                  icon: Icon(Icons.arrow_forward_rounded, size: 20, color: c.onLeaf),
                  onPressed: _build,
                ),
              ),
              ObRise(
                index: 8,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ObTextButton(
                    label: 'I already have an account',
                    color: c.text,
                    onPressed: _login,
                  ),
                ),
              ),
              ObRise(
                index: 8,
                child: Text(
                  'About 2 minutes · No account needed yet',
                  textAlign: TextAlign.center,
                  style: ObText.body(c.muted, size: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MbLogoTile(size: 32, background: c.raised),
        const SizedBox(width: 10),
        Text('MacroBalance',
            style: ObText.title(c.text).copyWith(letterSpacing: -0.3)),
      ],
    );
  }
}

const _loop = 7.0;

/// One chip of the loop: where it starts and when, from the mock's
/// `.chip.a/b/c` rules.
class _Chip {
  const _Chip(this.name, this.cals, this.dx, this.dy, this.delay, this.dot);
  final String name;
  final int cals;
  final double dx, dy, delay;
  final Color Function(ObColors) dot;
}

final _chips = <_Chip>[
  _Chip('Greek yogurt', 210, -104, -128, .6, (c) => c.protein),
  _Chip('Salmon bowl', 640, 110, -104, 1.8, (c) => c.carbs),
  _Chip('Oat latte', 120, -100, 128, 3.0, (c) => c.fat),
];

/// Phase 0..1 of a looping animation that started [delay] seconds in, or
/// null before it has started.
double? _phase(double s, double delay) {
  if (s < delay) return null;
  return ((s - delay) % _loop) / _loop;
}

class _RingScene extends StatelessWidget {
  const _RingScene({required this.seconds, required this.still});

  final double seconds;
  final bool still;

  /// "Cals left" steps down as each chip lands (mock `@keyframes left`).
  static double _left(double p) {
    const e = Cubic(.4, 0, .2, 1);
    double lerp(double a, double b, double t) => a + (b - a) * e.transform(t);
    if (p < .357) return 2234;
    if (p < .414) return lerp(2234, 2024, seg(p, .357, .414));
    if (p < .529) return 2024;
    if (p < .586) return lerp(2024, 1384, seg(p, .529, .586));
    if (p < .70) return 1384;
    if (p < .757) return lerp(1384, 1264, seg(p, .70, .757));
    if (p < .943) return 1264;
    return lerp(1264, 2234, seg(p, .943, 1));
  }

  /// Green flash on each change (mock `@keyframes tick`).
  static double _flash(double p) {
    double tri(double a, double peak, double b) {
      if (p <= a || p >= b) return 0;
      return p < peak ? (p - a) / (peak - a) : (b - p) / (b - peak);
    }

    return math.max(tri(.357, .385, .529),
        math.max(tri(.529, .557, .70), tri(.70, .728, .943)));
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final p = (seconds % _loop) / _loop;
    final left = still ? 1264.0 : _left(p);
    final text = Color.lerp(c.text, c.leaf, still ? 0 : _flash(p))!;
    final breathe = still ? 1.0 : 1 + 0.025 * (0.5 - 0.5 * math.cos(2 * math.pi * p));
    final n = left.round();
    final label = '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: breathe,
          child: CustomPaint(
            size: const Size(248, 248),
            painter: _RingPainter(c, seconds, still),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: '$label cals left today',
              excludeSemantics: true,
              child: Text(
                label,
                style: ObText.display(44, color: text, height: 1).copyWith(
                  letterSpacing: -1.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('cals left today',
                style: ObText.body(c.text2, size: 14, weight: FontWeight.w500)),
          ],
        ),
        if (!still)
          for (final chip in _chips) _chipAt(c, chip),
      ],
    );
  }

  Widget _chipAt(ObColors c, _Chip chip) {
    final p = _phase(seconds, chip.delay);
    if (p == null) return const SizedBox.shrink();
    const e = Cubic(.5, 0, .2, 1);
    double opacity;
    double scale;
    double travel; // 0 at the start offset, 1 at the ring's centre
    if (p < .10) {
      final t = e.transform(p / .10);
      opacity = t;
      scale = .9 + .1 * t;
      travel = 0;
    } else if (p < .18) {
      opacity = 1;
      scale = 1;
      travel = 0;
    } else if (p < .30) {
      final t = e.transform((p - .18) / .12);
      opacity = 1 - t;
      scale = 1 - .6 * t;
      travel = t;
    } else {
      return const SizedBox.shrink();
    }
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(chip.dx * (1 - travel), chip.dy * (1 - travel)),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 164,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: chip.dot(c), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(chip.name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: ObText.body(c.text, size: 13, weight: FontWeight.w500)
                          .copyWith(height: 1)),
                ),
                Text('${chip.cals}',
                    style: ObText.body(c.text2, size: 13, weight: FontWeight.w500)
                        .copyWith(height: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.c, this.seconds, this.still);

  final ObColors c;
  final double seconds;
  final bool still;

  /// start angle (degrees from the top), arc length (px on the r=100
  /// ring), delay, colour.
  List<(double, double, double, Color)> get _arcs => [
        (0, 150, .9, c.protein),
        (92, 210, 2.1, c.carbs),
        (218, 84, 3.3, c.fat),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const r = 100.0;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = c.raised,
    );
    for (final (start, len, delay, color) in _arcs) {
      var grown = len;
      var opacity = 1.0;
      if (!still) {
        final p = _phase(seconds, delay);
        if (p == null) continue;
        grown = len * seg(p, 0, .18, const Cubic(.3, .7, .2, 1));
        opacity = 1 - seg(p, .82, 1);
      }
      if (grown <= 0 || opacity <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: opacity);
      canvas.drawArc(rect, (start - 90) * math.pi / 180, grown / r, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.seconds != seconds || old.c != c;
}
