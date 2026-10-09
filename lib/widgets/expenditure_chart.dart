import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/expenditure_series.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/utils/weight_trend.dart';
import 'package:macrotracker/widgets/weight_chart.dart';

/// Daily expenditure over time (spec 7.1 R2): the estimate as a line with
/// its ±1 sd band, and the starting formula estimate as a dashed line.
///
/// The line breaks at missing days and at resets. A reset also gets a faint
/// marker, and history from before the current learning start is drawn in
/// grey: it's kept, but it no longer counts.
///
/// Check-in days are dots on the baseline (spec 7.1 R2); tapping one calls
/// [onCheckin] with its day.
///
/// Built like [WeightChart]: days placed by time, round-number axis on the
/// right, drawn in from the left, and touch and drag to read a day
/// ([onScrub] reports it, then null on release).
class ExpenditureChart extends StatefulWidget {
  const ExpenditureChart({
    super.key,
    required this.series,
    required this.start,
    required this.end,
    required this.colors,
    this.formulaTdee,
    this.onScrub,
    this.checkins = const [],
    this.onCheckin,
    this.simple = false,
  });

  /// The rows in range.
  final ExpenditureSeries series;
  final DateTime start;
  final DateTime end;
  final CustomColors colors;

  /// The starting estimate, drawn dashed when it shares the scale.
  final double? formulaTdee;
  final ValueChanged<EnergyEstimate?>? onScrub;

  /// Check-in days to mark.
  final List<DateTime> checkins;
  final ValueChanged<DateTime>? onCheckin;

  /// Just the line (simple mode): no band, no reset markers, and no range
  /// while scrubbing. The y axis fits the line alone.
  final bool simple;

  /// The width of a check-in's touch target.
  static const double checkinTarget = 32;

  @override
  State<ExpenditureChart> createState() => _ExpenditureChartState();
}

class _ExpenditureChartState extends State<ExpenditureChart> {
  EnergyEstimate? _selected;

