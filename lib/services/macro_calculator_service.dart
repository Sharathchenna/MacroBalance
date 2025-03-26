import 'dart:math';

class MacroCalculatorService {
  // Gender constants
  static const int MALE = 0;
  static const int FEMALE = 1;

  // Activity level multipliers - Updated based on recent research
  static const double SEDENTARY = 1.2;
  static const double LIGHTLY_ACTIVE = 1.375;
  static const double MODERATELY_ACTIVE = 1.55;
  static const double VERY_ACTIVE = 1.725;
  static const double EXTRA_ACTIVE = 1.9;

  // Goals
  static const int GOAL_LOSE = 0;
  static const int GOAL_MAINTAIN = 1;
  static const int GOAL_GAIN = 2;

  // BMR Formula types
  static const int FORMULA_MIFFLIN_ST_JEOR = 0; // Default, most accurate for general population
  static const int FORMULA_HARRIS_BENEDICT = 1; // Original equation
  static const int FORMULA_REVISED_HARRIS_BENEDICT = 2; // Revised in 1984
  static const int FORMULA_KATCH_MCARDLE = 3; // For those who know body fat %

  // Calculate BMR using multiple formulas based on scientific research
  double calculateBMR(int gender, double weightKg, double heightCm, int age, {int formula = FORMULA_MIFFLIN_ST_JEOR, double? bodyFatPercentage}) {
    // Default to Mifflin-St Jeor (most accurate according to research)
    switch (formula) {
      case FORMULA_MIFFLIN_ST_JEOR:
        // Mifflin-St Jeor Equation (1990) - endorsed by the Academy of Nutrition and Dietetics
        double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
        return gender == MALE ? bmr + 5 : bmr - 161;
        
      case FORMULA_HARRIS_BENEDICT:
        // Original Harris-Benedict Equation (1919)
        if (gender == MALE) {
          return 66.47 + (13.75 * weightKg) + (5.003 * heightCm) - (6.755 * age);
        } else {
          return 655.1 + (9.563 * weightKg) + (1.85 * heightCm) - (4.676 * age);
        }
        
      case FORMULA_REVISED_HARRIS_BENEDICT:
        // Revised Harris-Benedict Equation by Roza and Shizgal (1984)
        if (gender == MALE) {
          return 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * age);
        } else {
          return 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.33 * age);
        }
        
      case FORMULA_KATCH_MCARDLE:
        // Katch-McArdle Formula (1996) - accounts for body composition
        if (bodyFatPercentage != null) {
          double leanBodyMass = weightKg * (1 - (bodyFatPercentage / 100));
          return 370 + (21.6 * leanBodyMass);
        } else {
          // Fall back to Mifflin-St Jeor if body fat % not provided
          double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
          return gender == MALE ? bmr + 5 : bmr - 161;
        }
        
