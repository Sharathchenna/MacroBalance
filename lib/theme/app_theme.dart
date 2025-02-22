import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F4F0),
    cardColor: Colors.white,
    primaryColor: Colors.black87,
    colorScheme: const ColorScheme.light(
      primary: Colors.black87,
      secondary: Colors.blue,
      surface: Colors.white,
      onSurface: Color(0xFFE0E0E0),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      // onSurface: Colors.black87,
    ),
    // Add extension colors for custom widgets
    extensions: [
      const CustomColors(
        cardBackground: Colors.white,
        dateNavigatorBackground: Color(0xFFF0E9DF),
        calorieTrackerBackground: Colors.white,
        macroCardBackground: Colors.white,
        textPrimary: Colors.black87,
        textSecondary: Color(0xFF666666),
      )
    ],
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    primaryColor: Colors.white,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.blue,
      surface: Color(0xFF1E1E1E),
      onSurface: Color(0xFF1E1E1E),
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      // onSurface: Colors.white,
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
