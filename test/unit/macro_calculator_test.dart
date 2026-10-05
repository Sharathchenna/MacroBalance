import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';

void main() {
  final calc = MacroCalculatorService();

  Map<String, dynamic> run({
    String gender = MacroCalculatorService.MALE,
    double weightKg = 80,
    double heightCm = 180,
    int age = 30,
    int activity = 3,
    String goal = MacroCalculatorService.GOAL_MAINTAIN,
    int? deficit,
    double? goalWeightKg,
  }) =>
      calc.calculateAll(
        gender: gender,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        activityLevel: activity,
        goal: goal,
        deficit: deficit,
        goalWeightKg: goalWeightKg,
      );

  num n(Map<String, dynamic> r, String k) => r[k] as num;

  test('produces every value the app reads', () {
    final r = run();
    for (final key in ['bmr', 'tdee', 'target_calories', 'protein_g', 'carb_g', 'fat_g']) {
      expect(r[key], isA<num>(), reason: key);
      expect((r[key] as num).isFinite, isTrue, reason: key);
      expect(r[key] as num, greaterThan(0), reason: key);
    }
  });

  test('Mifflin-St Jeor BMR for an 80 kg, 180 cm, 30-year-old man', () {
    // 10*80 + 6.25*180 - 5*30 + 5 = 1780
    final r = calc.calculateAll(
      gender: MacroCalculatorService.MALE,
      weightKg: 80,
      heightCm: 180,
      age: 30,
      activityLevel: 3,
      goal: MacroCalculatorService.GOAL_MAINTAIN,
      bmrFormula: MacroCalculatorService.FORMULA_MIFFLIN_ST_JEOR,
    );
    expect(n(r, 'bmr'), closeTo(1780, 1));
  });

  test('women get a lower BMR than men of the same size', () {
    expect(n(run(gender: MacroCalculatorService.FEMALE), 'bmr'),
        lessThan(n(run(), 'bmr')));
  });

  test('more activity means a higher TDEE', () {
    expect(n(run(activity: 5), 'tdee'), greaterThan(n(run(activity: 1), 'tdee')));
  });

  test('losing targets fewer calories than maintaining, gaining more', () {
    final maintain = n(run(), 'target_calories');
    expect(n(run(goal: MacroCalculatorService.GOAL_LOSE, deficit: 500, goalWeightKg: 75),
        'target_calories'), lessThan(maintain));
    expect(n(run(goal: MacroCalculatorService.GOAL_GAIN, deficit: 300, goalWeightKg: 85),
        'target_calories'), greaterThan(maintain));
  });

  test('macro calories roughly add up to the calorie target', () {
    for (final goal in [
      MacroCalculatorService.GOAL_LOSE,
      MacroCalculatorService.GOAL_MAINTAIN,
      MacroCalculatorService.GOAL_GAIN,
    ]) {
      final r = run(goal: goal, deficit: 400, goalWeightKg: 78);
      final macroKcal = n(r, 'protein_g') * 4 + n(r, 'carb_g') * 4 + n(r, 'fat_g') * 9;
      expect(macroKcal, closeTo(n(r, 'target_calories'), n(r, 'target_calories') * 0.05),
          reason: goal);
    }
  });

  test('extreme but valid inputs never give NaN or negative values', () {
    for (final r in [
      run(weightKg: 40, heightCm: 145, age: 80, activity: 1),
      run(weightKg: 200, heightCm: 210, age: 18, activity: 5),
      run(goal: MacroCalculatorService.GOAL_LOSE, deficit: 1000, weightKg: 50, goalWeightKg: 45),
    ]) {
      for (final key in ['bmr', 'tdee', 'target_calories', 'protein_g', 'carb_g', 'fat_g']) {
        final v = r[key] as num;
        expect(v.isFinite && v >= 0, isTrue, reason: '$key = $v');
      }
    }
  });
}
