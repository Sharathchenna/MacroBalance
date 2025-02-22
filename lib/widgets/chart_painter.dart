// ignore_for_file: depend_on_referenced_packages, unused_local_variable, constant_identifier_names

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/theme/app_theme.dart';

/// Custom painter for drawing the weight journey line chart.
///
/// Follows the blog’s approach: draws horizontal lines with left-side labels,
/// bottom labels (dates) and connects weight points with a line.
class ChartPainter extends CustomPainter {
  static const int NUMBER_OF_DAYS = 31;
  static const int NUMBER_OF_HORIZONTAL_LINES = 5;
  static const double MAX_ALLOWED_WEIGHT = 300.0; // Maximum weight to display
  static const double MIN_ALLOWED_WEIGHT = 0.0; // Minimum weight to display
  static const double WEIGHT_PADDING = 5.0; // Padding for min/max values

  final List<WeightEntry> entries;
  // Calculated drawing parameters:
  late double leftOffsetStart;
  late double topOffsetEnd;
  late double drawingWidth;
  late double drawingHeight;

  final dashedLinePaint = Paint()
    ..color = Colors.grey.shade400
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  ChartPainter(this.entries);

  double _calculateMinWeight() {
    if (entries.isEmpty) return MIN_ALLOWED_WEIGHT;

    final minWeight = entries.map((e) => e.weight).reduce(math.min);
    // Ensure minimum weight doesn't go below MIN_ALLOWED_WEIGHT
    final adjustedMin = math.max(
        (minWeight - WEIGHT_PADDING).floorToDouble(), MIN_ALLOWED_WEIGHT);

    return adjustedMin;
  }

  double _calculateMaxWeight() {
    if (entries.isEmpty) return 100.0;

    final maxWeight = entries.map((e) => e.weight).reduce(math.max);
    // Ensure maximum weight doesn't exceed MAX_ALLOWED_WEIGHT
    final adjustedMax = math.min(
        (maxWeight + WEIGHT_PADDING).ceilToDouble(), MAX_ALLOWED_WEIGHT);

    return adjustedMax;
  }

  @override
  void paint(Canvas canvas, Size size) {
    leftOffsetStart = size.width * 0.1;
    topOffsetEnd = size.height;
    drawingWidth = size.width - leftOffsetStart - 10;
    drawingHeight = topOffsetEnd - 10;

    if (entries.isEmpty) return;

    final minWeight = _calculateMinWeight();
    final maxWeight = _calculateMaxWeight();

    // Draw left labels with horizontal lines
    _drawLeftLabels(canvas, size, minWeight, maxWeight);

    // Draw bottom labels (dates)
    _drawBottomLabels(canvas, size);

    // Draw the data lines
    _drawDataLines(canvas, minWeight, maxWeight);
  }

