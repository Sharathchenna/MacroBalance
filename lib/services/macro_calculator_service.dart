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
    int? deficit,
    double? proteinRatio,
    double? fatRatio,
    double? goalWeightKg,
    // bmrFormula parameter is optional now - the service will determine the best one
    int? bmrFormula,
    double? bodyFatPercentage,
    bool? isAthlete,
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

    // First, calculate BMR using the selected formula
    double bmr;
    if (selectedFormula == FORMULA_KATCH_MCARDLE && bodyFatPercentage != null) {
      // Calculate lean body mass
      double lbm = weightKg * (1 - (bodyFatPercentage / 100));
      // Katch-McArdle Formula
      bmr = 370 + (21.6 * lbm);
    } else if (selectedFormula == FORMULA_REVISED_HARRIS_BENEDICT) {
      // Revised Harris-Benedict Equation (1984)
      if (gender == MALE) {
        bmr = 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * age);
      } else {
        bmr = 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * age);
      }
    } else if (selectedFormula == FORMULA_HARRIS_BENEDICT) {
      // Original Harris-Benedict Equation (1919)
      if (gender == MALE) {
        bmr = 66.5 + (13.75 * weightKg) + (5.003 * heightCm) - (6.75 * age);
      } else {
        bmr = 655.1 + (9.563 * weightKg) + (1.850 * heightCm) - (4.676 * age);
      }
    } else {
      // Default to Mifflin-St Jeor Equation (most accurate for general population)
      if (gender == MALE) {
        bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
      } else {
        bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
      }
    }

    // Calculate TDEE (Total Daily Energy Expenditure)
    double tdee;
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
        tdee = bmr * 1.2; // Default to sedentary
    }

    // Calculate target calories based on goal
    double targetCalories;
    if (goal == GOAL_LOSE) {
      targetCalories = tdee - (deficit ?? 500);
      // Ensure minimum calories threshold met (safety)
      targetCalories = max(1200, targetCalories);
    } else if (goal == GOAL_GAIN) {
      targetCalories = tdee + (deficit ?? 500);
    } else {
      // Maintain
      targetCalories = tdee;
    }

    // Calculate macros based on target calories
    final protein = proteinRatio != null
        ? weightKg * proteinRatio
        : (gender == MALE ? weightKg * 2.0 : weightKg * 1.8);
    final proteinCalories = protein * 4;

    final fatPercent = fatRatio ?? 0.25;
    final fatCalories = targetCalories * fatPercent;
    final fat = fatCalories / 9;

    final carbCalories = targetCalories - proteinCalories - fatCalories;
    final carb = carbCalories / 4;

    // Calculate weight change rate
    double weeklyWeightChange = 0;
    if (goal != GOAL_MAINTAIN) {
      // 7700 calories = approximately 1 kg of body fat
      weeklyWeightChange =
          ((goal == GOAL_LOSE ? -1 : 1) * (deficit ?? 500) * 7) / 7700;
    }

    // Calculate weight-related stats
    Map<String, dynamic> weightStats = {};
    if (goalWeightKg != null && goal != GOAL_MAINTAIN) {
      final double weightDifference =
          goal == GOAL_LOSE ? weightKg - goalWeightKg : goalWeightKg - weightKg;
      
      if (weeklyWeightChange != 0) {
        final double weeksToGoal = weightDifference / weeklyWeightChange.abs();
        weightStats = {
          'current_weight': weightKg,
          'goal_weight': goalWeightKg,
          'weight_difference': weightDifference,
          'weekly_change': weeklyWeightChange,
          'weeks_to_goal': weeksToGoal,
          'days_to_goal': weeksToGoal * 7,
          'goal_date': DateTime.now().add(Duration(days: (weeksToGoal * 7).round())).toIso8601String(),
        };
      }
    }

    String getFormulaName(int formula) {
      switch(formula) {
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
      'tdee': tdee.round(),
      'target_calories': targetCalories.round(),
      'protein_g': protein.round(),
      'fat_g': fat.round(),
      'carb_g': carb.round(),
      'protein_calories': proteinCalories.round(),
      'fat_calories': fatCalories.round(),
      'carb_calories': carbCalories.round(),
      'protein_percent': (proteinCalories / targetCalories * 100).round(),
      'fat_percent': (fatCalories / targetCalories * 100).round(),
      'carb_percent': (carbCalories / targetCalories * 100).round(),
      'weekly_weight_change': weeklyWeightChange,
      'weight_stats': weightStats,
      'formula_used': getFormulaName(selectedFormula),
      'formula_code': selectedFormula,
      'body_fat_percentage': bodyFatPercentage,
      'is_athlete': isAthlete,
    };
  }

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
    if (bodyFatPercentage != null) {
      return FORMULA_KATCH_MCARDLE;
    }
    
    // Calculate BMI to help determine the best formula
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
