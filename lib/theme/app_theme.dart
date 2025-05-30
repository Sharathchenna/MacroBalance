import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

// Premium Color System based on sophisticated slate palette
class PremiumColors {
  // Slate Scale (Main Color System) - Professional and modern
  static const Color slate900 = Color(0xFF0F172A); // Ultra dark - Headers
  static const Color slate800 = Color(0xFF1E293B); // Dark backgrounds
  static const Color slate700 = Color(0xFF334155); // Medium dark accents
  static const Color slate600 = Color(0xFF475569); // Text on light backgrounds
  static const Color slate500 = Color(0xFF64748B); // Subtle text
  static const Color slate400 = Color(0xFF94A3B8); // Placeholder text
  static const Color slate300 = Color(0xFFCBD5E1); // Borders
  static const Color slate200 = Color(0xFFE2E8F0); // Light borders
  static const Color slate100 = Color(0xFFF1F5F9); // Background sections
  static const Color slate50 = Color(0xFFF8FAFC); // Card backgrounds
  static const Color zinc50 = Color(0xFFFAFAFA); // Main background

  // Premium dark theme pastel colors
  static const Color darkBackground = Color(0xFF16161A); // Near black
  static const Color darkSurface = Color(0xFF22222A); // Charcoal gray
  static const Color darkCard = Color(0xFF2A2A33); // Dark gray cards
  static const Color darkContainer =
      Color(0xFF1E1E25); // Slightly lighter than background for containers
  static const Color darkBorder = Color(0xFF3A3A43); // Subtle borders
  static const Color darkText = Color(0xFFF7F7F7); // Off-white
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Light medium gray
  static const Color darkAccent = Color(0xFFF59E0B); // Vibrant orange

  // Pastel accent colors for dark mode
  static const Color pastelBlue = Color(0xFF7DD3FC); // Sky blue
  static const Color pastelPurple = Color(0xFFA78BFA); // Lavender
  static const Color pastelGreen = Color(0xFF86EFAC); // Mint green
  static const Color pastelPink = Color(0xFFFDA4AF); // Soft pink
  static const Color pastelYellow = Color(0xFFFDE047); // Warm yellow
  static const Color pastelOrange = Color(0xFFFB923C); // Peach

  // Premium accent colors (use sparingly for impact)
  static const Color emerald500 = Color(0xFF10B981); // Success
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color red500 = Color(0xFFEF4444); // Error
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color blue500 = Color(0xFF3B82F6); // Primary actions
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color amber500 = Color(0xFFF59E0B); // Warning/Energy
  static const Color amber50 = Color(0xFFFFFBEB);

  // Modern energetic accent colors
  static const Color vibrantOrange =
      Color(0xFFF59E0B); // Primary accent - motivation
  static const Color desaturatedMagenta =
      Color(0xFFD53F8C); // Alternative unique accent
  static const Color softRed = Color(0xFFE53E3E); // Alert/attention
  static const Color energeticBlue = Color(0xFF3182CE); // Supporting blue
  static const Color successGreen = Color(0xFF38A169); // Success states

  // Premium gradients for elevated surfaces
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [slate900, slate800],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFBFC)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
  );

  // Premium dark theme - True dark experience with warm undertones
  static const Color trueDarkBackground =
      Color(0xFF0F0F0F); // Near black with warmth
  static const Color trueDarkCard = Color(0xFF1A1A1A); // Dark charcoal
  static const Color trueDarkSurface = Color(0xFF121212); // True dark surface
  static const Color trueDarkContainer = Color(0xFF1E1E1E); // Elevated surface

  // Dark mode accent colors - optimized for dark backgrounds
  static const Color blue400 = Color(0xFF60A5FA); // Lighter blue for dark bg
  static const Color emerald400 = Color(0xFF34D399); // Success on dark
  static const Color red400 = Color(0xFFF87171); // Error on dark
  static const Color amber400 = Color(0xFFFBBF24); // Warning on dark
}

// Premium Typography System using Inter font for superior readability
class PremiumTypography {
  // Display styles - for hero sections and major headings
  static TextStyle display1 = GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    height: 1.1,
  );

  // Headlines - main titles with proper hierarchy
  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static TextStyle h3 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.4,
  );

  static TextStyle h4 = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );

  // Body text - optimized for readability
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.4,
  );

  // UI Elements
  static TextStyle button = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.3,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.3,
  );

  // Captions and labels
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static TextStyle label = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.3,
  );

  static TextStyle subtitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.5,
  );

  // Special styles for specific use cases
  static TextStyle numeric = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()], // Monospaced numbers
  );
}

