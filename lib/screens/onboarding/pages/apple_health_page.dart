import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/services/storage_service.dart';

class AppleHealthPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const AppleHealthPage({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  Future<void> _handleConnect(BuildContext context) async {
    final healthService = HealthService();
    try {
      bool granted = await healthService.requestPermissions();
      StorageService().put('healthConnected', granted);
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
      // Proceed to the next step regardless of connection success/failure for now
      // as per the original logic. Consider refining this based on UX requirements.
      onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return Scaffold(
      // Assuming AppBar with back button and progress is handled by the parent OnboardingScreen
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor, // Use theme background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2), // Add more space at the top
              _buildIllustration(context, theme, customColors),
              const Spacer(flex: 3), // Add more space below illustration
              _buildContent(theme, customColors),
              const Spacer(flex: 1), // Space before buttons
              _buildButtons(context, theme, customColors),
              const SizedBox(height: 24), // Bottom padding
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
          'Connect to\nApple Health', // Use newline for two lines
          style: AppTypography.onboardingTitle.copyWith(
            // Use onboardingTitle style
            color: customColors?.textPrimary ?? theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold, // Make it bold
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          // Using original text, as "Cal AI" seems like a placeholder in the image
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
            backgroundColor:
                theme.colorScheme.primary, // Use theme primary color
            foregroundColor:
                theme.colorScheme.onPrimary, // Use theme onPrimary color
            padding:
                const EdgeInsets.symmetric(vertical: 18), // Slightly taller
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0), // Fully rounded
            ),
            elevation: 0, // No shadow
          ),
          // Changed text to "Continue"
          child: Text('Continue',
              style: AppTypography.onboardingButton.copyWith(
                  fontWeight: FontWeight.bold)), // Use onboardingButton style
        ),
        const SizedBox(height: 16), // Increased spacing
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor:
                customColors?.textSecondary ?? theme.colorScheme.secondary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              // Ensure consistent tap area
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
          child: Text(
            'Not now',
            style: AppTypography.onboardingButton.copyWith(
              // Use onboardingButton style
              color: customColors?.textSecondary ?? theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration(
      BuildContext context, ThemeData theme, CustomColors? customColors) {
    final size = MediaQuery.of(context).size;
    // Estimate height based on image proportions, adjust as needed
    final illustrationHeight = size.height * 0.25;
    final illustrationWidth = size.width * 0.8; // Keep similar width

    return Container(
      height: illustrationHeight,
      width: double.infinity, // Take full width for centering
      child: Center(
        child: SizedBox(
          width: illustrationWidth,
          height: illustrationHeight,
          child: Stack(
            alignment: Alignment.center, // Center stack children
            children: [
              // Faint background circle
              Container(
                width: illustrationWidth * 0.9, // Slightly smaller than stack
                height: illustrationHeight,
                decoration: BoxDecoration(
                  color: (theme.colorScheme.surface)
                      .withOpacity(0.05), // Use theme surface color
                  shape: BoxShape.circle,
                ),
              ),

              // Connection lines
              CustomPaint(
                painter: _HealthConnectionsPainter(
                  theme: theme,
                  customColors: customColors,
                  // Pass relative positions for icons - Adjusted for better visual balance
                  heartPos: const Offset(-0.35, 0.25), // Slightly lower-left
                  checkPos: const Offset(0.0, -0.05), // Slightly lower center
                  applePos: const Offset(0.35, -0.15), // Slightly lower right
                ),
                size: Size(illustrationWidth, illustrationHeight),
              ),

              // Health App Icon (left) - Adjusted position
              Positioned(
                left: illustrationWidth * 0.02, // Further left
                top: illustrationHeight * 0.55, // Slightly lower
                child: _HealthIcon(
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  backgroundColor: Colors.white,
                  size: 35, // Slightly larger
                ),
              ),

              // Checkmark Icon (middle) - Adjusted position
              Positioned(
                // Centered horizontally, slightly above vertical center
                left: illustrationWidth * 0.42, // Slightly right
                top: illustrationHeight * 0.30, // Slightly lower
                child: _HealthIcon(
                  icon: Icons.check_circle,
                  // Use theme primary color for consistency
                  color: theme.colorScheme.primary,
                  backgroundColor: Colors.transparent,
                  showContainer: false,
                  size: 32,
                ),
              ),

              // Apple icon (right) - Adjusted position
              Positioned(
                right: illustrationWidth * 0.02, // Slightly more inset
                top: illustrationHeight * 0.15, // Slightly lower
                child: _AppleIcon(
                  customColors: customColors,
                  size: 35, // Slightly larger
                ),
              ),

              // Activity bubbles - Adjusted positions for better visual balance
              Positioned(
                left: illustrationWidth * 0.0, // Keep left
                top: illustrationHeight * 0.1, // Slightly higher
                child: _ActivityBubble(
                    text: 'Walking', theme: theme, customColors: customColors),
              ),
              Positioned(
                left: illustrationWidth * 0.03, // Slightly inset
                top: illustrationHeight * 0.35, // Slightly higher
                child: _ActivityBubble(
                    text: 'Running', theme: theme, customColors: customColors),
              ),
              Positioned(
                right: illustrationWidth * 0.08, // Slightly inset
                top: illustrationHeight * 0.40, // Slightly lower
                child: _ActivityBubble(
                    text: 'Yoga', theme: theme, customColors: customColors),
              ),
              Positioned(
                right: illustrationWidth * 0.05, // Keep right
                top: illustrationHeight * 0.65, // Slightly higher
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

// --- Helper Widgets (Modified) ---

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

    // Match the image style: white container, rounded corners, subtle shadow
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor, // Should be white for Health icon
        borderRadius: BorderRadius.circular(15), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Softer shadow
            spreadRadius: 1,
            blurRadius: 8,
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
  final double size;

  const _AppleIcon({this.customColors, this.size = 30});

  @override
  Widget build(BuildContext context) {
    // Match the image style: dark container, white logo
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Use a dark color, preferably from theme if available, else fallback
        color: Theme.of(context).colorScheme.primary, // Get theme from context
        borderRadius: BorderRadius.circular(15), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Slightly darker shadow
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/icons/Apple logo.svg', // Ensure this path is correct
        height: size,
        width: size,
        colorFilter: const ColorFilter.mode(
          Colors.white, // White logo
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
    // Match image style: white background, rounded, subtle shadow
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: customColors?.cardBackground ??
            theme.colorScheme.surface, // White/Surface background
        borderRadius: BorderRadius.circular(20), // Pill shape
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Softer shadow
            spreadRadius: 0,
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: AppTypography.body2.copyWith(
          color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500, // Slightly bolder
        ),
      ),
    );
  }
}

// --- Custom Painter (Modified) ---

class _HealthConnectionsPainter extends CustomPainter {
  final ThemeData theme;
  final CustomColors? customColors;
  final Offset heartPos; // Relative position (-0.5 to 0.5) - Corrected typo
  final Offset checkPos; // Relative position
  final Offset applePos; // Relative position

  _HealthConnectionsPainter({
    required this.theme,
    required this.customColors,
    required this.heartPos,
    required this.checkPos,
    required this.applePos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // Use a darker grey or primary color variant
      // Use textSecondary from theme for connection lines
      ..color = (customColors?.textSecondary ?? theme.colorScheme.outline)
          .withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 // Slightly thinner to match image better
      ..strokeCap = StrokeCap.round;

    // Calculate absolute positions based on size and relative offsets
    // Center is (size.width / 2, size.height / 2)
    Offset absHeartPos = Offset(
      size.width / 2 + heartPos.dx * size.width,
      size.height / 2 + heartPos.dy * size.height,
    );
    Offset absCheckPos = Offset(
      size.width / 2 + checkPos.dx * size.width,
      size.height / 2 + checkPos.dy * size.height,
    );
    Offset absApplePos = Offset(
      size.width / 2 + applePos.dx * size.width,
      size.height / 2 + applePos.dy * size.height,
    );

    // Adjust connection points to be closer to the icon centers
    // These are estimations, might need fine-tuning
    Offset heartExit = absHeartPos + const Offset(30, 0); // Exit right
    Offset checkEntryHeart =
        absCheckPos + const Offset(-15, 15); // Enter bottom-left
    Offset checkExitApple =
        absCheckPos + const Offset(15, -15); // Exit top-right
    Offset appleEntry =
        absApplePos + const Offset(-25, 10); // Enter left-bottom

    // Heart to Check connection (Curve downwards)
    _drawCurvedLine(
      canvas,
      paint,
      heartExit,
      checkEntryHeart,
      controlPointOffset: const Offset(0, 30), // Curve downwards
    );

    // Check to Apple connection (Curve upwards)
    _drawCurvedLine(
      canvas,
      paint,
      checkExitApple,
      appleEntry,
      controlPointOffset: const Offset(0, -30), // Curve upwards
    );
  }

  void _drawCurvedLine(Canvas canvas, Paint paint, Offset start, Offset end,
      {Offset controlPointOffset = const Offset(0, -20)}) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    // Calculate control point relative to the midpoint
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final controlX = midX + controlPointOffset.dx;
    final controlY = midY + controlPointOffset.dy;

    path.quadraticBezierTo(
      controlX,
      controlY,
      end.dx,
      end.dy,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HealthConnectionsPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.customColors != customColors ||
        oldDelegate.heartPos != heartPos ||
        oldDelegate.checkPos != checkPos ||
        oldDelegate.applePos != applePos;
  }
}