  void _drawHorizontalLinesAndLabels(
      Canvas canvas, Size size, double minWeight, double maxWeight) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0)
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(10, 0),
        [Colors.grey.shade300, Colors.transparent],
        [0, 1],
        TileMode.repeated,
      );

    // Calculate weight step
    int lineStep =
        ((maxWeight - minWeight) / (NUMBER_OF_HORIZONTAL_LINES - 1)).round();
    double offsetStep = drawingHeight / (NUMBER_OF_HORIZONTAL_LINES - 1);

    for (int i = 0; i < NUMBER_OF_HORIZONTAL_LINES; i++) {
      double yOffset = 10 + i * offsetStep; // starting 10 for some top margin
      // Left label: weight value (from top = max to bottom = min)
      double labelWeight = maxWeight - i * lineStep;
      _drawHorizontalLabel(canvas, yOffset, labelWeight);

      // Draw the line from leftOffsetStart to right edge
      canvas.drawLine(
        Offset(leftOffsetStart, yOffset),
        Offset(size.width - 10, yOffset),
        paint,
      );
    }
  }

  void _drawHorizontalLabel(Canvas canvas, double yOffset, double labelWeight) {
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 10.0,
        textAlign: TextAlign.right,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.grey.shade600))
      ..addText(labelWeight.toStringAsFixed(0));
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: leftOffsetStart - 4));
    canvas.drawParagraph(paragraph, Offset(0.0, yOffset - 6));
  }

  void _drawBottomLabels(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    // Find the earliest and latest dates in the entries
    final DateTime endDate = entries.first.dateTime;
    final DateTime startDate = entries.last.dateTime;
    final int totalDays = endDate.difference(startDate).inDays;

    // Calculate optimal interval for labels (aim for 4-5 labels)
    final int interval = math.max((totalDays / 4).round(), 1);

    double dayWidth = drawingWidth / totalDays;

    // Draw labels at intervals
    for (int i = 0; i <= totalDays; i += interval) {
      DateTime labelDate = startDate.add(Duration(days: i));
      double xOffset = leftOffsetStart + (i * dayWidth);

      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontSize: 10.0,
          textAlign: TextAlign.center,
        ),
      )
        ..pushStyle(ui.TextStyle(color: Colors.grey.shade600))
        ..addText(DateFormat('MMM d').format(labelDate));

      final ui.Paragraph paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: 50.0));

      canvas.drawParagraph(
        paragraph,
        Offset(xOffset - 25, topOffsetEnd + 10),
      );
    }
  }

  void _drawDataLines(Canvas canvas, double minWeight, double maxWeight) {
    if (entries.length < 2) return;
    // final customColors = Theme.of(context).extension<CustomColors>();
    // Filter out any weight entries that are outside the allowed range
    final validEntries = entries
        .where((entry) =>
            entry.weight >= MIN_ALLOWED_WEIGHT &&
            entry.weight <= MAX_ALLOWED_WEIGHT)
        .toList();

    if (validEntries.length < 2) return;

    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade800.withValues(alpha: 0.2),
          Colors.grey.shade800.withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(
        leftOffsetStart,
        10,
        drawingWidth,
        drawingHeight,
      ));

    final DateTime startDate = _getStartDateOfChart();
    double dayWidth = drawingWidth / NUMBER_OF_DAYS;

    // Helper to convert entry to canvas coordinate
    Offset _getEntryOffset(WeightEntry entry) {
      int daysFromStart = entry.dateTime.difference(startDate).inDays;
      double relativeX = daysFromStart.clamp(0, NUMBER_OF_DAYS).toDouble();
      double x = leftOffsetStart + relativeX * dayWidth;
      double relativeY = (entry.weight - minWeight) / (maxWeight - minWeight);
      double y = 10 + drawingHeight - (relativeY * drawingHeight);
      return Offset(x, y);
    }

    // Get all data points
    final List<Offset> points = validEntries.map(_getEntryOffset).toList();

    // Build a smooth path using quadratic Bézier curves.
    final Path linePath = Path();
    final Path fillPath = Path();

    linePath.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, 10 + drawingHeight); // Start at bottom
    fillPath.lineTo(points.first.dx, points.first.dy); // Line up to first point

    for (int i = 0; i < points.length - 1; i++) {
      // Calculate the midpoint between the current point and the next point.
      final midPoint = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );

      // Add curves to both paths
      linePath.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        midPoint.dx,
        midPoint.dy,
      );
      fillPath.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        midPoint.dx,
        midPoint.dy,
      );
    }

    // Connect the last midpoint with the last point
    linePath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, points.last.dy);

    // Complete the fill path by drawing down to bottom and back to start
    fillPath.lineTo(points.last.dx, 10 + drawingHeight);
    fillPath.lineTo(points.first.dx, 10 + drawingHeight);

    // Draw the fill first, then the line on top
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    // Draw dashed line from current weight to axis
    if (points.isNotEmpty) {
      final currentPoint = points.first;
      _drawDashedLine(
        canvas,
        currentPoint,
        Offset(leftOffsetStart, currentPoint.dy),
        dashedLinePaint,
      );
    }

    // Draw the marker for the most recent entry
    final markerPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.first, 5.0, markerPaint);

    // Draw current weight label above the point
    if (entries.isNotEmpty) {
      final currentWeight = entries.first.weight;
      final labelText = currentWeight.toStringAsFixed(1);

      final labelPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final labelBgPaint = Paint()
        ..color = Colors.grey.shade800
        ..style = PaintingStyle.fill;

      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      // Draw label background
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: points.first.translate(0, -(textPainter.height + 15)),
          width: textPainter.width + 16,
          height: textPainter.height + 8,
        ),
        const Radius.circular(6),
      );

      canvas.drawRRect(labelRect, labelBgPaint);

      // Draw label text
      textPainter.paint(
        canvas,
        points.first.translate(
          -(textPainter.width / 2),
          -(textPainter.height + 24),
        ),
      );
    }
  }

  // Returns the start date (NUMBER_OF_DAYS ago from today)
  DateTime _getStartDateOfChart() {
    return DateTime.now().subtract(const Duration(days: NUMBER_OF_DAYS));
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.entries != entries;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final dash = 5.0;
    final gap = 5.0;
    final steps = (end - start).distance / (dash + gap);
    final vector = (end - start) / steps;

    for (double i = 0; i < steps.floor(); i++) {
      final startDash = start + (vector * i * 2);
      final endDash = startDash + vector;
      canvas.drawLine(startDash, endDash, paint);
    }
  }

  void _drawLeftLabels(
      Canvas canvas, Size size, double minWeight, double maxWeight) {
    final labelStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 12,
    );

    // Fixed positions for horizontal lines (5 lines)
    const numberOfLines = 5;
    final lineSpacing = drawingHeight / (numberOfLines - 1);

    // Calculate weight step based on min and max weight
    final weightRange = maxWeight - minWeight;
    final weightStep = weightRange / (numberOfLines - 1);

    // Draw horizontal lines and labels
    for (int i = 0; i < numberOfLines; i++) {
      // Calculate y position (fixed spacing)
      final y = 10 + (drawingHeight - (i * lineSpacing));

      // Calculate weight value for this line
      final weight = minWeight + (i * weightStep);

      // Draw weight label
      final textSpan = TextSpan(
        text: weight.toStringAsFixed(1),
        style: labelStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(0, y - textPainter.height / 2),
      );

      // Draw horizontal line
      canvas.drawLine(
        Offset(leftOffsetStart, y),
        Offset(size.width - 10, y),
        Paint()
          ..color = Colors.grey.shade300
          ..strokeWidth = 0.5,
      );
    }
  }
}

/// Dummy model representing a weight entry.
/// Replace or adjust this as needed.
class WeightEntry {
  final DateTime dateTime;
  final double weight;
  WeightEntry({required this.dateTime, required this.weight});
}
