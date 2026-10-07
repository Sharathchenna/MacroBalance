import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
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
            'deficit_surplus': 500,
            'height_cm': 180,
            'body_fat_pct': null,
            'protein_ratio': null,
            'fat_ratio': null,
          }));
      final g = GoalsProvider();
      await g.recalculateMacroGoals(2800);
      expect(g.caloriesGoal, 2300);
      expect(g.proteinGoal, 162); // 81 × 2.0
      expect(g.proteinGoal * 4 + g.carbsGoal * 4 + g.fatGoal * 9, closeTo(2300, 5));
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
  });
}
