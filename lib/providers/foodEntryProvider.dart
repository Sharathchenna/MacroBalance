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
import 'package:http/http.dart' as http; // Import for HTTP requests
import 'package:macrotracker/screens/searchPage.dart'; // Import FoodItem and Serving
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
    // Initialize basic state, but DO NOT load user-specific entries here.
    if (_initialLoadComplete) return;
    debugPrint("[Provider Init] Initializing provider structure...");
    // Clear any potential leftover state from previous sessions (belt-and-suspenders)
    _entries.clear();
    await _clearDateCache();
    // Load non-user-specific data or defaults if necessary
    await loadNutritionGoals(); // Load goals (might be user-specific, ensure cleared on logout too)
    _initialLoadComplete = true; // Mark basic structure as initialized
    debugPrint("[Provider Init] Provider structure initialized.");
    // User-specific entries will be loaded via loadEntriesForCurrentUser
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
    try {
      final String? entriesJson = StorageService().get(_storageKey);
      if (entriesJson != null && entriesJson.isNotEmpty) {
        _loadEntriesFromJson(entriesJson);
        debugPrint('Loaded ${_entries.length} entries from local storage.');
      } else {
        debugPrint('No entries found in local storage.');
        _entries =
            []; // Ensure entries list is initialized if nothing is loaded
      }
    } catch (e) {
      debugPrint('Error loading entries from local storage: $e');
      _entries = []; // Initialize to empty list on error
    }
    // No need to notifyListeners here as it's part of initialization
  }

  void _loadEntriesFromJson(String entriesJson) {
    try {
      final List<dynamic> decodedList = jsonDecode(entriesJson);
      _entries = decodedList
          .map((jsonItem) =>
              FoodEntry.fromJson(jsonItem as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error decoding entries JSON: $e');
      _entries = []; // Reset entries on decoding error
    }
  }

  Future<void> loadNutritionGoals() async {
    try {
      // First check for individual keys (these are saved by auth flow)
      final caloriesGoalFromHive = StorageService().get('calories_goal');
      final proteinGoalFromHive = StorageService().get('protein_goal');
      final carbsGoalFromHive = StorageService().get('carbs_goal');
      final fatGoalFromHive = StorageService().get('fat_goal');

      debugPrint("loadNutritionGoals: Checking individual keys first");
      debugPrint(
          "Individual keys from Hive: calories_goal=$caloriesGoalFromHive, protein_goal=$proteinGoalFromHive, carbs_goal=$carbsGoalFromHive, fat_goal=$fatGoalFromHive");

      // Update provider state if values are found in Hive
      bool updatedFromHive = false;
      if (caloriesGoalFromHive != null) {
        _caloriesGoal = (caloriesGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }
      if (proteinGoalFromHive != null) {
        _proteinGoal = (proteinGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }
      if (carbsGoalFromHive != null) {
        _carbsGoal = (carbsGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }
      if (fatGoalFromHive != null) {
        _fatGoal = (fatGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }

      if (updatedFromHive) {
        debugPrint("loadNutritionGoals: Updated from individual Hive keys");
        notifyListeners();
        return;
      }

      // Fall back to nutrition_goals JSON if individual keys not found
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
            'Loaded nutrition goals from nutrition_goals JSON: calories=${_caloriesGoal}, protein=${_proteinGoal}, carbs=${_carbsGoal}, fat=${_fatGoal}');
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
    try {
      final String entriesJson =
          jsonEncode(_entries.map((e) => e.toJson()).toList());
      await StorageService().put(_storageKey, entriesJson);
      debugPrint('Saved ${_entries.length} entries to local storage.');
      // No longer syncing the entire JSON blob here
    } catch (e) {
      debugPrint('Error saving entries to local storage: $e');
    }
  }

  // Syncs a single entry TO Supabase (Upsert)
  Future<void> _syncSingleEntryToSupabase(FoodEntry entry) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Cannot sync entry ${entry.id}: User not logged in.');
      return;
    }

    try {
      // Calculate nutrients for this specific entry instance
      final calories = _calculateNutrientForEntry(entry, 'calories');
      final protein = _calculateNutrientForEntry(entry, 'Protein');
      final carbs =
          _calculateNutrientForEntry(entry, 'Carbohydrate, by difference');
      final fat = _calculateNutrientForEntry(entry, 'Total lipid (fat)');

      final Map<String, dynamic> entryData = {
        'entry_id': entry.id, // Use the existing UUID
        'user_id': userId,
        'fdc_id': entry.food.fdcId,
        'food_name': entry.food.name,
        'brand_name': entry.food.brandName,
        'meal': entry.meal,
        'quantity': entry.quantity,
        'unit': entry.unit,
        'entry_date': entry.date.toUtc().toIso8601String(), // Store in UTC
        'serving_description': entry.servingDescription,
        'calories_per_entry': calories,
        'protein_per_entry': protein,
        'carbs_per_entry': carbs,
        'fat_per_entry': fat,
        // created_at is handled by default value
        // updated_at is handled by trigger or default value
      };

      await Supabase.instance.client.from('food_log').upsert(entryData);
      debugPrint('Synced entry ${entry.id} to Supabase food_log.');
    } catch (e) {
      debugPrint('Error syncing entry ${entry.id} to Supabase food_log: $e');
      // TODO: Implement retry logic or error queuing if needed
    }
  }

  // Deletes a single entry FROM Supabase
  Future<void> _deleteEntryFromSupabase(String entryId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint(
          'Cannot delete entry $entryId from Supabase: User not logged in.');
      return;
    }

    try {
      await Supabase.instance.client.from('food_log').delete().match({
        'entry_id': entryId,
        'user_id': userId
      }); // Match both entry and user ID
      debugPrint('Synced deletion of entry $entryId from Supabase food_log.');
    } catch (e) {
      debugPrint(
          'Error syncing deletion of entry $entryId from Supabase food_log: $e');
      // TODO: Implement retry logic or error queuing if needed
    }
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
    debugPrint("[FoodEntryProvider] Adding entry: ${entry.food.name} (${entry.quantity} ${entry.unit}) to meal ${entry.meal} on ${entry.date.toIso8601String()}");
    _entries.add(entry);
    await _clearDateCache(); // Clear the cache to ensure fresh data
    debugPrint("[FoodEntryProvider] Cache cleared after adding entry.");
    notifyListeners(); // Notify listeners immediately after adding entry
    debugPrint("[FoodEntryProvider] Notified listeners after adding entry.");
    await _saveEntries(); // Save to local storage
    debugPrint("[FoodEntryProvider] Entry saved locally.");
    await _syncSingleEntryToSupabase(entry); // Sync to Supabase
    debugPrint("[FoodEntryProvider] Entry synced to Supabase.");
    _notifyNativeStatsChanged(); // Update widgets if needed
    debugPrint("[FoodEntryProvider] Notified native stats changed.");

    // Force a refresh of the cached data for this date
    final cacheKey =
        '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
    _dateEntriesCache.remove(cacheKey);
    _dateCacheTimestamp.remove(cacheKey);
    debugPrint("[FoodEntryProvider] Removed date cache for ${cacheKey}.");

    // Notify listeners again after all async operations are complete
    notifyListeners();
    debugPrint("[FoodEntryProvider] Notified listeners again after async ops.");
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _clearDateCache();
    notifyListeners();
    await _saveEntries(); // Save locally first
    await _deleteEntryFromSupabase(id); // Then sync deletion to Supabase
    _notifyNativeStatsChanged();
  }

  Future<void> clearEntries() async {
    _entries.clear();
    await _clearDateCache();
    notifyListeners();
    // Also clear from storage when clearing in memory
    await StorageService().delete(_storageKey);
    debugPrint('Entries cleared from memory and local storage.');
    // Optionally trigger Supabase sync for clearing in the future
    _notifyNativeStatsChanged(); // Keep this if needed for widgets
  }

  // --- Corrected Calculation Methods ---

  // Helper to calculate nutrient value for a single entry
  double _calculateNutrientForEntry(FoodEntry entry, String nutrientKey) {
    // --- Special handling for AI-detected foods ---
    // AI-detected foods store the selected serving's nutrients directly in the FoodItem
    // and the quantity represents the multiplier for that serving.
    if (entry.food.brandName == 'AI Detected') {
      double baseValue = 0.0;
      if (nutrientKey == 'calories') {
        baseValue = entry.food.calories;
      } else {
        baseValue = entry.food.nutrients[nutrientKey] ?? 0.0;
      }
      double calculatedValue = baseValue * entry.quantity;
      debugPrint("[DEBUG Provider] AI Entry: ${entry.food.name}, Nutrient: $nutrientKey, BaseValue: $baseValue, Quantity: ${entry.quantity}, Result: $calculatedValue");
      return calculatedValue;
    }

    // --- Existing logic for non-AI foods ---
    Serving? serving;
    // Try to find the exact serving description saved with the entry
    if (entry.servingDescription != null && entry.food.servings.isNotEmpty) {
      try {
        // Find the serving that matches the description stored in the entry
        serving = entry.food.servings
            .firstWhere((s) => s.description == entry.servingDescription);
      } catch (e) {
        print(
            "Warning: Serving description '${entry.servingDescription}' not found for ${entry.food.name}. Falling back.");
        serving = null; // Ensure serving is null if not found
      }
    }

    double multiplier = 1.0;
    double baseValue = 0.0;

    if (serving != null) {
      // --- Calculation based on the specific serving ---
      double baseAmount = serving.metricAmount;
      if (baseAmount <= 0) {
        print(
            "Warning: Serving base amount is invalid (${baseAmount}) for ${serving.description}, defaulting to 1.");
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
        multiplier = entry.quantity /
            baseAmount; // Assumes baseAmount is 1 for "1 unit" servings
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
        print(
            "Warning: Cannot reliably calculate nutrient for ${entry.food.name} with unit '${entry.unit}' in fallback mode.");
        return 0.0; // Return 0 for this entry if unit conversion is impossible in fallback
      }
      // If unit is 'g', quantityInGrams remains entry.quantity

      double foodServingSize = entry.food.servingSize; // This is typically 100g
      if (foodServingSize <= 0) {
        print(
            "Warning: Food default serving size is invalid (${foodServingSize}) for ${entry.food.name}, defaulting to 100g.");
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
    debugPrint("[DEBUG Provider] Entry: ${entry.food.name}, Nutrient: $nutrientKey, BaseValue: $baseValue, Multiplier: $multiplier, Result: $calculatedValue");
    return calculatedValue;
  }

  double getTotalCaloriesForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0,
        (sum, entry) => sum + _calculateNutrientForEntry(entry, 'calories'));
  }

  double getTotalProteinForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0,
        (sum, entry) => sum + _calculateNutrientForEntry(entry, 'Protein'));
  }

  double getTotalCarbsForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(
        0.0,
        (sum, entry) =>
            sum +
            _calculateNutrientForEntry(entry, 'Carbohydrate, by difference'));
  }

  double getTotalFatForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(
        0.0,
        (sum, entry) =>
            sum + _calculateNutrientForEntry(entry, 'Total lipid (fat)'));
  }

  // --- NEW Centralized Calculation Method ---

  Map<String, double> getNutrientTotalsForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final entry in entriesForDate) {
      totalCalories += _calculateNutrientForEntry(entry, 'calories');
      totalProtein += _calculateNutrientForEntry(entry, 'Protein');
      totalCarbs +=
          _calculateNutrientForEntry(entry, 'Carbohydrate, by difference');
      totalFat += _calculateNutrientForEntry(entry, 'Total lipid (fat)');
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  // --- End NEW Method ---

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

    try {
      // First check for individual keys (these are saved by auth flow)
      final caloriesGoalFromHive = StorageService().get('calories_goal');
      final proteinGoalFromHive = StorageService().get('protein_goal');
      final carbsGoalFromHive = StorageService().get('carbs_goal');
      final fatGoalFromHive = StorageService().get('fat_goal');

      debugPrint(
          "FoodEntryProvider Values from Hive: calories_goal=$caloriesGoalFromHive, protein_goal=$proteinGoalFromHive, carbs_goal=$carbsGoalFromHive, fat_goal=$fatGoalFromHive");

      // Update provider state if values are found in Hive
      bool updatedFromHive = false;
      if (caloriesGoalFromHive != null) {
        _caloriesGoal = (caloriesGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }
      if (proteinGoalFromHive != null) {
        _proteinGoal = (proteinGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }
      if (carbsGoalFromHive != null) {
        _carbsGoal = (carbsGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }
      if (fatGoalFromHive != null) {
        _fatGoal = (fatGoalFromHive as num).toDouble();
        updatedFromHive = true;
      }

      if (updatedFromHive) {
        debugPrint(
            "FoodEntryProvider: Updated values from individual Hive keys");
        debugPrint(
            "FoodEntryProvider updated values: calories=${_caloriesGoal}, protein=${_proteinGoal}, carbs=${_carbsGoal}, fat=${_fatGoal}");
        notifyListeners();
        diagnosticInfo['updatedFromIndividualKeys'] = true;
      } else {
        // If individual keys don't exist, fall back to nutrition_goals
        await loadNutritionGoals();
        diagnosticInfo['loadedFromNutritionGoals'] = true;
      }

      diagnosticInfo['success'] = true;
    } catch (e) {
      diagnosticInfo['errors'].add('General error: ${e.toString()}');
      debugPrint("FoodEntryProvider forceSyncAndDiagnose error: $e");
    }

    return diagnosticInfo;
  }

  // --- Helper to fetch full food details via Supabase Edge Function ---
  Future<FoodItem?> _fetchFullFoodDetails(String foodId) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('Error fetching food details: User not authenticated.');
      return null;
    }
    // Ensure foodId is not empty
    if (foodId.isEmpty) {
      debugPrint('Error fetching food details: foodId is empty.');
      return null;
    }

    // URL for the Supabase Edge Function (should match searchPage.dart)
    const String fatSecretProxyUrl =
        'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/fatsecret-proxy';

    try {
      final response = await http.post(
        Uri.parse(fatSecretProxyUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'endpoint': 'get', // Assuming 'get' is the endpoint for food details
          'query': foodId, // Pass the food ID as the query
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // FatSecret 'food.get' returns the food details directly under a 'food' key
        if (responseBody != null && responseBody['food'] != null) {
          // Use the existing factory from searchPage.dart to parse the detailed food data
          return FoodItem.fromFatSecretJson(
              responseBody['food'] as Map<String, dynamic>);
        } else {
          debugPrint(
              'Error parsing food details response for ID $foodId: "food" key not found or null.');
          return null;
        }
      } else {
        debugPrint(
            'Proxy Function Error fetching food details for ID $foodId (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint(
          'Error calling proxy function for food details ID $foodId: $e');
      return null;
    }
  }
  // --- End Helper ---

  Future<void> loadEntriesFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Cannot load entries from Supabase: User not logged in.');
      return;
    }

    debugPrint('Loading entries from Supabase food_log...');
    try {
      final response = await Supabase.instance.client
          .from('food_log')
          .select() // Select all columns needed to reconstruct FoodEntry
          .eq('user_id', userId);

      if (response is List) {
        // final Set<String> localEntryIds = _entries.map((e) => e.id).toSet(); // REMOVED - _entries is cleared before this now
        int processedCount = 0; // Count processed records
        List<FoodEntry> fetchedEntries =
            []; // Temp list to hold successfully fetched entries

        // Use Future.forEach for async operations inside the loop
        await Future.forEach(response, (record) async {
          if (record is Map<String, dynamic>) {
            try {
              final String foodId = record['fdc_id']?.toString() ?? '';
              if (foodId.isEmpty) {
                debugPrint(
                    'Skipping record due to missing fdc_id: ${record['entry_id']}');
                return; // Skip this record if foodId is missing
              }

              // Fetch the full food details using the helper function
              final FoodItem? fullFoodItem =
                  await _fetchFullFoodDetails(foodId);

              if (fullFoodItem != null) {
                // Successfully fetched full details, create the FoodEntry
                final entry = FoodEntry(
                  id: record['entry_id'],
                  food: fullFoodItem, // Use the fully detailed food item
                  meal: record['meal'] ?? 'Unknown',
                  quantity: (record['quantity'] as num?)?.toDouble() ?? 0.0,
                  unit: record['unit'] ?? '',
                  date: DateTime.parse(record['entry_date'])
                      .toLocal(), // Convert back to local
                  servingDescription: record['serving_description'],
                );

                // Add successfully created entry to the temporary list
                fetchedEntries.add(entry);
                processedCount++;
              } else {
                // Failed to fetch full details, log a warning
                debugPrint(
                    'Warning: Could not fetch full details for food ID $foodId (Entry ID: ${record['entry_id']}). Skipping this entry during load.');
                // Optionally create a placeholder entry if needed, but skipping is safer
              }
            } catch (e) {
              debugPrint(
                  'Error processing Supabase entry record: $record. Error: $e');
            }
          }
        });

        // After processing all records, replace the main list and save
        // Since _entries was cleared by loadEntriesForCurrentUser, we just assign the fetched list
        _entries = fetchedEntries;
        int finalEntryCount = _entries.length;

        debugPrint(
            'Loaded from Supabase. Processed ${processedCount} records. Final entry count: ${finalEntryCount}.');

        // Always notify and save if entries were loaded, even if count is 0 (to reflect cleared state)
        await _clearDateCache(); // Clear cache
        notifyListeners(); // Notify UI about changes
        await _saveEntries(); // Save the (potentially empty) list locally
      } else {
        debugPrint('Load from Supabase failed: Unexpected response format.');
      }
    } catch (e) {
      debugPrint('Error loading entries from Supabase food_log: $e');
    }
  }

  // New method to explicitly load entries for the current user
  Future<void> loadEntriesForCurrentUser() async {
    debugPrint("[Provider Load] Starting loadEntriesForCurrentUser...");
    // 1. Ensure provider is initialized structurally
    await ensureInitialized();

    // 2. Clear any existing entries in memory and cache (important!)
    _entries.clear();
    await _clearDateCache();
    debugPrint("[Provider Load] Cleared existing in-memory entries and cache.");

    // 3. Explicitly delete local storage entry data before loading from Supabase
    await StorageService().delete(_storageKey);
    debugPrint(
        "[Provider Load] Deleted local storage entries ('$_storageKey').");

    // 4. Load fresh entries directly from Supabase for the current user
    await loadEntriesFromSupabase(); // This method now handles fetching and merging/replacing
    debugPrint("[Provider Load] Finished loading/merging from Supabase.");

    // 5. Notify listeners after all loading is complete
    notifyListeners();
    debugPrint(
        "[Provider Load] loadEntriesForCurrentUser complete. Notified listeners.");
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