// Premium Animation System
class PremiumAnimations {
  // Timing constants for consistent feel
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Premium curves for natural feeling animations
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.bounceOut;
  static const Curve gentle = Curves.easeInOutCubic;
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true, // Enable Material 3 for modern components
    brightness: Brightness.light,
    scaffoldBackgroundColor: PremiumColors.zinc50,
    cardColor: PremiumColors.slate50,
    primaryColor: PremiumColors.slate900,

    colorScheme: ColorScheme.light(
      primary: PremiumColors.slate900,
      secondary: PremiumColors.slate600,
      surface: PremiumColors.slate50,
      surfaceContainer: Colors.white,
      onSurface: PremiumColors.slate800,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: PremiumColors.red500,
      onError: Colors.white,
      tertiary: PremiumColors.blue500,
      onTertiary: Colors.white,
      outline: PremiumColors.slate300,
      outlineVariant: PremiumColors.slate200,
    ),

    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      backgroundColor: Colors.transparent,
      foregroundColor: PremiumColors.slate900,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: PremiumTypography.h3.copyWith(
        color: PremiumColors.slate900,
      ),
    ),

    cardTheme: CardTheme(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: PremiumColors.slate200.withOpacity(0.6),
          width: 1,
        ),
      ),
      shadowColor: PremiumColors.slate900.withOpacity(0.04),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PremiumColors.blue400, // Blue accent instead of white
        foregroundColor: PremiumColors.slate900, // Dark text on blue
        elevation: 2,
        shadowColor: PremiumColors.blue400.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: PremiumTypography.button,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PremiumColors.slate700,
        side: BorderSide(
          color: PremiumColors.slate300,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: PremiumTypography.button,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PremiumColors.slate700,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: PremiumTypography.buttonSmall,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PremiumColors.slate100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.slate200,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.slate200,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.blue500,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.red500,
          width: 1,
        ),
      ),
      labelStyle: PremiumTypography.label.copyWith(
        color: PremiumColors.slate600,
      ),
      hintStyle: PremiumTypography.bodyMedium.copyWith(
        color: PremiumColors.slate400,
      ),
    ),

    // Enhanced theme extensions
    extensions: [
      const CustomColors(
        cardBackground: Colors.white,
        dateNavigatorBackground: PremiumColors.slate100,
        calorieTrackerBackground: Colors.white,
        macroCardBackground: Colors.white,
        textPrimary: PremiumColors.slate900,
        textSecondary: PremiumColors.slate600,
        accentPrimary: PremiumColors.slate900,
      )
    ],

    textTheme: TextTheme(
      displayLarge: PremiumTypography.display1,
      headlineLarge: PremiumTypography.h1,
      headlineMedium: PremiumTypography.h2,
      headlineSmall: PremiumTypography.h3,
      titleLarge: PremiumTypography.h4,
      titleMedium: PremiumTypography.subtitle,
      bodyLarge: PremiumTypography.bodyLarge,
      bodyMedium: PremiumTypography.bodyMedium,
      bodySmall: PremiumTypography.bodySmall,
      labelLarge: PremiumTypography.button,
      labelMedium: PremiumTypography.label,
      labelSmall: PremiumTypography.caption,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor:
        PremiumColors.trueDarkBackground, // Near black with warmth
    cardColor: PremiumColors.trueDarkCard, // Dark charcoal
    primaryColor: PremiumColors.blue400, // Blue accent instead of white
    colorScheme: ColorScheme.dark(
      primary: PremiumColors.blue400, // Primary accent - blue instead of white
      secondary: PremiumColors.slate300, // Secondary actions
      surface: PremiumColors.trueDarkSurface, // True dark surface
      surfaceContainer: PremiumColors.trueDarkContainer, // Elevated surface
      surfaceContainerHighest: PremiumColors.trueDarkCard, // Highest elevation
      surfaceContainerHigh: PremiumColors.trueDarkContainer, // High elevation
      surfaceContainerLow: PremiumColors.trueDarkSurface, // Low elevation
      surfaceContainerLowest:
          PremiumColors.trueDarkBackground, // Lowest elevation
      onSurface: PremiumColors.slate50, // Primary text
      onPrimary: PremiumColors.slate900, // Text on primary (dark text on blue)
      onSecondary: PremiumColors.slate900, // Text on secondary (inverted)
      error: PremiumColors.red400, // Error states optimized for dark
      onError: PremiumColors.slate900, // Text on error (dark text on red)
      tertiary: PremiumColors.emerald400, // Success color
      onTertiary:
          PremiumColors.slate900, // Text on tertiary (dark text on green)
      outline: PremiumColors.slate700, // Borders
      outlineVariant: PremiumColors.slate800, // Dark borders
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: Colors.transparent,
      foregroundColor: PremiumColors.slate50, // Ultra light headers
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: PremiumTypography.h3.copyWith(
        color: PremiumColors.slate50,
      ),
    ),
    cardTheme: CardTheme(
      color: PremiumColors.trueDarkCard, // Dark charcoal cards
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: PremiumColors.slate800.withOpacity(0.6), // Dark borders
          width: 1,
        ),
      ),
      shadowColor: Colors.black.withOpacity(0.4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PremiumColors.blue400, // Blue accent for visibility
        foregroundColor: PremiumColors.slate900, // Dark text on blue
        elevation: 2,
        shadowColor: PremiumColors.blue400.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: PremiumTypography.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PremiumColors.slate300, // Secondary actions
        side: BorderSide(
          color: PremiumColors.slate700, // Clear borders
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: PremiumTypography.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PremiumColors.slate300, // Secondary actions
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: PremiumTypography.buttonSmall,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PremiumColors.slate900, // Input fill color
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.slate700, // Default border
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.slate700, // Default border
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.blue400, // Focused border
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: PremiumColors.red400, // Error border
          width: 1,
        ),
      ),
      labelStyle: PremiumTypography.label.copyWith(
        color: PremiumColors.slate300, // Label text
      ),
      hintStyle: PremiumTypography.bodyMedium.copyWith(
        color: PremiumColors.slate500, // Hint text
      ),
    ),
    extensions: [
      const CustomColors(
        cardBackground: PremiumColors.trueDarkCard, // Dark charcoal cards
        dateNavigatorBackground: PremiumColors.slate900, // Background sections
        calorieTrackerBackground: PremiumColors.trueDarkCard, // Match cards
        macroCardBackground: PremiumColors.trueDarkCard, // Consistency
        textPrimary: PremiumColors.slate50, // Primary text
        textSecondary: PremiumColors.slate300, // Secondary text
        accentPrimary: PremiumColors.blue400, // Blue accent instead of white
      )
    ],
    textTheme: TextTheme(
      displayLarge:
          PremiumTypography.display1.copyWith(color: PremiumColors.slate50),
      headlineLarge:
          PremiumTypography.h1.copyWith(color: PremiumColors.slate50),
      headlineMedium:
          PremiumTypography.h2.copyWith(color: PremiumColors.slate50),
      headlineSmall:
          PremiumTypography.h3.copyWith(color: PremiumColors.slate50),
      titleLarge: PremiumTypography.h4.copyWith(color: PremiumColors.slate50),
      titleMedium:
          PremiumTypography.subtitle.copyWith(color: PremiumColors.slate300),
      bodyLarge:
          PremiumTypography.bodyLarge.copyWith(color: PremiumColors.slate50),
      bodyMedium:
          PremiumTypography.bodyMedium.copyWith(color: PremiumColors.slate300),
      bodySmall:
          PremiumTypography.bodySmall.copyWith(color: PremiumColors.slate400),
      labelLarge:
          PremiumTypography.button.copyWith(color: PremiumColors.slate50),
      labelMedium:
          PremiumTypography.label.copyWith(color: PremiumColors.slate300),
      labelSmall:
          PremiumTypography.caption.copyWith(color: PremiumColors.slate500),
    ),
  );

  // Premium box shadow system
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: PremiumColors.slate900.withOpacity(0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: PremiumColors.slate900.withOpacity(0.02),
          blurRadius: 6,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: PremiumColors.slate900.withOpacity(0.08),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: PremiumColors.slate900.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: PremiumColors.slate900.withOpacity(0.02),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  // Dark theme shadows
  static List<BoxShadow> get darkCardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get darkElevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.6),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get darkSubtleShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];
}

// Enhanced custom colors extension (keeping your existing structure)
@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  final Color cardBackground;
  final Color dateNavigatorBackground;
  final Color calorieTrackerBackground;
  final Color macroCardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentPrimary;

  const CustomColors({
    required this.cardBackground,
    required this.dateNavigatorBackground,
    required this.calorieTrackerBackground,
    required this.macroCardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentPrimary,
  });

  @override
  CustomColors copyWith({
    Color? cardBackground,
    Color? dateNavigatorBackground,
    Color? calorieTrackerBackground,
    Color? macroCardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentPrimary,
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
      accentPrimary: accentPrimary ?? this.accentPrimary,
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
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
    );
  }
}
