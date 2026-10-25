import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours for the intro and onboarding (docs/onboarding-redesign, Palette
/// board). Dark is the main look; light follows the app's light theme.
@immutable
class ObColors {
  const ObColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.text,
    required this.text2,
    required this.muted,
    required this.leaf,
    required this.onLeaf,
    required this.leafText,
    required this.sun,
    required this.onSun,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color raised;
  final Color line;
  final Color text;
  final Color text2;
  final Color muted;

  /// Brand green: buttons, progress, selection.
  final Color leaf;
  final Color onLeaf;

  /// Green for text on [bg] or [surface], readable in both themes.
  final Color leafText;

  /// Highlights and the occasional warm accent (streaks, caps).
  final Color sun;
  final Color onSun;

  final Color protein;
  final Color carbs;
  final Color fat;
  final bool isDark;

  static const dark = ObColors(
    bg: Color(0xFF0C0E0D),
    surface: Color(0xFF151917),
    raised: Color(0xFF1D221F),
    line: Color(0xFF2A302C),
    text: Color(0xFFF4F6F4),
    text2: Color(0xFFA3ADA6),
    muted: Color(0xFF7C8680),
    leaf: Color(0xFF57D883),
    onLeaf: Color(0xFF06240F),
    leafText: Color(0xFF57D883),
    sun: Color(0xFFFFD23F),
    onSun: Color(0xFF2A1E00),
    protein: Color(0xFFFF6B5E),
    carbs: Color(0xFF4DA8FF),
    fat: Color(0xFFF59E3B),
    isDark: true,
  );

  static const light = ObColors(
    bg: Color(0xFFF6F5F0),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEEECE5),
    line: Color(0xFFE0DDD4),
    text: Color(0xFF111412),
    text2: Color(0xFF545C56),
    muted: Color(0xFF6F776F),
    leaf: Color(0xFF57D883),
    onLeaf: Color(0xFF06240F),
    leafText: Color(0xFF1B7F45),
    sun: Color(0xFFFFD23F),
    onSun: Color(0xFF2A1E00),
    protein: Color(0xFFE5483B),
    carbs: Color(0xFF1F7FD6),
    fat: Color(0xFF9A560A),
    isDark: false,
  );

  static ObColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Type for the intro and onboarding: Onest for display, Inter for body.
/// Both are bundled in assets/google_fonts.
class ObText {
  static TextStyle display(double size, {Color? color, double height = 1.12}) =>
      GoogleFonts.onest(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -size / 32,
        height: height,
        color: color,
      );

  /// Page titles.
  static TextStyle h1(Color color) => display(32, color: color);

  /// Option titles and card headings.
  static TextStyle title(Color color, {double size = 17}) => GoogleFonts.onest(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: color,
      );

  static TextStyle body(Color color, {double size = 15, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, height: 1.5, color: color);

  /// Small caps line above a title ("YOUR GOAL").
  static TextStyle eyebrow(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: color,
      );

  static TextStyle button(Color color) => GoogleFonts.onest(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
      );
}

/// Motion used across onboarding.
class ObMotion {
  static const rise = Duration(milliseconds: 700);
  static const stagger = Duration(milliseconds: 80);
  static const curve = Cubic(.2, .8, .2, 1);
}
