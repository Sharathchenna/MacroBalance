// ignore_for_file: file_names

import 'package:macrotracker/screens/searchPage.dart';

class FoodEntry {
  final String id;
  final FoodItem food;
  final String meal;
  final double quantity;
  final String unit;
  final DateTime date;
  final String? servingDescription;

  FoodEntry({
    required this.id,
    required this.food,
    required this.meal,
    required this.quantity,
    required this.unit,
    required this.date,
    this.servingDescription,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'food': {
          'fdcId': food.fdcId,
          'name': food.name,
          'calories': food.calories,
          'brandName': food.brandName,
          'nutrients': food.nutrients,
          'mealType': food.mealType,
          'servingSize': food.servingSize,
          // Serialize the servings list
          'servings': food.servings.map((s) => s.toJson()).toList(),
        },
        'meal': meal,
        'quantity': quantity,
        'unit': unit,
        // UTC with a 'Z' so a timestamptz column round-trips to the same day.
        'date': date.toUtc().toIso8601String(),
        'servingDescription': servingDescription,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    final food = Map<String, dynamic>.from(json['food'] as Map);
    final nutrients = <String, double>{};
    (food['nutrients'] as Map? ?? {}).forEach((key, value) {
      final parsed = _toDouble(value);
      if (parsed != null) nutrients[key.toString()] = parsed;
    });
    return FoodEntry(
      id: json['id'].toString(),
      food: FoodItem(
        fdcId: food['fdcId'].toString(),
        name: food['name'] as String? ?? 'Unknown food',
        calories: _toDouble(food['calories']) ?? 0.0,
        brandName: food['brandName'] as String? ?? '',
        nutrients: nutrients,
        mealType: food['mealType'] as String? ?? '',
        servingSize: _toDouble(food['servingSize']) ?? 100.0,
        servings: (food['servings'] as List<dynamic>? ?? [])
            .map((s) => Serving.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      ),
      meal: json['meal'] as String,
      quantity: _toDouble(json['quantity']) ?? 0.0,
      unit: json['unit'] as String? ?? 'g',
      date: DateTime.parse(json['date'] as String),
      servingDescription: json['servingDescription'] as String?,
    );
  }

  // Supabase returns whole numbers as ints (1 rather than 1.0).
  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Static method to create a FoodItem for AI-detected foods
  static FoodItem createFood({
    required String fdcId,
    required String name,
    required String brandName,
    required double calories,
    required Map<String, double> nutrients,
    required String mealType,
  }) {
    return FoodItem(
      fdcId: fdcId,
      name: name,
      calories: calories,
      brandName: brandName,
      nutrients: nutrients,
      mealType: mealType,
      servingSize: 100.0, // Default serving size
      servings: [], // No detailed servings for AI-detected foods
    );
  }
}