  void _select(Offset local, Size size) {
    final rows = widget.series.rows;
    if (rows.isEmpty) return;
    final layout = _ChartLayout(widget, size);
    var best = rows.first;
    var bestDx = double.infinity;
    for (final r in rows) {
      final dx = (layout.x(r.day) - local.dx).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = r;
      }
    }
    if (best.day != _selected?.day) {
      HapticFeedback.selectionClick();
      setState(() => _selected = best);
      widget.onScrub?.call(best);
    }
  }

  void _clear() {
    if (_selected == null) return;
    setState(() => _selected = null);
    widget.onScrub?.call(null);
  }

  @override
  void didUpdateWidget(ExpenditureChart old) {
    super.didUpdateWidget(old);
    final s = _selected;
    if (s != null && !widget.series.rows.any((r) => r.day == s.day)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final layout = _ChartLayout(widget, size);
      final chart = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, size),
        onTapUp: (_) => _clear(),
        onTapCancel: _clear,
        onHorizontalDragStart: (d) => _select(d.localPosition, size),
        onHorizontalDragUpdate: (d) => _select(d.localPosition, size),
        onHorizontalDragEnd: (_) => _clear(),
        onHorizontalDragCancel: _clear,
        child: TweenAnimationBuilder<double>(
          // Draw in from the left whenever the range changes.
          key: ValueKey(widget.start),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, reveal, _) => CustomPaint(
            size: size,
            painter: _ExpenditurePainter(
              chart: widget,
              selected: _selected,
              reveal: reveal,
              labelStyle: DefaultTextStyle.of(context).style,
            ),
          ),
        ),
      );
      final ticks = widget.onCheckin == null || widget.series.isEmpty
          ? const <DateTime>[]
          : layout.visibleCheckins();
      if (ticks.isEmpty) return chart;
      // Each check-in gets a target around its dot, over the date labels;
      // it wins the tap over scrubbing.
      return Stack(
        children: [
          Positioned.fill(child: chart),
          for (final d in ticks)
            Positioned(
              left: layout.x(d) - ExpenditureChart.checkinTarget / 2,
              top: layout.plot.bottom - 18,
              width: ExpenditureChart.checkinTarget,
              bottom: 0,
              child: Semantics(
                button: true,
                label: 'Check-in ${DateFormat.MMMd().format(d)}',
                child: GestureDetector(
                  key: ValueKey('expenditure_checkin_${d.toIso8601String()}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onCheckin!(d);
                  },
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Where things go: shared by painting and touch.
class _ChartLayout {
  _ChartLayout(this.chart, this.size) {
    final scale =
        chart.series.scale(formula: chart.formulaTdee, band: !chart.simple);
    showFormula = scale.showsFormula;
    final pad = (scale.hi - scale.lo) * 0.08;
    ticks = niceTicks(scale.lo - pad, scale.hi + pad, count: 4);
    yMin = ticks.first;
    yMax = ticks.last;
    final startDay =
        DateTime(chart.start.year, chart.start.month, chart.start.day);
    final endDay = DateTime(chart.end.year, chart.end.month, chart.end.day);
    // Pad both ends so the first and last days sit inside the plot.
    final from = startDay.millisecondsSinceEpoch.toDouble();
    final to = math.max(endDay.millisecondsSinceEpoch.toDouble(), from);
    final edge = math.max(day / 2, (to - from) * 0.02);
    t0 = from - edge;
    t1 = to + edge;
  }

  final ExpenditureChart chart;
  final Size size;
  late final List<double> ticks;
  late final double yMin, yMax, t0, t1;
  late final bool showFormula;

  static const double day = 86400000.0;
  static const double left = 6, right = 40, top = 10, bottom = 26;

  Rect get plot =>
      Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  double x(DateTime d) {
    final ms = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    return plot.left + (ms - t0) / (t1 - t0) * plot.width;
  }

  double get dayWidth => day / (t1 - t0) * plot.width;

  /// The check-in days that fall on the plot.
  List<DateTime> visibleCheckins() => [
        for (final d in chart.checkins)
          if (x(d) >= plot.left - 1 && x(d) <= plot.right + 1) d,
      ];

  double y(double cals) =>
      plot.bottom - (cals - yMin) / (yMax - yMin) * plot.height;
}

class _ExpenditurePainter extends CustomPainter {
  _ExpenditurePainter({
    required this.chart,
    required this.selected,
    required this.reveal,
    required this.labelStyle,
  });

  final ExpenditureChart chart;
  final EnergyEstimate? selected;
  final double reveal;
  final TextStyle labelStyle;

  static final _number = NumberFormat.decimalPattern();

  CustomColors get colors => chart.colors;

  /// Pre-reset history: a dimmed grey, far enough from the accent in both
  /// themes to read as different (checked with the dataviz validator).
  Color get _past => colors.textSecondary.withValues(alpha: 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    final l = _ChartLayout(chart, size);
    final plot = l.plot;
    if (plot.width <= 0 || plot.height <= 0) return;

    _drawGrid(canvas, l);
    _drawDates(canvas, l);
    if (chart.series.isEmpty) return;
    if (l.showFormula && chart.formulaTdee != null) _drawFormula(canvas, l);

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
        0, 0, plot.left + (plot.width + 8) * reveal, size.height));
    for (final s in chart.series.segments) {
      _drawSegment(canvas, l, s);
    }
    canvas.restore();

    if (!chart.simple) {
      for (final d in chart.series.resets) {
        _drawReset(canvas, l, d);
      }
    }
    for (final d in l.visibleCheckins()) {
      _drawCheckin(canvas, l, d);
    }
    if (selected != null) _drawSelection(canvas, l, selected!);
  }

  void _drawSegment(Canvas canvas, _ChartLayout l, ExpenditureSegment s) {
    final color = s.preReset ? _past : colors.accentPrimary;
    final line = [for (final r in s.rows) Offset(l.x(r.day), l.y(r.tdee))];
    final upper = [
      for (final r in s.rows) Offset(l.x(r.day), l.y(r.tdee + r.tdeeSd))
    ];
    final lower = [
      for (final r in s.rows.reversed)
        Offset(l.x(r.day), l.y(r.tdee - r.tdeeSd))
    ];
    final bandPaint = Paint()
      ..color = color.withValues(alpha: s.preReset ? 0.10 : 0.16);

    if (line.length == 1) {
      if (chart.simple) {
        canvas.drawCircle(line.first, 2.5, Paint()..color = color);
        return;
      }
      // A lone day: its range as a short bar, the estimate as a dot.
      final w = math.min(6.0, math.max(2.0, l.dayWidth));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(line.first.dx - w / 2, upper.first.dy,
              line.first.dx + w / 2, lower.first.dy),
          const Radius.circular(2),
        ),
        bandPaint,
      );
      canvas.drawCircle(line.first, 2.5, Paint()..color = color);
      return;
    }

    final band = monotonePath(upper)
      ..lineTo(lower.first.dx, lower.first.dy)
      ..extendWithPath(monotonePath(lower), Offset.zero)
      ..close();
    if (!chart.simple) canvas.drawPath(band, bandPaint);
    canvas.drawPath(
      monotonePath(line),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.preReset ? 2 : 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  TextPainter _text(String s,
          {double size = 11, Color? color, FontWeight? weight}) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: labelStyle.copyWith(
            fontSize: size,
            color: color ?? colors.textSecondary,
            fontWeight: weight ?? FontWeight.w500,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

  void _drawGrid(Canvas canvas, _ChartLayout l) {
    final grid = Paint()
      ..color = colors.textSecondary.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (final v in l.ticks) {
      final y = l.y(v);
      canvas.drawLine(Offset(l.plot.left, y), Offset(l.plot.right, y), grid);
      if (chart.series.isEmpty) continue;
      final tp = _text(_number.format(v.round()));
      tp.paint(canvas, Offset(l.plot.right + 6, y - tp.height / 2));
    }
  }

  void _drawDates(Canvas canvas, _ChartLayout l) {
    double lastRight = -double.infinity;
    for (final (date, label) in dateTicks(chart.start, chart.end)) {
      final x = l.x(date);
      if (x < l.plot.left - 1 || x > l.plot.right + 1) continue;
      final tp = _text(label);
      var dx = x - tp.width / 2;
      dx = math.max(l.plot.left, math.min(dx, l.plot.right - tp.width));
      if (dx < lastRight + 6) continue;
      tp.paint(canvas, Offset(dx, l.plot.bottom + 8));
      lastRight = dx + tp.width;
    }
  }

  /// The formula's estimate, dashed like the Weight chart's goal. Its label
  /// goes at whichever end the line is farther from it (a run starts on the
  /// formula, so usually the right), on the side away from the line.
  void _drawFormula(Canvas canvas, _ChartLayout l) {
    final formula = chart.formulaTdee!;
    final y = l.y(formula);
    final paint = Paint()
      ..color = colors.textSecondary.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (double x = l.plot.left; x < l.plot.right; x += 8) {
      canvas.drawLine(
          Offset(x, y), Offset(math.min(x + 4, l.plot.right), y), paint);
    }
    final tp = _text('Starting estimate', size: 10, weight: FontWeight.w600);
    final rows = chart.series.rows;
    final atRight = (rows.last.tdee - formula).abs() >=
        (rows.first.tdee - formula).abs();
    final end = atRight ? rows.last : rows.first;
    var top = end.tdee >= formula ? y + 3 : y - tp.height - 3;
    top = top.clamp(l.plot.top, l.plot.bottom - tp.height).toDouble();
    final left = atRight
        ? l.plot.right - tp.width - 6
        : math.max(l.plot.left + 4, l.x(end.day) + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left - 4, top - 1, tp.width + 8, tp.height + 2),
        const Radius.circular(6),
      ),
      Paint()..color = colors.cardBackground.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(left, top));
  }

  /// A reset: a faint dashed rule between the last day before it and the
  /// first day after, labelled at the top.
  void _drawReset(Canvas canvas, _ChartLayout l, DateTime d) {
    final x = l.x(d) - l.dayWidth / 2;
    if (x < l.plot.left || x > l.plot.right + 1) return;
    final paint = Paint()
      ..color = colors.textSecondary.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final tp = _text('Reset', size: 10, weight: FontWeight.w600);
    final labelTop = l.plot.top;
    for (double y = labelTop + tp.height + 4; y < l.plot.bottom; y += 6) {
      canvas.drawLine(
          Offset(x, y), Offset(x, math.min(y + 3, l.plot.bottom)), paint);
    }
    final left = (x - tp.width / 2)
        .clamp(l.plot.left, math.max(l.plot.left, l.plot.right - tp.width))
        .toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left - 4, labelTop - 1, tp.width + 8, tp.height + 2),
        const Radius.circular(6),
      ),
      Paint()..color = colors.cardBackground,
    );
    tp.paint(canvas, Offset(left, labelTop));
  }

  /// A check-in: an accent dot on the baseline, ringed in the card colour so
  /// it sits on top of the grid.
  void _drawCheckin(Canvas canvas, _ChartLayout l, DateTime d) {
    final p = Offset(l.x(d), l.plot.bottom);
    canvas.drawCircle(p, 5, Paint()..color = colors.cardBackground);
    canvas.drawCircle(p, 3.5, Paint()..color = colors.accentPrimary);
  }

  void _drawSelection(Canvas canvas, _ChartLayout l, EnergyEstimate r) {
    final x = l.x(r.day);
    canvas.drawLine(
      Offset(x, l.plot.top),
      Offset(x, l.plot.bottom),
      Paint()
        ..color = colors.textSecondary.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
    final preReset = chart.series.segments
        .any((s) => s.preReset && !r.day.isBefore(s.first) && !r.day.isAfter(s.last));
    final color = preReset ? colors.textSecondary : colors.accentPrimary;
    // The day's range as a soft bar, the estimate as a ring.
    if (!chart.simple) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 3, l.y(r.tdee + r.tdeeSd), x + 3,
              l.y(r.tdee - r.tdeeSd)),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: 0.25),
      );
    }
    final p = Offset(x, l.y(r.tdee));
    canvas.drawCircle(p, 9, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawCircle(p, 5.5, Paint()..color = colors.cardBackground);
    canvas.drawCircle(
      p,
      5.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ExpenditurePainter old) =>
      old.chart != chart || old.selected != selected || old.reveal != reveal;
}
