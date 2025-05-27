import 'package:uuid/uuid.dart';

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final String? imageUrl;
  final List<String> dietaryTags; // e.g., ['vegetarian', 'keto', 'gluten-free']
  final String difficulty; // 'easy', 'medium', 'hard'
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    String? id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    this.imageUrl,
    required this.dietaryTags,
    required this.difficulty,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
      prepTimeMinutes: json['prep_time_minutes'] ?? 0,
      cookTimeMinutes: json['cook_time_minutes'] ?? 0,
      servings: json['servings'] ?? 1,
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbohydrates: (json['carbohydrates'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      imageUrl: json['image_url'],
      dietaryTags: List<String>.from(json['dietary_tags'] ?? []),
      difficulty: json['difficulty'] ?? 'medium',
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
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'servings': servings,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'image_url': imageUrl,
      'dietary_tags': dietaryTags,
      'difficulty': difficulty,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Calculate macros per serving
  double get caloriesPerServing => calories / servings;
  double get proteinPerServing => protein / servings;
  double get carbohydratesPerServing => carbohydrates / servings;
  double get fatPerServing => fat / servings;
  double get fiberPerServing => fiber / servings;

  // Total cooking time
  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  // Check if recipe matches dietary preferences
  bool matchesDietaryPreferences(List<String> preferences) {
    return preferences.every((pref) => dietaryTags.contains(pref));
  }

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? servings,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    double? fiber,
    String? imageUrl,
    List<String>? dietaryTags,
    String? difficulty,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      imageUrl: imageUrl ?? this.imageUrl,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
