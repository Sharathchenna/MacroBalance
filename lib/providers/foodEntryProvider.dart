// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import '../screens/searchPage.dart'; // Import Serving class definition and FoodItem
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:math'; // Added for min function
import 'dart:async'; // Added for Timer
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:macrotracker/services/widget_service.dart';
import 'package:macrotracker/providers/goals_provider.dart';

// Define the channel name consistently
const String _statsChannelName = 'app.macrobalance.com/stats';
const MethodChannel _statsChannel = MethodChannel(_statsChannelName);

/// The food entries the user has logged: stored on the device and synced to
/// `food_entries`. Goals live in [GoalsProvider].
class FoodEntryProvider with ChangeNotifier {
  List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';

  // Cache for date entries
  final Map<String, List<FoodEntry>> _dateEntriesCache = {};
  final Map<String, DateTime> _dateCacheTimestamp = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Flag to prevent multiple initial loads
  bool _initialLoadComplete = false;

  // Daily sync functionality
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

  /// True once this account's entries have been read from the device.
  bool get isLoaded => _isLoaded;
  bool _isLoaded = false;

  /// Called after the log changes: with the entry's day for an add, edit or
  /// delete, or null when the whole log may have changed (load, cloud merge).
  /// The energy estimate refreshes from it.
  void Function(DateTime? day)? onEntriesChanged;

  /// Total cals logged on each day that has entries.
  Map<DateTime, double> caloriesByDay() {
    final out = <DateTime, double>{};
    for (final e in _entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      out[day] = (out[day] ?? 0) + calculateNutrientForEntry(e, 'calories');
    }
    return out;
  }

