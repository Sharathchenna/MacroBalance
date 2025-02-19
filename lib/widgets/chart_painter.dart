import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Custom painter for drawing the weight journey line chart.
///
/// Follows the blog’s approach: draws horizontal lines with left-side labels,
/// bottom labels (dates) and connects weight points with a line.
class ChartPainter extends CustomPainter {
  static const int NUMBER_OF_DAYS = 31;
  static const int NUMBER_OF_HORIZONTAL_LINES = 5;

  final List<WeightEntry> entries;

  // Calculated drawing parameters:
  late double leftOffsetStart;
  late double topOffsetEnd;
  late double drawingWidth;
  late double drawingHeight;

  ChartPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    // Set up drawing boundaries
    leftOffsetStart = size.width * 0.1; // leave space for left labels
    topOffsetEnd = size.height * 0.9;   // bottom area for x labels
    drawingWidth = size.width - leftOffsetStart - 10;
    drawingHeight = topOffsetEnd - 10;

    // Get data boundaries
    if (entries.isEmpty) return;
    final minWeight = entries.map((e) => e.weight).reduce(math.min);
    final maxWeight = entries.map((e) => e.weight).reduce(math.max);

    // Draw horizontal lines and left labels
    _drawHorizontalLinesAndLabels(canvas, size, minWeight, maxWeight);

    // Draw bottom labels (dates)
    _drawBottomLabels(canvas, size);

    // Draw the data lines (and markers)
    _drawDataLines(canvas, minWeight, maxWeight);
  }

  void _drawHorizontalLinesAndLabels(Canvas canvas, Size size, double minWeight, double maxWeight) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;

    // Calculate weight step
    int lineStep = ((maxWeight - minWeight) / (NUMBER_OF_HORIZONTAL_LINES - 1)).round();
    double offsetStep = drawingHeight / (NUMBER_OF_HORIZONTAL_LINES - 1);

    for (int i = 0; i < NUMBER_OF_HORIZONTAL_LINES; i++) {
      double yOffset = 10 + i * offsetStep;    // starting 10 for some top margin
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
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText(labelWeight.toStringAsFixed(0));
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: leftOffsetStart - 4));
    canvas.drawParagraph(paragraph, Offset(0.0, yOffset - 6));
  }

  void _drawBottomLabels(Canvas canvas, Size size) {
    // For bottom labels, we label every 7 days.
    final int interval = 7;
    final DateTime startDate = _getStartDateOfChart();

    double dayWidth = drawingWidth / NUMBER_OF_DAYS;
    for (int day = 0; day <= NUMBER_OF_DAYS; day += interval) {
      double xOffset = leftOffsetStart + day * dayWidth;
      DateTime labelDate = startDate.add(Duration(days: day));
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: 10.0, textAlign: TextAlign.center),
      )
        ..pushStyle(ui.TextStyle(color: Colors.black))
        ..addText(DateFormat('d MMM').format(labelDate));
      final ui.Paragraph paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: 50.0));
      canvas.drawParagraph(paragraph, Offset(xOffset - 25.0, topOffsetEnd + 2));
    }
  }

  void _drawDataLines(Canvas canvas, double minWeight, double maxWeight) {
    if (entries.length < 2) return;
    
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0;
    
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
    
    // Draw lines between consecutive points and circles at points.
    for (int i = 0; i < entries.length - 1; i++) {
      Offset p1 = _getEntryOffset(entries[i]);
      Offset p2 = _getEntryOffset(entries[i + 1]);
      canvas.drawLine(p1, p2, paint);
      canvas.drawCircle(p2, 3.0, paint);
    }
    // Draw a larger circle for the most recent entry.
    canvas.drawCircle(_getEntryOffset(entries.first), 5.0, paint);
  }

  // Returns the start date (NUMBER_OF_DAYS ago from today)
  DateTime _getStartDateOfChart() {
    return DateTime.now().subtract(const Duration(days: NUMBER_OF_DAYS));
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}

/// Dummy model representing a weight entry.
/// Replace or adjust this as needed.
class WeightEntry {
  final DateTime dateTime;
  final double weight;
  WeightEntry({required this.dateTime, required this.weight});
}