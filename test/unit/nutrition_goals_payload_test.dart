import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  test('weights that were never loaded (0) are not sent', () {
    provider
      ..goalWeightKg = 0
      ..currentWeightKg = 0;
    final payload = provider.nutritionGoalsPayload();
    expect(payload.containsKey('goal_weight_kg'), isFalse);
    expect(payload.containsKey('current_weight_kg'), isFalse);
    // The rest of the goals still sync.
    expect(payload['calories_goal'], provider.caloriesGoal);
  });

  test('real weights are sent', () {
    provider
      ..goalWeightKg = 72
      ..currentWeightKg = 80.5;
    final payload = provider.nutritionGoalsPayload();
    expect(payload['goal_weight_kg'], 72);
    expect(payload['current_weight_kg'], 80.5);
  });

  test('a goal weight is kept even when the current weight is unknown', () {
    provider
      ..goalWeightKg = 65
      ..currentWeightKg = 0;
    final payload = provider.nutritionGoalsPayload();
    expect(payload['goal_weight_kg'], 65);
    expect(payload.containsKey('current_weight_kg'), isFalse);
  });

  test('carries the calorie and macro goals in both shapes', () {
    provider
      ..caloriesGoal = 2100
      ..proteinGoal = 160
      ..carbsGoal = 200
      ..fatGoal = 70;
    final payload = provider.nutritionGoalsPayload();
    expect(payload, containsPair('calories_goal', 2100));
    expect(payload, containsPair('protein_goal', 160));
    expect(payload, containsPair('carbs_goal', 200));
    expect(payload, containsPair('fat_goal', 70));
    expect(payload['macro_targets'],
        {'calories': 2100, 'protein': 160, 'carbs': 200, 'fat': 70});
    expect(payload['goal_type'], provider.goalType);
    expect(DateTime.parse(payload['updated_at']).isUtc, isTrue);
  });
}