      default:
        // Default to Mifflin-St Jeor
        double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
        return gender == MALE ? bmr + 5 : bmr - 161;
    }
  }

  // Calculate TDEE (Total Daily Energy Expenditure)
  double calculateTDEE(double bmr, double activityMultiplier) {
    return bmr * activityMultiplier;
  }

  // Calculate calorie target based on goal
  int calculateCalorieTarget(double tdee, int goal, int deficit, int gender) {
    // Minimum safe calorie intakes based on Harvard Medical School and NIH recommendations
    final int maleMinimumCalories = 1500;
    final int femaleMinimumCalories = 1200;
    
    switch (goal) {
      case GOAL_LOSE:
        // Ensure deficit doesn't go below safe minimum
        return max((tdee - deficit).round(), (gender == MALE) ? maleMinimumCalories : femaleMinimumCalories);
      case GOAL_GAIN:
        // For muscle gain, ISSN recommends surplus of 350-500 calories
        return (tdee + deficit).round();
      case GOAL_MAINTAIN:
      default:
        return tdee.round();
    }
  }

  // Calculate goal weight timeframe (in weeks)
  double calculateGoalTimeframe(double currentWeightKg, double goalWeightKg, int calorieTarget, double tdee) {
    // Based on scientific consensus: 1kg of fat ≈ 7700 calories
    double calorieDeficitSurplusPerDay = (tdee - calorieTarget).abs();
    double weightDifferenceKg = (currentWeightKg - goalWeightKg).abs();
    double caloriesNeeded = weightDifferenceKg * 7700;
    
    // Calculate days and convert to weeks
    double days = caloriesNeeded / calorieDeficitSurplusPerDay;
    return days / 7;
  }

  // Calculate recommended weight loss/gain rate (kg per week)
  double calculateRecommendedRate(int goal, int gender) {
    // NIH and Harvard recommendations: safe weight change is 0.5-1kg per week
    switch (goal) {
      case GOAL_LOSE:
        return gender == MALE ? 0.9 : 0.7; // Men can safely lose slightly more
      case GOAL_GAIN:
        return 0.5; // ISSN recommends 0.25-0.5kg/week for muscle gain
      default:
        return 0.0;
    }
  }

  // Calculate macronutrient targets based on ISSN recommendations
  Map<String, int> calculateMacros(double weightKg, int calorieTarget,
      double proteinRatio, double fatRatio, int goal) {
    
    // ISSN protein recommendations: 1.6-2.2g/kg for active individuals
    // Higher for cutting, lower for bulking
    double adjustedProteinRatio = proteinRatio;
    if (goal == GOAL_LOSE && proteinRatio < 2.0) {
      adjustedProteinRatio = 2.0; // Higher protein for preservation during weight loss
    }
    
    // Calculate protein (g per kg of body weight)
    int proteinGrams = (weightKg * adjustedProteinRatio).round();

    // Calculate fat (percentage of total calories)
    // Harvard and NIH recommend 20-35% of calories from healthy fats
    int fatGrams = ((calorieTarget * fatRatio) / 9).round();

    // Calculate remaining calories for carbs
    int proteinCalories = proteinGrams * 4;
    int fatCalories = fatGrams * 9;
    int carbCalories = calorieTarget - proteinCalories - fatCalories;
    int carbGrams = (carbCalories / 4).round();

    return {
      'protein': proteinGrams,
      'fat': fatGrams,
      'carbs': max(carbGrams, 50), // Minimum 50g carbs recommended by NIH
      'calories': calorieTarget
    };
  }

  // Calculate step recommendations based on physical activity guidelines
  int recommendSteps(int goal) {
    // Based on CDC and American Heart Association guidelines
    switch (goal) {
      case GOAL_LOSE:
        return 12000; // Higher step count for weight loss
      case GOAL_GAIN:
        return 7500; // Moderate step count for muscle gain
      case GOAL_MAINTAIN:
      default:
        return 10000; // Standard recommendation
    }
  }

  // Main calculation function that brings it all together
  Map<String, dynamic> calculateAll({
    required int gender,
    required double weightKg,
    required double heightCm,
    required int age,
    required double activityLevel,
    required int goal,
    double? goalWeightKg,
    int deficit = 500, // Default deficit/surplus of 500 calories
    double proteinRatio = 1.8, // Default protein g/kg
    double fatRatio = 0.25, // Default fat as 25% of total calories
    double? bodyFatPercentage,
    int bmrFormula = FORMULA_MIFFLIN_ST_JEOR,
  }) {
    double bmr = calculateBMR(gender, weightKg, heightCm, age, formula: bmrFormula, bodyFatPercentage: bodyFatPercentage);
    double tdee = calculateTDEE(bmr, activityLevel);
    int calorieTarget = calculateCalorieTarget(tdee, goal, deficit, gender);
    Map<String, int> macros = calculateMacros(weightKg, calorieTarget, proteinRatio, fatRatio, goal);
    int steps = recommendSteps(goal);
    
    // Goal weight related calculations
    double recommendedWeeklyRate = calculateRecommendedRate(goal, gender);
    double timeframeWeeks = 0;
    
    if (goalWeightKg != null && goalWeightKg > 0) {
      timeframeWeeks = calculateGoalTimeframe(weightKg, goalWeightKg, calorieTarget, tdee);
    }

    return {
      'bmr': bmr.round(),
      'tdee': tdee.round(),
      'calorie_target': calorieTarget,
      'protein': macros['protein'],
      'fat': macros['fat'],
      'carbs': macros['carbs'],
      'recommended_steps': steps,
      'recommended_weekly_rate': recommendedWeeklyRate,
      'goal_timeframe_weeks': timeframeWeeks.round(),
      'goal_weight_kg': goalWeightKg,
    };
  }
}
