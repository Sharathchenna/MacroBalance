import 'dart:math';

class MacroCalculatorService {
  // Gender constants
  static const int MALE = 0;
  static const int FEMALE = 1;

  // Activity level multipliers
  static const double SEDENTARY = 1.2;
  static const double LIGHTLY_ACTIVE = 1.375;
  static const double MODERATELY_ACTIVE = 1.55;
  static const double VERY_ACTIVE = 1.725;
  static const double EXTRA_ACTIVE = 1.9;

  // Goals
  static const int GOAL_LOSE = 0;
  static const int GOAL_MAINTAIN = 1;
  static const int GOAL_GAIN = 2;

  // Calculate BMR using Mifflin-St Jeor Equation
  double calculateBMR(int gender, double weightKg, double heightCm, int age) {
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);

    if (gender == MALE) {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    return bmr;
  }

  // Calculate TDEE (Total Daily Energy Expenditure)
  double calculateTDEE(double bmr, double activityMultiplier) {
    return bmr * activityMultiplier;
  }

  // Calculate calorie target based on goal
  int calculateCalorieTarget(double tdee, int goal, int deficit, int gender) {
    switch (goal) {
      case GOAL_LOSE:
        return max((tdee - deficit).round(), (gender == MALE) ? 1500 : 1200);
      case GOAL_GAIN:
        return (tdee + deficit).round();
      case GOAL_MAINTAIN:
      default:
        return tdee.round();
    }
  }

  // Calculate macronutrient targets
  Map<String, int> calculateMacros(double weightKg, int calorieTarget,
      double proteinRatio, double fatRatio) {
    // Calculate protein (g per kg of body weight)
    int proteinGrams = (weightKg * proteinRatio).round();

    // Calculate fat (percentage of total calories)
    int fatGrams = ((calorieTarget * fatRatio) / 9).round();

    // Calculate remaining calories for carbs
    int proteinCalories = proteinGrams * 4;
    int fatCalories = fatGrams * 9;
    int carbCalories = calorieTarget - proteinCalories - fatCalories;
    int carbGrams = (carbCalories / 4).round();

    return {
      'protein': proteinGrams,
      'fat': fatGrams,
      'carbs': carbGrams,
      'calories': calorieTarget
    };
  }

  // Calculate step recommendations
  int recommendSteps(int goal) {
    switch (goal) {
      case GOAL_LOSE:
        return 10000; // Higher step count for weight loss
      case GOAL_GAIN:
        return 6000; // Lower step count to avoid excessive calorie burn
      case GOAL_MAINTAIN:
      default:
        return 8000; // Moderate step count for maintenance
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
    int deficit = 500, // Default deficit/surplus of 500 calories
    double proteinRatio = 1.8, // Default protein g/kg
    double fatRatio = 0.25, // Default fat as 25% of total calories
  }) {
    double bmr = calculateBMR(gender, weightKg, heightCm, age);
    double tdee = calculateTDEE(bmr, activityLevel);
    int calorieTarget = calculateCalorieTarget(tdee, goal, deficit, gender);
    Map<String, int> macros =
        calculateMacros(weightKg, calorieTarget, proteinRatio, fatRatio);
    int steps = recommendSteps(goal);

    return {
      'bmr': bmr.round(),
      'tdee': tdee.round(),
      'calorie_target': calorieTarget,
      'protein': macros['protein'],
      'fat': macros['fat'],
      'carbs': macros['carbs'],
      'recommended_steps': steps,
    };
  }
}
