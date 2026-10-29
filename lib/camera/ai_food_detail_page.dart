import 'package:flutter/material.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:macrotracker/utils/ai_food_conversion.dart';

/// An AI-detected or AI-suggested food, in the same detail page as any
/// searched food: same servings, amount entry and nutrition. Adding goes back
/// to the list it was opened from.
class AIFoodDetailPage extends StatelessWidget {
  final AIFoodItem food;

  final String? selectedMeal;

  /// Day to log into; defaults to the day selected on the dashboard.
  final DateTime? logDate;

  const AIFoodDetailPage({
    super.key,
    required this.food,
    this.selectedMeal,
    this.logDate,
  });

  @override
  Widget build(BuildContext context) => FoodDetailPage(
        food: food.toFoodItem(),
        selectedMeal: selectedMeal,
        logDate: logDate,
        returnOnAdd: true,
      );
}
