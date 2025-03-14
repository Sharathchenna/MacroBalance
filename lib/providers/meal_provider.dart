import 'package:flutter/foundation.dart';
import '../models/food_item.dart';

enum MealType { breakfast, lunch, dinner, snacks }

class MealProvider with ChangeNotifier {
  final Map<MealType, List<FoodItem>> _meals = {
    MealType.breakfast: [],
    MealType.lunch: [],
    MealType.dinner: [],
    MealType.snacks: [],
  };

  List<FoodItem> getMealItems(MealType type) => _meals[type] ?? [];

  void addToMeal(MealType type, FoodItem item) {
    _meals[type]?.add(item);
    notifyListeners();
  }

  void removeFromMeal(MealType type, FoodItem item) {
    _meals[type]?.remove(item);
    notifyListeners();
  }
}
