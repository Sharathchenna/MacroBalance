import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';

class AppleHealthPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  // Removed progress parameter

  const AppleHealthPage({
    super.key,
    required this.onNext,
    required this.onSkip,
    // Removed progress required
  });

  Future<void> _handleConnect(BuildContext context) async {
    final healthService = HealthService();
    try {
      bool granted = await healthService.requestPermissions();
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected to Health')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health permissions were not granted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to Health: ${e.toString()}')),
      );
    } finally {
      onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return Scaffold(
      appBar: AppBar(
        // Added AppBar
        backgroundColor: Colors.transparent,
        elevation: 0,
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back,
        //       color: customColors?.textPrimary ?? theme.colorScheme.onSurface),
        //   onPressed: () => Navigator.pop(context), // Back button action
        // ),
        // Removed LinearProgressIndicator from title
      ),
      body: SafeArea(
        top: false, // AppBar handles top safe area
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              _buildIllustration(context, theme, customColors),
              const Spacer(),
              _buildContent(theme, customColors),
              const SizedBox(height: 32),
              _buildButtons(context, theme, customColors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, CustomColors? customColors) {
    return Column(
      children: [
        Text(
          'Connect to Apple Health',
          style: AppTypography.onboardingTitle.copyWith(
            color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Sync your daily activity between MacroBalance and the Health app to have the most thorough data.',
          style: AppTypography.body1.copyWith(
            color: customColors?.textSecondary ??
                theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildButtons(
      BuildContext context, ThemeData theme, CustomColors? customColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => _handleConnect(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            elevation: 0,
          ),
          child: Text('Connect Health', style: AppTypography.onboardingButton),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor:
                customColors?.textSecondary ?? theme.colorScheme.secondary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            'Not now',
            style: AppTypography.onboardingButton.copyWith(
              color: customColors?.textSecondary ?? theme.colorScheme.secondary,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration(
      BuildContext context, ThemeData theme, CustomColors? customColors) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.3,
      width: size.width,
      child: Center(
        child: SizedBox(
          width: size.width * 0.8,
          height: size.height * 0.25,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Connection lines
              CustomPaint(
                painter: _HealthConnectionsPainter(
                  theme: theme,
                  customColors: customColors,
                ),
                size: Size.infinite,
              ),

              // Health App Icon (left)
              Positioned(
                left: 0,
                top: size.height * 0.12,
                child: _HealthIcon(
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  backgroundColor: Colors.white,
                ),
              ),

              // Checkmark Icon (middle)
              Positioned(
                left: size.width * 0.35,
                top: size.height * 0.08,
                child: _HealthIcon(
                  icon: Icons.check_circle,
                  color: customColors?.textPrimary ?? theme.colorScheme.primary,
                  backgroundColor: Colors.transparent,
                  showContainer: false,
                  size: 32,
                ),
              ),

              // Apple icon (right)
              Positioned(
                right: 0,
                top: size.height * 0.03,
                child: _AppleIcon(
                  customColors: customColors,
                ),
              ),

              // Activity bubbles - upper row
              Positioned(
                left: size.width * 0.05,
                top: 0,
                child: _ActivityBubble(
                    text: 'Walking', theme: theme, customColors: customColors),
              ),
              Positioned(
                right: size.width * 0.05,
                top: size.height * 0.07,
                child: _ActivityBubble(
                    text: 'Yoga', theme: theme, customColors: customColors),
              ),

              // Activity bubbles - lower row
              Positioned(
                left: size.width * 0.15,
                bottom: 0,
                child: _ActivityBubble(
                    text: 'Running', theme: theme, customColors: customColors),
              ),
              Positioned(
                right: size.width * 0.15,
                bottom: size.height * 0.02,
                child: _ActivityBubble(
                    text: 'Sleep', theme: theme, customColors: customColors),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool showContainer;
  final double size;

  const _HealthIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.showContainer = true,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: size);

    if (!showContainer) return iconWidget;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: iconWidget,
    );
  }
}

class _AppleIcon extends StatelessWidget {
  final CustomColors? customColors;

  const _AppleIcon({this.customColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: customColors?.textPrimary ?? Colors.black,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/icons/Apple logo.svg',
        height: 30,
        width: 30,
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _ActivityBubble extends StatelessWidget {
  final String text;
  final ThemeData theme;
  final CustomColors? customColors;

  const _ActivityBubble({
    required this.text,
    required this.theme,
    required this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: customColors?.cardBackground ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: AppTypography.body2.copyWith(
          color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _HealthConnectionsPainter extends CustomPainter {
  final ThemeData theme;
  final CustomColors? customColors;

  _HealthConnectionsPainter({
    required this.theme,
    required this.customColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (customColors?.textSecondary ?? Colors.grey).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Heart to Check connection
    _drawCurvedLine(
      canvas,
      paint,
      Offset(size.width * 0.1, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.4),
    );

    // Check to Apple connection
    _drawCurvedLine(
      canvas,
      paint,
      Offset(size.width * 0.4, size.height * 0.4),
      Offset(size.width * 0.85, size.height * 0.2),
    );
  }

  void _drawCurvedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2 - 20,
        end.dx,
        end.dy,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HealthConnectionsPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.customColors != customColors;
  }
}
