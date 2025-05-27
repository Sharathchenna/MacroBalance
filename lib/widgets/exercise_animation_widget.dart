import 'package:flutter/material.dart';
import 'dart:math' as math;

class ExerciseAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;

  const ExerciseAnimationWidget({
    Key? key,
    required this.exerciseName,
    this.isPlaying = true,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.blueAccent,
  }) : super(key: key);

  @override
  State<ExerciseAnimationWidget> createState() =>
      _ExerciseAnimationWidgetState();
}

class _ExerciseAnimationWidgetState extends State<ExerciseAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _breathingController;
  late Animation<double> _primaryAnimation;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _primaryController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _primaryAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Curves.easeInOut,
    ));

    _breathingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    if (widget.isPlaying) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    _primaryController.repeat(reverse: true);
    _breathingController.repeat(reverse: true);
  }

  void _stopAnimations() {
    _primaryController.stop();
    _breathingController.stop();
  }

  @override
  void didUpdateWidget(ExerciseAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  Widget _buildExerciseSpecificAnimation() {
    final exerciseName = widget.exerciseName.toLowerCase();

    if (exerciseName.contains('push') || exerciseName.contains('press')) {
      return _buildPushUpAnimation();
    } else if (exerciseName.contains('squat')) {
      return _buildSquatAnimation();
    } else if (exerciseName.contains('plank')) {
      return _buildPlankAnimation();
    } else if (exerciseName.contains('lunge')) {
      return _buildLungeAnimation();
    } else if (exerciseName.contains('pull') || exerciseName.contains('row')) {
      return _buildPullAnimation();
    } else if (exerciseName.contains('curl')) {
      return _buildCurlAnimation();
    } else if (exerciseName.contains('burpee')) {
      return _buildBurpeeAnimation();
    } else if (exerciseName.contains('jump') || exerciseName.contains('hop')) {
      return _buildJumpAnimation();
    } else {
      return _buildGenericAnimation();
    }
  }

  Widget _buildPushUpAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 120),
          painter: ModernPushUpPainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildSquatAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 160),
          painter: ModernSquatPainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildPlankAnimation() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 100),
          painter: ModernPlankPainter(
            breathingProgress: _breathingAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildLungeAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(140, 160),
          painter: ModernLungePainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildPullAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(160, 180),
          painter: ModernPullPainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildCurlAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 160),
          painter: ModernCurlPainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildBurpeeAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(180, 120),
          painter: ModernBurpeePainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildJumpAnimation() {
    return AnimatedBuilder(
      animation: _primaryAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 160),
          painter: ModernJumpPainter(
            progress: _primaryAnimation.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildGenericAnimation() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        final scale = 1.0 + (_breathingAnimation.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.primaryColor.withOpacity(0.8),
                  widget.primaryColor,
                  widget.secondaryColor,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _buildExerciseSpecificAnimation(),
    );
  }
}

