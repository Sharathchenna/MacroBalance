import 'recipe.dart';
import 'food.dart';

enum MealType { breakfast, lunch, dinner, snack }

class MealItem {
  final String id;
  final String type; // 'recipe' or 'food'
  final String itemId; // recipe_id or food_id
  final String name;
  final double servings;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  MealItem({
    required this.id,
    required this.type,
    required this.itemId,
    required this.name,
    required this.servings,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  factory MealItem.fromRecipe(Recipe recipe, double servings) {
    return MealItem(
      id: '${recipe.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'recipe',
      itemId: recipe.id,
      name: recipe.name,
      servings: servings,
      calories: recipe.caloriesPerServing * servings,
      protein: recipe.proteinPerServing * servings,
      carbohydrates: recipe.carbohydratesPerServing * servings,
      fat: recipe.fatPerServing * servings,
      fiber: recipe.fiberPerServing * servings,
    );
  }

  factory MealItem.fromFoodItem(FoodItem foodItem, double servings) {
    return MealItem(
      id: '${foodItem.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'food',
      itemId: foodItem.id,
      name: foodItem.name,
      servings: servings,
      calories: foodItem.calories * servings,
      protein: foodItem.protein * servings,
      carbohydrates: foodItem.carbs * servings,
      fat: foodItem.fat * servings,
      fiber: (foodItem.nutrients['Fiber'] ?? 0) * servings,
    );
  }

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'food',
      itemId: json['item_id'] ?? '',
      name: json['name'] ?? '',
      servings: (json['servings'] ?? 1).toDouble(),
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbohydrates: (json['carbohydrates'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'item_id': itemId,
      'name': name,
      'servings': servings,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
    };
  }
}

class Meal {
  final String id;
  final String name;
  final MealType type;
  final List<MealItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Meal({
    required this.id,
    required this.name,
    required this.type,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: MealType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MealType.breakfast,
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => MealItem.fromJson(item))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Calculate total macros for the meal
  double get totalCalories => items.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => items.fold(0, (sum, item) => sum + item.protein);
  double get totalCarbohydrates =>
      items.fold(0, (sum, item) => sum + item.carbohydrates);
  double get totalFat => items.fold(0, (sum, item) => sum + item.fat);
  double get totalFiber => items.fold(0, (sum, item) => sum + item.fiber);

  // Add item to meal
  Meal addItem(MealItem item) {
    return copyWith(
      items: [...items, item],
      updatedAt: DateTime.now(),
    );
  }

  // Remove item from meal
  Meal removeItem(String itemId) {
    return copyWith(
      items: items.where((item) => item.id != itemId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Meal copyWith({
    String? id,
    String? name,
    MealType? type,
    List<MealItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DailyMealPlan {
  final String id;
  final String userId;
  final DateTime date;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbohydrates;
  final double targetFat;
  final List<Meal> plannedMeals;
  final List<Meal> loggedMeals;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyMealPlan({
    required this.id,
    required this.userId,
    required this.date,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbohydrates,
    required this.targetFat,
    required this.plannedMeals,
    required this.loggedMeals,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyMealPlan.fromJson(Map<String, dynamic> json) {
    return DailyMealPlan(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      targetCalories: (json['target_calories'] ?? 0).toDouble(),
      targetProtein: (json['target_protein'] ?? 0).toDouble(),
      targetCarbohydrates: (json['target_carbohydrates'] ?? 0).toDouble(),
      targetFat: (json['target_fat'] ?? 0).toDouble(),
      plannedMeals: (json['planned_meals'] as List<dynamic>?)
              ?.map((meal) => Meal.fromJson(meal))
              .toList() ??
          [],
      loggedMeals: (json['logged_meals'] as List<dynamic>?)
              ?.map((meal) => Meal.fromJson(meal))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0], // Date only
      'target_calories': targetCalories,
      'target_protein': targetProtein,
      'target_carbohydrates': targetCarbohydrates,
      'target_fat': targetFat,
      'planned_meals': plannedMeals.map((meal) => meal.toJson()).toList(),
      'logged_meals': loggedMeals.map((meal) => meal.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Calculate totals for planned meals
  double get plannedCalories =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get plannedProtein =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalProtein);
  double get plannedCarbohydrates =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalCarbohydrates);
  double get plannedFat =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalFat);

  // Calculate totals for logged meals
  double get loggedCalories =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get loggedProtein =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalProtein);
  double get loggedCarbohydrates =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalCarbohydrates);
  double get loggedFat =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalFat);

  // Calculate remaining macros
  double get remainingCalories => targetCalories - loggedCalories;
  double get remainingProtein => targetProtein - loggedProtein;
  double get remainingCarbohydrates =>
      targetCarbohydrates - loggedCarbohydrates;
  double get remainingFat => targetFat - loggedFat;

  DailyMealPlan copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbohydrates,
    double? targetFat,
    List<Meal>? plannedMeals,
    List<Meal>? loggedMeals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyMealPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbohydrates: targetCarbohydrates ?? this.targetCarbohydrates,
      targetFat: targetFat ?? this.targetFat,
      plannedMeals: plannedMeals ?? this.plannedMeals,
      loggedMeals: loggedMeals ?? this.loggedMeals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
