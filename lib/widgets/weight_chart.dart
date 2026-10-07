import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/utils/weight_trend.dart';

/// Weight over time: weigh-ins as dots joined by a line, and the goal as a
/// dashed line when it's close enough to share the scale. When weigh-ins are
/// frequent enough for day-to-day swings to be noise ([showsTrend]), the line
/// follows the smoothed trend instead and the dots show the scale readings.
///
/// Readings the trend left out as outliers ([ignored]) are drawn as grey
/// hollow rings off the line.
///
/// Dates are placed by time, so gaps between weigh-ins read as gaps. Axis
/// values are round numbers in the unit shown (kg or lbs). Touch and drag to
/// read a weigh-in; [onScrub] reports its index, then null on release. A tap
/// on a weigh-in reports it to [onTapEntry] (to edit or delete it).
class WeightChart extends StatefulWidget {
  const WeightChart({
    super.key,
    required this.entries,
    required this.trend,
    required this.start,
    required this.end,
    required this.isMetric,
    required this.colors,
    this.goalKg,
    this.ignored = const [],
    this.onScrub,
    this.onTapEntry,
  });

  /// Weigh-ins in the range, oldest first.
  final List<WeightEntry> entries;

  /// Trend weight (kg) at each of [entries].
  final List<double> trend;
  final DateTime start;
  final DateTime end;
  final bool isMetric;
  final CustomColors colors;
  final double? goalKg;

  /// Whether each of [entries] was left out of the trend. Empty means none.
  final List<bool> ignored;
  final ValueChanged<int?>? onScrub;
  final ValueChanged<int>? onTapEntry;

  /// Whether the line is the smoothed trend rather than the weigh-ins: only
  /// with at least 10 weigh-ins about every couple of days or more often.
  /// With fewer, the trend lags so far behind the readings that the line
  /// looks disconnected from the dots.
  static bool showsTrend(List<WeightEntry> entries) {
    if (entries.length < 10) return false;
    final days = entries.last.day.difference(entries.first.day).inDays;
    return days / (entries.length - 1) <= 2.5;
  }

  /// Whether the goal line is drawn: only when it's within about twice the
  /// data's spread, so a far-off goal doesn't flatten the line.
  bool isIgnored(int i) => i < ignored.length && ignored[i];

  static bool showsGoal(
      List<WeightEntry> entries, List<double> trend, double? goalKg) {
    if (goalKg == null || entries.isEmpty) return false;
    final values = [for (final e in entries) e.kg, ...trend];
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final reach = 2 * math.max(hi - lo, 1.0);
    return goalKg >= lo - reach && goalKg <= hi + reach;
  }

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart> {
  int? _selected;
  Offset? _tapAt;

  void _select(Offset local, Size size) {
    final layout = _ChartLayout(widget, size);
    if (widget.entries.isEmpty) return;
    var best = 0;
    var bestDx = double.infinity;
    for (var i = 0; i < widget.entries.length; i++) {
      final dx = (layout.x(widget.entries[i].date) - local.dx).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = i;
      }
    }
    if (best != _selected) {
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
  void didUpdateWidget(WeightChart old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.entries.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          _tapAt = d.localPosition;
          _select(d.localPosition, size);
        },
        onTapUp: (_) {
          final i = _selected;
          final at = _tapAt;
          _clear();
          if (i == null || at == null || widget.onTapEntry == null) return;
          // Only a tap close to the weigh-in, not anywhere on the chart.
          final x = _ChartLayout(widget, size).x(widget.entries[i].date);
          if ((x - at.dx).abs() <= 24) widget.onTapEntry!(i);
        },
        onTapCancel: _clear,
        onHorizontalDragStart: (d) => _select(d.localPosition, size),
        onHorizontalDragUpdate: (d) => _select(d.localPosition, size),
        onHorizontalDragEnd: (_) => _clear(),
        onHorizontalDragCancel: _clear,
        child: TweenAnimationBuilder<double>(
          // Draw in from the left whenever the range or unit changes.
          key: ValueKey('${widget.start}-${widget.isMetric}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, reveal, _) => CustomPaint(
            size: size,
            painter: _WeightChartPainter(
              chart: widget,
              selected: _selected,
              reveal: reveal,
              labelStyle: DefaultTextStyle.of(context).style,
            ),
          ),
        ),
      );
    });
  }
}

