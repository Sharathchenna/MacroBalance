import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/pages/obstacles_page.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// What we say back to each obstacle, by code.
const _replies = {
  'logging_slow': (
    Icons.photo_camera_outlined,
    'Snap a photo or describe it in a sentence. No more scrolling a database.'
  ),
  'static_target': (
    Icons.autorenew_rounded,
    'A weekly check-in moves it when your body does, and explains every change.'
  ),
  'distrust_numbers': (
    Icons.fact_check_outlined,
    'Your targets come from what you actually burn, and every change comes with its reason.'
  ),
  'weekends': (
    Icons.calendar_today_outlined,
    'Check-ins look at your whole week, so one big Saturday doesn’t derail the plan.'
  ),
  'plateau': (
    Icons.show_chart_rounded,
    'When your burn drops, your target follows, so progress doesn’t stall.'
  ),
  'eating_out': (
    Icons.restaurant_outlined,
    'Photograph the plate or describe the dish. A close estimate beats skipping the log.'
  ),
  'motivation': (
    Icons.local_fire_department_outlined,
    'A plan that keeps up with you makes the next day easy to start.'
  ),
};

/// The reply to the obstacles: why a fixed target turns into a plateau, and
/// one card for each obstacle picked. Saves nothing.
class InsightPage extends StatelessWidget {
  const InsightPage({super.key, required this.goal, required this.obstacles});

