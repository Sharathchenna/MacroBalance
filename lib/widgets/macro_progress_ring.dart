import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_theme.dart';
import '../theme/typography.dart';

class MacroProgressRing extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final double percentage;
  final double size;

  const MacroProgressRing({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'g',
    required this.color,
    required this.percentage,
    this.size = 70, // Slightly reduced default size
  });

  @override
  State<MacroProgressRing> createState() => _MacroProgressRingState();
}

class _MacroProgressRingState extends State<MacroProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.percentage,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MacroProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.percentage,
        end: widget.percentage,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));

      _animationController
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context).extension<CustomColors>();
    final bgColor = widget.color.withAlpha(((0.12) * 255).round());
    final highlightColor = HSLColor.fromColor(widget.color)
        .withLightness(
            (HSLColor.fromColor(widget.color).lightness + 0.2).clamp(0.0, 1.0))
        .toColor();

    return SizedBox(
      width: widget.size + 16, // Reduced padding
      height: widget.size + 40, // Reduced height since removing percentage
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title and icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForMacro(widget.label),
                  color: widget.color,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTypography.body2.copyWith(
                  color: widget.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress ring container
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background track
                CustomPaint(
                  painter: CircleProgressPainter(
                    color: bgColor,
                    progress: 1.0,
                    strokeWidth: 8,
                  ),
                  size: Size(widget.size, widget.size),
                ),

                // Animated progress
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CircleProgressPainter(
                        color: widget.color,
                        progress: _progressAnimation.value,
                        strokeWidth: 8,
                        useGradient: true,
                        gradientColors: [widget.color, highlightColor],
                      ),
                      size: Size(widget.size, widget.size),
                    );
                  },
                ),

                // Center value
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.value,
                      style: AppTypography.h3.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      widget.unit,
                      style: AppTypography.caption.copyWith(
                        color: widget.color.withAlpha(((0.8) * 255).round()),
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForMacro(String macro) {
    switch (macro.toLowerCase()) {
      case 'carbs':
        return Icons.grain_rounded;
      case 'protein':
        return Icons.fitness_center_rounded;
      case 'fat':
        return Icons.opacity_rounded;
      default:
        return Icons.pie_chart_rounded;
    }
  }
}

class CircleProgressPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double strokeWidth;
  final bool useGradient;
  final List<Color>? gradientColors;

  CircleProgressPainter({
    required this.color,
    required this.progress,
    required this.strokeWidth,
    this.useGradient = false,
    this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Create the progress arc path
    final path = Path()
      ..arcTo(
        rect,
        -pi / 2, // Start from top
        2 * pi * progress, // Arc angle
        false,
      );

    // Create paint for stroke
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Apply color or gradient
    if (useGradient && gradientColors != null && gradientColors!.length >= 2) {
      final gradient = SweepGradient(
        colors: [...gradientColors!, gradientColors!.first],
        stops: [0.0, progress, 1.0],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        transform: const GradientRotation(-pi / 2),
      );
      paint.shader = gradient.createShader(rect);
    } else {
      paint.color = color;
    }

    // Draw path
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CircleProgressPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