/// Where things go: shared by painting and touch.
class _ChartLayout {
  _ChartLayout(this.chart, this.size) {
    final unit = chart.isMetric ? 1.0 : lbsPerKg;
    final values = [
      for (final e in chart.entries) e.kg * unit,
      for (final t in chart.trend) t * unit,
    ];
    var lo = values.isEmpty ? 0.0 : values.reduce(math.min);
    var hi = values.isEmpty ? 1.0 : values.reduce(math.max);
    // Keep a flat month from looking dramatic: show at least 2 kg / 4 lbs.
    final minSpan = chart.isMetric ? 2.0 : 4.0;
    showGoal = WeightChart.showsGoal(chart.entries, chart.trend, chart.goalKg);
    if (showGoal) {
      final goal = chart.goalKg! * unit;
      lo = math.min(lo, goal);
      hi = math.max(hi, goal);
    }
    if (hi - lo < minSpan) {
      final mid = (hi + lo) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
    }
    final pad = (hi - lo) * 0.08;
    ticks = niceTicks(lo - pad, hi + pad, count: 4);
    yMin = ticks.first;
    yMax = ticks.last;
    this.unit = unit;
    final startDay = DateTime(chart.start.year, chart.start.month, chart.start.day);
    final endDay = DateTime(chart.end.year, chart.end.month, chart.end.day);
    // Pad both ends so the first and last days (and their labels) sit
    // inside the plot rather than on its edges.
    const day = 86400000.0;
    final from = startDay.millisecondsSinceEpoch.toDouble();
    final to = math.max(endDay.millisecondsSinceEpoch.toDouble(), from);
    final edge = math.max(day / 2, (to - from) * 0.02);
    t0 = from - edge;
    t1 = to + edge;
    trend = WeightChart.showsTrend(chart.entries);
  }

  final WeightChart chart;
  final Size size;
  late final List<double> ticks;
  late final double yMin, yMax, unit, t0, t1;
  late final bool trend;
  bool showGoal = false;

  static const double left = 6, right = 40, top = 10, bottom = 26;

  Rect get plot => Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  double x(DateTime d) {
    final day = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    return plot.left + (day - t0) / (t1 - t0) * plot.width;
  }

  double y(double kg) =>
      plot.bottom - (kg * unit - yMin) / (yMax - yMin) * plot.height;

