import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/foodEntry.dart';
import '../screens/searchPage.dart';
import 'package:macrotracker/services/storage_service.dart';
import '../services/widget_service.dart';
import 'dart:convert';
import 'dart:math';

// Define the channel name consistently
const String _statsChannelName = 'app.macrobalance.com/stats';
const MethodChannel _statsChannel = MethodChannel(_statsChannelName);

class FoodEntryProvider with ChangeNotifier {
  List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';

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
    debugPrint("[FoodEntry] Starting _initialize...");
    if (_initialLoadComplete) {
      debugPrint("[FoodEntry] _initialize already complete, returning.");
      return;
    }
    debugPrint("[FoodEntry] Initializing provider structure...");
    
    // Clear any potential leftover state from previous sessions
    _entries.clear();
    await _clearDateCache();
    debugPrint("[FoodEntry] Cleared entries and cache.");
    
    _initialLoadComplete = true;
    debugPrint("[FoodEntry] Provider structure initialized. InitialLoadComplete = true.");
    debugPrint("[FoodEntry] _initialize finished.");
  }

  Future<void> ensureInitialized() async {
    if (!_initialLoadComplete) {
      await _initialize();
    }
  }

  // --- Getters ---
  List<FoodEntry> get entries => _entries;

  // --- Entry Management ---
  Future<void> addEntry(FoodEntry entry) async {
    debugPrint("[FoodEntry] Adding entry: ${entry.food.name}, Quantity: ${entry.quantity}");
    _entries.add(entry);
    await _clearDateCache(); // Clear cache as entries changed
    notifyListeners();
    await saveEntries(); // Save locally only
    await _updateWidgets();
    debugPrint("[FoodEntry] Entry ${entry.id} added locally.");
  }

  Future<void> removeEntry(String entryId) async {
    debugPrint("[FoodEntry] Removing entry with ID: $entryId");
    final initialCount = _entries.length;
    _entries.removeWhere((entry) => entry.id == entryId);
    if (_entries.length < initialCount) {
      await _clearDateCache(); // Clear cache as entries changed
      notifyListeners();
      await saveEntries(); // Save locally only
      debugPrint("[FoodEntry] Entry $entryId removed locally.");
    } else {
      debugPrint("[FoodEntry] Entry $entryId not found in list.");
    }
  }

  Future<void> updateEntry(FoodEntry updatedEntry) async {
    debugPrint("[FoodEntry] Starting updateEntry for entry ${updatedEntry.id}...");
    final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
    debugPrint("[FoodEntry] Received updatedEntry: ID=${updatedEntry.id}, Name=${updatedEntry.food.name}, Quantity=${updatedEntry.quantity}");
    
    if (index != -1) {
      debugPrint("[FoodEntry] Found entry ${updatedEntry.id} at index $index. Old entry: ${_entries[index].food.name}, Quantity: ${_entries[index].quantity}");
      _entries[index] = updatedEntry;
      debugPrint("[FoodEntry] Updated entry ${updatedEntry.id}. New entry: ${_entries[index].food.name}, Quantity: ${_entries[index].quantity}");
      await _clearDateCache(); // Clear cache as entries changed
      debugPrint("[FoodEntry] Cleared date cache after update.");
      notifyListeners();
      await saveEntries(); // Save locally only
      debugPrint("[FoodEntry] Entry ${updatedEntry.id} updated locally.");
    } else {
      debugPrint("[FoodEntry] Entry ${updatedEntry.id} not found for update.");
    }
  }

  Future<void> clearEntries() async {
    debugPrint("[FoodEntry] Clearing all entries...");
    _entries.clear();
    await _clearDateCache(); // Clear cache
    notifyListeners();
    await StorageService().delete(_storageKey); // Delete local storage data
    debugPrint("[FoodEntry] All entries cleared locally.");
  }

  // --- Data Retrieval ---
  List<FoodEntry> getAllEntriesForDate(DateTime date) {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // Check cache first
    if (_dateEntriesCache.containsKey(dateKey) && _dateCacheTimestamp.containsKey(dateKey)) {
      final cacheTime = _dateCacheTimestamp[dateKey]!;
      if (DateTime.now().difference(cacheTime) < _cacheDuration) {
        debugPrint("[FoodEntry] Returning cached entries for $dateKey (${_dateEntriesCache[dateKey]!.length} entries)");
        return _dateEntriesCache[dateKey]!;
      }
    }

         // Filter entries for the specific date
     final filteredEntries = _entries.where((entry) {
       return entry.date.year == date.year &&
              entry.date.month == date.month &&
              entry.date.day == date.day;
     }).toList();

    // Cache the result
    _dateEntriesCache[dateKey] = filteredEntries;
    _dateCacheTimestamp[dateKey] = DateTime.now();

    debugPrint("[FoodEntry] Filtered and cached ${filteredEntries.length} entries for date ${date.toIso8601String()}");
    return filteredEntries;
  }

  List<FoodEntry> getEntriesForMeal(DateTime date, String meal) {
    debugPrint("[FoodEntry] Getting entries for date ${date.toIso8601String()} and meal $meal...");
    final entriesForDate = getAllEntriesForDate(date);
    final filteredEntries = entriesForDate.where((entry) => entry.meal == meal).toList();
    debugPrint("[FoodEntry] Found ${filteredEntries.length} entries for meal $meal on ${date.toIso8601String()}.");
    return filteredEntries;
  }

  // --- Nutrient Calculations ---
  double calculateNutrientForEntry(FoodEntry entry, String nutrientKey) {
    debugPrint("[FoodEntry] Calculating nutrient '$nutrientKey' for entry: ${entry.food.name}, Quantity: ${entry.quantity}, Unit: ${entry.unit}");

         // Handle direct food nutrients (per 100g)
     double baseValue = 0.0;
     switch (nutrientKey.toLowerCase()) {
       case 'calories':
         baseValue = entry.food.calories;
         break;
       case 'protein':
         baseValue = entry.food.nutrients['Protein'] ?? 0.0;
         break;
       case 'carbs':
         baseValue = entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0;
         break;
       case 'fat':
         baseValue = entry.food.nutrients['Total lipid (fat)'] ?? 0.0;
         break;
     }

    // Direct calculation for weight-based entries (grams/ounces)
    if (entry.unit.toLowerCase() == 'g' || entry.unit.toLowerCase() == 'grams') {
      double calculatedValue = baseValue * entry.quantity / 100;
      debugPrint("[FoodEntry] Direct calculation (grams): $baseValue * ${entry.quantity} / 100 = $calculatedValue");
      return calculatedValue;
    }

    if (entry.unit.toLowerCase() == 'oz' || entry.unit.toLowerCase() == 'ounces') {
      double gramsFromOz = entry.quantity * 28.3495; // Convert oz to grams
      double calculatedValue = baseValue * gramsFromOz / 100;
      debugPrint("[FoodEntry] Direct calculation (ounces): $baseValue * $gramsFromOz / 100 = $calculatedValue");
      return calculatedValue;
    }

    // For serving-based entries, use serving information
    if (entry.food.servings != null && entry.food.servings!.isNotEmpty) {
      final serving = entry.food.servings!.first;
      double multiplier = 1.0;
      double baseValue = 0.0;

             switch (nutrientKey.toLowerCase()) {
         case 'calories':
           baseValue = serving.calories;
           break;
         case 'protein':
           baseValue = serving.nutrients['Protein'] ?? 0.0;
           break;
         case 'carbs':
           baseValue = serving.nutrients['Carbohydrate, by difference'] ?? 0.0;
           break;
         case 'fat':
           baseValue = serving.nutrients['Total lipid (fat)'] ?? 0.0;
           break;
       }

      double baseAmount = serving.metricAmount;
      String servingUnit = serving.metricUnit.toLowerCase();
      bool isWeightBasedServing = (servingUnit == 'g' || servingUnit == 'oz');

      if (isWeightBasedServing) {
        // Weight-based serving
        double quantityGrams = entry.quantity;
        if (entry.unit.toLowerCase() == 'oz' || entry.unit.toLowerCase() == 'ounces') {
          quantityGrams = entry.quantity * 28.3495; // Convert oz to grams
        }

        if (servingUnit == 'oz') {
          baseAmount = baseAmount * 28.3495; // Convert serving amount to grams
        }

        multiplier = quantityGrams / baseAmount;
        debugPrint("[FoodEntry] Weight-based serving calculation: quantity=$quantityGrams, baseAmount=$baseAmount, multiplier=$multiplier");
      } else {
        // Volume or count-based serving
        double quantityGrams = entry.quantity;
        if (entry.unit.toLowerCase() == 'oz' || entry.unit.toLowerCase() == 'ounces') {
          quantityGrams = entry.quantity * 28.3495; // Convert oz to grams for consistency
        }

        // Use food serving size (typically 100g) as the baseline
        double foodServingSize = entry.food.servingSize; // This is typically 100g
        multiplier = quantityGrams / foodServingSize;
        debugPrint("[FoodEntry] Volume/count-based serving calculation: quantity=$quantityGrams, foodServingSize=$foodServingSize, multiplier=$multiplier");

                 // Get base value from food (per 100g) instead of serving
         switch (nutrientKey.toLowerCase()) {
           case 'calories':
             baseValue = entry.food.calories;
             break;
           case 'protein':
             baseValue = entry.food.nutrients['Protein'] ?? 0.0;
             break;
           case 'carbs':
             baseValue = entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0;
             break;
           case 'fat':
             baseValue = entry.food.nutrients['Total lipid (fat)'] ?? 0.0;
             break;
         }
      }

      double calculatedValue = baseValue * multiplier;
      debugPrint("[FoodEntry] Serving-based calculation: baseValue=$baseValue, multiplier=$multiplier, result=$calculatedValue");
      return calculatedValue;
    }

    debugPrint("[FoodEntry] No valid calculation method found, returning 0");
    return 0.0;
  }

  double getTotalCaloriesForDate(DateTime date) {
    return getAllEntriesForDate(date)
        .fold(0.0, (sum, entry) => sum + calculateNutrientForEntry(entry, 'calories'));
  }

  double getTotalProteinForDate(DateTime date) {
    return getAllEntriesForDate(date)
        .fold(0.0, (sum, entry) => sum + calculateNutrientForEntry(entry, 'protein'));
  }

  double getTotalCarbsForDate(DateTime date) {
    final total = getAllEntriesForDate(date)
        .fold(0.0, (sum, entry) => sum + calculateNutrientForEntry(entry, 'carbs'));
    debugPrint("[FoodEntry] Total carbs for ${date.toIso8601String()}: $total");
    return total;
  }

  double getTotalFatForDate(DateTime date) {
    final total = getAllEntriesForDate(date)
        .fold(0.0, (sum, entry) => sum + calculateNutrientForEntry(entry, 'fat'));
    debugPrint("[FoodEntry] Total fat for ${date.toIso8601String()}: $total");
    return total;
  }

  Map<String, double> getNutrientTotalsForDate(DateTime date) {
    final entries = getAllEntriesForDate(date);
    
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final entry in entries) {
      totalCalories += calculateNutrientForEntry(entry, 'calories');
      totalProtein += calculateNutrientForEntry(entry, 'protein');
      totalCarbs += calculateNutrientForEntry(entry, 'carbs');
      totalFat += calculateNutrientForEntry(entry, 'fat');
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  // --- Storage Operations ---
  Future<void> loadEntries() async {
    debugPrint("[FoodEntry] Loading entries from storage...");
    final entriesJson = StorageService().get(_storageKey);
    if (entriesJson != null) {
      _loadEntriesFromJson(entriesJson);
      debugPrint("[FoodEntry] Loaded ${_entries.length} entries from storage.");
    } else {
      debugPrint("[FoodEntry] No entries found in storage.");
    }
    notifyListeners();
  }

  void _loadEntriesFromJson(String entriesJson) {
    try {
      final List<dynamic> decodedList = jsonDecode(entriesJson);
      _entries = decodedList.map((json) => FoodEntry.fromJson(json)).toList();
    } catch (e) {
      debugPrint("[FoodEntry] Error loading entries: $e");
      _entries = [];
    }
  }

  Future<void> saveEntries() async {
    debugPrint("[FoodEntry] Saving ${_entries.length} entries...");
    final String entriesJson = jsonEncode(_entries.map((entry) => entry.toJson()).toList());
    await StorageService().put(_storageKey, entriesJson);
    debugPrint("[FoodEntry] Entries saved successfully.");
  }

  Future<void> loadEntriesForCurrentUser() async {
    debugPrint("[FoodEntry] Starting loadEntriesForCurrentUser...");
    
    // 1. Ensure provider is initialized structurally
    await ensureInitialized();
    
    // 2. Clear any existing entries to avoid duplicates
    _entries.clear();
    await _clearDateCache();
    debugPrint("[FoodEntry] Cleared existing entries and cache.");
    
    // 3. Load entries from local storage only
    await loadEntries();
    debugPrint("[FoodEntry] Loaded entries from local storage.");
    
    // 4. Notify listeners about the loaded state
    notifyListeners();
    debugPrint("[FoodEntry] loadEntriesForCurrentUser finished.");
  }

  // --- Cache Management ---
  Future<void> _clearDateCache() async {
    _dateEntriesCache.clear();
    _dateCacheTimestamp.clear();
    debugPrint("[FoodEntry] Date cache cleared.");
  }

  // --- Widget and Platform Integration ---
  Future<void> _updateWidgets() async {
    try {
      await _notifyNativeStatsChanged();
    } catch (e) {
      debugPrint('[FoodEntry] Error updating widgets: $e');
    }
  }

  Future<void> _notifyNativeStatsChanged() async {
    try {
      await _statsChannel.invokeMethod('notifyStatsChanged');
    } catch (e) {
      debugPrint('[FoodEntry] Error notifying native stats changed: $e');
    }
  }

  // --- Utility Methods ---
  Future<Map<String, dynamic>> forceSyncAndDiagnose() async {
    final diagnosticInfo = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'localEntriesCount': _entries.length,
      'cacheSize': _dateEntriesCache.length,
      'success': true
    };

    try {
      // Just refresh the entries from storage
      await loadEntries();
      diagnosticInfo['success'] = true;
    } catch (e) {
      diagnosticInfo['error'] = e.toString();
      diagnosticInfo['success'] = false;
      debugPrint("[FoodEntry] forceSyncAndDiagnose error: $e");
    }

    return diagnosticInfo;
  }

  // --- Cleanup Methods ---
  Future<void> clearUserData() async {
    debugPrint("[FoodEntry] Clearing all user data...");
    _entries.clear();
    await _clearDateCache();
    
    // Clear local storage
    await StorageService().delete(_storageKey);
    
    notifyListeners();
    debugPrint("[FoodEntry] All user data cleared.");
  }
} 