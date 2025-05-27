import 'package:uuid/uuid.dart';
import 'recipe.dart';

class MealItem {
  final String id;
  final Recipe? recipe;
  final String? customFoodName;
  final double servings;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final bool isLogged;

  MealItem({
    String? id,
    this.recipe,
    this.customFoodName,
    required this.servings,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    this.isLogged = false,
  })  : assert(recipe != null || customFoodName != null),
        id = id ?? const Uuid().v4();

  factory MealItem.fromRecipe(Recipe recipe,
      {double servings = 1.0, bool isLogged = false}) {
    return MealItem(
      recipe: recipe,
      servings: servings,
      calories: recipe.calories * servings,
      protein: recipe.protein * servings,
      carbohydrates: recipe.carbohydrates * servings,
      fat: recipe.fat * servings,
      fiber: recipe.fiber * servings,
      isLogged: isLogged,
    );
  }

  factory MealItem.fromCustomFood({
    required String name,
    required double servings,
    required double calories,
    required double protein,
    required double carbohydrates,
    required double fat,
    double fiber = 0,
    bool isLogged = false,
  }) {
    return MealItem(
      customFoodName: name,
      servings: servings,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
      fiber: fiber,
      isLogged: isLogged,
    );
  }

  String get name => recipe?.name ?? customFoodName ?? 'Unknown Food';

  MealItem copyWith({
    String? id,
    Recipe? recipe,
    String? customFoodName,
    double? servings,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    double? fiber,
    bool? isLogged,
  }) {
    return MealItem(
      id: id ?? this.id,
      recipe: recipe ?? this.recipe,
      customFoodName: customFoodName ?? this.customFoodName,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      isLogged: isLogged ?? this.isLogged,
    );
  }

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      id: json['id'],
      recipe: json['recipe'] != null ? Recipe.fromJson(json['recipe']) : null,
      customFoodName: json['custom_food_name'],
      servings: (json['servings'] ?? 1).toDouble(),
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbohydrates: (json['carbohydrates'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      isLogged: json['is_logged'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipe': recipe?.toJson(),
      'custom_food_name': customFoodName,
      'servings': servings,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'is_logged': isLogged,
    };
  }
}

class Meal {
  final String id;
  final String name;
  final List<MealItem> items;
  final DateTime time;
  final bool isLogged;

  Meal({
    String? id,
    required this.name,
    required this.items,
    DateTime? time,
    this.isLogged = false,
  })  : id = id ?? const Uuid().v4(),
        time = time ?? DateTime.now();

  double get totalCalories => items.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => items.fold(0, (sum, item) => sum + item.protein);
  double get totalCarbohydrates =>
      items.fold(0, (sum, item) => sum + item.carbohydrates);
  double get totalFat => items.fold(0, (sum, item) => sum + item.fat);
  double get totalFiber => items.fold(0, (sum, item) => sum + item.fiber);

  Meal copyWith({
    String? id,
    String? name,
    List<MealItem>? items,
    DateTime? time,
    bool? isLogged,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      time: time ?? this.time,
      isLogged: isLogged ?? this.isLogged,
    );
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      name: json['name'] ?? '',
      items: (json['items'] as List?)
              ?.map((item) => MealItem.fromJson(item))
              .toList() ??
          [],
      time:
          json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
      isLogged: json['is_logged'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      'time': time.toIso8601String(),
      'is_logged': isLogged,
    };
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
    String? id,
    required this.userId,
    required this.date,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbohydrates,
    required this.targetFat,
    List<Meal>? plannedMeals,
    List<Meal>? loggedMeals,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        plannedMeals = plannedMeals ?? [],
        loggedMeals = loggedMeals ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get plannedCalories =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get plannedProtein =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalProtein);
  double get plannedCarbohydrates =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalCarbohydrates);
  double get plannedFat =>
      plannedMeals.fold(0, (sum, meal) => sum + meal.totalFat);

  double get loggedCalories =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get loggedProtein =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalProtein);
  double get loggedCarbohydrates =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalCarbohydrates);
  double get loggedFat =>
      loggedMeals.fold(0, (sum, meal) => sum + meal.totalFat);

  double get caloriesDifference => loggedCalories - targetCalories;
  double get proteinDifference => loggedProtein - targetProtein;
  double get carbohydratesDifference =>
      loggedCarbohydrates - targetCarbohydrates;
  double get fatDifference => loggedFat - targetFat;

  double get caloriesProgress =>
      targetCalories > 0 ? (loggedCalories / targetCalories) * 100 : 0;
  double get proteinProgress =>
      targetProtein > 0 ? (loggedProtein / targetProtein) * 100 : 0;
  double get carbohydratesProgress => targetCarbohydrates > 0
      ? (loggedCarbohydrates / targetCarbohydrates) * 100
      : 0;
  double get fatProgress => targetFat > 0 ? (loggedFat / targetFat) * 100 : 0;

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

  factory DailyMealPlan.fromJson(Map<String, dynamic> json) {
    return DailyMealPlan(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      targetCalories: (json['target_calories'] ?? 0).toDouble(),
      targetProtein: (json['target_protein'] ?? 0).toDouble(),
      targetCarbohydrates: (json['target_carbohydrates'] ?? 0).toDouble(),
      targetFat: (json['target_fat'] ?? 0).toDouble(),
      plannedMeals: ((json['planned_meals'] ?? []) as List)
          .map((meal) => Meal.fromJson(meal))
          .toList(),
      loggedMeals: ((json['logged_meals'] ?? []) as List)
          .map((meal) => Meal.fromJson(meal))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T').first,
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
}
