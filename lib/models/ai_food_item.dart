class AIFoodItem {
  final String name;
  final List<String> servingSizes;
  final List<double> calories;
  final List<double> protein;
  final List<double> carbohydrates;
  final List<double> fat;
  final List<double> fiber;

  AIFoodItem({
    required this.name,
    required this.servingSizes,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  factory AIFoodItem.fromJson(Map<String, dynamic> json) {
    return AIFoodItem(
      name: json['food'] as String,
      servingSizes: List<String>.from(json['serving_size']),
      calories:
          List<double>.from(json['calories'].map((x) => (x as num).toDouble())),
      protein:
          List<double>.from(json['protein'].map((x) => (x as num).toDouble())),
      carbohydrates: List<double>.from(
          json['carbohydrates'].map((x) => (x as num).toDouble())),
      fat: List<double>.from(json['fat'].map((x) => (x as num).toDouble())),
      fiber: List<double>.from(json['fiber'].map((x) => (x as num).toDouble())),
    );
  }

  // Get nutrition values for a specific serving size index
  NutritionInfo getNutritionForIndex(int index, double quantity) {
    if (index < 0 || index >= servingSizes.length) {
      return NutritionInfo.zero();
    }

    return NutritionInfo(
      calories: calories[index] * quantity,
      protein: protein[index] * quantity,
      carbohydrates: carbohydrates[index] * quantity,
      fat: fat[index] * quantity,
      fiber: fiber[index] * quantity,
    );
  }
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

  factory NutritionInfo.zero() {
    return NutritionInfo(
      calories: 0,
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      fiber: 0,
    );
  }
}
