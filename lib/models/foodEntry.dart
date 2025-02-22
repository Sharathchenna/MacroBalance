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
}