// Modern Push-up Painter
class ModernPushUpPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernPushUpPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final baseY = size.height * 0.8;

    // Animation: up and down movement
    final pushProgress = math.sin(progress * math.pi);
    final bodyHeight = pushProgress * 25;
    final shoulderY = baseY - 40 - bodyHeight;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, baseY + 15),
        width: 100 + (bodyHeight * 2),
        height: 20,
      ),
      shadowPaint,
    );

    // Head
    canvas.drawCircle(
      Offset(centerX - 60, shoulderY - 20),
      12,
      bodyPaint,
    );

    // Body line (torso)
    canvas.drawLine(
      Offset(centerX - 60, shoulderY),
      Offset(centerX + 60, shoulderY + 15),
      paint,
    );

    // Arms - dynamic positioning
    final armAngle = pushProgress * 0.3;
    canvas.drawLine(
      Offset(centerX - 60, shoulderY),
      Offset(centerX - 90 + (armAngle * 10), baseY + 10),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 30, shoulderY + 8),
      Offset(centerX - 50 + (armAngle * 10), baseY + 10),
      paint,
    );

    // Legs
    canvas.drawLine(
      Offset(centerX + 40, shoulderY + 10),
      Offset(centerX + 70, baseY + 10),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 60, shoulderY + 15),
      Offset(centerX + 90, baseY + 10),
      paint,
    );

    // Motion lines for effect
    if (bodyHeight > 10) {
      final motionPaint = Paint()
        ..color = primaryColor.withOpacity(0.4)
        ..strokeWidth = 2;

      for (int i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(centerX - 80 + (i * 10), shoulderY - 10),
          Offset(centerX - 70 + (i * 10), shoulderY - 5),
          motionPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ModernPushUpPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern Squat Painter
class ModernSquatPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernSquatPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final baseY = size.height * 0.9;

    // Squat animation - smooth up and down
    final squatProgress = math.sin(progress * math.pi);
    final squatDepth = squatProgress * 40;
    final torsoY = baseY - 120 + squatDepth;
    final hipY = baseY - 60 + squatDepth;

    // Head
    canvas.drawCircle(
      Offset(centerX, torsoY - 30),
      14,
      bodyPaint,
    );

    // Torso
    canvas.drawLine(
      Offset(centerX, torsoY - 16),
      Offset(centerX, hipY),
      paint,
    );

    // Arms - extend forward during squat
    final armExtension = squatProgress * 35;
    canvas.drawLine(
      Offset(centerX, torsoY),
      Offset(centerX - 35 - armExtension, torsoY + 15),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, torsoY),
      Offset(centerX + 35 + armExtension, torsoY + 15),
      paint,
    );

    // Thighs - angle based on squat depth
    final thighAngle = squatProgress * 1.4;
    final leftThighEnd = Offset(
      centerX - 15 - (35 * math.sin(thighAngle)),
      hipY + (35 * math.cos(thighAngle)),
    );
    final rightThighEnd = Offset(
      centerX + 15 + (35 * math.sin(thighAngle)),
      hipY + (35 * math.cos(thighAngle)),
    );

    canvas.drawLine(Offset(centerX - 15, hipY), leftThighEnd, paint);
    canvas.drawLine(Offset(centerX + 15, hipY), rightThighEnd, paint);

    // Calves
    canvas.drawLine(leftThighEnd, Offset(centerX - 25, baseY), paint);
    canvas.drawLine(rightThighEnd, Offset(centerX + 25, baseY), paint);

    // Feet
    canvas.drawLine(
      Offset(centerX - 40, baseY),
      Offset(centerX - 10, baseY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 10, baseY),
      Offset(centerX + 40, baseY),
      paint,
    );

    // Ground line
    canvas.drawLine(
      Offset(0, baseY + 5),
      Offset(size.width, baseY + 5),
      Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(ModernSquatPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern Plank Painter
class ModernPlankPainter extends CustomPainter {
  final double breathingProgress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernPlankPainter({
    required this.breathingProgress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Subtle breathing effect
    final breathingOffset = math.sin(breathingProgress * math.pi) * 2;

    // Head
    canvas.drawCircle(
      Offset(centerX - 70, centerY - 15 + breathingOffset),
      10,
      bodyPaint,
    );

    // Body (straight plank line with slight breathing movement)
    canvas.drawLine(
      Offset(centerX - 60, centerY - 5 + breathingOffset),
      Offset(centerX + 70, centerY - 5 + breathingOffset),
      paint,
    );

    // Supporting arms
    canvas.drawLine(
      Offset(centerX - 60, centerY - 5 + breathingOffset),
      Offset(centerX - 70, centerY + 35),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 40, centerY - 5 + breathingOffset),
      Offset(centerX - 50, centerY + 35),
      paint,
    );

    // Supporting legs/feet
    canvas.drawLine(
      Offset(centerX + 50, centerY - 5 + breathingOffset),
      Offset(centerX + 60, centerY + 35),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 70, centerY - 5 + breathingOffset),
      Offset(centerX + 80, centerY + 35),
      paint,
    );

    // Ground line
    canvas.drawLine(
      Offset(0, centerY + 40),
      Offset(size.width, centerY + 40),
      Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..strokeWidth = 2,
    );

    // Stability indicators
    final stabilityPaint = Paint()
      ..color = primaryColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX - 65, centerY + 35), 3, stabilityPaint);
    canvas.drawCircle(Offset(centerX - 45, centerY + 35), 3, stabilityPaint);
    canvas.drawCircle(Offset(centerX + 55, centerY + 35), 3, stabilityPaint);
    canvas.drawCircle(Offset(centerX + 75, centerY + 35), 3, stabilityPaint);
  }

  @override
  bool shouldRepaint(ModernPlankPainter oldDelegate) {
    return oldDelegate.breathingProgress != breathingProgress;
  }
}

