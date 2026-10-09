import 'dart:math';

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
    double? pacePct,
    double? goalWeightKg,
    double? tdee,
  }) =>
      calc.calculateAll(
        gender: gender,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        activityLevel: activity,
        goal: goal,
        pacePct: pacePct,
        goalWeightKg: goalWeightKg,
        tdee: tdee,
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
    final r = run();
    expect(n(r, 'bmr'), closeTo(1780, 1));
    expect(r['formula_used'], 'Mifflin-St Jeor');
  });

  test('Mifflin-St Jeor is used for every body shape: no formula switching', () {
    // Underweight (BMI 15.4) used to switch to Harris-Benedict.
    final r = run(weightKg: 50, heightCm: 180);
    expect(n(r, 'bmr'), closeTo(10 * 50 + 6.25 * 180 - 5 * 30 + 5, 1));
  });

  test('a scanned body fat % averages in Katch-McArdle', () {
    final r = calc.calculateAll(
      gender: MacroCalculatorService.MALE,
      weightKg: 80,
      heightCm: 180,
      age: 30,
      activityLevel: 3,
      goal: MacroCalculatorService.GOAL_MAINTAIN,
      bodyFatPercentage: 15,
    );
    expect(n(r, 'bmr'), closeTo((1780 + 370 + 21.6 * 68) / 2, 1));
    expect(r['formula_used'], 'Mifflin-St Jeor + Katch-McArdle');
  });

  test('weekly change uses the body\'s energy density, not 7,700 per kg', () {
    final r = run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 0.5, goalWeightKg: 75);
    final ed = n(r, 'energy_density');
    expect(ed, isNot(7700));
    expect(n(r, 'weekly_weight_change'),
        closeTo((n(r, 'target_calories') - n(r, 'tdee')) * 7 / ed, 0.01));
    expect(n(r, 'weekly_weight_change'), closeTo(-0.4, 0.01)); // 0.5% of 80 kg
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
    expect(n(run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 0.5, goalWeightKg: 75),
        'target_calories'), lessThan(maintain));
    expect(n(run(goal: MacroCalculatorService.GOAL_GAIN, pacePct: 0.25, goalWeightKg: 85),
        'target_calories'), greaterThan(maintain));
  });

  test('macro calories add up to the calorie target', () {
    for (final goal in [
      MacroCalculatorService.GOAL_LOSE,
      MacroCalculatorService.GOAL_MAINTAIN,
      MacroCalculatorService.GOAL_GAIN,
    ]) {
      final r = run(goal: goal, pacePct: 0.5, goalWeightKg: 78);
      final macroKcal = n(r, 'protein_g') * 4 + n(r, 'carb_g') * 4 + n(r, 'fat_g') * 9;
      expect(macroKcal, closeTo(n(r, 'target_calories'), 5), reason: goal);
    }
  });

  test('extreme but valid inputs never give NaN or negative values', () {
    for (final r in [
      run(weightKg: 40, heightCm: 145, age: 80, activity: 1),
      run(weightKg: 200, heightCm: 210, age: 18, activity: 5),
      run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 1.0, weightKg: 50, goalWeightKg: 45),
    ]) {
      for (final key in ['bmr', 'tdee', 'target_calories', 'protein_g', 'carb_g', 'fat_g']) {
        final v = r[key] as num;
        expect(v.isFinite && v >= 0, isTrue, reason: '$key = $v');
      }
    }
  });

  test('the target comes from the pace, through the safety limits', () {
    final r = run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 0.5, goalWeightKg: 75);
    final ed = n(r, 'energy_density');
    expect(n(r, 'target_calories'), closeTo(n(r, 'tdee') - 0.005 * 80 * ed / 7, 1));
    expect(r['pace_pct_per_week'], 0.5);
    expect(r['limit_hit'], isNull);

    // 1%/week is more than a 25% deficit for this man.
    final fast = run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 1.0, goalWeightKg: 75);
    expect(n(fast, 'target_calories'), closeTo(n(fast, 'tdee') * 0.75, 1));
    expect(fast['limit_hit'], 'maxDeficit');
    expect(n(fast, 'effective_pace_pct'), lessThan(1.0));
  });

  test('a learned expenditure replaces the formula, which is still reported', () {
    final formula = run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 0.5, goalWeightKg: 75);
    expect(formula['tdee_learned'], isFalse);
    expect(formula['formula_tdee'], formula['tdee']);

    final learned = run(
        goal: MacroCalculatorService.GOAL_LOSE, pacePct: 0.5, goalWeightKg: 75, tdee: 3000);
    expect(learned['tdee_learned'], isTrue);
    expect(learned['tdee'], 3000);
    expect(learned['formula_tdee'], formula['tdee']);
    final ed = n(learned, 'energy_density');
    expect(n(learned, 'target_calories'), closeTo(3000 - 0.005 * 80 * ed / 7, 1));
    // Weeks to goal and the weekly change follow the learned value too.
    expect(n(learned, 'weekly_weight_change'),
        closeTo((n(learned, 'target_calories') - 3000) * 7 / ed, 0.01));
  });

  test('no pace means the recommended one', () {
    expect(run(goal: MacroCalculatorService.GOAL_LOSE, goalWeightKg: 75)['pace_pct_per_week'], 0.5);
    expect(run(goal: MacroCalculatorService.GOAL_GAIN, goalWeightKg: 85)['pace_pct_per_week'], 0.25);
  });

  test('a small woman is never set below 1,200 cals', () {
    final r = run(
      gender: MacroCalculatorService.FEMALE,
      weightKg: 45,
      heightCm: 150,
      age: 60,
      activity: 1,
      goal: MacroCalculatorService.GOAL_LOSE,
      pacePct: 1.0,
      goalWeightKg: 42,
    );
    expect(n(r, 'target_calories'), 1200);
    expect(r['limit_hit'], 'floor');
  });

  test('weeks to goal come from the projection', () {
    final r = run(goal: MacroCalculatorService.GOAL_LOSE, pacePct: 0.5, goalWeightKg: 75);
    final stats = r['weight_stats'] as Map;
    final weeks = (stats['weeks_to_goal'] as num).toDouble();
    // 0.5% of the current weight a week (adaptive re-plans each week).
    final from = (stats['current_weight'] as num).toDouble();
    expect(weeks, closeTo(log(75 / from) / log(0.995), 0.1));
    expect(stats['weeks_low'], closeTo(0.85 * weeks, 1e-9));
    expect(stats['weeks_high'], closeTo(1.25 * weeks, 1e-9));
  });
}
