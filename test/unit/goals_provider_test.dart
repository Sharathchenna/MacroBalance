import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in [
      'nutrition_goals',
      'calories_goal',
      'protein_goal',
      'carbs_goal',
      'fat_goal',
      'goal_settings',
    ]) {
      await StorageService().delete(key);
    }
    goals = GoalsProvider();
  });

  test('weights that were never loaded (0) are not sent', () {
    goals
      ..goalWeightKg = 0
      ..currentWeightKg = 0;
    final payload = goals.userMacrosPayload();
    expect(payload.containsKey('goal_weight_kg'), isFalse);
    expect(payload.containsKey('current_weight_kg'), isFalse);
    // The rest of the goals still sync.
    expect(payload['calories_goal'], goals.caloriesGoal);
  });

  test('real weights are sent', () {
    goals
      ..goalWeightKg = 72
      ..currentWeightKg = 80.5;
    final payload = goals.userMacrosPayload();
    expect(payload['goal_weight_kg'], 72);
    expect(payload['current_weight_kg'], 80.5);
  });

  test('a goal weight is kept even when the current weight is unknown', () {
    goals
      ..goalWeightKg = 65
      ..currentWeightKg = 0;
    final payload = goals.userMacrosPayload();
    expect(payload['goal_weight_kg'], 65);
    expect(payload.containsKey('current_weight_kg'), isFalse);
  });

  test('carries the calorie and macro goals in both shapes', () {
    goals
      ..caloriesGoal = 2100
      ..proteinGoal = 160
      ..carbsGoal = 200
      ..fatGoal = 70;
    final payload = goals.userMacrosPayload();
    expect(payload, containsPair('calories_goal', 2100));
    expect(payload, containsPair('protein_goal', 160));
    expect(payload, containsPair('carbs_goal', 200));
    expect(payload, containsPair('fat_goal', 70));
    expect(payload['macro_targets'],
        {'calories': 2100, 'protein': 160, 'carbs': 200, 'fat': 70});
    expect(payload['goal_type'], goals.goalType);
    expect(DateTime.parse(payload['updated_at']).isUtc, isTrue);
  });

  test('starts from the defaults when nothing is saved', () {
    expect(goals.caloriesGoal, 2000);
    expect(goals.proteinGoal, 150);
    expect(goals.carbsGoal, 225);
    expect(goals.fatGoal, 65);
    expect(goals.goalType, MacroCalculatorService.GOAL_MAINTAIN);
  });

  test('changes are saved on the device and read back', () {
    goals
      ..caloriesGoal = 2400
      ..proteinGoal = 180
      ..stepsGoal = 8000
      ..currentWeightKg = 82
      ..goalWeightKg = 76;

    final reloaded = GoalsProvider();
    expect(reloaded.caloriesGoal, 2400);
    expect(reloaded.proteinGoal, 180);
    expect(reloaded.stepsGoal, 8000);
    expect(reloaded.currentWeightKg, 82);
    expect(reloaded.goalWeightKg, 76);
  });

  test('restores the account goals at sign-in when the device has none', () async {
    await GoalsProvider.cacheUserMacros({
      'calories_goal': 1800,
      'protein_goal': 140,
      'carbs_goal': 170,
      'fat_goal': 60,
    });
    await goals.load();
    expect(goals.caloriesGoal, 1800);
    expect(goals.proteinGoal, 140);
    expect(goals.carbsGoal, 170);
    expect(goals.fatGoal, 60);
  });

  test("the device's own goals win over the sign-in fallback", () async {
    goals.caloriesGoal = 2600;
    await GoalsProvider.cacheUserMacros({'calories_goal': 1800});
    await goals.load();
    expect(goals.caloriesGoal, 2600);
  });

  test('clearing returns to the defaults and forgets the saved goals', () async {
    goals
      ..caloriesGoal = 2600
      ..goalWeightKg = 70;
    await goals.clearUserData();
    expect(goals.caloriesGoal, 2000);
    expect(goals.goalWeightKg, 0);
    expect(GoalsProvider().caloriesGoal, 2000);
  });

  group('recalculateMacroGoals', () {
    test('uses the profile onboarding saved: protein from the capped reference weight', () async {
      // 120 kg at 180 cm: reference weight is the BMI-25 weight, 81 kg.
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            'macro_targets': {'calories': 2500, 'protein': 150, 'carbs': 250, 'fat': 70},
            'current_weight_kg': 120,
            'goal_type': MacroCalculatorService.GOAL_LOSE,
            'pace_pct_per_week': 0.25,
            'sex': MacroCalculatorService.MALE,
            'age': 30,
            'height_cm': 180,
            'body_fat_pct': null,
            'protein_ratio': null,
            'fat_ratio': null,
          }));
      final g = GoalsProvider();
      await g.recalculateMacroGoals(2800);
      final ed = energyDensity(
          fatMassKg(weightKg: 120, heightCm: 180, age: 30, sex: Sex.male));
      final cals = (2800 - 0.0025 * 120 * ed / 7).roundToDouble();
      expect(g.caloriesGoal, cals);
      expect(g.proteinGoal, 162); // 81 × 2.0
      expect(g.proteinGoal * 4 + g.carbsGoal * 4 + g.fatGoal * 9, closeTo(cals, 5));
    });

    test('keeps the split inputs when it saves', () async {
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            'current_weight_kg': 70,
            'height_cm': 175,
            'body_fat_pct': 18,
            'protein_ratio': 2.2,
            'fat_ratio': 0.3,
          }));
      final g = GoalsProvider();
      await g.recalculateMacroGoals(2400);
      final saved = jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['height_cm'], 175);
      expect(saved['body_fat_pct'], 18);
      expect(saved['protein_ratio'], 2.2);
      expect(saved['fat_ratio'], 0.3);
      expect(g.proteinGoal, (70 * 0.82 * 2.2).round());
    });

    test('goes through the safety limits: never under the floor for the sex', () async {
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            'current_weight_kg': 60,
            'goal_type': MacroCalculatorService.GOAL_LOSE,
            'pace_pct_per_week': 1.0,
            'sex': MacroCalculatorService.MALE,
            'age': 50,
            'height_cm': 165,
          }));
      final g = GoalsProvider();
      await g.recalculateMacroGoals(1700);
      expect(g.caloriesGoal, 1500);
    });

    test('changing the pace recalculates the targets', () async {
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            'current_weight_kg': 80,
            'goal_type': MacroCalculatorService.GOAL_LOSE,
            'sex': MacroCalculatorService.MALE,
            'age': 30,
            'height_cm': 180,
            'tdee': 2800,
          }));
      final g = GoalsProvider();
      expect(g.pacePctPerWeek, 0.5); // recommended
      await g.recalculateMacroGoals(2800);
      final atHalf = g.caloriesGoal;
      g.pacePctPerWeek = 0.25;
      await Future<void>.delayed(Duration.zero);
      expect(g.caloriesGoal, greaterThan(atHalf));
      final saved = jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['pace_pct_per_week'], 0.25);
      expect(saved.containsKey('deficit_surplus'), isFalse);
    });
  });

  group('sync', () {
    test('sends the pace and goal settings, and no deficit', () async {
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            'current_weight_kg': 80,
            'goal_type': MacroCalculatorService.GOAL_LOSE,
            'pace_pct_per_week': 0.75,
            'sex': MacroCalculatorService.FEMALE,
            'age': 34,
            'activity_level': 3,
            'formula_tdee': 2210.4,
            'height_cm': 168,
            'body_fat_pct': 28,
            'protein_ratio': 2.2,
            'fat_ratio': 0.3,
          }));
      final payload = GoalsProvider().userMacrosPayload();
      expect(payload['pace_pct_per_week'], 0.75);
      expect(payload['sex'], 'female');
      expect(payload['age'], 34);
      expect(payload['activity_level'], 3);
      expect(payload['formula_tdee'], 2210);
      expect(payload['height_cm'], 168);
      expect(payload['body_fat_pct'], 28);
      expect(payload['protein_g_per_kg'], 2.2);
      expect(payload['fat_ratio'], 0.3);
      expect(payload.containsKey('deficit_surplus'), isFalse);
    });

    test('maintaining sends no pace; an unknown profile is not sent', () {
      final payload = goals.userMacrosPayload();
      expect(payload['pace_pct_per_week'], isNull);
      for (final key in ['sex', 'age', 'activity_level', 'height_cm', 'formula_tdee']) {
        expect(payload.containsKey(key), isFalse, reason: key);
      }
    });

    test('sign-in restores the pace and settings from the account', () async {
      await GoalsProvider.cacheUserMacros({
        'calories_goal': 1900,
        'goal_type': MacroCalculatorService.GOAL_GAIN,
        'pace_pct_per_week': 0.1,
        'sex': 'male',
        'age': 41,
        'height_cm': 181.5,
        'protein_g_per_kg': 1.8,
        'current_weight_kg': 70,
      });
      final g = GoalsProvider();
      expect(g.caloriesGoal, 1900);
      expect(g.goalType, MacroCalculatorService.GOAL_GAIN);
      expect(g.pacePctPerWeek, 0.1);
      final payload = g.userMacrosPayload();
      expect(payload['sex'], 'male');
      expect(payload['age'], 41);
      expect(payload['height_cm'], 181.5);
      expect(payload['protein_g_per_kg'], 1.8);
    });
  });
  group('profile (sex, height, age)', () {
    Future<void> seed({String? recordedOn}) => StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2000, 'protein': 150, 'carbs': 200, 'fat': 60},
          'current_weight_kg': 80,
          'goal_weight_kg': 75,
          'goal_type': MacroCalculatorService.GOAL_LOSE,
          'pace_pct_per_week': 0.5,
          'sex': MacroCalculatorService.MALE,
          'age': 30,
          'age_recorded_on': recordedOn,
          'activity_level': 3,
          'height_cm': 180,
        }));

    test('the age in use goes up with the whole years since it was recorded', () async {
      await seed(recordedOn: '2025-06-15');
      expect(GoalsProvider(clock: () => DateTime(2026, 6, 14)).age, 30);
      expect(GoalsProvider(clock: () => DateTime(2026, 6, 15)).age, 31);
    });

    test('an age with no record date is used as it is', () async {
      await seed();
      expect(GoalsProvider(clock: () => DateTime(2040, 1, 1)).age, 30);
    });

    test('saving an age records today and syncs both', () async {
      await seed(recordedOn: '2020-01-01');
      final g = GoalsProvider(clock: () => DateTime(2026, 3, 9));
      await g.saveProfile(age: 45);
      expect(g.age, 45);
      final payload = g.userMacrosPayload();
      expect(payload['age'], 45);
      expect(payload['age_recorded_on'], '2026-03-09');
      final saved = jsonDecode(StorageService().get('nutrition_goals'));
      expect(saved['age_recorded_on'], '2026-03-09');
      expect(GoalsProvider(clock: () => DateTime(2027, 3, 9)).age, 46);
    });

    test('previewing changes nothing; the preview matches what saving does', () async {
      await seed();
      final g = GoalsProvider(clock: () => DateTime(2026, 3, 9));
      final change = g.previewProfile(heightCm: 160)!;
      expect(change.before.calories, 2000);
      expect(change.after.calories, isNot(2000));
      expect(g.caloriesGoal, 2000);
      expect(g.heightCm, 180);
      await g.saveProfile(heightCm: 160);
      expect(g.heightCm, 160);
      expect(g.caloriesGoal, change.after.calories);
      expect(g.proteinGoal, change.after.protein);
      expect(g.carbsGoal, change.after.carbs);
      expect(g.fatGoal, change.after.fat);
    });

    test('a lower height or a switch to female lowers the targets; older age too', () async {
      await seed();
      final g = GoalsProvider(clock: () => DateTime(2026, 3, 9));
      expect(g.previewProfile(heightCm: 165)!.after.calories,
          lessThan(g.previewProfile(heightCm: 180)!.after.calories));
      expect(g.previewProfile(sex: MacroCalculatorService.FEMALE)!.after.calories,
          lessThan(g.previewProfile(sex: MacroCalculatorService.MALE)!.after.calories));
      expect(g.previewProfile(age: 50)!.after.calories,
          lessThan(g.previewProfile(age: 30)!.after.calories));
    });

    test('the new targets come from the formula expenditure at the chosen pace', () async {
      await seed();
      final g = GoalsProvider(clock: () => DateTime(2026, 3, 9));
      await g.saveProfile(sex: MacroCalculatorService.FEMALE);
      // Mifflin: 10·80 + 6.25·180 − 5·30 − 161 = 1614 → × 1.55
      expect(g.tdee, closeTo(1614 * 1.55, 0.01));
      expect(g.bmr, closeTo(1614, 0.01));
      expect(g.userMacrosPayload()['sex'], 'female');
    });

    test('there is nothing to preview without a current weight', () {
      expect(goals.previewProfile(age: 40), isNull);
    });

    test('sign-in restores the age record date', () async {
      await GoalsProvider.cacheUserMacros({
        'calories_goal': 1900,
        'age': 41,
        'age_recorded_on': '2025-01-02',
      });
      final g = GoalsProvider(clock: () => DateTime(2026, 1, 2));
      expect(g.age, 42);
    });
  });
}