  double yDisplay(double v) =>
      plot.bottom - (v - yMin) / (yMax - yMin) * plot.height;
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.chart,
    required this.selected,
    required this.reveal,
    required this.labelStyle,
  });

  final WeightChart chart;
  final int? selected;
  final double reveal;
  final TextStyle labelStyle;

  CustomColors get colors => chart.colors;

  @override
  void paint(Canvas canvas, Size size) {
    final l = _ChartLayout(chart, size);
    final plot = l.plot;
    if (plot.width <= 0 || plot.height <= 0) return;

    _drawGrid(canvas, l);
    _drawDates(canvas, l);
    if (l.showGoal) _drawGoal(canvas, l);

    if (chart.entries.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
        0, 0, plot.left + (plot.width + 8) * reveal, size.height));

    final accent = colors.accentPrimary;
    // Ignored readings stay off the line joining the weigh-ins; the trend
    // carries through them.
    final points = [
      for (var i = 0; i < chart.entries.length; i++)
        if (l.trend || !chart.isIgnored(i))
          Offset(l.x(chart.entries[i].date),
              l.y(l.trend ? chart.trend[i] : chart.entries[i].kg)),
    ];

    // In trend mode the weigh-ins are faint context under the line;
    // otherwise they're the data, drawn as rings on top of it.
    if (l.trend) _drawWeighIns(canvas, l, faint: true);

    if (points.length > 1) {
      // Monotone, so the curve never overshoots: every peak and dip on the
      // line is a real reading.
      final line = monotonePath(points);
      final fill = Path.from(line)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, plot.top),
            Offset(0, plot.bottom),
            [accent.withOpacity(0.16), accent.withOpacity(0.0)],
          ),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (!l.trend) _drawWeighIns(canvas, l, faint: false);
    _drawIgnored(canvas, l);
    canvas.restore();

    if (selected != null && selected! < chart.entries.length) {
      _drawSelection(canvas, l, selected!);
    }
  }

  void _drawWeighIns(Canvas canvas, _ChartLayout l, {required bool faint}) {
    final accent = colors.accentPrimary;
    final n = chart.entries.length;
    final spacing = l.plot.width / n;
    if (faint) {
      // Behind the trend: small solid dots, smaller still when crowded.
      final r = spacing < 3 ? 1.2 : 2.2;
      final paint = Paint()..color = accent.withOpacity(spacing < 3 ? 0.3 : 0.45);
      for (var i = 0; i < n; i++) {
        if (chart.isIgnored(i)) continue;
        final e = chart.entries[i];
        canvas.drawCircle(Offset(l.x(e.date), l.y(e.kg)), r, paint);
      }
      return;
    }
    final r = n == 1 ? 5.0 : (spacing < 10 ? 2.5 : 3.5);
    final fill = Paint()..color = colors.cardBackground;
    final ring = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = spacing < 10 ? 1.4 : 1.8;
    for (var i = 0; i < n; i++) {
      if (chart.isIgnored(i)) continue;
      final e = chart.entries[i];
      final p = Offset(l.x(e.date), l.y(e.kg));
      canvas.drawCircle(p, r, fill);
      canvas.drawCircle(p, r, ring);
    }
  }

  /// Readings left out of the trend: grey hollow rings, on top of the line.
  void _drawIgnored(Canvas canvas, _ChartLayout l) {
    final spacing = l.plot.width / chart.entries.length;
    final r = spacing < 10 ? 3.0 : 4.0;
    final fill = Paint()..color = colors.cardBackground;
    final ring = Paint()
      ..color = colors.textSecondary.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var i = 0; i < chart.entries.length; i++) {
      if (!chart.isIgnored(i)) continue;
      final e = chart.entries[i];
      final p = Offset(l.x(e.date), l.y(e.kg));
      canvas.drawCircle(p, r, fill);
      canvas.drawCircle(p, r, ring);
    }
  }

  TextPainter _text(String s, {double size = 11, Color? color, FontWeight? weight}) =>
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
      ..color = colors.textSecondary.withOpacity(0.14)
      ..strokeWidth = 1;
    final step = l.ticks.length > 1 ? l.ticks[1] - l.ticks[0] : 1;
    final decimals = step == step.roundToDouble() ? 0 : 1;
    for (final v in l.ticks) {
      final y = l.yDisplay(v);
      canvas.drawLine(Offset(l.plot.left, y), Offset(l.plot.right, y), grid);
      // With nothing in range the scale means nothing, so leave it unlabelled.
      if (chart.entries.isEmpty) continue;
      final tp = _text(v.toStringAsFixed(decimals));
      tp.paint(canvas, Offset(l.plot.right + 8, y - tp.height / 2));
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

  void _drawGoal(Canvas canvas, _ChartLayout l) {
    final y = l.y(chart.goalKg!);
    final paint = Paint()
      ..color = colors.textSecondary.withOpacity(0.7)
      ..strokeWidth = 1.2;
    for (double x = l.plot.left; x < l.plot.right; x += 8) {
      canvas.drawLine(
          Offset(x, y), Offset(math.min(x + 4, l.plot.right), y), paint);
    }
    final tp = _text('Goal', size: 10, weight: FontWeight.w600);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(l.plot.left + 4, y - tp.height / 2 - 2, tp.width + 10,
          tp.height + 4),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = colors.cardBackground);
    tp.paint(canvas, Offset(l.plot.left + 9, y - tp.height / 2));
  }

  void _drawSelection(Canvas canvas, _ChartLayout l, int i) {
    final e = chart.entries[i];
    final x = l.x(e.date);
    canvas.drawLine(
      Offset(x, l.plot.top),
      Offset(x, l.plot.bottom),
      Paint()
        ..color = colors.textSecondary.withOpacity(0.45)
        ..strokeWidth = 1,
    );
    final accent = colors.accentPrimary;
    if (l.trend) {
      canvas.drawCircle(Offset(x, l.y(chart.trend[i])), 4, Paint()..color = accent);
    }
    final p = Offset(x, l.y(e.kg));
    final ring = chart.isIgnored(i) ? colors.textSecondary : accent;
    canvas.drawCircle(p, 9, Paint()..color = ring.withValues(alpha: 0.2));
    canvas.drawCircle(p, 5.5, Paint()..color = colors.cardBackground);
    canvas.drawCircle(
      p,
      5.5,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.chart != chart || old.selected != selected || old.reveal != reveal;
}

/// How curved [monotonePath] is: 0 joins points with straight lines; 1 is a
/// full monotone curve.
const double _curviness = 0.5;

/// Monotone cubic through [points] (at least two), so a line never
/// overshoots a value. Shared by the Progress charts.
Path monotonePath(List<Offset> points) {
  final n = points.length;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  final slopes = List<double>.filled(n - 1, 0);
  for (var i = 0; i < n - 1; i++) {
    final dx = points[i + 1].dx - points[i].dx;
    slopes[i] = dx == 0 ? 0 : (points[i + 1].dy - points[i].dy) / dx;
  }
  final tangents = List<double>.filled(n, 0);
  tangents[0] = slopes.first;
  tangents[n - 1] = slopes.last;
  for (var i = 1; i < n - 1; i++) {
    tangents[i] = slopes[i - 1] * slopes[i] <= 0
        ? 0
        : (slopes[i - 1] + slopes[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    if (slopes[i] == 0) {
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }
    final a = tangents[i] / slopes[i];
    final b = tangents[i + 1] / slopes[i];
    final h = math.sqrt(a * a + b * b);
    if (h > 3) {
      tangents[i] = 3 / h * a * slopes[i];
      tangents[i + 1] = 3 / h * b * slopes[i];
    }
  }
  for (var i = 0; i < n - 1; i++) {
    final p0 = points[i], p1 = points[i + 1];
    final dx = p1.dx - p0.dx;
    if (dx == 0) {
      path.lineTo(p1.dx, p1.dy);
      continue;
    }
    // Pull each end's tangent halfway toward the segment's own slope:
    // softer than a full curve, without the corners of straight lines.
    final t0 = slopes[i] + (tangents[i] - slopes[i]) * _curviness;
    final t1 = slopes[i] + (tangents[i + 1] - slopes[i]) * _curviness;
    path.cubicTo(p0.dx + dx / 3, p0.dy + t0 * dx / 3,
        p1.dx - dx / 3, p1.dy - t1 * dx / 3, p1.dx, p1.dy);
  }
  return path;
}

/// Labelled dates for an axis from [start] to [end]: days for about a week,
/// weeks for about a month, then months, then years.
List<(DateTime, String)> dateTicks(DateTime start, DateTime end) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  final span = to.difference(from).inDays;
  if (span <= 8) {
    return [
      for (var i = 0; i <= span; i++)
        () {
          final d = DateTime(from.year, from.month, from.day + i);
          return (d, DateFormat.E().format(d));
        }(),
    ];
  }
  if (span <= 40) {
    // Every week, counted back from the last day so today is labelled.
    final ticks = <(DateTime, String)>[];
    for (var d = to; !d.isBefore(from); d = DateTime(d.year, d.month, d.day - 7)) {
      ticks.insert(0, (d, DateFormat.MMMd().format(d)));
    }
    return ticks;
  }
  final months = span <= 200 ? 1 : (span <= 400 ? 2 : (span <= 800 ? 4 : 12));
  final ticks = <(DateTime, String)>[];
  var d = DateTime(from.year, from.month + 1, 1);
  if (months == 12) d = DateTime(from.year + 1, 1, 1);
  final format = span > 400 && months < 12 ? DateFormat("MMM ''yy") : DateFormat.MMM();
  while (!d.isAfter(to)) {
    ticks.add((d, months == 12 ? DateFormat.y().format(d) : format.format(d)));
    d = DateTime(d.year, d.month + months, 1);
  }
  return ticks;
}
