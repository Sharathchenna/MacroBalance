import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Needed for migration
import '../models/user_preferences.dart'; // Import UserPreferences model

class StorageService {
  static const String _preferencesBoxName = 'user_preferences';
  static const String _migrationFlagKey = 'prefs_migrated_to_hive_v1';

  late Box _preferencesBox;

  // Private constructor for Singleton pattern
  StorageService._privateConstructor();

  // Static instance
  static final StorageService _instance = StorageService._privateConstructor();

  // Factory constructor to return the static instance
  factory StorageService() {
    return _instance;
  }

  // Initialize the service: open the Hive box and perform migration if needed
  Future<void> initialize() async {
    try {
      _preferencesBox = await Hive.openBox<dynamic>(_preferencesBoxName);
      debugPrint('Hive box "$_preferencesBoxName" opened successfully.');

      // Check if migration from SharedPreferences is needed
      await _migrateFromSharedPreferencesIfNeeded();
    } catch (e) {
      debugPrint('Error initializing StorageService or opening Hive box: $e');
      // Consider how to handle initialization errors (e.g., retry, fallback)
    }
  }

  // --- Migration Logic ---

  Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    try {
      final bool migrationDone = get(_migrationFlagKey, defaultValue: false);

      if (!migrationDone) {
        debugPrint('Starting migration from SharedPreferences to Hive...');
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys();

        int migratedCount = 0;
        for (String key in allKeys) {
          // Avoid migrating the migration flag itself if it somehow exists
          if (key == _migrationFlagKey) continue;

          final value = prefs.get(key);
          if (value != null) {
            await _preferencesBox.put(key, value);
            migratedCount++;
            // Optional: Remove the key from SharedPreferences after migration
            // await prefs.remove(key);
          }
        }

        // Mark migration as complete in Hive
        await _preferencesBox.put(_migrationFlagKey, true);
        debugPrint('Migration complete. Migrated $migratedCount keys.');

        // Optional: Clear all SharedPreferences after successful migration
        // await prefs.clear();
        // debugPrint('SharedPreferences cleared after migration.');
      } else {
        debugPrint('SharedPreferences migration already completed.');
      }
    } catch (e) {
      debugPrint('Error during SharedPreferences migration: $e');
      // Decide how to handle migration errors. Maybe retry later?
    }
  }

  // --- Core Get/Put Methods ---

  // Get a value from the Hive box
  dynamic get(String key, {dynamic defaultValue}) {
    try {
      return _preferencesBox.get(key, defaultValue: defaultValue);
    } catch (e) {
      debugPrint('Error getting key "$key" from Hive: $e');
      return defaultValue;
    }
  }

  // Put a value into the Hive box and sync to Supabase
  Future<void> put(String key, dynamic value) async {
    try {
      // Write locally immediately
      await _preferencesBox.put(key, value);
      debugPrint('Put key "$key" with value "$value" into Hive.');

      // Asynchronously sync to Supabase (don't wait for it)
      // _syncToSupabase(key, value); // Commented out - causing errors due to table schema mismatch
    } catch (e) {
      debugPrint('Error putting key "$key" into Hive: $e');
    }
  }

  // Delete a value from the Hive box and sync deletion to Supabase
  Future<void> delete(String key) async {
    try {
      // Delete locally immediately
      await _preferencesBox.delete(key);
      debugPrint('Deleted key "$key" from Hive.');

      // Asynchronously sync deletion to Supabase
      // _deleteFromSupabase(key); // Commented out - causing errors due to table schema mismatch
    } catch (e) {
      debugPrint('Error deleting key "$key" from Hive: $e');
    }
  }

  // --- Supabase Syncing ---

  // Sync a single key-value pair up to Supabase
  Future<void> _syncToSupabase(String key, dynamic value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Cannot sync key "$key" to Supabase: User not logged in.');
      return;
    }

    // Do not sync the migration flag
    if (key == _migrationFlagKey) {
      return;
    }

    try {
      // Use toString() for simplicity, assuming TEXT column in Supabase.
      // If using JSONB, you'd need JSON encoding/decoding.
      final String valueString = value.toString();

      await Supabase.instance.client
          .from('user_preferences') // Ensure this table exists in Supabase
          .upsert({
        'user_id': userId,
        'key': key,
        'value': valueString, // Store as text
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Successfully synced key "$key" to Supabase.');
    } catch (e) {
      debugPrint('Error syncing key "$key" to Supabase: $e');
      // Implement retry logic or error queuing if needed for offline support
    }
  }

  // Sync deletion up to Supabase
  Future<void> _deleteFromSupabase(String key) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Cannot delete key "$key" from Supabase: User not logged in.');
      return;
    }

    // Do not try to delete the migration flag from Supabase
    if (key == _migrationFlagKey) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('user_preferences')
          .delete()
          .match({'user_id': userId, 'key': key});
      debugPrint('Successfully synced deletion of key "$key" to Supabase.');
    } catch (e) {
      debugPrint('Error syncing deletion of key "$key" to Supabase: $e');
      // Implement retry logic or error queuing if needed
    }
  }

  // Fetch all preferences from Supabase and update the local Hive box
  /* // Commented out - This service should only handle local storage now.
  Future<void> syncFromServer() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Cannot sync from Supabase: User not logged in.');
      return;
    }

    debugPrint('Starting sync from Supabase...');
    try {
      final response = await Supabase.instance.client
          .from('user_preferences')
          .select('key, value') // Select only key and value
          .eq('user_id', userId);

      // Assuming response is List<Map<String, dynamic>>
       if (response is List) {
         int updatedCount = 0;
         for (final record in response) {
           if (record is Map<String, dynamic>) {
             final key = record['key'] as String?;
             final value = record['value']; // This will likely be String

             if (key != null && key != _migrationFlagKey && value != null) {
               // TODO: Attempt to parse value back to original type if needed
               // For now, storing as String as fetched.
               // If you stored bools/ints/doubles, you might try parsing here.
               // Example:
               // dynamic parsedValue = value;
               // if (value is String) {
               //   if (value.toLowerCase() == 'true') parsedValue = true;
               //   else if (value.toLowerCase() == 'false') parsedValue = false;
               //   else if (int.tryParse(value) != null) parsedValue = int.parse(value);
               //   else if (double.tryParse(value) != null) parsedValue = double.parse(value);
               // }
               await _preferencesBox.put(key, value); // Store the raw value (likely string)
               updatedCount++;
             }
           }
         }
         debugPrint('Sync from Supabase complete. Updated $updatedCount local keys.');
       } else {
          debugPrint('Sync from Supabase failed: Unexpected response format.');
       }

    } catch (e) {
      debugPrint('Error syncing from Supabase: $e');
    }
  }
  */

  // Clear all preferences from the Hive box, except the migration flag
  Future<void> clearAllPreferences() async {
    try {
      // Get all keys
      final keys = _preferencesBox.keys.toList();
      int deleteCount = 0;
      for (var key in keys) {
        // Don't delete the migration flag
        if (key != _migrationFlagKey) {
          await _preferencesBox.delete(key);
          deleteCount++;
        }
      }
      debugPrint(
          'Cleared $deleteCount preferences from Hive box "$_preferencesBoxName".');
      // Note: This does NOT clear data from Supabase.
    } catch (e) {
      debugPrint(
          'Error clearing preferences from Hive box "$_preferencesBoxName": $e');
    }
  }

  // Optional: Method to listen for changes in the Hive box
  void listenForChanges(VoidCallback listener) {
    _preferencesBox.listenable().addListener(listener);
  }

  // Optional: Method to close the box when done (e.g., on app dispose)
  Future<void> dispose() async {
    try {
      await _preferencesBox.close();
      debugPrint('Hive box "$_preferencesBoxName" closed.');
    } catch (e) {
      debugPrint('Error closing Hive box "$_preferencesBoxName": $e');
    }
  }

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
