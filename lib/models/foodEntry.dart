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
        },
        'meal': meal,
        'quantity': quantity,
        'unit': unit,
        'date': date.toIso8601String(),
        'servingDescription': servingDescription,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'],
        food: FoodItem(
          fdcId: json['food']['fdcId'],
          name: json['food']['name'],
          calories: json['food']['calories'],
          brandName: json['food']['brandName'],
          nutrients: Map<String, double>.from(json['food']['nutrients']),
          mealType: json['food']['mealType'],
          servingSize: json['food']['servingSize'],
          servings: [],
        ),
        meal: json['meal'],
        quantity: json['quantity'],
        unit: json['unit'],
        date: DateTime.parse(json['date']),
        servingDescription: json['servingDescription'],
      );

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
