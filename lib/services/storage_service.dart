import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Needed for migration
import '../models/user_preferences.dart'; // Import UserPreferences model
import 'dart:async';

class StorageService {
  static const String _preferencesBoxName = 'user_preferences';
  static const String _migrationFlagKey = 'prefs_migrated_to_hive_v1';

  late Box _preferencesBox;

  // Performance optimizations
  static const int _maxCacheSize = 100;
  final Map<String, dynamic> _memoryCache = <String, dynamic>{};
  final Map<String, Timer> _writeTimers = <String, Timer>{};
  final Map<String, dynamic> _pendingWrites = <String, dynamic>{};
  static const Duration _writeDelay = Duration(milliseconds: 500);

  // Private constructor for Singleton pattern
  StorageService._privateConstructor();

  // Static instance
  static final StorageService _instance = StorageService._privateConstructor();

  // Factory constructor to return the static instance
  factory StorageService() {
    return _instance;
  }

  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Initialize with performance optimizations
  Future<void> initialize() async {
    if (_isInitialized) {
      return _initCompleter.future;
    }

    try {
      _preferencesBox = await Hive.openBox<dynamic>(_preferencesBoxName);
      debugPrint('Hive box "$_preferencesBoxName" opened successfully.');

      // Preload frequently used data into memory cache
      await _preloadCache();

      // Migration in background to avoid blocking startup
      _migrateFromSharedPreferencesInBackground();

      _isInitialized = true;
      _initCompleter.complete();
    } catch (e) {
      debugPrint('Error initializing StorageService: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
  }

  /// Preload frequently accessed data
  Future<void> _preloadCache() async {
    try {
      // Preload common preferences
      final commonKeys = [
        'theme_mode',
        'units_metric',
        'notifications_enabled',
        'daily_calorie_goal',
        'daily_protein_goal',
        'daily_carbs_goal',
        'daily_fat_goal',
      ];

      for (final key in commonKeys) {
        if (_preferencesBox.containsKey(key)) {
          _memoryCache[key] = _preferencesBox.get(key);
        }
      }

      debugPrint('Preloaded ${_memoryCache.length} preferences into cache');
    } catch (e) {
      debugPrint('Error preloading cache: $e');
    }
  }

  /// Background migration to avoid blocking initialization
  void _migrateFromSharedPreferencesInBackground() {
    Future.microtask(() async {
      try {
        await _migrateFromSharedPreferencesIfNeeded();
      } catch (e) {
        debugPrint('Background migration error: $e');
      }
    });
  }

  Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    try {
      final bool migrationDone =
          _preferencesBox.get(_migrationFlagKey, defaultValue: false);

      if (!migrationDone) {
        debugPrint('Starting SharedPreferences migration...');
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys();

        int migratedCount = 0;
        final batch = <String, dynamic>{};

        for (String key in allKeys) {
          if (key == _migrationFlagKey) continue;

          final value = prefs.get(key);
          if (value != null) {
            batch[key] = value;
            migratedCount++;
          }
        }

        // Batch write for better performance
        if (batch.isNotEmpty) {
          await _preferencesBox.putAll(batch);

          // Update memory cache with migrated data
          _memoryCache.addAll(batch);
        }

        await _preferencesBox.put(_migrationFlagKey, true);
        debugPrint('Migration completed. Migrated $migratedCount keys.');
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

  /// Optimized get with memory cache
  dynamic get(String key, {dynamic defaultValue}) {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        return _memoryCache[key];
      }

      // Fallback to Hive
      final value = _preferencesBox.get(key, defaultValue: defaultValue);

      // Cache in memory for faster access
      if (value != defaultValue && _memoryCache.length < _maxCacheSize) {
        _memoryCache[key] = value;
      }

      return value;
    } catch (e) {
      debugPrint('Error getting key "$key": $e');
      return defaultValue;
    }
  }

  /// Optimized put with write-behind caching
  Future<void> put(String key, dynamic value) async {
    try {
      // Update memory cache immediately for fast reads
      _memoryCache[key] = value;

      // Cancel any existing write timer for this key
      _writeTimers[key]?.cancel();

      // Store pending write
      _pendingWrites[key] = value;

      // Set up delayed write to reduce disk I/O
      _writeTimers[key] = Timer(_writeDelay, () async {
        await _flushPendingWrite(key);
      });

      debugPrint('Scheduled write for key "$key"');
    } catch (e) {
      debugPrint('Error scheduling write for key "$key": $e');
    }
  }

  /// Flush a specific pending write
  Future<void> _flushPendingWrite(String key) async {
    if (!_pendingWrites.containsKey(key)) return;

    try {
      final value = _pendingWrites.remove(key);
      _writeTimers.remove(key);

      await _preferencesBox.put(key, value);
      debugPrint('Flushed write for key "$key"');

      // Sync to Supabase in background (if needed)
      // _syncToSupabaseInBackground(key, value);
    } catch (e) {
      debugPrint('Error flushing write for key "$key": $e');
    }
  }

  /// Force flush all pending writes
  Future<void> flushAllPendingWrites() async {
    if (_pendingWrites.isEmpty) return;

    try {
      // Cancel all timers
      for (final timer in _writeTimers.values) {
        timer.cancel();
      }
      _writeTimers.clear();

      // Batch write all pending changes
      await _preferencesBox.putAll(Map.from(_pendingWrites));
      debugPrint('Flushed ${_pendingWrites.length} pending writes');

      _pendingWrites.clear();
    } catch (e) {
      debugPrint('Error flushing all pending writes: $e');
    }
  }

  /// Optimized delete with cache invalidation
  Future<void> delete(String key) async {
    try {
      // Remove from memory cache
      _memoryCache.remove(key);

      // Cancel any pending write
      _writeTimers[key]?.cancel();
      _writeTimers.remove(key);
      _pendingWrites.remove(key);

      // Delete from Hive
      await _preferencesBox.delete(key);
      debugPrint('Deleted key "$key"');
    } catch (e) {
      debugPrint('Error deleting key "$key": $e');
    }
  }

  /// Check if key exists (fast memory + Hive check)
  bool containsKey(String key) {
    return _memoryCache.containsKey(key) || _preferencesBox.containsKey(key);
  }

  /// Get all keys (for debugging)
  Iterable<String> getAllKeys() {
    final Set<String> allKeys = <String>{};
    allKeys.addAll(_memoryCache.keys);
    allKeys.addAll(_preferencesBox.keys.cast<String>());
    return allKeys;
  }

  /// Clear all data (with confirmation)
  Future<void> clearAll() async {
    try {
      // Cancel all pending writes
      for (final timer in _writeTimers.values) {
        timer.cancel();
      }
      _writeTimers.clear();
      _pendingWrites.clear();

      // Clear memory cache
      _memoryCache.clear();

      // Clear Hive box
      await _preferencesBox.clear();
      debugPrint('Cleared all storage data');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  /// Get storage statistics (for debugging)
  Map<String, dynamic> getStorageStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'pending_writes': _pendingWrites.length,
      'active_timers': _writeTimers.length,
      'hive_box_size': _preferencesBox.length,
      'is_initialized': _isInitialized,
    };
  }

  /// Compact and optimize storage
  Future<void> compact() async {
    try {
      // Flush pending writes first
      await flushAllPendingWrites();

      // Compact Hive box
      await _preferencesBox.compact();

      // Clear old memory cache entries if too large
      if (_memoryCache.length > _maxCacheSize) {
        final keysToRemove =
            _memoryCache.keys.take(_memoryCache.length - _maxCacheSize);
        for (final key in keysToRemove) {
          _memoryCache.remove(key);
        }
      }

      debugPrint('Storage compaction completed');
    } catch (e) {
      debugPrint('Error during storage compaction: $e');
    }
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    try {
      // Flush all pending writes before disposal
      await flushAllPendingWrites();

      // Cancel all timers
      for (final timer in _writeTimers.values) {
        timer.cancel();
      }
      _writeTimers.clear();

      // Clear memory cache
      _memoryCache.clear();

      debugPrint('StorageService disposed successfully');
    } catch (e) {
      debugPrint('Error disposing StorageService: $e');
    }
  }

  // Background Supabase sync (commented out for now due to table schema issues)
  /*
  void _syncToSupabaseInBackground(String key, dynamic value) {
    Future.microtask(() async {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || key == _migrationFlagKey) return;

      try {
        await Supabase.instance.client
            .from('user_preferences')
            .upsert({
          'user_id': userId,
          'key': key,
          'value': value.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Background Supabase sync error for key "$key": $e');
    }
    });
  }
  */

  // --- UserPreferences-specific methods ---

  // Key for storing UserPreferences object
  static const String _userPreferencesKey = 'user_preferences_object';

  // Save UserPreferences to Hive
  Future<void> saveUserPreferences(UserPreferences userPreferences) async {
    try {
      final json = userPreferences.toJson();
      await put(_userPreferencesKey, json);
      debugPrint('UserPreferences saved to Hive successfully.');
    } catch (e) {
      debugPrint('Error saving UserPreferences to Hive: $e');
    }
  }

  // Get UserPreferences from Hive
  UserPreferences? getUserPreferences() {
    try {
      final json = get(_userPreferencesKey);
      if (json != null && json is Map<String, dynamic>) {
        return UserPreferences.fromJson(json);
      }
      debugPrint('No UserPreferences found in Hive.');
      return null;
    } catch (e) {
      debugPrint('Error getting UserPreferences from Hive: $e');
      return null;
    }
  }

  // Get UserPreferences with default values if none exist
  UserPreferences getUserPreferencesWithDefaults({String userId = 'default'}) {
    final existingPrefs = getUserPreferences();
    if (existingPrefs != null) {
      return existingPrefs;
    }

    // Return default UserPreferences if none exist
    debugPrint('No UserPreferences found, returning defaults.');
    return UserPreferences(
      userId: userId,
      targetCalories: 2000,
      targetProtein: 150,
      targetCarbohydrates: 200,
      targetFat: 65,
      dietaryPreferences: DietaryPreferences(
        preferences: [],
        allergies: [],
        dislikedFoods: [],
        mealsPerDay: 3,
      ),
      fitnessGoals: FitnessGoals(
        primary: 'general_fitness',
        secondary: [],
        workoutsPerWeek: 3,
      ),
      equipment: EquipmentAvailability(),
    );
  }

  // Update specific nutritional targets
  Future<void> updateNutritionalTargets({
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
  }) async {
    try {
      final currentPrefs = getUserPreferencesWithDefaults();
      final updatedPrefs = currentPrefs.copyWith(
        targetCalories: calories ?? currentPrefs.targetCalories,
        targetProtein: protein ?? currentPrefs.targetProtein,
        targetCarbohydrates: carbohydrates ?? currentPrefs.targetCarbohydrates,
        targetFat: fat ?? currentPrefs.targetFat,
        updatedAt: DateTime.now(),
      );
      await saveUserPreferences(updatedPrefs);
      debugPrint('Nutritional targets updated successfully.');
    } catch (e) {
      debugPrint('Error updating nutritional targets: $e');
    }
  }

  // Delete UserPreferences
  Future<void> deleteUserPreferences() async {
    try {
      await delete(_userPreferencesKey);
      debugPrint('UserPreferences deleted from Hive.');
    } catch (e) {
      debugPrint('Error deleting UserPreferences from Hive: $e');
    }
  }
}
