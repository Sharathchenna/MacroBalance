import 'package:flutter/material.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F7F3),
    cardColor: Colors.white,
    primaryColor: Colors.black, // Changed to a more vibrant blue
    colorScheme: ColorScheme.light(
      primary: Colors.black87, // Vibrant blue
      secondary: Colors.black54,
      surface: Colors.white,
      onSurface: Colors.black87,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: const Color(0xFFD32F2F),
      tertiary: const Color(0xFF4CAF50), // Added for success states
    ),
    // Add extension colors for custom widgets
    extensions: [
      const CustomColors(
        cardBackground: Colors.white,
        dateNavigatorBackground: Color(0xFFF0E9DF),
        calorieTrackerBackground: Colors.white,
        macroCardBackground: Colors.white,
        textPrimary: Colors.black, // Changed from black87 to full black
        textSecondary: Color(0xFF666666),
      )
    ],
    textTheme: TextTheme(
      headlineLarge: AppTypography.h1,
      headlineMedium: AppTypography.h2,
      bodyLarge: AppTypography.body1,
      bodyMedium: AppTypography.body2,
      labelMedium: AppTypography.caption,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    primaryColor: const Color(0xFF90CAF9), // Lighter blue for dark theme
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF90CAF9), // Lighter blue for better visibility
      secondary: const Color(0xFF81D4FA),
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
      onSurface: Colors.white, // Brighter text on surface
      onBackground: Colors.white,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      error: const Color(0xFFEF5350),
      tertiary: const Color(0xFF81C784), // Added for success states
    ),
    // Add extension colors for custom widgets
    extensions: [
      const CustomColors(
        cardBackground: Color(0xFF1E1E1E),
        dateNavigatorBackground: Color(0xFF2C2C2C),
        calorieTrackerBackground: Color(0xFF1E1E1E),
        macroCardBackground: Color(0xFF1E1E1E),
        textPrimary: Colors.white,
        textSecondary: Color(0xFFAAAAAA),
      )
    ],
  );
}

// Add custom colors extension
@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  final Color cardBackground;
  final Color dateNavigatorBackground;
  final Color calorieTrackerBackground;
  final Color macroCardBackground;
  final Color textPrimary;
  final Color textSecondary;

  const CustomColors({
    required this.cardBackground,
    required this.dateNavigatorBackground,
    required this.calorieTrackerBackground,
    required this.macroCardBackground,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  CustomColors copyWith({
    Color? cardBackground,
    Color? dateNavigatorBackground,
    Color? calorieTrackerBackground,
    Color? macroCardBackground,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return CustomColors(
      cardBackground: cardBackground ?? this.cardBackground,
      dateNavigatorBackground:
          dateNavigatorBackground ?? this.dateNavigatorBackground,
      calorieTrackerBackground:
          calorieTrackerBackground ?? this.calorieTrackerBackground,
      macroCardBackground: macroCardBackground ?? this.macroCardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  ThemeExtension<CustomColors> lerp(
      ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      dateNavigatorBackground: Color.lerp(
          dateNavigatorBackground, other.dateNavigatorBackground, t)!,
      calorieTrackerBackground: Color.lerp(
          calorieTrackerBackground, other.calorieTrackerBackground, t)!,
      macroCardBackground:
          Color.lerp(macroCardBackground, other.macroCardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}
