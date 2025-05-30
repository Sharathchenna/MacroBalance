import '../models/foodEntry.dart';
import '../screens/searchPage.dart'; // For Serving class

class NutritionCalculatorService {
  static const Map<String, double> _unitToGrams = {
    'g': 1.0,
    'oz': 28.35,
    'lbs': 453.59,
    'kg': 1000.0,
  };

  /// Calculate nutrient value for a food entry
  static double calculateNutrientForEntry(FoodEntry entry, String nutrientKey) {
    try {
      // Handle AI-detected foods differently
      if (entry.food.brandName == 'AI Detected') {
        return _calculateAIDetectedNutrient(entry, nutrientKey);
      }

      // Handle regular foods with serving information
      return _calculateRegularFoodNutrient(entry, nutrientKey);
    } catch (e) {
      print(
          'Error calculating nutrient $nutrientKey for ${entry.food.name}: $e');
      return 0.0;
    }
  }

  static double _calculateAIDetectedNutrient(
      FoodEntry entry, String nutrientKey) {
    double baseValue = 0.0;

    if (nutrientKey == 'calories') {
      baseValue = entry.food.calories;
    } else {
      baseValue = entry.food.nutrients[nutrientKey] ?? 0.0;
    }

    // For AI foods, quantity is the multiplier for the selected serving
    return baseValue * entry.quantity;
  }

  static double _calculateRegularFoodNutrient(
      FoodEntry entry, String nutrientKey) {
    // Try to find the specific serving
    Serving? serving = _findServing(entry);

    if (serving != null) {
      return _calculateFromServing(entry, serving, nutrientKey);
    } else {
      return _calculateFromDefault(entry, nutrientKey);
    }
  }

  static Serving? _findServing(FoodEntry entry) {
    if (entry.servingDescription == null || entry.food.servings.isEmpty) {
      return null;
    }

    try {
      return entry.food.servings
          .firstWhere((s) => s.description == entry.servingDescription);
    } catch (e) {
      print(
          'Warning: Serving "${entry.servingDescription}" not found for ${entry.food.name}');
      return null;
    }
  }

  static double _calculateFromServing(
      FoodEntry entry, Serving serving, String nutrientKey) {
    double baseValue = _getServingNutrientValue(serving, nutrientKey);
    double multiplier = _calculateServingMultiplier(entry, serving);
    return baseValue * multiplier;
  }

  static double _calculateFromDefault(FoodEntry entry, String nutrientKey) {
    double baseValue = _getDefaultNutrientValue(entry.food, nutrientKey);
    double multiplier = _calculateDefaultMultiplier(entry);
    return baseValue * multiplier;
  }

  static double _getServingNutrientValue(Serving serving, String nutrientKey) {
    if (nutrientKey == 'calories') {
      return serving.calories;
    }
    return serving.nutrients[nutrientKey] ?? 0.0;
  }

  static double _getDefaultNutrientValue(FoodItem food, String nutrientKey) {
    if (nutrientKey == 'calories') {
      return food.calories;
    }
    return food.nutrients[nutrientKey] ?? 0.0;
  }

  static double _calculateServingMultiplier(FoodEntry entry, Serving serving) {
    double baseAmount = serving.metricAmount;
    if (baseAmount <= 0) {
      print(
          'Warning: Invalid serving amount (${baseAmount}) for ${serving.description}');
      baseAmount = 1.0;
    }

    String servingUnit = serving.metricUnit.toLowerCase();
    bool isWeightBased = servingUnit == 'g' || servingUnit == 'oz';

    if (isWeightBased) {
      double quantityInGrams = _convertToGrams(entry.quantity, entry.unit);
      return quantityInGrams / baseAmount;
    } else {
      return entry.quantity / baseAmount;
    }
  }

  static double _calculateDefaultMultiplier(FoodEntry entry) {
    // For fallback calculations, assume unit conversion is possible
    if (!_canConvertToGrams(entry.unit)) {
      print(
          'Warning: Cannot convert unit "${entry.unit}" to grams for ${entry.food.name}');
      return 0.0;
    }

    double quantityInGrams = _convertToGrams(entry.quantity, entry.unit);
    double servingSize =
        entry.food.servingSize > 0 ? entry.food.servingSize : 100.0;
    return quantityInGrams / servingSize;
  }

  static bool _canConvertToGrams(String unit) {
    return _unitToGrams.containsKey(unit.toLowerCase());
  }

  static double _convertToGrams(double quantity, String unit) {
    double conversionFactor = _unitToGrams[unit.toLowerCase()] ?? 1.0;
    return quantity * conversionFactor;
  }

  /// Calculate total nutrition for multiple entries
  static Map<String, double> calculateTotalNutrition(List<FoodEntry> entries) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;

    for (final entry in entries) {
      totalCalories += calculateNutrientForEntry(entry, 'calories');
      totalProtein += calculateNutrientForEntry(entry, 'Protein');
      totalCarbs +=
          calculateNutrientForEntry(entry, 'Carbohydrate, by difference');
      totalFat += calculateNutrientForEntry(entry, 'Total lipid (fat)');
      totalFiber += calculateNutrientForEntry(entry, 'Fiber');
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'fiber': totalFiber,
    };
  }

  /// Calculate nutrition totals for a specific meal
  static Map<String, double> calculateMealNutrition(
      List<FoodEntry> entries, String meal) {
    final mealEntries = entries.where((entry) => entry.meal == meal).toList();
    return calculateTotalNutrition(mealEntries);
  }

  /// Calculate macro percentages from nutrition totals
  static Map<String, double> calculateMacroPercentages(
      Map<String, double> nutrition) {
    double protein = nutrition['protein'] ?? 0.0;
    double carbs = nutrition['carbs'] ?? 0.0;
    double fat = nutrition['fat'] ?? 0.0;

    // Convert to calories
    double proteinCals = protein * 4;
    double carbCals = carbs * 4;
    double fatCals = fat * 9;

    double total = proteinCals + carbCals + fatCals;

    if (total <= 0) {
      return {"protein": 0.33, "carbs": 0.33, "fat": 0.34};
    }

    return {
      "protein": proteinCals / total,
      "carbs": carbCals / total,
      "fat": fatCals / total,
    };
  }

  /// Calculate remaining nutrition based on goals
  static Map<String, double> calculateRemainingNutrition(
    Map<String, double> consumed,
    Map<String, double> goals,
  ) {
    return {
      'calories': (goals['calories'] ?? 0.0) - (consumed['calories'] ?? 0.0),
      'protein': (goals['protein'] ?? 0.0) - (consumed['protein'] ?? 0.0),
      'carbs': (goals['carbs'] ?? 0.0) - (consumed['carbs'] ?? 0.0),
      'fat': (goals['fat'] ?? 0.0) - (consumed['fat'] ?? 0.0),
      'fiber': (goals['fiber'] ?? 0.0) - (consumed['fiber'] ?? 0.0),
    };
  }
}
