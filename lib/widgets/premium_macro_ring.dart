import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_theme.dart';

/// Premium macro progress ring with sophisticated animations and styling
class PremiumMacroRing extends StatefulWidget {
  final String label;
  final int current;
  final int target;
  final Color color;
  final IconData? icon;
  final String unit;
  final double size;
  final bool showPercentage;
  final bool animated;

  const PremiumMacroRing({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.icon,
    this.unit = 'g',
    this.size = 80,
    this.showPercentage = false,
    this.animated = true,
  });

  @override
  State<PremiumMacroRing> createState() => _PremiumMacroRingState();
}

class _PremiumMacroRingState extends State<PremiumMacroRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: PremiumAnimations.slow,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _calculateProgress(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PremiumAnimations.smooth,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PremiumAnimations.bounce,
    ));

    if (widget.animated) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(PremiumMacroRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current ||
        oldWidget.target != widget.target) {
      final newProgress = _calculateProgress();
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: newProgress,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: PremiumAnimations.smooth,
      ));

      _animationController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _calculateProgress() {
    if (widget.target == 0) return 0.0;
    return (widget.current / widget.target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Create gradient colors
    final gradientColors = [
      widget.color,
      HSLColor.fromColor(widget.color)
          .withLightness((HSLColor.fromColor(widget.color).lightness + 0.15)
              .clamp(0.0, 1.0))
          .toColor(),
    ];

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.size + 40,
            height: widget.size + 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.color.withAlpha(((0.15) * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.color,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      style: (theme.textTheme.bodySmall ?? const TextStyle())
                          .copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress ring container with glow effect
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _progressAnimation.value > 0.8
                        ? [
                            BoxShadow(
                              color: widget.color.withAlpha(((0.3) * 255).round()),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background track with subtle gradient
                      CustomPaint(
                        painter: _RingPainter(
                          color: isDark
                              ? widget.color.withAlpha(((0.15) * 255).round())
                              : widget.color.withAlpha(((0.1) * 255).round()),
                          progress: 1.0,
                          strokeWidth: 8,
                          useGradient: false,
                        ),
                        size: Size(widget.size, widget.size),
                      ),

                      // Animated progress ring with gradient
                      CustomPaint(
                        painter: _RingPainter(
                          color: widget.color,
                          progress: _progressAnimation.value,
                          strokeWidth: 8,
                          useGradient: true,
                          gradientColors: gradientColors,
                        ),
                        size: Size(widget.size, widget.size),
                      ),

                      // Center content with enhanced typography
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: PremiumAnimations.fast,
                            style: (theme.textTheme.titleLarge ??
                                    const TextStyle())
                                .copyWith(
                              color: widget.color,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              fontFeatures: [const FontFeature.tabularFigures()],
                            ),
                            child: Text(
                              widget.current.toString(),
                            ),
                          ),
                          if (widget.unit.isNotEmpty)
                            Text(
                              widget.unit,
                              style: (theme.textTheme.labelSmall ??
                                      const TextStyle())
                                  .copyWith(
                                color: widget.color.withAlpha(((0.7) * 255).round()),
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Progress information
                if (widget.showPercentage)
                  Text(
                    '${(_progressAnimation.value * 100).round()}%',
                    style: (theme.textTheme.labelSmall ?? const TextStyle())
                        .copyWith(
                      color: widget.color.withAlpha(((0.8) * 255).round()),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  RichText(
                    text: TextSpan(
                      style: (theme.textTheme.labelSmall ?? const TextStyle())
                          .copyWith(
                        color: theme.extension<CustomColors>()?.textSecondary,
                      ),
                      children: [
                        TextSpan(text: '${widget.current}'),
                        TextSpan(
                          text: ' / ',
                          style: TextStyle(
                            color: (theme
                                        .extension<CustomColors>()
                                        ?.textSecondary ??
                                    Colors.grey)
                                .withAlpha(((0.6) * 255).round()),
                          ),
                        ),
                        TextSpan(text: '${widget.target}'),
                        if (widget.unit.isNotEmpty)
                          TextSpan(text: ' ${widget.unit}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the ring progress indicator
class _RingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double strokeWidth;
  final bool useGradient;
  final List<Color>? gradientColors;

  _RingPainter({
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

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (useGradient &&
        gradientColors != null &&
        gradientColors!.length >= 2 &&
        progress > 0) {
      // Create sweep gradient for smooth color transition
      final sweepAngle = 2 * pi * progress;
      if (sweepAngle > 0) {
        final gradient = SweepGradient(
          colors: gradientColors!,
          stops: const [0.0, 1.0],
          startAngle: -pi / 2,
          endAngle: -pi / 2 + sweepAngle,
        );
        paint.shader = gradient.createShader(rect);
      } else {
        paint.color = color;
      }
    } else {
      paint.color = color;
    }

    // Only draw arc if progress is greater than 0
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -pi / 2, // Start from top
        2 * pi * progress, // Arc angle based on progress
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.useGradient != useGradient;
  }
}

/// Macro-specific ring with predefined styling
class MacroProgressRing extends StatelessWidget {
  final String macro;
  final int current;
  final int target;
  final double size;
  final bool animated;

  const MacroProgressRing({
    super.key,
    required this.macro,
    required this.current,
    required this.target,
    this.size = 80,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final macroConfig = _getMacroConfig(macro);

    return PremiumMacroRing(
      label: macro,
      current: current,
      target: target,
      color: macroConfig.color,
      icon: macroConfig.icon,
      unit: macroConfig.unit,
      size: size,
      animated: animated,
    );
  }

  _MacroConfig _getMacroConfig(String macro) {
    switch (macro.toLowerCase()) {
      case 'carbs':
      case 'carbohydrates':
        return _MacroConfig(
          color: PremiumColors.blue500,
          icon: Icons.grain_rounded,
          unit: 'g',
        );
      case 'protein':
        return _MacroConfig(
          color: PremiumColors.emerald500,
          icon: Icons.fitness_center_rounded,
          unit: 'g',
        );
      case 'fat':
      case 'fats':
        return _MacroConfig(
          color: PremiumColors.amber500,
          icon: Icons.opacity_rounded,
          unit: 'g',
        );
      case 'steps':
        return _MacroConfig(
          color: PremiumColors.slate600,
          icon: Icons.directions_walk_rounded,
          unit: '',
        );
      default:
        return _MacroConfig(
          color: PremiumColors.slate500,
          icon: Icons.pie_chart_rounded,
          unit: 'g',
        );
    }
  }
}

class _MacroConfig {
  final Color color;
  final IconData icon;
  final String unit;

  _MacroConfig({
    required this.color,
    required this.icon,
    required this.unit,
  });
}
