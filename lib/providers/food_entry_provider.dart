import 'package:flutter/widgets.dart';
import '../models/foodEntry.dart';
import '../models/nutrition_goals.dart';
import '../repositories/food_entry_repository.dart';
import '../repositories/nutrition_goals_repository.dart';
import '../services/macro_calculator_service.dart';

class FoodEntryProvider with ChangeNotifier {
  final FoodEntryRepository _entryRepository = FoodEntryRepository();
  final NutritionGoalsRepository _goalsRepository = NutritionGoalsRepository();

  List<FoodEntry> _entries = [];
  NutritionGoals _nutritionGoals = NutritionGoals.defaultGoals();
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _disposed = false; // Add disposed flag

  // Enhanced cache with LRU-like behavior
  final Map<String, List<FoodEntry>> _dateEntriesCache = {};
  final Map<String, DateTime> _dateCacheTimestamp = {};
  final Map<String, Map<String, double>> _nutritionTotalsCache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const int _maxCacheSize = 50; // Limit cache size

  // Performance optimization: Batch update flag
  bool _batchUpdateInProgress = false;

  // Getters
  List<FoodEntry> get entries => List.unmodifiable(_entries);
  NutritionGoals get nutritionGoals => _nutritionGoals;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  // Nutrition goal getters for backwards compatibility
  double get caloriesGoal => _nutritionGoals.calories;
  double get proteinGoal => _nutritionGoals.protein;
  double get carbsGoal => _nutritionGoals.carbs;
  double get fatGoal => _nutritionGoals.fat;
  int get stepsGoal => _nutritionGoals.steps;
  double get bmr => _nutritionGoals.bmr;
  double get tdee => _nutritionGoals.tdee;
  double get goalWeightKg => _nutritionGoals.goalWeightKg;
  double get currentWeightKg => _nutritionGoals.currentWeightKg;
  String get goalType => _nutritionGoals.goalType;
  int get deficitSurplus => _nutritionGoals.deficitSurplus;

  // Goal type as int for backwards compatibility
  int get goalTypeAsInt {
    switch (_nutritionGoals.goalType) {
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

  /// Optimized notification method with batching support
  void _safeNotifyListeners() {
    if (_disposed || _batchUpdateInProgress) {
      // Don't notify if disposed or batch update in progress
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_batchUpdateInProgress && !_disposed) {
        notifyListeners();
      }
    });
  }

  /// Start batch update to prevent multiple rebuilds
  void startBatchUpdate() {
    if (_disposed) return; // Early return if disposed
    _batchUpdateInProgress = true;
  }

  /// End batch update and trigger single notification
  void endBatchUpdate() {
    if (_disposed) return; // Early return if disposed
    _batchUpdateInProgress = false;
    _safeNotifyListeners();
  }

