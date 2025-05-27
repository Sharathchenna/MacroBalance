import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    // useMaterial3: true, // Enable Material 3
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    primaryColor: Colors.black,
    colorScheme: ColorScheme.light(
      primary: Colors.black,
      secondary: Colors.black54,
      surface: Colors.white,
      onSurface: Colors.black,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: Colors.black,
      tertiary: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle:
          SystemUiOverlayStyle.dark, // Dark icons for light theme
    ),
    // Add Material 3 card theme with containerColor
    // cardTheme: const CardTheme(
    //   color: Colors.white,
    //   surfaceTintColor: Colors.transparent,
    // ),
    // Add extension colors for custom widgets
    extensions: [
      const CustomColors(
        cardBackground: Colors.white,
        dateNavigatorBackground: Color(0xFFF5F5F5),
        calorieTrackerBackground: Colors.white,
        macroCardBackground: Colors.white,
        textPrimary: Colors.black,
        textSecondary: Colors.black54,
        accentPrimary: Colors.black,
      )
    ],
    textTheme: TextTheme(
      headlineLarge: AppTypography.h1,
      headlineMedium: AppTypography.h2,
      headlineSmall: AppTypography.h3, // Added h3 style
      bodyLarge: AppTypography.body1,
      bodyMedium: AppTypography.body2,
      labelMedium: AppTypography.caption,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    // useMaterial3: true, // Enable Material 3
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    cardColor: Colors.black,
    primaryColor: Colors.white,
    colorScheme: ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white70,
      surface: Colors.black,
      background: Colors.black,
      onSurface: Colors.white,
      onBackground: Colors.white,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      error: Colors.white,
      tertiary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle:
          SystemUiOverlayStyle.light, // Light icons for dark theme
    ),
    // Add Material 3 card theme with containerColor
    // cardTheme: const CardTheme(
    //   color: Color(0xFF1E1E1E),
    //   surfaceTintColor: Colors.transparent,
    // ),
    // Add extension colors for custom widgets
    extensions: [
      const CustomColors(
        cardBackground: Colors.black,
        dateNavigatorBackground: Color(0xFF1A1A1A),
        calorieTrackerBackground: Colors.black,
        macroCardBackground: Colors.black,
        textPrimary: Colors.white,
        textSecondary: Colors.white70,
        accentPrimary: Colors.white,
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
  final Color accentPrimary; // Added accentPrimary property

  const CustomColors({
    required this.cardBackground,
    required this.dateNavigatorBackground,
    required this.calorieTrackerBackground,
    required this.macroCardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentPrimary, // Added accentPrimary parameter
  });

  @override
  CustomColors copyWith({
    Color? cardBackground,
    Color? dateNavigatorBackground,
    Color? calorieTrackerBackground,
    Color? macroCardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentPrimary, // Added accentPrimary parameter to copyWith
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
      accentPrimary: accentPrimary ?? this.accentPrimary, // Added accentPrimary
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
      accentPrimary: Color.lerp(
          accentPrimary, other.accentPrimary, t)!, // Added accentPrimary lerp
    );
  }
}
