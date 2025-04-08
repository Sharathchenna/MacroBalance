// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import '../screens/searchPage.dart'; // Import Serving class definition
import '../screens/searchPage.dart'; // Import Serving class definition
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:math'; // Added for min function
import '../services/widget_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
// Removed ExpenditureProvider import, interaction handled differently
import 'package:macrotracker/services/macro_calculator_service.dart'; // Import MacroCalculatorService

// Define the channel name consistently
const String _statsChannelName = 'app.macrobalance.com/stats';
const MethodChannel _statsChannel = MethodChannel(_statsChannelName);

class FoodEntryProvider with ChangeNotifier {
  List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';

  // Daily nutrition goals - Can be set manually or calculated
  double _caloriesGoal = 2000.0;
  double _proteinGoal = 150.0;
  double _carbsGoal = 225.0;
  double _fatGoal = 65.0;

  // User profile/goal parameters needed for macro calculation
  String _gender = MacroCalculatorService.MALE;
  int _age = 30;
  double _heightCm = 175;
  int _activityLevel = MacroCalculatorService.LIGHTLY_ACTIVE;
  double? _proteinRatio; // g/kg
  double? _fatRatio; // percentage

  // Other goals and parameters
  int _stepsGoal = 10000;
  double _bmr = 1500.0;
  double _tdee =
      2000.0; // Can be calculated by ExpenditureService or MacroCalculatorService
  double _goalWeightKg = 0.0;
  double _currentWeightKg = 0.0;
  String _goalType = MacroCalculatorService.GOAL_MAINTAIN;
  int _deficitSurplus = 500;

  // Cache for date entries
  final Map<String, List<FoodEntry>> _dateEntriesCache = {};
  final Map<String, DateTime> _dateCacheTimestamp = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Flag to prevent multiple initial loads
  bool _initialLoadComplete = false;

  FoodEntryProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialLoadComplete) return;
    // TODO: Load user profile data (_gender, _age, _heightCm, _activityLevel, _proteinRatio, _fatRatio) from storage
    await _loadEntries();
    await loadNutritionGoals(); // Load initial/saved goals and profile data
    _initialLoadComplete = true;
    debugPrint("FoodEntryProvider initialized.");
  }

  Future<void> ensureInitialized() async {
    if (!_initialLoadComplete) {
      await _initialize();
    }
  }

  List<FoodEntry> get entries => _entries;

  // --- Getters ---
  double get caloriesGoal => _caloriesGoal;
  double get proteinGoal => _proteinGoal;
  double get carbsGoal => _carbsGoal;
  double get fatGoal => _fatGoal;
  int get stepsGoal => _stepsGoal;
  double get bmr => _bmr;
  double get tdee => _tdee;
  double get goalWeightKg => _goalWeightKg;
  double get currentWeightKg => _currentWeightKg;
  String get goalType => _goalType;
  int get deficitSurplus => _deficitSurplus;

  int get goalTypeAsInt {
    switch (_goalType) {
      case MacroCalculatorService.GOAL_MAINTAIN:
        return 1;
      case MacroCalculatorService.GOAL_LOSE:
        return 2;
      case MacroCalculatorService.GOAL_GAIN:
        return 3;
      default:
        return 1;
    }
  }

  // --- Setters (Restored) ---
  set caloriesGoal(double value) {
    _caloriesGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
    _syncNutritionGoalsToSupabase();
  }

  set proteinGoal(double value) {
    _proteinGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
    _syncNutritionGoalsToSupabase();
  }

  set carbsGoal(double value) {
    _carbsGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
    _syncNutritionGoalsToSupabase();
  }

  set fatGoal(double value) {
    _fatGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
    _syncNutritionGoalsToSupabase();
  }

  set stepsGoal(int value) {
    _stepsGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  set goalWeightKg(double value) {
    _goalWeightKg = value;
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  // Restore setter for current weight
  set currentWeightKg(double value) {
    if (_currentWeightKg != value) {
      _currentWeightKg = value;
      _saveNutritionGoals();
      notifyListeners();
      _syncNutritionGoalsToSupabase();
      // TODO: Consider triggering TDEE recalculation here via ExpenditureProvider if needed
    }
  }

  // Method to update current weight (alternative to setter)
  Future<void> updateCurrentWeight(double newWeightKg) async {
    currentWeightKg = newWeightKg; // Use the setter
  }

  set goalType(String value) {
    if (_goalType != value) {
      _goalType = value;
      _saveNutritionGoals();
      notifyListeners();
      _syncNutritionGoalsToSupabase();
      recalculateMacroGoals(_tdee); // Recalculate when goal type changes
    }
  }

  set goalTypeAsInt(int value) {
    String newGoalType;
    switch (value) {
      case 1:
        newGoalType = MacroCalculatorService.GOAL_MAINTAIN;
        break;
      case 2:
        newGoalType = MacroCalculatorService.GOAL_LOSE;
        break;
      case 3:
        newGoalType = MacroCalculatorService.GOAL_GAIN;
        break;
      default:
        newGoalType = MacroCalculatorService.GOAL_MAINTAIN;
    }
    if (_goalType != newGoalType) {
      goalType = newGoalType;
    }
  }

  set deficitSurplus(int value) {
    if (_deficitSurplus != value) {
      _deficitSurplus = value;
      _saveNutritionGoals();
      notifyListeners();
      _syncNutritionGoalsToSupabase();
      recalculateMacroGoals(_tdee); // Recalculate when deficit changes
    }
  }

  // Restore updateNutritionGoals method (used by editGoals screen)
  Future<void> updateNutritionGoals({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required int steps,
    required double bmr,
    required double tdee,
    // Add other goals if needed (e.g., weight)
  }) async {
    _caloriesGoal = calories;
    _proteinGoal = protein;
    _carbsGoal = carbs;
    _fatGoal = fat;
    _stepsGoal = steps;
    _bmr = bmr;
    _tdee = tdee; // Update TDEE if provided manually

    _saveNutritionGoals(); // Save locally
    notifyListeners(); // Notify UI
    _updateWidgets(); // Update widgets (if applicable)
    _syncNutritionGoalsToSupabase(); // Sync to Supabase
  }

  // --- Dynamic Goal Recalculation ---
  Future<void> recalculateMacroGoals(double calculatedTDEE) async {
    debugPrint(
        "Recalculating macro goals with TDEE: ${calculatedTDEE.round()}");
    _tdee = calculatedTDEE; // Store the dynamically calculated TDEE

    // Calculate target calories based on goal and TDEE
    double targetCalories;
    int calorieAdjustment = _deficitSurplus;
    if (_goalType == MacroCalculatorService.GOAL_LOSE) {
      targetCalories = _tdee - calorieAdjustment;
      targetCalories = max(1200, targetCalories);
    } else if (_goalType == MacroCalculatorService.GOAL_GAIN) {
      targetCalories = _tdee + calorieAdjustment;
    } else {
      targetCalories = _tdee;
    }

    // Ensure currentWeightKg is loaded before calling this
    if (_currentWeightKg <= 0) {
      debugPrint("Cannot recalculate goals: Current weight is not set.");
      // TODO: Optionally load weight here if needed or use a default/fallback
      return;
    }

    // Use the static helper method from MacroCalculatorService
    // Corrected call to use public static method
    final Map<String, double> macros = MacroCalculatorService.distributeMacros(
      targetCalories: targetCalories,
      weightKg: _currentWeightKg,
      gender: _gender,
      proteinRatio: _proteinRatio,
      fatRatio: _fatRatio,
    );

    // Update provider state with calculated goals
    _caloriesGoal = targetCalories.roundToDouble();
    _proteinGoal = macros['protein_g']!.roundToDouble();
    _carbsGoal = macros['carb_g']!.roundToDouble();
    _fatGoal = macros['fat_g']!.roundToDouble();

    debugPrint(
        "Calculated Goals: Cals=$_caloriesGoal, P=$_proteinGoal, C=$_carbsGoal, F=$_fatGoal");

    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
    _syncNutritionGoalsToSupabase();
  }

  // --- Load/Save/Sync Methods ---
  Future<void> _loadEntries() async {
    // ... (existing implementation) ...
  }

  void _loadEntriesFromJson(String entriesJson) {
    // ... (existing implementation) ...
  }

  Future<void> loadNutritionGoals() async {
    try {
      final String? nutritionGoalsString =
          StorageService().get('nutrition_goals');
      if (nutritionGoalsString != null && nutritionGoalsString.isNotEmpty) {
        final Map<String, dynamic> nutritionGoals =
            jsonDecode(nutritionGoalsString);

        // Load macro targets
        if (nutritionGoals['macro_targets'] != null) {
          final macroTargets = nutritionGoals['macro_targets'];
          _caloriesGoal = (macroTargets['calories'] as num).toDouble();
          _proteinGoal = (macroTargets['protein'] as num).toDouble();
          _carbsGoal = (macroTargets['carbs'] as num).toDouble();
          _fatGoal = (macroTargets['fat'] as num).toDouble();
        }

        // Load other goals
        _stepsGoal = nutritionGoals['steps_goal'] ?? _stepsGoal;
        _bmr = (nutritionGoals['bmr'] as num?)?.toDouble() ?? _bmr;
        _tdee = (nutritionGoals['tdee'] as num?)?.toDouble() ?? _tdee;
        _goalWeightKg =
            (nutritionGoals['goal_weight_kg'] as num?)?.toDouble() ??
                _goalWeightKg;
        _currentWeightKg =
            (nutritionGoals['current_weight_kg'] as num?)?.toDouble() ??
                _currentWeightKg;

        debugPrint(
            'Loaded nutrition goals from storage: calories=${_caloriesGoal}, protein=${_proteinGoal}, carbs=${_carbsGoal}, fat=${_fatGoal}');
      } else {
        debugPrint('No nutrition goals found in storage');
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
    notifyListeners();
  }

  Future<void> _syncNutritionGoalsFromSupabase() async {
    // ... (existing implementation) ...
  }

  void _saveNutritionGoals() {
    final Map<String, dynamic> goals = {
      'macro_targets': {
        'calories': _caloriesGoal,
        'protein': _proteinGoal,
        'carbs': _carbsGoal,
        'fat': _fatGoal,
      },
      'steps_goal': _stepsGoal,
      'bmr': _bmr,
      'tdee': _tdee,
      'goal_weight_kg': _goalWeightKg,
      'current_weight_kg': _currentWeightKg,
      'goal_type': _goalType,
      'updated_at': DateTime.now().toIso8601String(),
    };

    StorageService().put('nutrition_goals', jsonEncode(goals));
    debugPrint('Saved nutrition goals to storage: ${jsonEncode(goals)}');
  }

  Future<void> _syncNutritionGoalsToSupabase() async {
    // ... (existing implementation) ...
  }

  Future<void> _saveEntries() async {
    // ... (existing implementation) ...
  }

  Future<void> _syncEntriesToSupabase(String entriesJson) async {
    // ... (existing implementation) ...
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    // ... (existing implementation) ...
    return _entries
        .where((entry) =>
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  List<FoodEntry> getEntriesForMeal(String meal, DateTime date) {
    // ... (existing implementation) ...
    return _entries
        .where((entry) =>
            entry.meal == meal &&
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  Future<void> addEntry(FoodEntry entry) async {
    _entries.add(entry);
    await _clearDateCache();
    notifyListeners();
    await _saveEntries();
    _notifyNativeStatsChanged();
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _clearDateCache();
    notifyListeners();
    await _saveEntries();
    _notifyNativeStatsChanged();
  }

  Future<void> clearEntries() async {
    _entries.clear();
    await _clearDateCache();
    notifyListeners();
    StorageService().delete(_storageKey);
    debugPrint('Entries cleared from local storage only');
  }

  // --- Corrected Calculation Methods ---

  // Helper to calculate nutrient value for a single entry
  double _calculateNutrientForEntry(FoodEntry entry, String nutrientKey) {
    Serving? serving;
    // Try to find the exact serving description saved with the entry
    if (entry.servingDescription != null && entry.food.servings.isNotEmpty) {
      try {
        // Find the serving that matches the description stored in the entry
        serving = entry.food.servings.firstWhere((s) => s.description == entry.servingDescription);
      } catch (e) {
        print("Warning: Serving description '${entry.servingDescription}' not found for ${entry.food.name}. Falling back.");
        serving = null; // Ensure serving is null if not found
      }
    }

    double multiplier = 1.0;
    double baseValue = 0.0;

    if (serving != null) {
      // --- Calculation based on the specific serving ---
      double baseAmount = serving.metricAmount;
      if (baseAmount <= 0) {
        print("Warning: Serving base amount is invalid (${baseAmount}) for ${serving.description}, defaulting to 1.");
        baseAmount = 1.0; // Prevent division by zero
      }

      String servingUnit = serving.metricUnit.toLowerCase();
      // Check if the *serving's* unit indicates weight
      bool isWeightBasedServing = (servingUnit == 'g' || servingUnit == 'oz');

      if (isWeightBasedServing) {
        // If the serving is weight-based, convert the *entry's* quantity to grams
        double quantityGrams = entry.quantity;
        if (entry.unit.toLowerCase() == 'oz') {
          quantityGrams *= 28.35;
        } else if (entry.unit.toLowerCase() == 'lbs') {
           quantityGrams *= 453.59;
        } else if (entry.unit.toLowerCase() == 'kg') {
           quantityGrams *= 1000;
        }
        // else assume entry.unit is 'g' or compatible
        multiplier = quantityGrams / baseAmount;
      } else {
        // If the serving is unit-based (e.g., "1 burger"), use the entry's quantity directly
        multiplier = entry.quantity / baseAmount; // Assumes baseAmount is 1 for "1 unit" servings
      }

      // Get the nutrient value from the *serving's* data
      if (nutrientKey == 'calories') {
        baseValue = serving.calories;
      } else {
        baseValue = serving.nutrients[nutrientKey] ?? 0.0;
      }

    } else {
      // --- Fallback: Calculation based on food's default (usually 100g) values ---
      // This happens if no servingDescription was saved or if it didn't match any serving
      print("Info: Using fallback 100g calculation for ${entry.food.name}");

      // Convert entry quantity to grams based on entry.unit
      double quantityGrams = entry.quantity;
       if (entry.unit.toLowerCase() == 'oz') {
          quantityGrams *= 28.35;
       } else if (entry.unit.toLowerCase() == 'lbs') {
           quantityGrams *= 453.59;
       } else if (entry.unit.toLowerCase() == 'kg') {
           quantityGrams *= 1000;
       } else if (entry.unit.toLowerCase() != 'g') {
         // If the unit isn't a known weight unit, we cannot reliably convert to grams.
         // Log a warning and potentially return 0 for this entry's contribution.
         print("Warning: Cannot reliably calculate nutrient for ${entry.food.name} with unit '${entry.unit}' in fallback mode.");
         return 0.0; // Return 0 for this entry if unit conversion is impossible in fallback
       }
       // If unit is 'g', quantityInGrams remains entry.quantity

      double foodServingSize = entry.food.servingSize; // This is typically 100g
      if (foodServingSize <= 0) {
        print("Warning: Food default serving size is invalid (${foodServingSize}) for ${entry.food.name}, defaulting to 100g.");
        foodServingSize = 100.0;
      }
      multiplier = quantityGrams / foodServingSize;

      // Get the nutrient value from the food item's base nutrients (per 100g)
      if (nutrientKey == 'calories') {
        baseValue = entry.food.calories;
      } else {
        baseValue = entry.food.nutrients[nutrientKey] ?? 0.0;
      }
    }

    // Ensure multiplier is not negative
    if (multiplier < 0) multiplier = 0;

    // Final calculation
    double calculatedValue = baseValue * multiplier;
    // print("[DEBUG Provider] Entry: ${entry.food.name}, Nutrient: $nutrientKey, BaseValue: $baseValue, Multiplier: $multiplier, Result: $calculatedValue");
    return calculatedValue;
  }


  double getTotalCaloriesForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0, (sum, entry) => sum + _calculateNutrientForEntry(entry, 'calories'));
  }

  double getTotalProteinForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0, (sum, entry) => sum + _calculateNutrientForEntry(entry, 'Protein'));
  }

   double getTotalCarbsForDate(DateTime date) {
     final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0, (sum, entry) => sum + _calculateNutrientForEntry(entry, 'Carbohydrate, by difference'));
  }

   double getTotalFatForDate(DateTime date) {
     final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0, (sum, entry) => sum + _calculateNutrientForEntry(entry, 'Total lipid (fat)'));
  }

  List<FoodEntry> getAllEntriesForDate(DateTime date) {
    // ... (existing implementation) ...
    final localDate = date.toLocal();
    final startOfDay = DateTime(localDate.year, localDate.month, localDate.day);
    final endOfDay = DateTime(
        localDate.year, localDate.month, localDate.day, 23, 59, 59, 999);
    final cacheKey =
        '${startOfDay.year}-${startOfDay.month.toString().padLeft(2, '0')}-${startOfDay.day.toString().padLeft(2, '0')}';
    if (_dateEntriesCache.containsKey(cacheKey)) {
      final cacheTimestamp = _dateCacheTimestamp[cacheKey];
      if (cacheTimestamp != null &&
          DateTime.now().difference(cacheTimestamp) < _cacheDuration) {
        return _dateEntriesCache[cacheKey]!;
      }
    }
    final filteredEntries = _entries.where((entry) {
      final entryDate = entry.date.toLocal();
      return !entryDate.isBefore(startOfDay) && !entryDate.isAfter(endOfDay);
    }).toList();
    _dateEntriesCache[cacheKey] = filteredEntries;
    _dateCacheTimestamp[cacheKey] = DateTime.now();
    return filteredEntries;
  }

  Future<void> _updateWidgets() async {
    // ... (existing implementation) ...
  }

  Future<void> syncAllDataWithSupabase() async {
    // ... (existing implementation) ...
  }

  Future<Map<String, dynamic>> checkSupabaseConnection() async {
    // ... (existing implementation) ...
    try {/* ... */} catch (e) {
      return {
        'connected': false,
        'errorMessage': 'Connection error: ${e.toString()}'
      };
    }
    return {}; // Placeholder, ensure return
  }

  Future<void> _notifyNativeStatsChanged() async {
    // ... (existing implementation) ...
  }

  Future<Map<String, dynamic>> forceSyncAndDiagnose() async {
    final diagnosticInfo = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'syncStarted': true,
      'localEntriesCount': _entries.length,
      'errors': <String>[],
      'warnings': <String>[],
      'success': false
    };
    // ... (rest of existing implementation) ...
    try {/* ... */} catch (e) {
      diagnosticInfo['errors'].add('General error: ${e.toString()}');
    }
    return diagnosticInfo;
  }

  Future<void> loadEntriesFromSupabase() async {
    // ... (existing implementation) ...
  }

  Future<void> _clearDateCache() async {
    _dateEntriesCache.clear();
    _dateCacheTimestamp.clear();
  }

  void resetGoalsToDefault() {
    // ... (existing implementation) ...
    recalculateMacroGoals(_tdee); // Use the last known TDEE or default
  }
}
