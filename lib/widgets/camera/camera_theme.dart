import 'package:flutter/material.dart';

class CameraTheme {
  // Premium UI Colors - Enhanced
  static const Color accentColor = Color(0xFF47B9D1); // Sky blue accent
  static const Color premiumGold = Color(0xFFEDC953); // Rich gold
  static const Color premiumGoldLight = Color(0xFFF4E891); // Light gold
  static const Color premiumGoldDark = Color(0xFFD4AF37); // Dark gold
  static const Color darkOverlay = Color(0x80000000); // Enhanced overlay
  static const Color premiumBackground = Color(0xF01C1C1E); // Premium dark
  static const Color glassmorphicBackground = Color(0x1AFFFFFF); // Glass effect
  static const Color cardBackground = Color(0x26FFFFFF); // Card background

  // Sizes - Optimized for modern screens
  static const double buttonSize = 48.0;
  static const double shutterSize = 84.0;
  static const double borderRadius = 24.0;
  static const double floatingButtonSize = 56.0;
  static const double iconSize = 24.0;
  static const double smallIconSize = 20.0;

  // Enhanced Shadows
  static const List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x20000000),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> goldGlow = [
    BoxShadow(
      color: Color(0x60EDC953), // Enhanced gold glow
      offset: Offset(0, 0),
      blurRadius: 12,
      spreadRadius: 2,
    ),
  ];

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x30000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  // Premium Button Decorations
  static BoxDecoration get premiumButton => BoxDecoration(
        color: glassmorphicBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: premiumGold.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: softShadow,
      );

  static BoxDecoration get floatingButton => BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: premiumShadow,
      );

  static BoxDecoration get shutterButton => BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: premiumGold.withValues(alpha: 0.2),
            offset: const Offset(0, 0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      );

  static BoxDecoration get guideOverlay => BoxDecoration(
        border: Border.all(
          color: premiumGold,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: goldGlow,
      );

  static BoxDecoration get selectedModeButton => BoxDecoration(
        color: premiumGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: premiumGold,
          width: 2,
        ),
        boxShadow: goldGlow,
      );

  static BoxDecoration get unselectedModeButton => BoxDecoration(
        color: glassmorphicBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: softShadow,
      );

  // Enhanced Text Styles
  static const TextStyle instructionText = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    shadows: [
      Shadow(
        color: Color(0x60000000),
        offset: Offset(0, 2),
        blurRadius: 4,
      ),
    ],
  );

  static const TextStyle modeText = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const TextStyle selectedModeText = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    shadows: [
      Shadow(
        color: Color(0x40EDC953),
        offset: Offset(0, 1),
        blurRadius: 2,
      ),
    ],
  );

  // Premium Gradients
  static const LinearGradient topBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x90000000), // Enhanced opacity
      Color(0x40000000),
      Color(0x00000000), // Fade to transparent
    ],
  );

  static const LinearGradient bottomControlsGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      Color(0x90000000),
      Color(0x40000000),
      Color(0x00000000),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      premiumGoldLight,
      premiumGold,
      premiumGoldDark,
    ],
  );

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 250);
  static const Duration slowAnimation = Duration(milliseconds: 400);
}