  // --- Load/Save Methods (LOCAL ONLY) ---
  Future<void> loadEntries() async {
    debugPrint("[Provider Load] Starting loadEntries from local storage...");
    try {
      final String? entriesJson = StorageService().get(_storageKey);
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
      // Decode entries one by one so a single bad row can't blank the diary.
      final List<FoodEntry> loaded = [];
      for (final jsonItem in decodedList) {
        try {
          loaded.add(FoodEntry.fromJson(Map<String, dynamic>.from(jsonItem as Map)));
        } catch (e) {
          debugPrint('Skipping unreadable food entry: $e');
        }
      }
      _entries = loaded;
    } catch (e) {
      debugPrint('Error decoding entries JSON: $e');
      _entries = []; // Reset entries on decoding error
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
  double calculateNutrientForEntry(FoodEntry entry, String nutrientKey) =>
      nutrientForEntry(entry, nutrientKey);

  /// Amount of [nutrientKey] ('calories', 'Protein', ...) in one logged entry.
  /// Static and pure so it can be unit tested without storage or Supabase.
  static double nutrientForEntry(FoodEntry entry, String nutrientKey) {
    // --- Special handling for AI-detected foods ---
    // AI-detected foods logged from the AI screens store the selected serving's
    // nutrients directly in the FoodItem, and quantity is the multiplier. A
    // saved AI food logged later carries all its servings instead, so use the
    // chosen serving when it can be found.
    final hasMatchingServing = entry.servingDescription != null &&
        entry.food.servings.any((s) => s.description == entry.servingDescription);
    if (entry.food.brandName == 'AI Detected' && !hasMatchingServing) {
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
        // The serving's own amount is in its unit; compare grams with grams.
        final baseGrams = servingUnit == 'oz' ? baseAmount * 28.35 : baseAmount;
        multiplier = quantityGrams / baseGrams;
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
    final entriesForDate = getAllEntriesForDate(date);
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final entry in entriesForDate) {
      totalCalories += calculateNutrientForEntry(entry, 'calories');
      totalProtein += calculateNutrientForEntry(entry, 'Protein');
      totalCarbs +=
          calculateNutrientForEntry(entry, 'Carbohydrate, by difference');
      totalFat += calculateNutrientForEntry(entry, 'Total lipid (fat)');
    }

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
    await saveEntries();
    notifyListeners(); // Notify after saving and clearing cache
    _updateWidgets();
    _pushUpsert(entry);
    onEntriesChanged?.call(entry.date);
    debugPrint("[Provider Add] Entry ${entry.id} added locally.");
  }

  Future<void> removeEntry(String entryId) async {
    debugPrint("[Provider Remove] Removing entry $entryId...");
    final initialLength = _entries.length;
    final removedDays = [
      for (final entry in _entries)
        if (entry.id == entryId) entry.date,
    ];
    _entries.removeWhere((entry) => entry.id == entryId);
    if (_entries.length < initialLength) {
      debugPrint(
          "[Provider Remove] Entry $entryId found and removed from list.");
      await _clearDateCache(); // Clear cache as entries changed
      notifyListeners();
      await saveEntries();
      _updateWidgets();
      _pushDelete(entryId);
      for (final day in removedDays) {
        onEntriesChanged?.call(day);
      }
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
      final oldDay = _entries[index].date;
      _entries[index] = updatedEntry;
      debugPrint("[Provider Update] Updated entry ${updatedEntry.id}. New entry: ${_entries[index].food.name}, Quantity: ${_entries[index].quantity}");
      await _clearDateCache(); // Clear cache as entries changed
      debugPrint("[Provider Update] Cleared date cache after update.");
      notifyListeners();
      await saveEntries();
      _updateWidgets();
      _pushUpsert(updatedEntry);
      onEntriesChanged?.call(oldDay);
      final newDay = updatedEntry.date;
      if (oldDay.year != newDay.year ||
          oldDay.month != newDay.month ||
          oldDay.day != newDay.day) {
        onEntriesChanged?.call(updatedEntry.date);
      }
    } else {
      debugPrint("[Provider Update] Entry ${updatedEntry.id} not found for update.");
    }
  }

  static String _foodKey(FoodEntry entry) => '${entry.food.fdcId}|${entry.food.name}';

  /// The most recently logged distinct foods, newest first. Each item is the
  /// latest entry for that food, so re-logging repeats its last amount.
  List<FoodEntry> recentFoods({int limit = 10}) {
    // Newest day first; within a day, the later-logged entry first.
    final indexed = [for (var i = 0; i < _entries.length; i++) (i, _entries[i])]
      ..sort((a, b) {
        final byDate = b.$2.date.compareTo(a.$2.date);
        return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
      });
    final seen = <String>{};
    final result = <FoodEntry>[];
    for (final (_, entry) in indexed) {
      if (seen.add(_foodKey(entry))) result.add(entry);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// The foods logged most often (at least twice), most frequent first.
  List<FoodEntry> frequentFoods({int limit = 10}) {
    final counts = <String, int>{};
    final latest = <String, FoodEntry>{};
    for (final entry in _entries) {
      final key = _foodKey(entry);
      counts[key] = (counts[key] ?? 0) + 1;
      final current = latest[key];
      if (current == null || !entry.date.isBefore(current.date)) latest[key] = entry;
    }
    final keys = counts.keys.where((k) => counts[k]! >= 2).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys.take(limit).map((k) => latest[k]!).toList();
  }

  /// How many times a food has been logged, matched by id or name.
  int timesLogged({required String foodId, required String name}) =>
      _entries.where((e) => e.food.fdcId == foodId || e.food.name == name).length;

  /// Re-logs one meal's entries from [from] on [to], with new ids.
  /// Returns the new entries so the caller can offer Undo.
  Future<List<FoodEntry>> copyMeal({
    required DateTime from,
    required DateTime to,
    required String meal,
  }) async {
    final source = getEntriesForMeal(from, meal);
    final day = DateTime(to.year, to.month, to.day);
    final copies = [
      for (final entry in source)
        FoodEntry(
          id: const Uuid().v4(),
          food: entry.food,
          meal: meal,
          quantity: entry.quantity,
          unit: entry.unit,
          date: day,
          servingDescription: entry.servingDescription,
        ),
    ];
    for (final entry in copies) {
      await addEntry(entry);
    }
    return copies;
  }

  List<FoodEntry> getEntriesForMeal(DateTime date, String meal) {
    final entriesForDate = getAllEntriesForDate(date);
    final filteredEntries =
        entriesForDate.where((entry) => entry.meal == meal).toList();
    return filteredEntries;
  }

  // --- Cache Management ---
  Future<void> _clearDateCache() async {
    _dateEntriesCache.clear();
    _dateCacheTimestamp.clear();
    debugPrint("[Provider Cache] Date cache cleared.");
  }

  // --- Widget and Platform Integration ---

  /// The goals shown beside today's totals on the home-screen widget.
  GoalsProvider? _goals;

  /// The targets last sent to the widget, so it refreshes only when they change.
  (double, double, double, double)? _widgetTargets;

  /// Links the user's goals so the home-screen widget can show them.
  void attachGoals(GoalsProvider goals) {
    if (identical(_goals, goals)) return;
    _goals?.removeListener(_onGoalsChanged);
    _goals = goals..addListener(_onGoalsChanged);
    _widgetTargets = _targetsOf(goals);
  }

  static (double, double, double, double) _targetsOf(GoalsProvider goals) =>
      (goals.caloriesGoal, goals.proteinGoal, goals.carbsGoal, goals.fatGoal);

  void _onGoalsChanged() {
    final goals = _goals;
    if (goals != null && _targetsOf(goals) != _widgetTargets) _updateWidgets();
  }

  Future<void> _updateWidgets() async {
    try {
      // Home-screen widget reads today's totals from the shared app group.
      final today = DateTime.now();
      final goals = _goals;
      if (goals != null) {
        final totals = getNutrientTotalsForDate(today);
        _widgetTargets = _targetsOf(goals);
        await WidgetService.updateMacroWidget(
          totals['calories'] ?? 0,
          totals['protein'] ?? 0,
          totals['carbs'] ?? 0,
          totals['fat'] ?? 0,
          goals.caloriesGoal,
          goals.proteinGoal,
          goals.carbsGoal,
          goals.fatGoal,
        );
      }
      await WidgetService.updateRecentMeals(getAllEntriesForDate(today),
          (entry) => calculateNutrientForEntry(entry, 'calories'));
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
    
    await _initializeDailySync();
    _isLoaded = true;
    notifyListeners();
    onEntriesChanged?.call(null);

    // Pull anything logged on other devices (or before a reinstall).
    syncWithCloud().catchError((e) => debugPrint('[Food Sync] $e'));
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



  // --- Cloud sync for food entries ---
  //
  // Every add/update/delete is pushed straight away. A push that fails is kept
  // in a pending set in Hive and retried on the next sync, so offline edits are
  // never lost or overwritten. syncWithCloud() then pulls the user's rows and
  // merges: local entries win while they are pending, remote rows fill in what
  // other devices added, and entries removed elsewhere are dropped.

  static const String _pendingUpsertsKey = 'pending_entry_upserts';
  static const String _pendingDeletesKey = 'pending_entry_deletes';
  static const String _initialUploadKey = 'entry_sync_v2_done';
  static const int _remotePageSize = 1000;
  bool _isSyncing = false;

  Future<void> _initializeDailySync() async {
    final lastSyncString = StorageService().get(_lastSyncKey);
    if (lastSyncString is String) {
      _lastFoodEntrySyncDate = DateTime.tryParse(lastSyncString);
    }
  }

  Set<String> _readIdSet(String key) {
    final raw = StorageService().get(key);
    if (raw is! String || raw.isEmpty) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _writeIdSet(String key, Set<String> ids) async {
    await StorageService().put(key, jsonEncode(ids.toList()));
  }

  Map<String, dynamic> _remoteRow(FoodEntry entry, String userId) => {
        ...entry.toJson(),
        'user_id': userId,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      };

  Future<void> _pushUpsert(FoodEntry entry) async {
    final pending = _readIdSet(_pendingUpsertsKey)..add(entry.id);
    await _writeIdSet(_pendingUpsertsKey, pending);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('food_entries')
          .upsert(_remoteRow(entry, userId))
          .timeout(const Duration(seconds: 15));
      await _writeIdSet(_pendingUpsertsKey, _readIdSet(_pendingUpsertsKey)..remove(entry.id));
    } catch (e) {
      debugPrint('[Food Sync] Upsert of ${entry.id} queued for retry: $e');
    }
  }

  Future<void> _pushDelete(String entryId) async {
    await _writeIdSet(_pendingUpsertsKey, _readIdSet(_pendingUpsertsKey)..remove(entryId));
    await _writeIdSet(_pendingDeletesKey, _readIdSet(_pendingDeletesKey)..add(entryId));
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      await Supabase.instance.client
          .from('food_entries')
          .delete()
          .eq('id', entryId)
          .timeout(const Duration(seconds: 15));
      await _writeIdSet(_pendingDeletesKey, _readIdSet(_pendingDeletesKey)..remove(entryId));
    } catch (e) {
      debugPrint('[Food Sync] Delete of $entryId queued for retry: $e');
    }
  }

  Future<void> _upsertBatch(List<FoodEntry> entries, String userId) async {
    for (int i = 0; i < entries.length; i += 50) {
      final batch = entries
          .sublist(i, min(i + 50, entries.length))
          .map((e) => _remoteRow(e, userId))
          .toList();
      await Supabase.instance.client
          .from('food_entries')
          .upsert(batch)
          .timeout(const Duration(seconds: 30));
    }
  }

  Future<void> _flushPending(String userId) async {
    final pendingUpserts = _readIdSet(_pendingUpsertsKey);
    final toUpsert = _entries.where((e) => pendingUpserts.contains(e.id)).toList();
    if (toUpsert.isNotEmpty) {
      await _upsertBatch(toUpsert, userId);
    }
    await _writeIdSet(_pendingUpsertsKey, <String>{});

    final pendingDeletes = _readIdSet(_pendingDeletesKey);
    if (pendingDeletes.isNotEmpty) {
      await Supabase.instance.client
          .from('food_entries')
          .delete()
          .inFilter('id', pendingDeletes.toList())
          .timeout(const Duration(seconds: 30));
      await _writeIdSet(_pendingDeletesKey, <String>{});
    }
  }

  Future<List<FoodEntry>> _fetchRemoteEntries(String userId) async {
    final List<FoodEntry> remote = [];
    for (int from = 0;; from += _remotePageSize) {
      final rows = await Supabase.instance.client
          .from('food_entries')
          .select()
          .eq('user_id', userId)
          .order('id')
          .range(from, from + _remotePageSize - 1)
          .timeout(const Duration(seconds: 30));
      for (final row in rows) {
        try {
          remote.add(FoodEntry.fromJson(Map<String, dynamic>.from(row)));
        } catch (e) {
          debugPrint('[Food Sync] Skipping unreadable remote row: $e');
        }
      }
      if (rows.length < _remotePageSize) break;
    }
    return remote;
  }

  /// Pushes queued changes, then merges the user's cloud entries into this device.
  Future<void> syncWithCloud() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isSyncing) return;
    _isSyncing = true;
    try {
      // Builds before this one uploaded once a day, so today's entries may be
      // missing remotely. Upload everything once so the merge can trust remote.
      if (StorageService().get(_initialUploadKey) != true) {
        await _upsertBatch(_entries, userId);
        await StorageService().put(_initialUploadKey, true);
      }
      await _flushPending(userId);

      final remote = await _fetchRemoteEntries(userId);
      final remoteById = {for (final e in remote) e.id: e};
      final pendingUpserts = _readIdSet(_pendingUpsertsKey);
      final pendingDeletes = _readIdSet(_pendingDeletesKey);
      final localIds = _entries.map((e) => e.id).toSet();

      final merged = <FoodEntry>[
        // Local entries survive if the cloud has them or they still need pushing.
        ..._entries.where(
            (e) => remoteById.containsKey(e.id) || pendingUpserts.contains(e.id)),
        // Remote entries this device hasn't seen (another device, or a reinstall).
        ...remote.where(
            (e) => !localIds.contains(e.id) && !pendingDeletes.contains(e.id)),
      ];

      _entries = merged;
      await _clearDateCache();
      await saveEntries();
      _lastFoodEntrySyncDate = DateTime.now();
      await StorageService().put(_lastSyncKey, _lastFoodEntrySyncDate!.toIso8601String());
      notifyListeners();
      onEntriesChanged?.call(null);
    } catch (e) {
      debugPrint('[Food Sync] Sync failed, will retry next launch: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // Manual sync from the account screen.
  Future<void> forceFoodEntrySync() async {
    await syncWithCloud();
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
    
    _lastFoodEntrySyncDate = null;
    _isLoaded = false;

    _entries.clear();
    await _clearDateCache();
    
    // Clear local storage
    await StorageService().delete(_storageKey);
    await StorageService().delete(_lastSyncKey);
    await StorageService().delete(_pendingUpsertsKey);
    await StorageService().delete(_pendingDeletesKey);
    await StorageService().delete(_initialUploadKey);
    
    notifyListeners();
    debugPrint("[Provider Clear] All user data cleared.");
  }

  @override
  void dispose() {
    _goals?.removeListener(_onGoalsChanged);
    super.dispose();
  }
}
