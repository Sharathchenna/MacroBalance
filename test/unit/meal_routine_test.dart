import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/utils/meal_routine.dart';

import '../helpers/test_app.dart';

void main() {
  final today = DateTime(2026, 10, 6, 8, 30);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  group('MealRoutine.suggest', () {
    // Breakfast by day, built per test.
    late Map<DateTime, List<FoodEntry>> log;

    setUp(() => log = {});

    void eat(int daysBack, List<String> foods, {double quantity = 1}) {
      final day = daysAgo(daysBack);
      log[day] = [
        for (final f in foods)
          testEntry(name: f, meal: 'Breakfast', date: day, quantity: quantity),
      ];
    }

    RoutineSuggestion? suggest({DateTime? viewed}) => MealRoutine.suggest(
          meal: 'Breakfast',
          viewedDate: viewed ?? today,
          today: today,
          entriesFor: (day) => log[DateTime(day.year, day.month, day.day)] ?? const [],
        );

    test('the same meal on 3 of the last 7 days is a routine', () {
      eat(1, ['Oats', 'Milk']);
      eat(4, ['Oats', 'Milk']);
      eat(6, ['Oats', 'Milk']);
      final usual = suggest();
      expect(usual, isNotNull);
      expect(usual!.matchingDays, 3);
      expect(usual.entries.map((e) => e.food.name), ['Oats', 'Milk']);
    });

    test('only 2 matching days is not a routine', () {
      eat(1, ['Oats', 'Milk']);
      eat(2, ['Oats', 'Milk']);
      eat(3, ['Eggs', 'Toast']);
      expect(suggest(), isNull);
    });

    test('varied meals are not a routine', () {
      eat(1, ['Oats', 'Milk']);
      eat(2, ['Eggs', 'Toast']);
      eat(3, ['Pancakes']);
      eat(4, ['Yogurt', 'Granola']);
      eat(5, ['Smoothie']);
      expect(suggest(), isNull);
    });

    test('days older than the window do not count', () {
      eat(1, ['Oats', 'Milk']);
      eat(2, ['Oats', 'Milk']);
      eat(8, ['Oats', 'Milk']);
      expect(suggest(), isNull);
    });

    test('today is not part of the window', () {
      eat(0, ['Oats', 'Milk']);
      eat(1, ['Oats', 'Milk']);
      eat(2, ['Oats', 'Milk']);
      expect(suggest(), isNull);
    });

    test('mostly the same counts: one food can differ', () {
      eat(1, ['Eggs', 'Toast', 'Coffee']);
      eat(2, ['Eggs', 'Toast', 'Tea']);
      eat(3, ['Eggs', 'Toast', 'Coffee']);
      eat(5, ['eggs ', 'Toast']); // Case and spacing don't matter.
      final usual = suggest();
      expect(usual, isNotNull);
      expect(usual!.sourceDate, daysAgo(1));
      expect(usual.matchingDays, greaterThanOrEqualTo(3));
    });

    test('too different is not the same meal', () {
      eat(1, ['Eggs', 'Toast', 'Coffee']);
      eat(2, ['Eggs', 'Bagel', 'Tea']);
      eat(3, ['Eggs', 'Waffle', 'Juice']);
      expect(suggest(), isNull);
    });

    test('offers the most frequent combination, from its most recent day', () {
      eat(1, ['Pancakes']);
      eat(2, ['Oats', 'Milk'], quantity: 2);
      eat(3, ['Oats', 'Milk'], quantity: 1);
      eat(4, ['Oats', 'Milk'], quantity: 1);
      eat(5, ['Pancakes']);
      final usual = suggest();
      expect(usual, isNotNull);
      expect(usual!.entries.map((e) => e.food.name), ['Oats', 'Milk']);
      // Most recent occurrence, so its real quantities are copied.
      expect(usual.sourceDate, daysAgo(2));
      expect(usual.entries.every((e) => e.quantity == 2), isTrue);
    });

    test('among similar days, the exact combination eaten most wins', () {
      eat(1, ['Eggs', 'Toast', 'Juice']);
      eat(2, ['Eggs', 'Toast', 'Coffee']);
      eat(3, ['Eggs', 'Toast', 'Coffee']);
      eat(4, ['Eggs', 'Toast', 'Coffee']);
      final usual = suggest();
      expect(usual!.sourceDate, daysAgo(2));
      expect(usual.entries.map((e) => e.food.name), contains('Coffee'));
    });

    test('no suggestion on past or future days', () {
      eat(1, ['Oats', 'Milk']);
      eat(2, ['Oats', 'Milk']);
      eat(3, ['Oats', 'Milk']);
      expect(suggest(), isNotNull);
      expect(suggest(viewed: daysAgo(1)), isNull);
      expect(suggest(viewed: daysAgo(-1)), isNull);
    });
  });

  group('RoutineDismissals', () {
    late RoutineDismissals dismissals;

    setUp(() async {
      await setUpTestEnvironment();
      for (final key in RoutineDismissals.keysFor('Breakfast')) {
        await StorageService().delete(key);
      }
      dismissals = RoutineDismissals();
    });

    test('"Not today" hides it for that day only', () async {
      expect(dismissals.isHidden('Breakfast', today), isFalse);
      await dismissals.dismiss('Breakfast', today);
      expect(dismissals.isHidden('Breakfast', today), isTrue);
      expect(dismissals.isHidden('Breakfast', today.add(const Duration(hours: 10))), isTrue);
      expect(dismissals.isHidden('Lunch', today), isFalse);
      expect(dismissals.isHidden('Breakfast', daysAgo(-1)), isFalse);
    });

    test('3 dismissals in a row pause the meal for 14 days', () async {
      await dismissals.dismiss('Breakfast', today);
      await dismissals.dismiss('Breakfast', daysAgo(-1));
      expect(dismissals.isHidden('Breakfast', daysAgo(-2)), isFalse);
      await dismissals.dismiss('Breakfast', daysAgo(-2));
      expect(dismissals.isHidden('Breakfast', daysAgo(-3)), isTrue);
      expect(dismissals.isHidden('Breakfast', daysAgo(-15)), isTrue);
      expect(dismissals.isHidden('Breakfast', daysAgo(-16)), isFalse);
    });

    test('adding the suggestion resets the streak', () async {
      await dismissals.dismiss('Breakfast', today);
      await dismissals.dismiss('Breakfast', daysAgo(-1));
      await dismissals.used('Breakfast');
      await dismissals.dismiss('Breakfast', daysAgo(-2));
      expect(dismissals.isHidden('Breakfast', daysAgo(-3)), isFalse);
      await dismissals.dismiss('Breakfast', daysAgo(-3));
      await dismissals.dismiss('Breakfast', daysAgo(-4));
      expect(dismissals.isHidden('Breakfast', daysAgo(-5)), isTrue);
    });
  });
}
