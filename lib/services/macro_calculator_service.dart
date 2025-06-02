// ignore_for_file: constant_identifier_names

import 'dart:math';

class MacroCalculatorService {
  // Constants
  static const String MALE = 'male';
  static const String FEMALE = 'female';

  static const int SEDENTARY = 1;
  static const int LIGHTLY_ACTIVE = 2;
  static const int MODERATELY_ACTIVE = 3;
  static const int VERY_ACTIVE = 4;
  static const int EXTRA_ACTIVE = 5;

  static const String GOAL_LOSE = 'lose';
  static const String GOAL_MAINTAIN = 'maintain';
  static const String GOAL_GAIN = 'gain';

  // BMR Formulas
  static const int FORMULA_MIFFLIN_ST_JEOR = 1;
  static const int FORMULA_HARRIS_BENEDICT = 2;
  static const int FORMULA_REVISED_HARRIS_BENEDICT = 3;
  static const int FORMULA_KATCH_MCARDLE = 4;

  Map<String, dynamic> calculateAll({
    required String gender,
    required double weightKg,
    required double heightCm,
    required int age,
    required int activityLevel,
    required String goal,
    int?
        deficit, // Renamed from deficit for clarity, represents calorie adjustment
    double? proteinRatio, // e.g., 1.8, 2.0, 2.2 g/kg
    double? fatRatio, // e.g., 0.25 for 25%
    double? goalWeightKg,
    int? bmrFormula,
    double? bodyFatPercentage,
    bool? isAthlete,
    double? overrideTDEE, // Optional: Allow passing in a pre-calculated TDEE
  }) {
    // Use auto-detection if no specific formula is provided
    final selectedFormula = bmrFormula ??
        determineBestFormula(
          gender: gender,
          weightKg: weightKg,
          heightCm: heightCm,
          age: age,
          bodyFatPercentage: bodyFatPercentage,
          isAthlete: isAthlete ?? false,
        );

    // Calculate BMR only if TDEE is not overridden
    double bmr = 0;
    if (overrideTDEE == null) {
      if (selectedFormula == FORMULA_KATCH_MCARDLE &&
          bodyFatPercentage != null) {
        double lbm = weightKg * (1 - (bodyFatPercentage / 100));
        bmr = 370 + (21.6 * lbm);
      } else if (selectedFormula == FORMULA_REVISED_HARRIS_BENEDICT) {
        if (gender == MALE) {
          bmr =
              88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * age);
        } else {
          bmr =
              447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * age);
        }
      } else if (selectedFormula == FORMULA_HARRIS_BENEDICT) {
        if (gender == MALE) {
          bmr = 66.5 + (13.75 * weightKg) + (5.003 * heightCm) - (6.75 * age);
        } else {
          bmr = 655.1 + (9.563 * weightKg) + (1.850 * heightCm) - (4.676 * age);
        }
      } else {
        // Default to Mifflin-St Jeor
        if (gender == MALE) {
          bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
        } else {
          bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
        }
      }
    }

    // Calculate TDEE or use override
    double tdee;
    if (overrideTDEE != null) {
      tdee = overrideTDEE;
      // If TDEE is overridden, BMR calculation might not be relevant unless needed elsewhere
      // For simplicity, we'll leave BMR as 0 or recalculate if needed for display
      // Let's recalculate BMR here just for completeness in the output map, even if TDEE is overridden
      if (selectedFormula == FORMULA_KATCH_MCARDLE &&
          bodyFatPercentage != null) {
        double lbm = weightKg * (1 - (bodyFatPercentage / 100));
        bmr = 370 + (21.6 * lbm);
      } else if (selectedFormula == FORMULA_REVISED_HARRIS_BENEDICT) {
        if (gender == MALE) {
          bmr =
              88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * age);
        } else {
          bmr =
              447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * age);
        }
      } else if (selectedFormula == FORMULA_HARRIS_BENEDICT) {
        if (gender == MALE) {
          bmr = 66.5 + (13.75 * weightKg) + (5.003 * heightCm) - (6.75 * age);
        } else {
          bmr = 655.1 + (9.563 * weightKg) + (1.850 * heightCm) - (4.676 * age);
        }
      } else {
        if (gender == MALE) {
          bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
        } else {
          bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
        }
      }
    } else {
      switch (activityLevel) {
        case SEDENTARY:
          tdee = bmr * 1.2;
          break;
        case LIGHTLY_ACTIVE:
          tdee = bmr * 1.375;
          break;
        case MODERATELY_ACTIVE:
          tdee = bmr * 1.55;
          break;
        case VERY_ACTIVE:
          tdee = bmr * 1.725;
          break;
        case EXTRA_ACTIVE:
          tdee = bmr * 1.9;
          break;
        default:
          tdee = bmr * 1.2;
      }
    }

    // Calculate target calories based on goal and TDEE
    double targetCalories;
    int calorieAdjustment =
        deficit ?? 500; // Use provided deficit/surplus or default to 500
    if (goal == GOAL_LOSE) {
      targetCalories = tdee - calorieAdjustment;
      targetCalories = max(1200, targetCalories); // Ensure minimum calories
    } else if (goal == GOAL_GAIN) {
      targetCalories = tdee + calorieAdjustment;
    } else {
      // Maintain
      targetCalories = tdee;
    }

    // --- Calculate Macros using Helper ---
    // Corrected call to use the public static method
    final Map<String, double> macros = MacroCalculatorService.distributeMacros(
      targetCalories: targetCalories,
      weightKg: weightKg,
      gender: gender, // Pass gender for default protein calculation
      proteinRatio: proteinRatio, // g/kg
      fatRatio: fatRatio, // percentage (e.g., 0.25)
    );
    final proteinG = macros['protein_g']!;
    final fatG = macros['fat_g']!;
    final carbG = macros['carb_g']!;
    final proteinCalories = macros['protein_calories']!;
    final fatCalories = macros['fat_calories']!;
    final carbCalories = macros['carb_calories']!;
    // --- End Macro Calculation ---

    // Calculate weight change rate based on the *actual* calorie adjustment from TDEE
    double weeklyWeightChange = 0;
    if (goal != GOAL_MAINTAIN) {
      // Calculate the actual deficit/surplus achieved
      double actualDeficitSurplus = targetCalories - tdee;
      // 7700 calories = approximately 1 kg of body weight
      weeklyWeightChange = (actualDeficitSurplus * 7) / 7700;
    }

    // Calculate weight-related stats
    Map<String, dynamic> weightStats = {};
    if (goalWeightKg != null &&
        goal != GOAL_MAINTAIN &&
        weeklyWeightChange.abs() > 1e-6) {
      // Avoid division by zero
      final double weightDifference =
          goal == GOAL_LOSE ? weightKg - goalWeightKg : goalWeightKg - weightKg;
      if (weightDifference > 0) {
        // Only calculate if there's weight to lose/gain
        final double weeksToGoal = weightDifference / weeklyWeightChange.abs();
        weightStats = {
          'current_weight': weightKg,
          'goal_weight': goalWeightKg,
          'weight_difference': weightDifference,
          'weekly_change': weeklyWeightChange,
          'weeks_to_goal': weeksToGoal.isFinite ? weeksToGoal : null,
          'days_to_goal': weeksToGoal.isFinite ? weeksToGoal * 7 : null,
          'goal_date': weeksToGoal.isFinite
              ? DateTime.now()
                  .add(Duration(days: (weeksToGoal * 7).round()))
                  .toIso8601String()
              : null,
        };
      } else {
        // Already at or past goal weight
        weightStats = {
          'current_weight': weightKg,
          'goal_weight': goalWeightKg,
          'weight_difference': weightDifference,
          'weekly_change':
              weeklyWeightChange, // Still show potential change rate
          'weeks_to_goal': 0.0,
          'days_to_goal': 0.0,
          'goal_date': DateTime.now().toIso8601String(),
        };
      }
    }

    String getFormulaName(int formula) {
      switch (formula) {
        case FORMULA_MIFFLIN_ST_JEOR:
          return 'Mifflin-St Jeor';
        case FORMULA_HARRIS_BENEDICT:
          return 'Harris-Benedict (Original)';
        case FORMULA_REVISED_HARRIS_BENEDICT:
          return 'Harris-Benedict (Revised)';
        case FORMULA_KATCH_MCARDLE:
          return 'Katch-McArdle';
        default:
          return 'Unknown Formula';
      }
    }

    // Return all calculated values
    return {
      'bmr': bmr.round(),
      'tdee': tdee
          .round(), // The TDEE used for calculations (either calculated or overridden)
      'target_calories': targetCalories.round(),
      'protein_g': proteinG.round(),
      'fat_g': fatG.round(),
      'carb_g': carbG.round(),
      'protein_calories': proteinCalories.round(),
      'fat_calories': fatCalories.round(),
      'carb_calories': carbCalories.round(),
      'protein_percent': targetCalories > 0
          ? (proteinCalories / targetCalories * 100).round()
          : 0,
      'fat_percent':
          targetCalories > 0 ? (fatCalories / targetCalories * 100).round() : 0,
      'carb_percent': targetCalories > 0
          ? (carbCalories / targetCalories * 100).round()
          : 0,
      'weekly_weight_change': weeklyWeightChange,
      'weight_stats': weightStats,
      'formula_used': getFormulaName(selectedFormula),
      'formula_code': selectedFormula,
      'body_fat_percentage': bodyFatPercentage,
      'is_athlete': isAthlete,
    };
  }

  // --- Static Helper for Macro Distribution (Made Public) ---
  static Map<String, double> distributeMacros({
    required double targetCalories,
    required double weightKg,
    required String gender, // Needed for default protein calculation
    double? proteinRatio, // g/kg, e.g., 1.8, 2.0
    double? fatRatio, // percentage, e.g., 0.25 for 25%
  }) {
    // Protein Calculation (g/kg)
    // Use provided ratio, or default based on gender
    final double actualProteinRatio =
        proteinRatio ?? (gender == MALE ? 2.0 : 1.8);
    final double proteinG = weightKg * actualProteinRatio;
    final double proteinCalories = proteinG * 4;

    // Fat Calculation (percentage of total calories)
    // Use provided ratio, or default to 25%
    final double actualFatRatio = fatRatio ?? 0.25;
    final double fatCalories = targetCalories * actualFatRatio;
    final double fatG = fatCalories / 9;

    // Carbohydrate Calculation (remaining calories)
    final double carbCalories = targetCalories - proteinCalories - fatCalories;
    final double carbG = carbCalories / 4;

    // Ensure carbs are not negative (can happen with very high protein/fat ratios or low calories)
    final adjustedCarbG = max(0.0, carbG);
    final adjustedCarbCalories = adjustedCarbG * 4;

    // If carbs were adjusted, recalculate total calories slightly (should be minor)
    // final adjustedTotalCalories = proteinCalories + fatCalories + adjustedCarbCalories;

    return {
      'protein_g': proteinG,
      'fat_g': fatG,
      'carb_g': adjustedCarbG, // Use adjusted value
      'protein_calories': proteinCalories,
      'fat_calories': fatCalories,
      'carb_calories': adjustedCarbCalories, // Use adjusted value
    };
  }
  // --- End Static Helper ---

  // New method to determine the best BMR formula based on user characteristics
  int determineBestFormula({
    required String gender,
    required double weightKg,
    required double heightCm,
    required int age,
    double? bodyFatPercentage,
    required bool isAthlete,
  }) {
    // If body fat percentage is known, Katch-McArdle is generally the most accurate
    if (bodyFatPercentage != null && bodyFatPercentage > 0) {
      // Ensure bodyFat is positive
      return FORMULA_KATCH_MCARDLE;
    }

    // Calculate BMI to help determine the best formula
    if (heightCm <= 0) {
      return FORMULA_MIFFLIN_ST_JEOR; // Avoid division by zero if height is invalid
    }
    double heightMeters = heightCm / 100;
    double bmi = weightKg / (heightMeters * heightMeters);

    // For athletes, Revised Harris-Benedict works well
    if (isAthlete) {
      return FORMULA_REVISED_HARRIS_BENEDICT;
    }

    // For people with normal/average BMI, Mifflin-St Jeor is considered most accurate
    if (bmi >= 18.5 && bmi <= 29.9) {
      return FORMULA_MIFFLIN_ST_JEOR;
    }

    // For people outside normal BMI range, consider alternatives
    if (bmi < 18.5) {
      // For underweight individuals, Revised Harris-Benedict tends to be more accurate
      return FORMULA_REVISED_HARRIS_BENEDICT;
    } else {
      // For those with higher BMI, Mifflin-St Jeor is still generally recommended
      return FORMULA_MIFFLIN_ST_JEOR;
    }
  }
}
