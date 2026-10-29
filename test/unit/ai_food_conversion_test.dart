import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/utils/ai_food_conversion.dart';
import 'package:macrotracker/utils/quick_log.dart';

void main() {
  group('gramsInServing', () {
    test('reads grams and ounces from serving labels', () {
      expect(gramsInServing('1 slice (35g)'), 35);
      expect(gramsInServing('100g'), 100);
      expect(gramsInServing('1 bowl (300 g)'), 300);
      expect(gramsInServing('1,5 grams'), 1.5);
      expect(gramsInServing('2 oz'), closeTo(56.7, 0.01));
    });

    test('labels without a weight give none', () {
      expect(gramsInServing('1 burrito'), isNull);
      expect(gramsInServing('1 glass'), isNull);
      expect(gramsInServing('10 grapes'), isNull);
      expect(gramsInServing('1 cup (240 ml)'), isNull);
    });
  });

  group('AIFoodItem.toFoodItem', () {
    final burrito = AIFoodItem(
      name: 'Chicken burrito',
      servingSizes: ['1 burrito', '100 g'],
      calories: [650, 210],
      protein: [32, 10],
      carbohydrates: [70, 22],
      fat: [24, 8],
      fiber: [8, 3],
    );

    test('every AI serving becomes a serving, by weight when it has one', () {
      final food = burrito.toFoodItem();
      expect(food.brandName, 'AI Detected');
      expect(food.fdcId, 'Chicken burrito'.hashCode.toString());
      expect(food.servings.map((s) => s.description), ['1 burrito', '100 g']);
      expect(food.servings[0].metricUnit, 'serving');
      expect(food.servings[1].metricUnit, 'g');
      expect(food.servings[1].metricAmount, 100);
      expect(food.servings[1].nutrients['Fiber'], 3);
      expect(food.calories, 650);
    });

    FoodEntry log(double quantity, String unit, String serving) => FoodEntry(
          id: 'e',
          food: burrito.toFoodItem(),
          meal: 'Lunch',
          quantity: quantity,
          unit: unit,
          date: DateTime(2026, 10, 29),
          servingDescription: serving,
        );

    test('counts by serving or by weight the same way the dashboard does', () {
      expect(FoodEntryProvider.nutrientForEntry(log(1.5, 'serving', '1 burrito'), 'calories'), 975);
      expect(FoodEntryProvider.nutrientForEntry(log(150, 'g', '100 g'), 'calories'), 315);
      expect(FoodEntryProvider.nutrientForEntry(log(150, 'g', '100 g'), 'Protein'), 15);
    });

    test('logged amounts read naturally', () {
      expect(describeEntryAmount(log(1.5, 'serving', '1 burrito')), '1½ × 1 burrito');
      expect(describeEntryAmount(log(150, 'g', '100 g')), '150 g');
    });
  });
}
