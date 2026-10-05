import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/utils/meal_time.dart';
import 'package:macrotracker/utils/number_format.dart';
import 'package:macrotracker/utils/quick_log.dart';

FoodEntry _entry({
  required double quantity,
  required String unit,
  String? servingDescription,
  String brand = 'Brand',
  List<Serving> servings = const [],
}) =>
    FoodEntry(
      id: 'e',
      food: FoodItem(
        fdcId: '1',
        name: 'Oats',
        calories: 380,
        nutrients: const {},
        brandName: brand,
        mealType: '',
        servingSize: 100,
        servings: servings,
      ),
      meal: 'Breakfast',
      quantity: quantity,
      unit: unit,
      date: DateTime(2026, 10, 4),
      servingDescription: servingDescription,
    );

void main() {
  group('MealTime.forTime', () {
    test('picks the meal from the hour', () {
      expect(MealTime.forTime(DateTime(2026, 1, 1, 8)), 'Breakfast');
      expect(MealTime.forTime(DateTime(2026, 1, 1, 11)), 'Lunch');
      expect(MealTime.forTime(DateTime(2026, 1, 1, 15, 59)), 'Lunch');
      expect(MealTime.forTime(DateTime(2026, 1, 1, 16)), 'Dinner');
      expect(MealTime.forTime(DateTime(2026, 1, 1, 21)), 'Snacks');
      expect(MealTime.forTime(DateTime(2026, 1, 1, 2)), 'Snacks');
    });

    test('a manual choice is reused right after', () {
      MealTime.remember('Snacks');
      expect(MealTime.suggested(), 'Snacks');
    });
  });

  group('number formatting', () {
    test('drops trailing zeros', () {
      expect(formatNumber(100.0), '100');
      expect(formatNumber(12.5), '12.5');
      expect(formatNumber(0.333, maxDecimals: 2), '0.33');
    });

    test('shows common serving fractions as glyphs', () {
      expect(formatServings(0.5), '½');
      expect(formatServings(1.5), '1½');
      expect(formatServings(2), '2');
      expect(formatServings(0.75), '¾');
      expect(formatServings(1.2), '1.2');
    });

    test('accepts a comma decimal separator', () {
      expect(parseAmount('1,5'), 1.5);
      expect(parseAmount(' 2 '), 2);
      expect(parseAmount(''), isNull);
    });
  });

  group('describeEntryAmount', () {
    test('weight entries show the weight', () {
      expect(describeEntryAmount(_entry(quantity: 150, unit: 'g')), '150 g');
    });

    test('unit servings show the serving count', () {
      final cup = Serving(
          description: '1 cup', metricAmount: 1, metricUnit: 'cup', calories: 300, nutrients: const {});
      expect(
        describeEntryAmount(_entry(
            quantity: 1.5, unit: 'cup', servingDescription: '1 cup', servings: [cup])),
        '1½ × 1 cup',
      );
    });

    test('AI entries show the stored serving', () {
      expect(
        describeEntryAmount(_entry(
            quantity: 2, unit: 'serving', servingDescription: '2.0 x 1 bowl', brand: 'AI Detected')),
        '2 × 1 bowl',
      );
    });
  });
}
