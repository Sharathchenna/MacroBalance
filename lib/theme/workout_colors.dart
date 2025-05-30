import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Workout-specific color categories for better visual organization
/// Using muted, professional colors that match the app's theme
class WorkoutColors {
  // Category-based colors - muted and professional
  static const Color strengthSlate =
      PremiumColors.slate600; // Strength workouts
  static const Color cardioBlue =
      PremiumColors.energeticBlue; // Cardio workouts
  static const Color flexibilityPurple =
      PremiumColors.desaturatedMagenta; // Flexibility/Yoga
  static const Color hybridGreen = PremiumColors.successGreen; // Mixed workouts
  static const Color restGray = PremiumColors.slate500; // Rest days
  static const Color hiitAmber = PremiumColors.vibrantOrange; // HIIT workouts

  // Lighter variants for backgrounds and borders
  static const Color strengthLight = PremiumColors.slate200;
  static const Color cardioLight = PremiumColors.blue50;
  static const Color flexibilityLight = Color(0xFFF3E8FF); // Light purple
  static const Color hybridLight = PremiumColors.emerald50;
  static const Color hiitLight = PremiumColors.amber50;

  // Gradient combinations using existing colors
  static const LinearGradient strengthGradient = LinearGradient(
    colors: [PremiumColors.slate600, PremiumColors.slate500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardioGradient = LinearGradient(
    colors: [PremiumColors.energeticBlue, PremiumColors.blue500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient flexibilityGradient = LinearGradient(
    colors: [PremiumColors.desaturatedMagenta, Color(0xFFB83280)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hybridGradient = LinearGradient(
    colors: [PremiumColors.successGreen, PremiumColors.emerald500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hiitGradient = LinearGradient(
    colors: [PremiumColors.vibrantOrange, PremiumColors.amber500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Get color based on workout type - using app's existing palette
  static Color getWorkoutCategoryColor(
      String workoutType, List<String> targetMuscles) {
    final type = workoutType.toLowerCase();
    final musclesStr = targetMuscles.join(' ').toLowerCase();

    if (type.contains('hiit') || type.contains('interval')) {
      return hiitAmber;
    } else if (type.contains('cardio') ||
        type.contains('running') ||
        type.contains('cycling')) {
      return cardioBlue;
    } else if (type.contains('yoga') ||
        type.contains('flexibility') ||
        type.contains('stretch')) {
      return flexibilityPurple;
    } else if (musclesStr.contains('chest') ||
        musclesStr.contains('arms') ||
        musclesStr.contains('shoulders') ||
        type.contains('strength')) {
      return strengthSlate;
    } else if (type.contains('full body') || type.contains('circuit')) {
      return hybridGreen;
    }

    return strengthSlate; // Default to sophisticated slate
  }

  /// Get light background color for workout category
  static Color getWorkoutCategoryLightColor(
      String workoutType, List<String> targetMuscles) {
    final type = workoutType.toLowerCase();
    final musclesStr = targetMuscles.join(' ').toLowerCase();

    if (type.contains('hiit') || type.contains('interval')) {
      return hiitLight;
    } else if (type.contains('cardio') ||
        type.contains('running') ||
        type.contains('cycling')) {
      return cardioLight;
    } else if (type.contains('yoga') ||
        type.contains('flexibility') ||
        type.contains('stretch')) {
      return flexibilityLight;
    } else if (musclesStr.contains('chest') ||
        musclesStr.contains('arms') ||
        musclesStr.contains('shoulders') ||
        type.contains('strength')) {
      return strengthLight;
    } else if (type.contains('full body') || type.contains('circuit')) {
      return hybridLight;
    }

    return strengthLight; // Default
  }

  /// Get gradient based on workout type - using muted gradients
  static LinearGradient getWorkoutGradient(
      String workoutType, List<String> targetMuscles) {
    final type = workoutType.toLowerCase();
    final musclesStr = targetMuscles.join(' ').toLowerCase();

    if (type.contains('hiit') || type.contains('interval')) {
      return hiitGradient;
    } else if (type.contains('cardio') ||
        type.contains('running') ||
        type.contains('cycling')) {
      return cardioGradient;
    } else if (type.contains('yoga') ||
        type.contains('flexibility') ||
        type.contains('stretch')) {
      return flexibilityGradient;
    } else if (musclesStr.contains('chest') ||
        musclesStr.contains('arms') ||
        musclesStr.contains('shoulders') ||
        type.contains('strength')) {
      return strengthGradient;
    } else if (type.contains('full body') || type.contains('circuit')) {
      return hybridGradient;
    }

    return strengthGradient; // Default
  }

  /// Difficulty colors using existing palette
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return PremiumColors.successGreen;
      case 'intermediate':
        return PremiumColors.vibrantOrange;
      case 'advanced':
        return PremiumColors.softRed;
      default:
        return PremiumColors.slate500;
    }
  }
}

/// Enhanced animation curves and durations
class WorkoutAnimations {
  static const Duration quickAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration verySlowAnimation = Duration(milliseconds: 800);

  static const Curve elasticCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve gentleCurve = Curves.easeOutQuart;
}