  final String goal;
  final Set<String> obstacles;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final gain = goal == MacroCalculatorService.GOAL_GAIN;
    final picked = kObstacleCodes.where(obstacles.contains).toList();
    return ObPageBody(
      children: [
        ObRise(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'You weren’t the problem.\n'),
              TextSpan(text: 'The fixed number was.', style: TextStyle(color: c.leafText)),
            ]),
            style: ObText.h1(c.text),
          ),
        ),
        ObRise(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              switch (goal) {
                MacroCalculatorService.GOAL_GAIN =>
                  'As you gain weight, you burn a little more. A target that never moves turns into a plateau.',
                MacroCalculatorService.GOAL_MAINTAIN =>
                  'What you burn shifts with your weight, steps and season. A target that never moves drifts away from it.',
                _ =>
                  'As you lose weight, you burn a little less. A target that never moves turns into a plateau.',
              },
              style: ObText.body(c.text2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ObRise(index: 2, child: _ChartCard(rising: gain)),
        if (picked.isNotEmpty) ...[
          const SizedBox(height: 18),
          ObRise(
            index: 6,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('BUILT FOR WHAT YOU PICKED', style: ObText.eyebrow(c.text2)),
            ),
          ),
          for (var i = 0; i < picked.length; i++)
            ObRise(
              index: 7 + i,
              child: Padding(
                padding: EdgeInsets.only(bottom: i == picked.length - 1 ? 0 : 10),
                child: _ReplyCard(
                  key: Key('insight_reply_${picked[i]}'),
                  icon: _replies[picked[i]]!.$1,
                  title: kObstacleLabels[picked[i]]!,
                  body: _replies[picked[i]]!.$2,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: c.leaf),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ObText.title(c.text, size: 15)),
                const SizedBox(height: 2),
                Text(body, style: ObText.body(c.text2, size: 14).copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The plateau chart and its legend. Lines draw in, then the gap, arrow and
/// labels fade up. [rising] mirrors it for a gain goal (burn climbs towards
/// a fixed target).
class _ChartCard extends StatefulWidget {
  const _ChartCard({required this.rising});

  final bool rising;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2400);
  late final AnimationController _ctl = AnimationController(vsync: this, duration: _total);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _ctl.value = 1;
    } else {
      _ctl.forward();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// 0..1 progress of a stretch that starts at [startMs] and lasts [ms].
  double _seg(double startMs, double ms, Curve curve) {
    final t = (_ctl.value * _total.inMilliseconds - startMs) / ms;
    return curve.transform(t.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final rising = widget.rising;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Semantics(
            label: rising
                ? 'A fixed target line stays flat while your burn climbs towards it, closing the gap; MacroBalance moves your target up with your burn'
                : 'A fixed target line stays flat while your burn drops, opening a gap; MacroBalance moves your target down with your burn',
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) {
                  final labels = _seg(1600, 600, Curves.linear);
                  return LayoutBuilder(builder: (context, box) {
                    final w = box.maxWidth;
                    final sx = w / 310;
                    final sty =
                        ObText.body(c.text, size: 13, weight: FontWeight.w600).copyWith(height: 1.2);
                    return SizedBox(
                      height: 150,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(w, 150),
                            painter: _PlateauPainter(
                              colors: c,
                              rising: rising,
                              gap: _seg(1400, 800, Curves.linear),
                              line1: _seg(500, 1400, Curves.easeInOutCubic),
                              line2: _seg(1000, 1400, Curves.easeInOutCubic),
                              arrow: labels,
                            ),
                          ),
                          Positioned(
                            left: 10 * sx,
                            top: rising ? 98 : 7,
                            child: Opacity(
                              opacity: labels,
                              child: Text('Fixed target', style: sty),
                            ),
                          ),
                          Positioned(
                            right: 10 * sx,
                            top: rising ? 7 : 98,
                            child: Opacity(
                              opacity: labels,
                              child: Text('What you actually burn',
                                  style: sty.copyWith(color: c.leafText)),
                            ),
                          ),
                          Positioned(
                            left: 10 * sx,
                            bottom: 0,
                            child: Text('Week 1',
                                style: ObText.body(c.muted, size: 12, weight: FontWeight.w500)
                                    .copyWith(height: 1.2)),
                          ),
                          Positioned(
                            right: 10 * sx,
                            bottom: 0,
                            child: Text('Week 16',
                                style: ObText.body(c.muted, size: 12, weight: FontWeight.w500)
                                    .copyWith(height: 1.2)),
                          ),
                        ],
                      ),
                    );
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _ctl,
            builder: (context, child) =>
                Opacity(opacity: _seg(1600, 600, Curves.linear), child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.protein.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.protein.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: 'The plateau gap: ',
                          style: TextStyle(color: c.protein, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: rising
                              ? 'eating to the old target while your burn climbs.'
                              : 'eating to the old target while your burn drops.',
                        ),
                      ]),
                      style: ObText.body(c.text, size: 13).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints in the mock's 310 x 150 box (y offset by 20), stretched across the
/// width. Text is laid out by the parent so it stays crisp.
class _PlateauPainter extends CustomPainter {
  _PlateauPainter({
    required this.colors,
    required this.rising,
    required this.gap,
    required this.line1,
    required this.line2,
    required this.arrow,
  });

  final ObColors colors;
  final bool rising;
  final double gap;
  final double line1;
  final double line2;
  final double arrow;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 310;
    // Mock y (minus the 20 viewBox offset); mirrored for a gain goal.
    double y(double v) => rising ? 122 - (v - 20) : v - 20;
    Offset p(double x, double v) => Offset(x * sx, y(v));

    final start = p(10, 52);
    final end = p(300, 110);
    final burn = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(p(90, 60).dx, p(90, 60).dy, p(180, 92).dx, p(180, 92).dy, end.dx, end.dy);

    final area = Path.from(burn)
      ..lineTo(p(300, 52).dx, p(300, 52).dy)
      ..close();
    canvas.drawPath(area, Paint()..color = colors.protein.withValues(alpha: 0.2 * gap));

    void draw(Path path, double t, Paint paint) {
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * t), paint);
      }
    }

    draw(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(p(300, 52).dx, p(300, 52).dy),
      line1,
      Paint()
        ..color = colors.text2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    draw(
      burn,
      line2,
      Paint()
        ..color = colors.leaf
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    if (arrow > 0) {
      final a = Paint()
        ..color = colors.protein.withValues(alpha: arrow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final x = (310 - 28) * sx;
      final upper = y(rising ? 102 : 56);
      final lower = y(rising ? 56 : 102);
      canvas.drawLine(Offset(x, upper), Offset(x, lower), a);
      final head = Path()
        ..moveTo(x - 5, upper + 5)
        ..lineTo(x, upper)
        ..lineTo(x + 5, upper + 5)
        ..moveTo(x - 5, lower - 5)
        ..lineTo(x, lower)
        ..lineTo(x + 5, lower - 5);
      canvas.drawPath(head, a);
    }
  }

  @override
  bool shouldRepaint(_PlateauPainter old) =>
      old.gap != gap ||
      old.line1 != line1 ||
      old.line2 != line2 ||
      old.arrow != arrow ||
      old.rising != rising ||
      old.colors != colors;
}
