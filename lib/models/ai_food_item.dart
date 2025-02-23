import 'package:macrotracker/screens/searchPage.dart';

class AIFoodItem {
  final String name;
  final List<ServingSize> servingSizes;

  AIFoodItem({
    required this.name,
    required this.servingSizes,
  });

  factory AIFoodItem.fromJson(Map<String, dynamic> json) {
    return AIFoodItem(
      name: json['food'] as String,
      servingSizes: (json['servingSizes'] as List)
          .map((serving) => ServingSize(
                unit: serving['unit'] as String,
                nutritionInfo: NutritionInfo(
                  calories:
                      (serving['nutritionInfo']['calories'] as num).toDouble(),
                  protein:
                      (serving['nutritionInfo']['protein'] as num).toDouble(),
                  carbohydrates:
                      (serving['nutritionInfo']['carbohydrates'] as num)
                          .toDouble(),
                  fat: (serving['nutritionInfo']['fat'] as num).toDouble(),
                  fiber: (serving['nutritionInfo']['fiber'] as num).toDouble(),
                ),
              ))
          .toList(),
    );
  }

  // Group foods by name and combine their serving sizes
  static List<AIFoodItem> groupByFood(List<Map<String, dynamic>> jsonList) {
    final Map<String, List<ServingSize>> foodMap = {};

    for (var json in jsonList) {
      final foodName = json['food'] as String;
      final servingSizes =
          (json['servingSizes'] as List).map((serving) => ServingSize(
                unit: serving['unit'] as String,
                nutritionInfo: NutritionInfo(
                  calories:
                      (serving['nutritionInfo']['calories'] as num).toDouble(),
                  protein:
                      (serving['nutritionInfo']['protein'] as num).toDouble(),
                  carbohydrates:
                      (serving['nutritionInfo']['carbohydrates'] as num)
                          .toDouble(),
                  fat: (serving['nutritionInfo']['fat'] as num).toDouble(),
                  fiber: (serving['nutritionInfo']['fiber'] as num).toDouble(),
                ),
              ));

      if (!foodMap.containsKey(foodName)) {
        foodMap[foodName] = [];
      }
      foodMap[foodName]!.addAll(servingSizes);
    }

    return foodMap.entries.map((entry) {
      return AIFoodItem(
        name: entry.key,
        servingSizes: entry.value,
      );
    }).toList();
  }
}

extension AIFoodItemExtension on AIFoodItem {
  FoodItem toFoodItem() {
    // Convert serving size nutrients to per 100g
    final per100g = servingSizes.firstWhere(
      (size) => size.unit == '100g',
      orElse: () => servingSizes.first,
    );

    return FoodItem(
      fdcId: name.hashCode.toString(), // Use name hash as ID
      name: name,
      calories: per100g.nutritionInfo.calories,
      nutrients: {
        'Protein': per100g.nutritionInfo.protein,
        'Carbohydrate, by difference': per100g.nutritionInfo.carbohydrates,
        'Total lipid (fat)': per100g.nutritionInfo.fat,
        'Fiber': per100g.nutritionInfo.fiber,
      },
      brandName: 'AI Detected',
      mealType: '',
    );
  }
}

class ServingSize {
  final String unit;
  final NutritionInfo nutritionInfo;

  ServingSize({
    required this.unit,
    required this.nutritionInfo,
  });
}

class NutritionInfo {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });
}
