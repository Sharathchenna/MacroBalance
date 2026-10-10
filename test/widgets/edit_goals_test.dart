import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/editGoals.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;
  late GoalsProvider goals;
  final today = DateTime.now();

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('daily_progress');
    goals = GoalsProvider();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
    for (final e in List.of(provider.entries)) {
      await provider.removeEntry(e.id);
    }
  });

  Future<void> pumpGoals(WidgetTester tester,
      {double calories = 2000, double protein = 150, double carbs = 200, double fat = 67}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    goals
      ..caloriesGoal = calories
      ..proteinGoal = protein
      ..carbsGoal = carbs
      ..fatGoal = fat;
    await tester.pumpWidget(testApp(const EditGoalsScreen(),
        foodEntryProvider: provider, goalsProvider: goals));
    await settle(tester);
  }

  testWidgets('eaten today counts servings the same way as the dashboard',
      (tester) async {
    await tester.runAsync(() async {
      // 2 servings of a 150 kcal AI food, and 1 serving of 75 kcal.
      await provider.addEntry(testEntry(
          name: 'Burrito', meal: 'Lunch', date: today, calories: 150, quantity: 2));
      await provider.addEntry(testEntry(name: 'Toast', meal: 'Breakfast', date: today, calories: 75));
      // Yesterday doesn't count.
      await provider.addEntry(testEntry(
          name: 'Pizza', meal: 'Dinner', date: today.subtract(const Duration(days: 1)),
          calories: 800));
    });
    await pumpGoals(tester);

    final dashboardCalories = provider.getTotalCaloriesForDate(today).round();
    expect(dashboardCalories, 375);
    expect(find.text('375 / 2000 cals'), findsOneWidget);
    // testEntry has 5 g protein, 10 g carbs and 3 g fat per serving: 3 servings.
    expect(find.text('15 / 150 g'), findsOneWidget);
    expect(find.text('30 / 200 g'), findsOneWidget);
    expect(find.text('9 / 67 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('macro check', () {
    testWidgets('within 10 cals says the macros match', (tester) async {
      await pumpGoals(tester, protein: 150, carbs: 200, fat: 67); // 2003 kcal
      expect(find.text('Your macros add up to 2003 cals'), findsOneWidget);
      expect(find.text('This matches your 2000 cals goal.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('up to 5% off says how close it is', (tester) async {
      await pumpGoals(tester, protein: 150, carbs: 200, fat: 70); // 2030 kcal
      expect(find.text('Within 30 cals of your 2000 cals goal.'), findsOneWidget);
      expect(find.textContaining('Set calories to'), findsNothing);
    });

    testWidgets('just under 5% off is still within', (tester) async {
      // 600 + 900 + 594 = 2094: 94 kcal over, under the 100 kcal (5%) limit.
      await pumpGoals(tester, protein: 150, carbs: 225, fat: 66);
      expect(find.text('Within 94 cals of your 2000 cals goal.'), findsOneWidget);
    });

    testWidgets('editing a goal updates the check', (tester) async {
      await pumpGoals(tester, protein: 150, carbs: 200, fat: 67);
      expect(find.text('This matches your 2000 cals goal.'), findsOneWidget);
      goals.fatGoal = 90; // 2210 kcal
      await settle(tester);
      expect(find.textContaining('210 cals more than your 2000 cals goal.'), findsOneWidget);
    });

    testWidgets('more than 5% off explains the mismatch and offers fixes',
        (tester) async {
      await pumpGoals(tester, protein: 150, carbs: 75, fat: 80); // 1620 kcal
      expect(find.text('Your macros add up to 1620 cals'), findsOneWidget);
      expect(find.textContaining('380 cals less than your 2000 cals goal.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Set calories to 1620'), findsOneWidget);
    });
  });
}
