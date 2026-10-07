import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/targets.dart';

/// Onboarding's view of the goal maths: takes the app's string and int codes
/// and returns the results map the results screen and goal storage read. The
/// maths itself lives in `lib/services/energy/`.
class MacroCalculatorService {
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

  static Sex sexOf(String gender) => gender == FEMALE ? Sex.female : Sex.male;

  static GoalKind goalKindOf(String goal) => switch (goal) {
        GOAL_LOSE => GoalKind.lose,
        GOAL_GAIN => GoalKind.gain,
        _ => GoalKind.maintain,
      };

  /// Cals per kg of weight change for this body (Hall/Forbes).
  static double energyDensityFor({
    required String gender,
    required double weightKg,
    required double heightCm,
    required int age,
    double? bodyFatPercentage,
  }) =>
      energyDensity(fatMassKg(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        sex: sexOf(gender),
        bodyFatPct: bodyFatPercentage,
      ));

  /// [bodyFatPercentage] must be null unless the user entered one from a scan
  /// or smart scale. [proteinRatio] (g/kg of reference weight) is null for the
  /// default table.
  Map<String, dynamic> calculateAll({
    required String gender,
    required double weightKg,
    required double heightCm,
    required int age,
    required int activityLevel,
    required String goal,
    double? pacePct, // % of body weight a week; null: the recommended pace
    double? proteinRatio,
    double? fatRatio,
    double? goalWeightKg,
    double? bodyFatPercentage,
  }) {
    final sex = sexOf(gender);
    final bmr = basalMetabolicRate(
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      bodyFatPct: bodyFatPercentage,
    );
    final tdee = formulaTdee(
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      activityLevel: activityLevel,
      bodyFatPct: bodyFatPercentage,
    );

    final kcalPerKg = energyDensityFor(
      gender: gender,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      bodyFatPercentage: bodyFatPercentage,
    );
    final goalKind = goalKindOf(goal);
    final target = targetForPace(
      goal: goalKind,
      pacePct: pacePct ?? defaultPacePct(goalKind),
      tdee: tdee,
      sex: sex,
      weightKg: weightKg,
      energyDensity: kcalPerKg,
    );
    final targetCalories = target.cals;

    final macros = splitMacros(
      cals: targetCalories,
      goal: goalKind,
      weightKg: weightKg,
      heightCm: heightCm,
      bodyFatPct: bodyFatPercentage,
      proteinPerKg: proteinRatio,
      fatRatio: fatRatio,
    );
    final proteinCalories = macros.proteinG * 4;
    final carbCalories = macros.carbsG * 4;
    final fatCalories = macros.fatG * 9;

    final weeklyWeightChange =
        goal == GOAL_MAINTAIN ? 0.0 : (targetCalories - tdee) * 7 / kcalPerKg;

    Map<String, dynamic> weightStats = {};
    final weeks = goalWeightKg == null || goal == GOAL_MAINTAIN
        ? null
        : weeksToGoal(
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            tdee: tdee,
            cals: targetCalories,
            energyDensity: kcalPerKg,
          );
    if (weeks != null) {
      weightStats = {
        'current_weight': weightKg,
        'goal_weight': goalWeightKg,
        'weight_difference': (goalWeightKg! - weightKg).abs(),
        'weekly_change': weeklyWeightChange,
        'weeks_to_goal': weeks,
        'days_to_goal': weeks * 7,
        'goal_date':
            DateTime.now().add(Duration(days: (weeks * 7).round())).toIso8601String(),
      };
    }

    int percentOf(int cals) =>
        targetCalories > 0 ? (cals / targetCalories * 100).round() : 0;

    return {
      'goal': goal,
      'bmr': bmr.round(),
      'tdee': tdee.round(),
      'target_calories': targetCalories.round(),
      'protein_g': macros.proteinG,
      'fat_g': macros.fatG,
      'carb_g': macros.carbsG,
      'protein_calories': proteinCalories,
      'fat_calories': fatCalories,
      'carb_calories': carbCalories,
      'protein_percent': percentOf(proteinCalories),
      'fat_percent': percentOf(fatCalories),
      'carb_percent': percentOf(carbCalories),
      'weekly_weight_change': weeklyWeightChange,
      'pace_pct_per_week': target.pacePct,
      'effective_pace_pct': target.effectivePacePct,
      'limit_hit': target.limitHit?.name,
      'energy_density': kcalPerKg.round(),
      'weight_stats': weightStats,
      'formula_used': bodyFatPercentage == null
          ? 'Mifflin-St Jeor'
          : 'Mifflin-St Jeor + Katch-McArdle',
      'body_fat_percentage': bodyFatPercentage,
    };
  }
}