  /// Initialize the provider with optimized loading
  Future<void> initialize() async {
    if (_isInitialized || _disposed) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      // Load goals and entries in parallel
      await Future.wait([
        _loadGoals(),
        _loadEntries(),
      ]);

      // Check if disposed after async operations
      if (_disposed) return;

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing FoodEntryProvider: $e');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// Optimized load entries for current user
  Future<void> loadEntriesForCurrentUser() async {
    if (_isLoading || _disposed)
      return; // Prevent concurrent loads and disposed access

    _isLoading = true;
    _safeNotifyListeners();

    try {
      startBatchUpdate();

      _entries.clear();
      _clearAllCaches();

      // Load local entries first (fast, non-blocking)
      await _loadEntries();

      // Check if disposed before background operations
      if (_disposed) return;

      // Load from Supabase in background without blocking UI
      _loadEntriesFromSupabaseInBackground();
    } catch (e) {
      debugPrint('Error loading entries for current user: $e');
      // Ensure we always reset loading state even if local loading fails
    } finally {
      if (!_disposed) {
        _isLoading = false;
        endBatchUpdate();
      }
    }
  }

  Future<void> _loadEntries() async {
    try {
      _entries = await _entryRepository.loadFromLocal();
    } catch (e) {
      debugPrint('Error loading local entries: $e');
      _entries = [];
    }
  }

  Future<void> _loadGoals() async {
    try {
      _nutritionGoals = await _goalsRepository.loadGoals();
    } catch (e) {
      debugPrint('Error loading goals: $e');
      _nutritionGoals = NutritionGoals.defaultGoals();
    }
  }

  /// Background loading from Supabase (non-blocking)
  void _loadEntriesFromSupabaseInBackground() {
    Future.microtask(() async {
      try {
        // Check if disposed before starting operation
        if (_disposed) return;

        // Add timeout to prevent hanging
        final supabaseEntries =
            await _entryRepository.loadFromSupabase().timeout(
          const Duration(seconds: 30), // 30 second timeout
          onTimeout: () {
            debugPrint('Supabase load timeout - using local data');
            return _entries; // Return current local entries on timeout
          },
        );

        // Check if disposed before updating state
        if (_disposed) return;

        // Only update if we got different data
        if (!_areEntriesEqual(_entries, supabaseEntries)) {
          _entries = supabaseEntries;
          _clearAllCaches();
          await _entryRepository.saveToLocal(_entries);
          _safeNotifyListeners();
        }
      } catch (e) {
        debugPrint('Background Supabase load error: $e');
        // Continue with local data - don't fail the app
      }
    });
  }

  /// Check if two entry lists are equal (for optimization)
  bool _areEntriesEqual(List<FoodEntry> list1, List<FoodEntry> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  /// Optimized add entry with batching
  Future<void> addEntry(FoodEntry entry) async {
    if (_disposed) return; // Early return if disposed

    _entries.add(entry);
    _invalidateCacheForDate(entry.date);

    // Save locally immediately
    await _entryRepository.saveToLocal(_entries);
    _safeNotifyListeners();

    // Sync to Supabase in background
    _syncToSupabaseInBackground([entry]);
  }

  /// Optimized remove entry
  Future<void> removeEntry(String entryId) async {
    if (_disposed) return; // Early return if disposed

    final entryIndex = _entries.indexWhere((entry) => entry.id == entryId);
    if (entryIndex == -1) return;

    final removedEntry = _entries.removeAt(entryIndex);
    _invalidateCacheForDate(removedEntry.date);

    await _entryRepository.saveToLocal(_entries);
    _safeNotifyListeners();

    // Sync deletion to Supabase in background
    _entryRepository.deleteFromSupabase(entryId);
  }

  /// Optimized update entry
  Future<void> updateEntry(FoodEntry updatedEntry) async {
    if (_disposed) return; // Early return if disposed

    final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index == -1) return;

    final oldDate = _entries[index].date;
    _entries[index] = updatedEntry;

    // Invalidate cache for both old and new dates if different
    _invalidateCacheForDate(oldDate);
    if (!_isSameDay(oldDate, updatedEntry.date)) {
      _invalidateCacheForDate(updatedEntry.date);
    }

    await _entryRepository.saveToLocal(_entries);
    _safeNotifyListeners();

    // Sync to Supabase in background
    _syncToSupabaseInBackground([updatedEntry]);
  }

  /// Background Supabase sync
  void _syncToSupabaseInBackground(List<FoodEntry> entries) {
    Future.microtask(() async {
      for (final entry in entries) {
        try {
          // Check if disposed before each sync operation
          if (_disposed) return;

          await _entryRepository.syncEntryToSupabase(entry);
        } catch (e) {
          debugPrint('Background sync error for entry ${entry.id}: $e');
        }
      }
    });
  }

  /// Clear all entries with optimization
  Future<void> clearEntries() async {
    if (_disposed) return; // Early return if disposed

    _entries.clear();
    _clearAllCaches();
    await _entryRepository.clearLocal();
    _safeNotifyListeners();
  }

  /// Optimized get entries for date with enhanced caching
  List<FoodEntry> getEntriesForDate(DateTime date) {
    final dateKey = _getDateKey(date);

    // Check cache first
    if (_dateEntriesCache.containsKey(dateKey)) {
      final cacheTimestamp = _dateCacheTimestamp[dateKey];
      if (cacheTimestamp != null &&
          DateTime.now().difference(cacheTimestamp) < _cacheDuration) {
        return List.unmodifiable(_dateEntriesCache[dateKey]!);
      }
    }

    // Calculate and cache result
    final filteredEntries = _filterEntriesByDate(_entries, date);

    _updateCache(dateKey, filteredEntries);
    return List.unmodifiable(filteredEntries);
  }

  /// Optimized filter entries by date
  List<FoodEntry> _filterEntriesByDate(List<FoodEntry> entries, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    return entries.where((entry) {
      final entryDate = entry.date.toLocal();
      return !entryDate.isBefore(startOfDay) && !entryDate.isAfter(endOfDay);
    }).toList();
  }

  /// Get entries for a specific meal with caching
  List<FoodEntry> getEntriesForMeal(DateTime date, String mealType) {
    final allEntries = getEntriesForDate(date);
    return allEntries.where((entry) => entry.meal == mealType).toList();
  }

  /// Get all entries for date (backwards compatibility)
  List<FoodEntry> getAllEntriesForDate(DateTime date) {
    return getEntriesForDate(date);
  }

  /// Optimized nutrition totals calculation with caching
  Map<String, double> getNutritionTotalsForDate(DateTime date) {
    final dateKey = _getDateKey(date);

    // Check nutrition totals cache
    if (_nutritionTotalsCache.containsKey(dateKey)) {
      return Map.from(_nutritionTotalsCache[dateKey]!);
    }

    final entries = getEntriesForDate(date);
    final totals = _calculateNutritionTotals(entries);

    // Cache the result
    _nutritionTotalsCache[dateKey] = totals;

    return Map.from(totals);
  }

  /// Calculate nutrition totals efficiently
  Map<String, double> _calculateNutritionTotals(List<FoodEntry> entries) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final entry in entries) {
      final multiplier = entry.quantity / 100.0;

      totalCalories += (entry.food.calories * multiplier);
      totalProtein += ((entry.food.nutrients['Protein'] ?? 0.0) * multiplier);
      totalCarbs +=
          ((entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0) *
              multiplier);
      totalFat +=
          ((entry.food.nutrients['Total lipid (fat)'] ?? 0.0) * multiplier);
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  /// Update nutrition goals with cache invalidation
  Future<void> updateNutritionGoals(NutritionGoals newGoals) async {
    if (_disposed) return; // Early return if disposed

    _nutritionGoals = newGoals;
    await _goalsRepository.saveGoals(_nutritionGoals);
    _safeNotifyListeners();
  }

  /// Force sync and diagnose (with optimization)
  Future<void> forceSyncAndDiagnose() async {
    if (_disposed) return; // Early return if disposed

    debugPrint('[FoodEntryProvider] Starting force sync and diagnose...');

    try {
      await loadEntriesFromSupabase();
      debugPrint(
          '[FoodEntryProvider] Force sync completed. Total entries: ${_entries.length}');
    } catch (e) {
      debugPrint('[FoodEntryProvider] Force sync failed: $e');
    }
  }

  /// Load entries from Supabase (public method)
  Future<void> loadEntriesFromSupabase() async {
    if (_disposed) return; // Early return if disposed

    try {
      final supabaseEntries = await _entryRepository.loadFromSupabase();

      // Check again after async operation
      if (_disposed) return;

      _entries = supabaseEntries;
      _clearAllCaches();
      await _entryRepository.saveToLocal(_entries);
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error loading entries from Supabase: $e');
    }
  }

  // Cache management methods
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _updateCache(String dateKey, List<FoodEntry> entries) {
    // Implement LRU-like behavior
    if (_dateEntriesCache.length >= _maxCacheSize) {
      _evictOldestCacheEntry();
    }

    _dateEntriesCache[dateKey] = entries;
    _dateCacheTimestamp[dateKey] = DateTime.now();
  }

  void _evictOldestCacheEntry() {
    if (_dateCacheTimestamp.isEmpty) return;

    String oldestKey = _dateCacheTimestamp.keys.first;
    DateTime oldestTime = _dateCacheTimestamp[oldestKey]!;

    for (final entry in _dateCacheTimestamp.entries) {
      if (entry.value.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value;
      }
    }

    _dateEntriesCache.remove(oldestKey);
    _dateCacheTimestamp.remove(oldestKey);
    _nutritionTotalsCache.remove(oldestKey);
  }

  void _invalidateCacheForDate(DateTime date) {
    final dateKey = _getDateKey(date);
    _dateEntriesCache.remove(dateKey);
    _dateCacheTimestamp.remove(dateKey);
    _nutritionTotalsCache.remove(dateKey);
  }

  void _clearAllCaches() {
    _dateEntriesCache.clear();
    _dateCacheTimestamp.clear();
    _nutritionTotalsCache.clear();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  void dispose() {
    _disposed = true;

    // Clear all caches to free memory
    _clearAllCaches();

    // Clear entries list
    _entries.clear();

    // Reset flags
    _batchUpdateInProgress = false;
    _isInitialized = false;
    _isLoading = false;

    super.dispose();
  }
}
