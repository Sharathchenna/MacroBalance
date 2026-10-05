import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
    for (final e in List.of(provider.entries)) {
      await provider.removeEntry(e.id);
    }
  });

  test('add and remove keep the day and meal lists in step', () async {
    final eggs = testEntry(name: 'Eggs', meal: 'Breakfast', date: today, calories: 140);
    await provider.addEntry(eggs);
    expect(provider.getEntriesForMeal(today, 'Breakfast').map((e) => e.food.name), ['Eggs']);
    expect(provider.getEntriesForMeal(today, 'Lunch'), isEmpty);
    expect(provider.getEntriesForMeal(yesterday, 'Breakfast'), isEmpty);

    await provider.removeEntry(eggs.id);
    expect(provider.getAllEntriesForDate(today), isEmpty);
  });

  test('removing an unknown entry is harmless', () async {
    await provider.removeEntry('does-not-exist');
    expect(provider.entries, isEmpty);
  });

  test('daily calories add up servings, not grams', () async {
    await provider.addEntry(testEntry(name: 'Toast', meal: 'Dinner', date: today, calories: 75));
    await provider.addEntry(
        testEntry(name: 'Eggs', meal: 'Breakfast', date: today, calories: 70, quantity: 2));
    expect(provider.getTotalCaloriesForDate(today), closeTo(215, 0.01));
    expect(provider.getTotalCaloriesForDate(yesterday), 0);
  });

  test('copying a meal makes new entries on the target day only', () async {
    await provider.addEntry(testEntry(name: 'Soup', meal: 'Dinner', date: yesterday));
    await provider.addEntry(testEntry(name: 'Bread', meal: 'Dinner', date: yesterday));
    await provider.addEntry(testEntry(name: 'Tea', meal: 'Snacks', date: yesterday));

    final copied = await provider.copyMeal(from: yesterday, to: today, meal: 'Dinner');
    expect(copied, hasLength(2));
    expect(provider.getEntriesForMeal(today, 'Dinner'), hasLength(2));
    expect(provider.getEntriesForMeal(today, 'Snacks'), isEmpty);
    expect(provider.getEntriesForMeal(yesterday, 'Dinner'), hasLength(2));
    // New ids, so deleting a copy never deletes the original.
    final originalIds = provider.getEntriesForMeal(yesterday, 'Dinner').map((e) => e.id).toSet();
    expect(copied.every((e) => !originalIds.contains(e.id)), isTrue);
  });

  test('copying an empty meal copies nothing', () async {
    final copied = await provider.copyMeal(from: yesterday, to: today, meal: 'Lunch');
    expect(copied, isEmpty);
    expect(provider.getAllEntriesForDate(today), isEmpty);
  });

  test('entries survive a new provider instance (saved locally)', () async {
    await provider.addEntry(testEntry(name: 'Apple', meal: 'Snacks', date: today));
    final reloaded = FoodEntryProvider();
    await reloaded.ensureInitialized();
    await reloaded.loadEntriesForCurrentUser();
    expect(reloaded.getEntriesForMeal(today, 'Snacks').map((e) => e.food.name), contains('Apple'));
  });

  group('quick re-log lists', () {
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    test('recent foods: newest first, each food once, with its latest amount', () async {
      await provider.addEntry(testEntry(name: 'Oats', meal: 'Breakfast', date: twoDaysAgo));
      await provider.addEntry(testEntry(name: 'Rice', meal: 'Lunch', date: yesterday));
      await provider.addEntry(
          testEntry(name: 'Oats', meal: 'Breakfast', date: today, quantity: 2));
      final recent = provider.recentFoods();
      expect(recent.map((e) => e.food.name), ['Oats', 'Rice']);
      expect(recent.first.quantity, 2);
      expect(provider.recentFoods(limit: 1), hasLength(1));
    });

    test('most logged: only foods logged at least twice, most often first', () async {
      for (var i = 0; i < 3; i++) {
        await provider.addEntry(testEntry(
            name: 'Coffee', meal: 'Breakfast', date: today, quantity: 1 + i * 0.001));
      }
      await provider.addEntry(testEntry(name: 'Eggs', meal: 'Breakfast', date: yesterday));
      await provider.addEntry(
          testEntry(name: 'Eggs', meal: 'Breakfast', date: today, quantity: 3));
      await provider.addEntry(testEntry(name: 'Cake', meal: 'Snacks', date: today));

      final frequent = provider.frequentFoods();
      expect(frequent.map((e) => e.food.name), ['Coffee', 'Eggs']);
      // Re-logging repeats the most recent amount.
      expect(frequent.last.quantity, 3);
    });
  });
}
