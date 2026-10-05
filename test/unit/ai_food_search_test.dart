import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/ai_food_search_service.dart';

void main() {
  final response = {
    'items': [
      {
        'food': 'Sourdough bread',
        'serving_size': ['1 slice (35g)', '100 g', '1 cup cubes (45g)'],
        'calories': [90, 257, 116],
        'protein': [3.5, 10, 4.5],
        'carbohydrates': [17.5, 50, 22.5],
        'fat': [0.6, 1.7, 0.8],
        'fiber': [1, 2.9, 1.3],
      },
      {
        'food': 'Avocado toast',
        'serving_size': ['1 slice', '2 slices'],
        'calories': [190, 380],
        'protein': [5, 10],
        'carbohydrates': [20, 40],
        'fat': [11, 22],
        'fiber': [6, 12],
      },
    ],
  };

  group('parseResponse', () {
    test('keeps every serving the AI returned', () {
      final items = AIFoodSearchService.parseResponse(response);
      expect(items.map((i) => i.name), ['Sourdough bread', 'Avocado toast']);
      final bread = items.first;
      expect(bread.servingSizes, ['1 slice (35g)', '100 g', '1 cup cubes (45g)']);
      expect(bread.calories, [90.0, 257.0, 116.0]);
      expect(bread.protein, [3.5, 10.0, 4.5]);
      expect(bread.fiber, [1.0, 2.9, 1.3]);
      final cube = bread.getNutritionForIndex(2, 2);
      expect(cube.calories, 232);
      expect(cube.carbohydrates, 45);
    });

    test('a malformed item is skipped, the rest still show', () {
      final items = AIFoodSearchService.parseResponse({
        'items': [
          {'food': 'Broken', 'serving_size': ['1 cup']}, // no nutrients
          (response['items'] as List).last,
        ],
      });
      expect(items.map((i) => i.name), ['Avocado toast']);
    });

    test('older single-serving suggestions still work', () {
      final items = AIFoodSearchService.parseResponse({
        'suggestions': [
          {
            'name': 'Banana',
            'calories': 105,
            'protein': 1.3,
            'carbohydrates': 27,
            'fat': 0.4,
            'fiber': 3.1,
            'serving_size': '1 medium',
          },
          {'calories': 50}, // missing fields fall back to defaults
        ],
      });
      expect(items.first.name, 'Banana');
      expect(items.first.servingSizes, ['1 medium']);
      expect(items.first.calories, [105.0]);
      expect(items.last.name, 'Unknown Food');
      expect(items.last.servingSizes, ['100g']);
    });

    test('an empty or unknown body gives no results', () {
      expect(AIFoodSearchService.parseResponse({'items': []}), isEmpty);
      expect(AIFoodSearchService.parseResponse({'other': 1}), isEmpty);
    });
  });

  group('aiItemToDisplayFoodItem', () {
    test('shows the first serving, not a fixed 100 g', () {
      final bread = AIFoodSearchService.parseResponse(response).first;
      final card = aiItemToDisplayFoodItem(bread);
      expect(card.name, 'Sourdough bread');
      expect(card.calories, 90);
      expect(card.servings, hasLength(1));
      expect(card.servings.single.description, '1 slice (35g)');
      expect(card.servings.single.metricUnit, 'serving');
      expect(card.servings.single.calories, 90);
      expect(card.nutrients['Protein'], 3.5);
      expect(card.nutrients['Carbohydrate, by difference'], 17.5);
      expect(card.nutrients['Total lipid (fat)'], 0.6);
      expect(card.nutrients['Fiber'], 1);
    });
  });
}
