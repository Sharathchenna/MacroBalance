import 'package:uuid/uuid.dart';
import 'food.dart';
import '../screens/searchPage.dart' as search;

/// Model representing a food item saved by the user for quick re-logging
class SavedFood {
  final String id;
  final String userId; // The user who saved this food
  final FoodItem food; // The actual food item data
  final String? notes; // Optional notes the user might add
  final DateTime createdAt; // When this food was saved

  SavedFood({
    String? id,
    required this.userId,
    required this.food,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Convert our FoodItem to the SearchPage FoodItem type
  search.FoodItem toSearchPageFoodItem() {
    print('SavedFood: Converting to SearchPage FoodItem for ${food.name}');
    print('SavedFood: Total servings: ${food.servings.length}');
    if (food.servings.isNotEmpty) {
      print('SavedFood: First serving: ${food.servings[0].description}');
    }
    
    List<search.Serving> searchServings = food.servings.map((serving) {
      return search.Serving(
          description: serving.description,
          metricAmount: serving.metricAmount,
          metricUnit: serving.metricUnit,
          calories: serving.calories,
          nutrients: {
            'Protein': serving.protein,
            'Total lipid (fat)': serving.fat,
            'Carbohydrate, by difference': serving.carbohydrate,
            'Saturated fat': serving.saturatedFat,
            if (serving.polyunsaturatedFat != null)
              'Polyunsaturated fat': serving.polyunsaturatedFat!,
            if (serving.monounsaturatedFat != null)
              'Monounsaturated fat': serving.monounsaturatedFat!,
            if (serving.transFat != null) 'Trans fat': serving.transFat!,
            if (serving.cholesterol != null)
              'Cholesterol': serving.cholesterol!,
            if (serving.sodium != null) 'Sodium': serving.sodium!,
            if (serving.potassium != null) 'Potassium': serving.potassium!,
            if (serving.fiber != null) 'Fiber': serving.fiber!,
            if (serving.sugar != null) 'Sugar': serving.sugar!,
            if (serving.vitaminA != null) 'Vitamin A': serving.vitaminA!,
            if (serving.vitaminC != null) 'Vitamin C': serving.vitaminC!,
            if (serving.calcium != null) 'Calcium': serving.calcium!,
            if (serving.iron != null) 'Iron': serving.iron!,
          });
    }).toList();

    // Use the first serving (which is now the user's preferred serving) for default values
    final firstServing = food.servings.isNotEmpty ? food.servings[0] : null;
    
    return search.FoodItem(
      fdcId: food.id,
      name: food.name,
      brandName: food.brandName,
      mealType: 'breakfast', // Default meal type
      servingSize: firstServing?.metricAmount ?? 100.0,
      calories: firstServing?.calories ?? 0.0,
      nutrients: {
        'Protein': firstServing?.protein ?? 0.0,
        'Total lipid (fat)': firstServing?.fat ?? 0.0,
        'Carbohydrate, by difference': firstServing?.carbohydrate ?? 0.0,
      },
      servings: searchServings,
    );
  }

  // Create a copy with some fields updated
  SavedFood copyWith({
    String? id,
    String? userId,
    FoodItem? food,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavedFood(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      food: food ?? this.food,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    // Convert servings to JSON
    List<Map<String, dynamic>> servingsJson = food.servings.map((serving) {
      return {
        'description': serving.description,
        'amount': serving.amount,
        'unit': serving.unit,
        'metric_amount': serving.metricAmount,
        'metric_unit': serving.metricUnit,
        'calories': serving.calories,
        'carbohydrate': serving.carbohydrate,
        'protein': serving.protein,
        'fat': serving.fat,
        'saturated_fat': serving.saturatedFat,
        'polyunsaturated_fat': serving.polyunsaturatedFat,
        'monounsaturated_fat': serving.monounsaturatedFat,
        'trans_fat': serving.transFat,
        'cholesterol': serving.cholesterol,
        'sodium': serving.sodium,
        'potassium': serving.potassium,
        'fiber': serving.fiber,
        'sugar': serving.sugar,
        'vitamin_a': serving.vitaminA,
        'vitamin_c': serving.vitaminC,
        'calcium': serving.calcium,
        'iron': serving.iron,
      };
    }).toList();

    return {
      'id': id,
      'user_id': userId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'food': {
        'id': food.id,
        'name': food.name,
        'brand_name': food.brandName,
        'food_type': food.foodType,
        'servings': servingsJson,
        'nutrients': food.nutrients,
      }
    };
  }

  // Create from JSON data
  factory SavedFood.fromJson(Map<String, dynamic> json) {
    // Parse food data
    final foodJson = json['food'] as Map<String, dynamic>;

    // Parse servings
    List<ServingInfo> servings = [];
    if (foodJson['servings'] != null) {
      final servingsJson = foodJson['servings'] as List;
      servings = servingsJson.map((servingJson) {
        return ServingInfo(
          description: servingJson['description'] ?? '',
          amount: servingJson['amount']?.toDouble() ?? 0.0,
          unit: servingJson['unit'] ?? 'g',
          metricAmount: servingJson['metric_amount']?.toDouble() ?? 0.0,
          metricUnit: servingJson['metric_unit'] ?? 'g',
          calories: servingJson['calories']?.toDouble() ?? 0.0,
          carbohydrate: servingJson['carbohydrate']?.toDouble() ?? 0.0,
          protein: servingJson['protein']?.toDouble() ?? 0.0,
          fat: servingJson['fat']?.toDouble() ?? 0.0,
          saturatedFat: servingJson['saturated_fat']?.toDouble() ?? 0.0,
          polyunsaturatedFat: servingJson['polyunsaturated_fat']?.toDouble(),
          monounsaturatedFat: servingJson['monounsaturated_fat']?.toDouble(),
          transFat: servingJson['trans_fat']?.toDouble(),
          cholesterol: servingJson['cholesterol']?.toDouble(),
          sodium: servingJson['sodium']?.toDouble(),
          potassium: servingJson['potassium']?.toDouble(),
          fiber: servingJson['fiber']?.toDouble(),
          sugar: servingJson['sugar']?.toDouble(),
          vitaminA: servingJson['vitamin_a']?.toDouble(),
          vitaminC: servingJson['vitamin_c']?.toDouble(),
          calcium: servingJson['calcium']?.toDouble(),
          iron: servingJson['iron']?.toDouble(),
        );
      }).toList();
    }

    // Parse nutrients
    Map<String, double> nutrients = {};
    if (foodJson['nutrients'] != null) {
      final nutrientsJson = foodJson['nutrients'] as Map<String, dynamic>;
      nutrientsJson.forEach((key, value) {
        if (value is num) {
          nutrients[key] = value.toDouble();
        } else if (value is String) {
          nutrients[key] = double.tryParse(value) ?? 0.0;
        }
      });
    }

    // Create the food item
    final food = FoodItem(
      id: foodJson['id'] ?? '',
      name: foodJson['name'] ?? '',
      brandName: foodJson['brand_name'] ?? '',
      foodType: foodJson['food_type'] ?? '',
      servings: servings,
      nutrients: nutrients,
    );

    // Create the saved food
    return SavedFood(
      id: json['id'],
      userId: json['user_id'],
      food: food,
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'SavedFood(id: $id, userId: $userId, food: ${food.name}, notes: $notes, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedFood && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 