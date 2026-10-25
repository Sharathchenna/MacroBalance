import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_weight_input.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// Step: where the user wants to land (lose or gain only), with the plan's
/// projection at the recommended pace under it.
class GoalWeightPage extends StatefulWidget {
  final String goal;
  final double currentWeightKg;
  final double goalWeightKg;
  final double minKg;
  final double maxKg;
  final bool isMetricWeight;
  final ValueChanged<double> onGoalWeightChanged;

  /// About how many weeks to the goal at the recommended pace; null hides it.
  final int? weeks;
  final DateTime? projectedDate;

  const GoalWeightPage({
    super.key,
    required this.goal,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.minKg,
    required this.maxKg,
    required this.isMetricWeight,
    required this.onGoalWeightChanged,
    this.weeks,
    this.projectedDate,
  });

  @override
  State<GoalWeightPage> createState() => _GoalWeightPageState();
}

class _GoalWeightPageState extends State<GoalWeightPage> {
  Timer? _glide;
  bool _glided = false;

  @override
  void initState() {
    super.initState();
    // The ruler starts at today's weight and glides to the goal once.
    _glide = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _glided = true);
    });
  }

  @override
  void dispose() {
    _glide?.cancel();
    super.dispose();
  }

  bool get _gain => widget.goal == MacroCalculatorService.GOAL_GAIN;

  String _weight(double kg) => widget.isMetricWeight
      ? '${kg.toStringAsFixed(1)} kg'
      : '${(kg * 2.20462).toStringAsFixed(1)} lb';

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    final diffKg = (widget.currentWeightKg - widget.goalWeightKg).abs();
    final date = widget.projectedDate;
    final weeks = widget.weeks;
    return ObPageBody(
      children: [
        const ObHeader(eyebrow: 'Your goal', title: 'Where do you want to land?'),
        const SizedBox(height: 20),
        ObRise(
          index: 2,
          child: ObWeightInput(
            valueKg: widget.goalWeightKg,
            rulerValueKg: _glided || reduce ? null : widget.currentWeightKg,
            minKg: widget.minKg,
            maxKg: widget.maxKg,
            isMetric: widget.isMetricWeight,
            onChanged: widget.onGoalWeightChanged,
            fontSize: 64,
            numberWidth: 170,
            unitWidth: 100,
            unitSize: 20,
            rulerHeight: 64,
            gap: 12,
            label: 'Goal weight',
          ),
        ),
        const SizedBox(height: 6),
        ObRise(
          index: 2,
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'That’s '),
              TextSpan(
                  text: _weight(diffKg),
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
              const TextSpan(text: ' from where you are today.'),
            ]),
            textAlign: TextAlign.center,
            style: ObText.body(c.text2),
          ),
        ),
        const SizedBox(height: 18),
        ObRise(
          index: 3,
          child: ObCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stat(c, 'Today', _weight(widget.currentWeightKg), c.text, CrossAxisAlignment.start),
                    _stat(
                      c,
                      date == null ? 'Goal' : 'Goal · ${DateFormat('MMM d').format(date)}',
                      _weight(widget.goalWeightKg),
                      c.leafText,
                      CrossAxisAlignment.end,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Weight trending ${_gain ? 'up' : 'down'} to your goal',
                  child: SizedBox(
                    height: 72,
                    width: double.infinity,
                    child: _ProjectionCurve(rising: _gain),
                  ),
                ),
                if (weeks != null) ...[
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'About '),
                      TextSpan(
                          text: '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
                          style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                      const TextSpan(
                          text: ' at a steady pace. You’ll pick your pace next.'),
                    ]),
                    style: ObText.body(c.text2, size: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(ObColors c, String label, String value, Color color, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: ObText.body(c.text2, size: 12)),
        const SizedBox(height: 2),
        Text(value, style: ObText.title(color, size: 15)),
      ],
    );
  }
}

/// The curve from today to the goal: draws in after half a second, then the
/// goal dot pops.
class _ProjectionCurve extends StatefulWidget {
  const _ProjectionCurve({required this.rising});

  final bool rising;

  @override
  State<_ProjectionCurve> createState() => _ProjectionCurveState();
}

class _ProjectionCurveState extends State<_ProjectionCurve> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final draw = const Interval(0.2, 0.84, curve: Cubic(.4, 0, .2, 1)).transform(_c.value);
        final land = const Interval(0.8, 1, curve: Curves.easeOutBack).transform(_c.value);
        return CustomPaint(
          painter: _CurvePainter(
            rising: widget.rising,
            draw: draw,
            land: land,
            line: c.leaf,
            start: c.text,
            guide: c.line,
          ),
        );
      },
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.rising,
    required this.draw,
    required this.land,
    required this.line,
    required this.start,
    required this.guide,
  });

  final bool rising;
  final double draw;
  final double land;
  final Color line;
  final Color start;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on the mock's 310x72 grid and stretched to the card's width.
    final sx = size.width / 310;
    Offset p(double x, double y) => Offset(x * sx, y);
    final from = rising ? p(8, 62) : p(8, 10);
    final to = rising ? p(300, 10) : p(300, 62);
    final goalY = to.dy;

    // Dashed guide at the goal level.
    final guidePaint = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, goalY), Offset((x + 4).clamp(0, size.width), goalY), guidePaint);
    }

    final path = Path()..moveTo(from.dx, from.dy);
    if (rising) {
      path.cubicTo(p(100, 46).dx, 46, p(190, 18).dx, 18, to.dx, to.dy);
    } else {
      path.cubicTo(p(100, 26).dx, 26, p(190, 54).dx, 54, to.dx, to.dy);
    }
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * draw), paint);
    }

    canvas.drawCircle(from, 5, Paint()..color = start);
    if (land > 0) {
      canvas.drawCircle(to, 6 * land.clamp(0, 1.3), Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.draw != draw || old.land != land || old.rising != rising || old.line != line;
}
