import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/searchPage.dart';

Serving _serving(String description, double amount, String unit, double kcal,
        double protein) =>
    Serving(
      description: description,
      metricAmount: amount,
      metricUnit: unit,
      calories: kcal,
      nutrients: {'Protein': protein},
    );

FoodEntry _entry({
  required FoodItem food,
  double quantity = 1,
  String unit = 'g',
  String? servingDescription,
}) =>
    FoodEntry(
      id: 'e1',
      food: food,
      meal: 'Lunch',
      quantity: quantity,
      unit: unit,
      date: DateTime(2026, 10, 4),
      servingDescription: servingDescription,
    );

FoodItem _food({
  String brand = 'Brand',
  double kcalPer100 = 200,
  List<Serving> servings = const [],
}) =>
    FoodItem(
      fdcId: '1',
      name: 'Test food',
      calories: kcalPer100,
      nutrients: {'Protein': 10},
      brandName: brand,
      mealType: 'lunch',
      servingSize: 100,
      servings: servings,
    );

double kcal(FoodEntry e) => FoodEntryProvider.nutrientForEntry(e, 'calories');

void main() {
  group('nutrientForEntry', () {
    test('gram serving scales by grams eaten', () {
      final food = _food(servings: [_serving('100 g', 100, 'g', 250, 12)]);
      final entry =
          _entry(food: food, quantity: 150, servingDescription: '100 g');
      expect(kcal(entry), closeTo(375, 0.001));
      expect(FoodEntryProvider.nutrientForEntry(entry, 'Protein'),
          closeTo(18, 0.001));
    });

    test('ounce serving compares grams with grams', () {
      // 1 oz serving = 100 kcal; eating 2 oz should be 200 kcal, not ~5600.
      final food = _food(servings: [_serving('1 oz', 1, 'oz', 100, 5)]);
      final entry = _entry(
          food: food, quantity: 2, unit: 'oz', servingDescription: '1 oz');
      expect(kcal(entry), closeTo(200, 0.01));
    });

    test('unit serving multiplies by number of servings', () {
      final food = _food(servings: [_serving('1 cup', 1, 'cup', 120, 4)]);
      final entry = _entry(
          food: food, quantity: 1.5, unit: 'cup', servingDescription: '1 cup');
      expect(kcal(entry), closeTo(180, 0.001));
    });

    test('falls back to per-100 g when the serving is unknown', () {
      final entry = _entry(food: _food(kcalPer100: 200), quantity: 50);
      expect(kcal(entry), closeTo(100, 0.001));
    });

    test('AI entry from the AI screen: quantity times the stored serving', () {
      final entry = _entry(
        food: _food(brand: 'AI Detected', kcalPer100: 300),
        quantity: 2,
        unit: 'serving',
        servingDescription: '2.0 x 1 bowl',
      );
      expect(kcal(entry), closeTo(600, 0.001));
    });

    test('saved AI food uses the serving the user picked, not the first', () {
      final food = _food(
        brand: 'AI Detected',
        kcalPer100: 90, // first serving's calories, copied onto the food
        servings: [
          _serving('1 slice', 1, 'serving', 90, 3),
          _serving('1 bowl', 1, 'serving', 400, 12),
        ],
      );
      final entry = _entry(
          food: food, quantity: 1, unit: 'serving', servingDescription: '1 bowl');
      expect(kcal(entry), closeTo(400, 0.001));
    });
  });

  group('FoodEntry JSON', () {
    test('accepts whole numbers as ints, as Supabase returns them', () {
      final entry = FoodEntry.fromJson({
        'id': 'abc',
        'food': {
          'fdcId': 42,
          'name': 'Rice',
          'calories': 130,
          'brandName': '',
          'nutrients': {'Protein': 3, 'Total lipid (fat)': 0.3},
          'mealType': 'lunch',
          'servingSize': 100,
          'servings': [],
        },
        'meal': 'Lunch',
        'quantity': 1,
        'unit': 'g',
        'date': '2026-10-04T18:30:00.000Z',
      });
      expect(entry.quantity, 1.0);
      expect(entry.food.calories, 130.0);
      expect(entry.food.nutrients['Protein'], 3.0);
    });

    test('round-trips the date as UTC', () {
      final original = _entry(food: _food());
      final restored = FoodEntry.fromJson(original.toJson());
      expect(restored.date.isAtSameMomentAs(original.date), isTrue);
      expect(original.toJson()['date'], endsWith('Z'));
    });
  });

  group('DateProvider', () {
    test('a picked past day stays selected', () {
      final provider = DateProvider();
      provider.setDate(DateTime.now().subtract(const Duration(days: 3)));
      final picked = provider.selectedDate;
      provider.refreshIfNewDay();
      expect(provider.selectedDate, picked);
    });

    test('today stays today', () {
      final provider = DateProvider();
      provider.refreshIfNewDay();
      final now = DateTime.now();
      expect(provider.selectedDate, DateTime(now.year, now.month, now.day));
    });
  });
}
