import 'package:flutter/material.dart';
import 'app_theme.dart'; // Import for access to PremiumTypography

/// Legacy typography class maintained for backward compatibility
/// New code should use PremiumTypography from app_theme.dart
class AppTypography {
  // Maintain existing getters for backward compatibility
  static TextStyle get h1 => PremiumTypography.h1;
  static TextStyle get h2 => PremiumTypography.h2;
  static TextStyle get h3 => PremiumTypography.h3;
  static TextStyle get body1 => PremiumTypography.bodyLarge;
  static TextStyle get body2 => PremiumTypography.bodyMedium;
  static TextStyle get caption => PremiumTypography.caption;
  static TextStyle get button => PremiumTypography.button;

  // Legacy special typography - maintained for existing screens
  static TextStyle get onboardingTitle => PremiumTypography.h2.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.3,
      );

  static TextStyle get onboardingSubtitle => PremiumTypography.h3.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
      );

  static TextStyle get onboardingBody => PremiumTypography.bodyLarge.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.1,
      );

  static TextStyle get onboardingButton => PremiumTypography.button.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  // Typography for input fields
  static TextStyle get inputText => PremiumTypography.bodyLarge.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.5,
      );

  static TextStyle get inputLabel => PremiumTypography.label.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      );

  static TextStyle get inputHint => PremiumTypography.bodyMedium.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: PremiumColors.slate400,
      );

  // Additional legacy styles that might be used in existing code
  static TextStyle get subtitle => PremiumTypography.subtitle;
  static TextStyle get label => PremiumTypography.label;
  static TextStyle get bodySmall => PremiumTypography.bodySmall;
  static TextStyle get numeric => PremiumTypography.numeric;

  // Helper methods for common text styling patterns
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  // Theme-aware text styles that adapt to light/dark mode
  static TextStyle primaryText(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return PremiumTypography.bodyLarge.copyWith(
      color: customColors?.textPrimary ?? PremiumColors.slate900,
    );
  }

  static TextStyle secondaryText(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return PremiumTypography.bodyMedium.copyWith(
      color: customColors?.textSecondary ?? PremiumColors.slate600,
    );
  }

  static TextStyle headingText(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return PremiumTypography.h2.copyWith(
      color: customColors?.textPrimary ?? PremiumColors.slate900,
    );
  }

  static TextStyle captionText(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return PremiumTypography.caption.copyWith(
      color: customColors?.textSecondary ?? PremiumColors.slate500,
    );
  }
}
