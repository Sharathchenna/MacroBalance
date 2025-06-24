// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import '../screens/searchPage.dart'; // Import Serving class definition and FoodItem
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:math'; // Added for min function
import 'dart:async'; // Added for Timer
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
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

  // Daily sync functionality
  Timer? _dailySyncTimer;
  DateTime? _lastFoodEntrySyncDate;
  static const String _lastSyncKey = 'last_food_entry_sync_date';

  FoodEntryProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint("[Provider Init] Starting _initialize...");
    if (_initialLoadComplete) {
      debugPrint("[Provider Init] _initialize already complete, returning.");
      return;
    }
    debugPrint("[Provider Init] Initializing provider structure...");
    // Clear any potential leftover state from previous sessions (belt-and-suspenders)
    _entries.clear();
    await _clearDateCache();
    debugPrint("[Provider Init] Cleared entries and cache.");
    // Load non-user-specific data or defaults if necessary
    await loadNutritionGoals(); // Load goals (might be user-specific, ensure cleared on logout too)
    debugPrint("[Provider Init] Loaded nutrition goals.");
    
    // Initialize daily sync functionality
    await _initializeDailySync();
    debugPrint("[Provider Init] Daily sync initialized.");
    
    _initialLoadComplete = true; // Mark basic structure as initialized
    debugPrint(
        "[Provider Init] Provider structure initialized. InitialLoadComplete = true.");
    // User-specific entries will be loaded via loadEntriesForCurrentUser
    debugPrint("[Provider Init] _initialize finished.");
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

  // --- Load/Save Methods (LOCAL ONLY) ---
  Future<void> loadEntries() async {
    debugPrint("[Provider Load] Starting loadEntries from local storage...");
    try {
      final String? entriesJson = StorageService().get(_storageKey);
      debugPrint(
          "[Provider Load] Raw entries JSON from storage: $entriesJson"); // Added log
      if (entriesJson != null && entriesJson.isNotEmpty) {
        debugPrint(
            "[Provider Load] Found entries in local storage. JSON length: ${entriesJson.length}");
        _loadEntriesFromJson(entriesJson);
        debugPrint(
            '[Provider Load] Loaded ${_entries.length} entries from local storage.');
      } else {
        debugPrint('[Provider Load] No entries found in local storage.');
        _entries =
            []; // Ensure entries list is initialized if nothing is loaded
      }
    } catch (e) {
      debugPrint(
          '[Provider Load] Error loading entries from local storage: $e');
      _entries = []; // Initialize to empty list on error
    }
    debugPrint(
        "[Provider Load] loadEntries finished. Current entries count: ${_entries.length}");
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
      debugPrint(
          "[Provider Load] Raw nutrition_goals JSON from storage: $nutritionGoalsString"); // Added log
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
        _goalType = nutritionGoals['goal_type'] ?? _goalType;
        _deficitSurplus = nutritionGoals['deficit_surplus'] ?? _deficitSurplus;

        debugPrint('Loaded nutrition goals from storage');
        notifyListeners();
      } else {
        debugPrint('No nutrition goals found in storage, using defaults');
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
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
    // Keep nutrition goals sync - this is for daily macros/calories tracking
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Provider Sync] Cannot sync nutrition goals: User not logged in.');
      return;
    }

    try {
      final Map<String, dynamic> goalsData = {
        'user_id': userId,
        'calories_goal': _caloriesGoal,
        'protein_goal': _proteinGoal,
        'carbs_goal': _carbsGoal,
        'fat_goal': _fatGoal,
        'steps_goal': _stepsGoal,
        'bmr': _bmr,
        'tdee': _tdee,
        'goal_weight_kg': _goalWeightKg,
        'current_weight_kg': _currentWeightKg,
        'goal_type': _goalType,
        'deficit_surplus': _deficitSurplus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('nutrition_goals').upsert(goalsData);
      debugPrint('[Provider Sync] Synced nutrition goals to Supabase successfully.');
    } catch (e) {
      debugPrint('[Provider Sync] Error syncing nutrition goals to Supabase: $e');
    }
  }

  Future<void> saveEntries() async {
    debugPrint("[Provider Save] Starting saveEntries to local storage...");
    try {
      final String entriesJson =
          jsonEncode(_entries.map((e) => e.toJson()).toList());
      await StorageService().put(_storageKey, entriesJson);
      debugPrint(
          '[Provider Save] Saved ${_entries.length} entries to local storage.');
    } catch (e) {
      debugPrint('[Provider Save] Error saving entries to local storage: $e');
    }
    debugPrint("[Provider Save] saveEntries finished.");
  }

  // --- Nutrient Calculation Methods ---
  double calculateNutrientForEntry(FoodEntry entry, String nutrientKey) {
    debugPrint("[DEBUG CALC] Calculating nutrient '$nutrientKey' for entry: ${entry.food.name}, Quantity: ${entry.quantity}, Unit: ${entry.unit}, Brand: ${entry.food.brandName}");
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
      // For AI Detected foods, the baseValue is for the selected serving. Multiply by quantity.
      double calculatedValue = baseValue * entry.quantity;
      // Ensure multiplier is not negative (though quantity shouldn't be)
      if (calculatedValue < 0) calculatedValue = 0;
      debugPrint(
          "[DEBUG CALC]   AI Detected - Food: ${entry.food.name}, BaseValue: $baseValue, Entry Quantity: ${entry.quantity}. Calculated: $calculatedValue");
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
    debugPrint("[DEBUG CALC]   Non-AI - BaseValue: $baseValue, Multiplier: $multiplier. Calculated: $calculatedValue");
    debugPrint("[DEBUG CALC]   Final calculated value for ${entry.food.name}: $calculatedValue");
    return calculatedValue;
  }

  double getTotalCaloriesForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(0.0,
        (sum, entry) => sum + calculateNutrientForEntry(entry, 'calories'));
  }

  double getTotalProteinForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(
        0.0, (sum, entry) => sum + calculateNutrientForEntry(entry, 'Protein'));
  }

  double getTotalCarbsForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(
        0.0,
        (sum, entry) =>
            sum +
            calculateNutrientForEntry(entry, 'Carbohydrate, by difference'));
  }

  double getTotalFatForDate(DateTime date) {
    final entriesForDate = getAllEntriesForDate(date);
    return entriesForDate.fold(
        0.0,
        (sum, entry) =>
            sum + calculateNutrientForEntry(entry, 'Total lipid (fat)'));
  }

  // --- Centralized Calculation Method ---
  Map<String, double> getNutrientTotalsForDate(DateTime date) {
    debugPrint("[DEBUG TOTALS] Calculating totals for date: ${date.toIso8601String()}");
    final entriesForDate = getAllEntriesForDate(date);
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final entry in entriesForDate) {
      debugPrint("[DEBUG TOTALS]   Processing entry: ${entry.food.name}, Calculated Calories: ${calculateNutrientForEntry(entry, 'calories')}, Protein: ${calculateNutrientForEntry(entry, 'Protein')}, Carbs: ${calculateNutrientForEntry(entry, 'Carbohydrate, by difference')}, Fat: ${calculateNutrientForEntry(entry, 'Total lipid (fat)')}");
      totalCalories += calculateNutrientForEntry(entry, 'calories');
      totalProtein += calculateNutrientForEntry(entry, 'Protein');
      totalCarbs +=
          calculateNutrientForEntry(entry, 'Carbohydrate, by difference');
      totalFat += calculateNutrientForEntry(entry, 'Total lipid (fat)');
    }

    debugPrint("[DEBUG TOTALS]   Final Totals - Calories: $totalCalories, Protein: $totalProtein, Carbs: $totalCarbs, Fat: $totalFat");
    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  List<FoodEntry> getAllEntriesForDate(DateTime date) {
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

  // --- Entry Management Methods (LOCAL ONLY) ---
  Future<void> addEntry(FoodEntry entry) async {
    debugPrint("[Provider Add] Adding entry ${entry.id}...");
    debugPrint(
        "[Provider Add] Received FoodEntry: ID=${entry.id}, Name=${entry.food.name}, Quantity=${entry.quantity}, Unit=${entry.unit}, ServingDesc=${entry.servingDescription}, FoodBrand=${entry.food.brandName}");
    _entries.add(entry);
    await _clearDateCache(); // Clear cache as entries changed
    await saveEntries(); // Save locally only
    notifyListeners(); // Notify after saving and clearing cache
    debugPrint("[Provider Add] Entry ${entry.id} added locally.");
  }

  Future<void> removeEntry(String entryId) async {
    debugPrint("[Provider Remove] Removing entry $entryId...");
    final initialLength = _entries.length;
    _entries.removeWhere((entry) => entry.id == entryId);
    if (_entries.length < initialLength) {
      debugPrint(
          "[Provider Remove] Entry $entryId found and removed from list.");
      await _clearDateCache(); // Clear cache as entries changed
      notifyListeners();
      await saveEntries(); // Save locally only
      debugPrint("[Provider Remove] Entry $entryId removed locally.");
    } else {
      debugPrint("[Provider Remove] Entry $entryId not found in list.");
    }
  }

  Future<void> clearEntries() async {
    debugPrint("[Provider Clear] Clearing all entries...");
    _entries.clear();
    await _clearDateCache(); // Clear cache
    notifyListeners();
    await StorageService().delete(_storageKey); // Delete local storage data
    debugPrint("[Provider Clear] All entries cleared locally.");
  }

  Future<void> updateEntry(FoodEntry updatedEntry) async {
    debugPrint("[Provider Update] Starting updateEntry for entry ${updatedEntry.id}...");
    final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
    debugPrint(
        "[Provider Update] Received updatedEntry: ID=${updatedEntry.id}, Name=${updatedEntry.food.name}, Quantity=${updatedEntry.quantity}, Unit=${updatedEntry.unit}, FoodCalories=${updatedEntry.food.calories}, FoodBrand=${updatedEntry.food.brandName}");
    if (index != -1) {
      debugPrint("[Provider Update] Found entry ${updatedEntry.id} at index $index. Old entry: ${_entries[index].food.name}, Quantity: ${_entries[index].quantity}");
      _entries[index] = updatedEntry;
      debugPrint("[Provider Update] Updated entry ${updatedEntry.id}. New entry: ${_entries[index].food.name}, Quantity: ${_entries[index].quantity}");
      await _clearDateCache(); // Clear cache as entries changed
      debugPrint("[Provider Update] Cleared date cache after update.");
      notifyListeners();
      await saveEntries(); // Save locally only
      debugPrint("[Provider Update] Entry ${updatedEntry.id} updated locally.");
    } else {
      debugPrint("[Provider Update] Entry ${updatedEntry.id} not found for update.");
    }
  }

  List<FoodEntry> getEntriesForMeal(DateTime date, String meal) {
    debugPrint(
        "[Provider Get] Getting entries for date ${date.toIso8601String()} and meal $meal...");
    final entriesForDate = getAllEntriesForDate(date);
    final filteredEntries =
        entriesForDate.where((entry) => entry.meal == meal).toList();
    debugPrint(
        "[Provider Get] Found ${filteredEntries.length} entries for meal $meal on ${date.toIso8601String()}.");
    return filteredEntries;
  }

  // --- Cache Management ---
  Future<void> _clearDateCache() async {
    _dateEntriesCache.clear();
    _dateCacheTimestamp.clear();
    debugPrint("[Provider Cache] Date cache cleared.");
  }

  // --- Widget and Platform Integration ---
  Future<void> _updateWidgets() async {
    try {
      await _notifyNativeStatsChanged();
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }

  Future<void> _notifyNativeStatsChanged() async {
    try {
      await _statsChannel.invokeMethod('notifyStatsChanged');
    } catch (e) {
      debugPrint('Error notifying native stats changed: $e');
    }
  }

  // --- Initialization Methods ---
  Future<void> loadEntriesForCurrentUser() async {
    debugPrint("[Provider Load] Starting loadEntriesForCurrentUser...");
    // 1. Ensure provider is initialized structurally
    await ensureInitialized();
    
    // 2. Clear any existing entries to avoid duplicates
    _entries.clear();
    await _clearDateCache();
    debugPrint("[Provider Load] Cleared existing entries and cache.");
    
    // 3. Load entries from local storage only
    await loadEntries();
    debugPrint("[Provider Load] Loaded entries from local storage.");
    
    // 4. Reinitialize daily sync for the current user
    await _initializeDailySync();
    debugPrint("[Provider Load] Daily sync reinitialized for current user.");
    
    // 5. Notify listeners about the loaded state
    notifyListeners();
    debugPrint("[Provider Load] loadEntriesForCurrentUser finished.");
  }

  // --- Utility Methods ---
  Future<Map<String, dynamic>> checkSupabaseConnection() async {
    try {
      final response = await Supabase.instance.client
          .from('nutrition_goals')
          .select('count')
          .limit(1);
      return {
        'connected': true,
        'message': 'Connection successful',
        'response': response
      };
    } catch (e) {
      return {
        'connected': false,
        'errorMessage': 'Connection error: ${e.toString()}'
      };
    }
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

  // --- Cleanup Methods ---
  Future<void> resetGoalsToDefault() async {
    debugPrint("[Provider Reset] Resetting goals to default values...");
    
    // Reset goals to defaults
    _caloriesGoal = 2000.0;
    _proteinGoal = 150.0;
    _carbsGoal = 225.0;
    _fatGoal = 65.0;
    _stepsGoal = 10000;
    _bmr = 1500.0;
    _tdee = 2000.0;
    _goalWeightKg = 0.0;
    _currentWeightKg = 0.0;
    _goalType = MacroCalculatorService.GOAL_MAINTAIN;
    _deficitSurplus = 500;
    
    // Save the reset goals
    _saveNutritionGoals();
    
    notifyListeners();
    debugPrint("[Provider Reset] Goals reset to default values.");
  }

  Future<void> syncAllDataWithSupabase() async {
    debugPrint("[Provider Sync] Syncing all data with Supabase...");
    
    try {
      // Sync nutrition goals
      await _syncNutritionGoalsToSupabase();
      debugPrint("[Provider Sync] Successfully synced nutrition goals with Supabase.");
      
      // Sync food entries
      await _syncFoodEntriesToSupabase();
      debugPrint("[Provider Sync] Successfully synced food entries with Supabase.");
    } catch (e) {
      debugPrint("[Provider Sync] Error syncing with Supabase: $e");
      // Don't throw error, just log it
    }
  }  // Initialize daily sync functionality
  Future<void> _initializeDailySync() async {
    // Load last sync date from storage
    final lastSyncString = StorageService().get(_lastSyncKey);
    if (lastSyncString != null) {
      try {
        _lastFoodEntrySyncDate = DateTime.parse(lastSyncString);
      } catch (e) {
        debugPrint("[Daily Sync] Error parsing last sync date: $e");
      }
    }
    
    // Check if user is authenticated and perform initial sync if needed
    // This handles both first-time authentication and daily sync requirements
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await _performInitialSyncIfNeeded();
    }
    
    // Schedule the next midnight sync for automatic daily backups
    _scheduleMidnightSync();
  }

// Perform initial sync when user first authenticates
Future<void> _performInitialSyncIfNeeded() async {
  debugPrint("[Initial Sync] Checking if initial sync is needed...");
  
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  
  // Check if we need to sync:
  // 1. Never synced before
  // 2. Last sync was not today
  bool shouldSync = false;
  
  if (_lastFoodEntrySyncDate == null) {
    debugPrint("[Initial Sync] Never synced before - will perform initial sync");
    shouldSync = true;
  } else {
    final lastSyncDate = DateTime(_lastFoodEntrySyncDate!.year, 
        _lastFoodEntrySyncDate!.month, _lastFoodEntrySyncDate!.day);
    if (!lastSyncDate.isAtSameMomentAs(todayDate)) {
      debugPrint("[Initial Sync] Last sync was not today - will sync");
      shouldSync = true;
    } else {
      debugPrint("[Initial Sync] Already synced today - skipping initial sync");
    }
  }
  
  if (shouldSync) {
    try {
      debugPrint("[Initial Sync] Starting initial food entry sync...");
      
      // Sync food entries to Supabase
      await _syncFoodEntriesToSupabase();
      
      // Update last sync date
      _lastFoodEntrySyncDate = today;
      await StorageService().put(_lastSyncKey, today.toIso8601String());
      
      debugPrint("[Initial Sync] Initial sync completed successfully");
    } catch (e) {
      debugPrint("[Initial Sync] Error during initial sync: $e");
      // Don't throw error to avoid blocking user authentication
    }
  }
}

// Schedule sync to run at midnight
  void _scheduleMidnightSync() {
    _dailySyncTimer?.cancel(); // Cancel any existing timer
    
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);
    
    debugPrint("[Daily Sync] Scheduling next sync for: $nextMidnight (in ${timeUntilMidnight.inMinutes} minutes)");
    
    _dailySyncTimer = Timer(timeUntilMidnight, () async {
      await _performDailySync();
      // Schedule the next day's sync
      _scheduleMidnightSync();
    });
  }

  // Perform the daily sync at midnight
  Future<void> _performDailySync() async {
    debugPrint("[Daily Sync] Starting daily food entry sync...");
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Check if we already synced today
    if (_lastFoodEntrySyncDate != null) {
      final lastSyncDate = DateTime(_lastFoodEntrySyncDate!.year, 
          _lastFoodEntrySyncDate!.month, _lastFoodEntrySyncDate!.day);
      if (lastSyncDate.isAtSameMomentAs(todayDate)) {
        debugPrint("[Daily Sync] Already synced today, skipping...");
        return;
      }
    }
    
    try {
      // Sync food entries to Supabase
      await _syncFoodEntriesToSupabase();
      
      // Update last sync date
      _lastFoodEntrySyncDate = today;
      await StorageService().put(_lastSyncKey, today.toIso8601String());
      
      debugPrint("[Daily Sync] Daily sync completed successfully");
    } catch (e) {
      debugPrint("[Daily Sync] Error during daily sync: $e");
    }
  }

  // Sync food entries to Supabase
  Future<void> _syncFoodEntriesToSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Food Sync] Cannot sync food entries: User not logged in.');
      return;
    }

    try {
      debugPrint('[Food Sync] Starting food entries sync for user: $userId');
      
      // Get local entries
      final localEntries = _entries.map((entry) => {
        ...entry.toJson(),
        'user_id': userId,
        'synced_at': DateTime.now().toIso8601String(),
      }).toList();
      
      if (localEntries.isEmpty) {
        debugPrint('[Food Sync] No local entries to sync');
        return;
      }
      
      // Batch sync entries to avoid overwhelming the database
      const batchSize = 50;
      for (int i = 0; i < localEntries.length; i += batchSize) {
        final end = (i + batchSize < localEntries.length) ? i + batchSize : localEntries.length;
        final batch = localEntries.sublist(i, end);
        
        debugPrint('[Food Sync] Syncing batch ${(i / batchSize).floor() + 1} of ${(localEntries.length / batchSize).ceil()} (${batch.length} entries)');
        
        await Supabase.instance.client
            .from('food_entries')
            .upsert(batch);
      }
      
      debugPrint('[Food Sync] Successfully synced ${localEntries.length} food entries to Supabase');
    } catch (e) {
      debugPrint('[Food Sync] Error syncing food entries to Supabase: $e');
      rethrow;
    }
  }

  // Manual sync method for testing or force sync
  Future<void> forceFoodEntrySync() async {
    debugPrint("[Manual Sync] Force syncing food entries...");
    try {
      await _syncFoodEntriesToSupabase();
      
      // Update last sync date
      final now = DateTime.now();
      _lastFoodEntrySyncDate = now;
      await StorageService().put(_lastSyncKey, now.toIso8601String());
      
      debugPrint("[Manual Sync] Force sync completed successfully");
    } catch (e) {
      debugPrint("[Manual Sync] Error during force sync: $e");
      rethrow;
    }
  }

  // Check if sync is needed (for UI display)
  bool get needsSync {
    if (_lastFoodEntrySyncDate == null) return true;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastSyncDate = DateTime(_lastFoodEntrySyncDate!.year, 
        _lastFoodEntrySyncDate!.month, _lastFoodEntrySyncDate!.day);
    
    return !lastSyncDate.isAtSameMomentAs(today);
  }

  // Check if this is the first time syncing
  bool get isFirstTimeSync => _lastFoodEntrySyncDate == null;
  
  // Get sync status message for UI
  String get syncStatusMessage {
    if (_lastFoodEntrySyncDate == null) {
      return 'Never synced';
    }
    
    final now = DateTime.now();
    final daysSince = now.difference(_lastFoodEntrySyncDate!).inDays;
    
    if (daysSince == 0) {
      return 'Synced today';
    } else if (daysSince == 1) {
      return 'Synced yesterday';
    } else {
      return 'Synced $daysSince days ago';
    }
  }
  
  // Get sync subtitle for UI
  String get syncSubtitle {
    if (_lastFoodEntrySyncDate == null) {
      return 'Tap to backup your food entries to cloud';
    }
    
    if (needsSync) {
      return 'Tap to sync today\'s data to cloud';
    } else {
      return 'Your data is backed up and secure';
    }
  }

  // Get last sync date for UI display
  DateTime? get lastSyncDate => _lastFoodEntrySyncDate;

  Future<void> clearUserData() async {
    debugPrint("[Provider Clear] Clearing all user data...");
    
    // Cancel daily sync timer
    _dailySyncTimer?.cancel();
    _dailySyncTimer = null;
    _lastFoodEntrySyncDate = null;
    
    _entries.clear();
    await _clearDateCache();
    
    // Reset goals to defaults
    _caloriesGoal = 2000.0;
    _proteinGoal = 150.0;
    _carbsGoal = 225.0;
    _fatGoal = 65.0;
    _stepsGoal = 10000;
    _bmr = 1500.0;
    _tdee = 2000.0;
    _goalWeightKg = 0.0;
    _currentWeightKg = 0.0;
    _goalType = MacroCalculatorService.GOAL_MAINTAIN;
    _deficitSurplus = 500;
    
    // Clear local storage
    await StorageService().delete(_storageKey);
    await StorageService().delete('nutrition_goals');
    await StorageService().delete(_lastSyncKey);
    
    notifyListeners();
    debugPrint("[Provider Clear] All user data cleared.");
  }

  @override
  void dispose() {
    _dailySyncTimer?.cancel();
    super.dispose();
  }
}