// Modern Lunge Painter
class ModernLungePainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernLungePainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final baseY = size.height * 0.9;

    final lungeProgress = math.sin(progress * math.pi);
    final lungeDepth = lungeProgress * 35;
    final torsoY = baseY - 100 + lungeDepth * 0.5;

    // Head
    canvas.drawCircle(
      Offset(centerX, torsoY - 35),
      12,
      bodyPaint,
    );

    // Torso
    canvas.drawLine(
      Offset(centerX, torsoY - 23),
      Offset(centerX, torsoY + 30),
      paint,
    );

    // Arms - balanced positioning
    canvas.drawLine(
      Offset(centerX, torsoY - 5),
      Offset(centerX - 30, torsoY + 15),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, torsoY - 5),
      Offset(centerX + 30, torsoY + 15),
      paint,
    );

    // Front leg (bending)
    final frontKneeY = torsoY + 30 + lungeDepth;
    canvas.drawLine(
      Offset(centerX, torsoY + 30),
      Offset(centerX - 20, frontKneeY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 20, frontKneeY),
      Offset(centerX - 20, baseY),
      paint,
    );

    // Back leg (extending)
    final backLegExtension = lungeProgress * 45;
    canvas.drawLine(
      Offset(centerX, torsoY + 30),
      Offset(centerX + 35 + backLegExtension, baseY),
      paint,
    );

    // Feet with ground contact
    canvas.drawLine(
      Offset(centerX - 35, baseY),
      Offset(centerX - 5, baseY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 25 + backLegExtension, baseY),
      Offset(centerX + 45 + backLegExtension, baseY),
      paint,
    );

    // Movement arrows for direction
    if (lungeDepth > 15) {
      final arrowPaint = Paint()
        ..color = primaryColor.withOpacity(0.5)
        ..strokeWidth = 3;

      canvas.drawLine(
        Offset(centerX + 50, torsoY),
        Offset(centerX + 40, torsoY - 5),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(centerX + 50, torsoY),
        Offset(centerX + 40, torsoY + 5),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ModernLungePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern Pull-up Painter
class ModernPullPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernPullPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final pullProgress = math.sin(progress * math.pi);
    final pullHeight = pullProgress * 40;

    // Pull-up bar
    canvas.drawLine(
      Offset(centerX - 60, 25),
      Offset(centerX + 60, 25),
      barPaint,
    );

    // Bar supports
    canvas.drawLine(
        Offset(centerX - 55, 20), Offset(centerX - 55, 30), barPaint);
    canvas.drawLine(
        Offset(centerX + 55, 20), Offset(centerX + 55, 30), barPaint);

    // Head position changes with pull
    final headY = 70 - pullHeight;
    canvas.drawCircle(
      Offset(centerX, headY),
      12,
      bodyPaint,
    );

    // Torso
    final torsoY = headY + 45;
    canvas.drawLine(
      Offset(centerX, headY + 12),
      Offset(centerX, torsoY),
      paint,
    );

    // Arms to bar - angle changes with pull
    final armAngle = pullProgress * 0.5;
    canvas.drawLine(
      Offset(centerX, headY + 15),
      Offset(centerX - 25 + (armAngle * 10), 25),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, headY + 15),
      Offset(centerX + 25 - (armAngle * 10), 25),
      paint,
    );

    // Legs - slight swing during pull
    final legSwing = pullProgress * 10;
    canvas.drawLine(
      Offset(centerX, torsoY),
      Offset(centerX - 12 + legSwing, torsoY + 55),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, torsoY),
      Offset(centerX + 12 + legSwing, torsoY + 55),
      paint,
    );

    // Effort indicators
    if (pullHeight > 20) {
      final effortPaint = Paint()
        ..color = primaryColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;

      // Sweat drops
      canvas.drawCircle(Offset(centerX - 8, headY - 5), 2, effortPaint);
      canvas.drawCircle(Offset(centerX + 12, headY + 2), 1.5, effortPaint);
    }
  }

  @override
  bool shouldRepaint(ModernPullPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern Curl Painter
class ModernCurlPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernCurlPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final baseY = size.height * 0.9;
    final shoulderY = baseY - 90;

    final curlProgress = math.sin(progress * math.pi);
    final curlAngle = curlProgress * math.pi * 0.7;

    // Head
    canvas.drawCircle(
      Offset(centerX, shoulderY - 25),
      11,
      bodyPaint,
    );

    // Torso
    canvas.drawLine(
      Offset(centerX, shoulderY - 14),
      Offset(centerX, baseY - 35),
      paint,
    );

    // Curling arm
    final forearmX = centerX - 20 + (30 * math.sin(curlAngle));
    final forearmY = shoulderY + 15 - (30 * math.cos(curlAngle));

    canvas.drawLine(
      Offset(centerX, shoulderY),
      Offset(centerX - 20, shoulderY + 25),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 20, shoulderY + 25),
      Offset(forearmX, forearmY),
      paint,
    );

    // Static arm
    canvas.drawLine(
      Offset(centerX, shoulderY),
      Offset(centerX + 20, shoulderY + 25),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 20, shoulderY + 25),
      Offset(centerX + 25, shoulderY + 50),
      paint,
    );

    // Legs
    canvas.drawLine(
      Offset(centerX, baseY - 35),
      Offset(centerX - 15, baseY),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, baseY - 35),
      Offset(centerX + 15, baseY),
      paint,
    );

    // Dumbbell
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(forearmX, forearmY),
          width: 20,
          height: 8,
        ),
        const Radius.circular(4),
      ),
      bodyPaint,
    );

    // Weight plates
    canvas.drawCircle(Offset(forearmX - 8, forearmY), 4, bodyPaint);
    canvas.drawCircle(Offset(forearmX + 8, forearmY), 4, bodyPaint);

    // Motion arc
    if (curlProgress > 0.3) {
      final arcPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(centerX - 20, shoulderY + 25),
          width: 60,
          height: 60,
        ),
        -math.pi / 3,
        curlAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ModernCurlPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern Burpee Painter
class ModernBurpeePainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernBurpeePainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final baseY = size.height * 0.8;

    // Burpee phases: standing -> squat -> plank -> squat -> jump
    final phase = (progress * 4) % 4;

    if (phase < 1) {
      // Squatting down
      _drawSquattingPhase(
          canvas, size, phase, paint, bodyPaint, centerX, baseY);
    } else if (phase < 2) {
      // Plank position
      _drawPlankPhase(
          canvas, size, phase - 1, paint, bodyPaint, centerX, baseY);
    } else if (phase < 3) {
      // Coming back to squat
      _drawSquattingPhase(
          canvas, size, 1 - (phase - 2), paint, bodyPaint, centerX, baseY);
    } else {
      // Jumping
      _drawJumpPhase(canvas, size, phase - 3, paint, bodyPaint, centerX, baseY);
    }
  }

  void _drawSquattingPhase(Canvas canvas, Size size, double phase, Paint paint,
      Paint bodyPaint, double centerX, double baseY) {
    final squatDepth = phase * 30;
    final torsoY = baseY - 80 + squatDepth;

    canvas.drawCircle(Offset(centerX, torsoY - 25), 10, bodyPaint);
    canvas.drawLine(
        Offset(centerX, torsoY - 15), Offset(centerX, torsoY + 20), paint);
    canvas.drawLine(
        Offset(centerX, torsoY), Offset(centerX - 25, torsoY + 10), paint);
    canvas.drawLine(
        Offset(centerX, torsoY), Offset(centerX + 25, torsoY + 10), paint);
    canvas.drawLine(
        Offset(centerX, torsoY + 20), Offset(centerX - 15, baseY), paint);
    canvas.drawLine(
        Offset(centerX, torsoY + 20), Offset(centerX + 15, baseY), paint);
  }

  void _drawPlankPhase(Canvas canvas, Size size, double phase, Paint paint,
      Paint bodyPaint, double centerX, double baseY) {
    final plankY = baseY - 20;
    canvas.drawCircle(Offset(centerX - 50, plankY - 15), 8, bodyPaint);
    canvas.drawLine(
        Offset(centerX - 50, plankY), Offset(centerX + 50, plankY), paint);
    canvas.drawLine(
        Offset(centerX - 50, plankY), Offset(centerX - 60, baseY), paint);
    canvas.drawLine(
        Offset(centerX - 30, plankY), Offset(centerX - 40, baseY), paint);
    canvas.drawLine(
        Offset(centerX + 30, plankY), Offset(centerX + 40, baseY), paint);
    canvas.drawLine(
        Offset(centerX + 50, plankY), Offset(centerX + 60, baseY), paint);
  }

  void _drawJumpPhase(Canvas canvas, Size size, double phase, Paint paint,
      Paint bodyPaint, double centerX, double baseY) {
    final jumpHeight = math.sin(phase * math.pi) * 25;
    final torsoY = baseY - 80 - jumpHeight;

    canvas.drawCircle(Offset(centerX, torsoY - 25), 10, bodyPaint);
    canvas.drawLine(
        Offset(centerX, torsoY - 15), Offset(centerX, torsoY + 20), paint);
    canvas.drawLine(
        Offset(centerX, torsoY), Offset(centerX - 20, torsoY - 15), paint);
    canvas.drawLine(
        Offset(centerX, torsoY), Offset(centerX + 20, torsoY - 15), paint);
    canvas.drawLine(
        Offset(centerX, torsoY + 20), Offset(centerX - 15, baseY), paint);
    canvas.drawLine(
        Offset(centerX, torsoY + 20), Offset(centerX + 15, baseY), paint);

    // Motion lines
    if (jumpHeight > 10) {
      final motionPaint = Paint()
        ..color = primaryColor.withOpacity(0.4)
        ..strokeWidth = 2;
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(centerX - 30 + (i * 20), torsoY + 30 + jumpHeight),
          Offset(centerX - 25 + (i * 20), torsoY + 40 + jumpHeight),
          motionPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ModernBurpeePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern Jump Painter
class ModernJumpPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  ModernJumpPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final baseY = size.height * 0.9;

    final jumpProgress = math.sin(progress * math.pi);
    final jumpHeight = jumpProgress * 35;
    final torsoY = baseY - 80 - jumpHeight;

    // Crouch preparation and landing
    final legBend = (1 - jumpProgress) * 0.5;

    // Head
    canvas.drawCircle(
      Offset(centerX, torsoY - 25),
      12,
      bodyPaint,
    );

    // Torso
    canvas.drawLine(
      Offset(centerX, torsoY - 13),
      Offset(centerX, torsoY + 25),
      paint,
    );

    // Arms - swing with jump
    final armSwing = jumpProgress * 30;
    canvas.drawLine(
      Offset(centerX, torsoY - 5),
      Offset(centerX - 25, torsoY - 10 - armSwing),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, torsoY - 5),
      Offset(centerX + 25, torsoY - 10 - armSwing),
      paint,
    );

    // Legs - bend based on jump phase
    final legAngle = legBend * 0.8;
    canvas.drawLine(
      Offset(centerX, torsoY + 25),
      Offset(centerX - 15 - (legAngle * 20), baseY - (jumpHeight * 0.3)),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, torsoY + 25),
      Offset(centerX + 15 + (legAngle * 20), baseY - (jumpHeight * 0.3)),
      paint,
    );

    // Ground impact indicators
    if (jumpHeight < 5 && jumpHeight > 0) {
      final impactPaint = Paint()
        ..color = primaryColor.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX, baseY + 5),
          width: 40,
          height: 8,
        ),
        impactPaint,
      );
    }

    // Air time effects
    if (jumpHeight > 15) {
      final airPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..strokeWidth = 2;

      for (int i = 0; i < 4; i++) {
        canvas.drawLine(
          Offset(centerX - 40 + (i * 20), baseY + 10),
          Offset(centerX - 35 + (i * 20), baseY + 15),
          airPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ModernJumpPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
