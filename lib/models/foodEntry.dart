// ignore_for_file: file_names

import 'package:macrotracker/screens/searchPage.dart';

class FoodEntry {
  final String id;
  final FoodItem food;
  final String meal;
  final double quantity;
  final String unit;
  final DateTime date;

  FoodEntry({
    required this.id,
    required this.food,
    required this.meal,
    required this.quantity,
    required this.unit,
    required this.date,
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
        ),
        meal: json['meal'],
        quantity: json['quantity'],
        unit: json['unit'],
        date: DateTime.parse(json['date']),
      );
}
