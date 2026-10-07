import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/utils/weight_trend.dart' show niceTicks;

/// One bar: a day, or a week's daily average.
class IntakeBar {
  const IntakeBar({required this.start, required this.cals, this.partial = false});

  /// First day the bar covers.
  final DateTime start;

  /// Null when nothing was logged.
  final double? cals;

  /// Today, still being logged: drawn lighter.
  final bool partial;
}

/// Calories as bars against a dashed goal line. Bars within 10% of the goal
/// are solid; the rest are faded. Days with nothing logged get a small mark
/// on the baseline instead of a zero-height bar. Touch and drag to read a
/// bar; [onScrub] reports its index, then null on release.
class IntakeBarChart extends StatefulWidget {
  const IntakeBarChart({
    super.key,
    required this.bars,
    required this.goal,
    required this.label,
    required this.colors,
    this.onScrub,
  });

  final List<IntakeBar> bars;
  final double goal;

  /// Axis label for bar i, or null for none.
  final String? Function(int i) label;
  final CustomColors colors;
  final ValueChanged<int?>? onScrub;

  @override
  State<IntakeBarChart> createState() => _IntakeBarChartState();
}

class _IntakeBarChartState extends State<IntakeBarChart> {
  int? _selected;

  static const double _right = 40, _bottom = 24, _top = 8;

  int _indexAt(double dx, double width) {
    final plotWidth = width - _right;
    final i = (dx / plotWidth * widget.bars.length).floor();
    return i.clamp(0, widget.bars.length - 1);
  }

  void _select(Offset p, Size size) {
    if (widget.bars.isEmpty) return;
    final i = _indexAt(p.dx, size.width);
    if (i == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = i);
    widget.onScrub?.call(i);
  }

  void _clear() {
    if (_selected == null) return;
    setState(() => _selected = null);
    widget.onScrub?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, size),
        onTapUp: (_) => _clear(),
        onTapCancel: _clear,
        onHorizontalDragStart: (d) => _select(d.localPosition, size),
        onHorizontalDragUpdate: (d) => _select(d.localPosition, size),
        onHorizontalDragEnd: (_) => _clear(),
        onHorizontalDragCancel: _clear,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(widget.bars.length),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          builder: (context, grow, _) => CustomPaint(
            size: size,
            painter: _BarPainter(
              chart: widget,
              grow: grow,
              selected: _selected,
              textStyle: DefaultTextStyle.of(context).style,
            ),
          ),
        ),
      );
    });
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.chart,
    required this.grow,
    required this.selected,
    required this.textStyle,
  });

  final IntakeBarChart chart;
  final double grow;
  final int? selected;
  final TextStyle textStyle;

  TextPainter _text(String s, Color color) => TextPainter(
        text: TextSpan(
          text: s,
          style: textStyle.copyWith(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final colors = chart.colors;
    final plot = Rect.fromLTRB(0, _IntakeBarChartState._top,
        size.width - _IntakeBarChartState._right,
        size.height - _IntakeBarChartState._bottom);
    if (plot.width <= 0 || plot.height <= 0 || chart.bars.isEmpty) return;

    final maxBar = chart.bars
        .map((b) => b.cals ?? 0)
        .fold<double>(0, math.max);
    final ticks = niceTicks(0, math.max(math.max(maxBar, chart.goal) * 1.05, 500),
        count: 4);
    final top = ticks.last;
    double y(double v) => plot.bottom - v / top * plot.height;

    // Grid and values.
    final grid = Paint()
      ..color = colors.textSecondary.withOpacity(0.14)
      ..strokeWidth = 1;
    final number = NumberFormat.decimalPattern();
    for (final t in ticks) {
      canvas.drawLine(Offset(plot.left, y(t)), Offset(plot.right, y(t)), grid);
      final tp = _text(number.format(t.round()), colors.textSecondary);
      tp.paint(canvas, Offset(plot.right + 8, y(t) - tp.height / 2));
    }

    // Bars.
    final n = chart.bars.length;
    final slot = plot.width / n;
    final barWidth = math.min(28.0, slot * (n > 20 ? 0.62 : 0.56));
    final accent = colors.accentPrimary;
    for (var i = 0; i < n; i++) {
      final bar = chart.bars[i];
      final cx = plot.left + slot * (i + 0.5);
      if (bar.cals == null) {
        canvas.drawCircle(Offset(cx, plot.bottom - 2), 1.6,
            Paint()..color = colors.textSecondary.withOpacity(0.35));
        continue;
      }
      final onTarget = chart.goal > 0 &&
          (bar.cals! - chart.goal).abs() <= chart.goal * 0.1;
      var opacity = onTarget ? 1.0 : 0.45;
      if (bar.partial) opacity = 0.25;
      if (selected != null && selected != i) opacity *= 0.5;
      final h = math.max(2.0, (plot.bottom - y(bar.cals!)) * grow);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barWidth / 2, plot.bottom - h, barWidth, h),
        topLeft: Radius.circular(math.min(5, barWidth / 2)),
        topRight: Radius.circular(math.min(5, barWidth / 2)),
      );
      canvas.drawRRect(rect, Paint()..color = accent.withOpacity(opacity));
    }

    // Goal.
    if (chart.goal > 0) {
      final gy = y(chart.goal);
      final paint = Paint()
        ..color = colors.textPrimary.withOpacity(0.55)
        ..strokeWidth = 1.2;
      for (double x = plot.left; x < plot.right; x += 8) {
        canvas.drawLine(
            Offset(x, gy), Offset(math.min(x + 4, plot.right), gy), paint);
      }
    }

    // Dates.
    double lastRight = -double.infinity;
    for (var i = 0; i < n; i++) {
      final label = chart.label(i);
      if (label == null) continue;
      final tp = _text(label,
          i == selected ? colors.textPrimary : colors.textSecondary);
      final cx = plot.left + slot * (i + 0.5);
      final dx = math.max(plot.left, math.min(cx - tp.width / 2, plot.right - tp.width));
      if (dx < lastRight + 4) continue;
      tp.paint(canvas, Offset(dx, plot.bottom + 7));
      lastRight = dx + tp.width;
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.chart != chart || old.grow != grow || old.selected != selected;
}
