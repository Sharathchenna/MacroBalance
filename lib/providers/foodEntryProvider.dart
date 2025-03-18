// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math'; // Added for min function
import '../services/widget_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodEntryProvider with ChangeNotifier {
  List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';

  // Daily nutrition goals
  double _caloriesGoal = 2000.0;
  double _proteinGoal = 150.0;
  double _carbsGoal = 225.0;
  double _fatGoal = 65.0;

  FoodEntryProvider() {
    _loadEntries();
    _loadNutritionGoals();
  }

  List<FoodEntry> get entries => _entries;

  double get caloriesGoal => _caloriesGoal;
  double get proteinGoal => _proteinGoal;
  double get carbsGoal => _carbsGoal;
  double get fatGoal => _fatGoal;

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

  Future<void> _loadEntries() async {
    try {
      // First try to load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? entriesJson = prefs.getString(_storageKey);

      // Check if user is authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        // User is authenticated, try to sync from Supabase first
        try {
          final response = await Supabase.instance.client
              .from('user_food_entries')
              .select('entries_json')
              .eq('user_id', currentUser.id)
              .order('updated_at', ascending: false) // Get the most recent
              .limit(1) // Limit to one row
              .maybeSingle();

          if (response != null && response['entries_json'] != null) {
            // Use Supabase data if it exists
            final dynamic supabaseEntriesJson = response['entries_json'];
            String processedJson;

            if (supabaseEntriesJson is String) {
              processedJson = supabaseEntriesJson;
            } else if (supabaseEntriesJson is Map ||
                supabaseEntriesJson is List) {
              // If it's already a parsed object, encode it back to string
              processedJson = jsonEncode(supabaseEntriesJson);
            } else {
              throw FormatException('Unexpected format for entries_json');
            }

            // If the local data is different from Supabase, use the more recent one
            if (entriesJson != null && entriesJson != processedJson) {
              // For now, just use Supabase data
              _loadEntriesFromJson(processedJson);

              // Save the Supabase data locally
              await prefs.setString(_storageKey, processedJson);
            } else if (processedJson.isNotEmpty) {
              _loadEntriesFromJson(processedJson);
            }
          } else if (entriesJson != null) {
            // No Supabase data but we have local data, sync it up
            _loadEntriesFromJson(entriesJson);
            _syncEntriesToSupabase(entriesJson);
          }
        } catch (e) {
          debugPrint('Error syncing entries from Supabase: $e');
          // Fallback to local data
          if (entriesJson != null) {
            _loadEntriesFromJson(entriesJson);
          }
        }

        // Also try to load nutrition goals from Supabase
        await _syncNutritionGoalsFromSupabase();
      } else if (entriesJson != null) {
        // User not authenticated, just use local data
        _loadEntriesFromJson(entriesJson);
      }
    } catch (e) {
      debugPrint('Error loading food entries: $e');
    }
  }

  void _loadEntriesFromJson(String entriesJson) {
    try {
      final List<dynamic> decodedEntries = jsonDecode(entriesJson);
      _entries.clear();
      _entries.addAll(
        decodedEntries.map((entry) => FoodEntry.fromJson(entry)).toList(),
      );
      notifyListeners();
      _updateWidgets();
    } catch (e) {
      debugPrint('Error parsing entries JSON: $e');
      // If there's a parsing error, try to recover
      try {
        // Try to clean up the JSON string
        String cleanJson = entriesJson
            .replaceAll("'", '"') // Replace single quotes with double quotes
            .replaceAll(RegExp(r'([{,]\s*)(\w+)(\s*:)'),
                r'$1"$2"$3'); // Add quotes to keys

        final List<dynamic> decodedEntries = jsonDecode(cleanJson);
        _entries.clear();
        _entries.addAll(
          decodedEntries.map((entry) => FoodEntry.fromJson(entry)).toList(),
        );
        notifyListeners();
        _updateWidgets();
      } catch (recoveryError) {
        debugPrint('Failed to recover from JSON parsing error: $recoveryError');
      }
    }
  }

  Future<void> _loadNutritionGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _caloriesGoal = prefs.getDouble('calories_goal') ?? 2000.0;
      _proteinGoal = prefs.getDouble('protein_goal') ?? 150.0;
      _carbsGoal = prefs.getDouble('carbs_goal') ?? 225.0;
      _fatGoal = prefs.getDouble('fat_goal') ?? 65.0;
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  Future<void> _syncNutritionGoalsFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final response = await Supabase.instance.client
          .from('user_macros')
          .select('calories_goal, protein_goal, carbs_goal, fat_goal')
          .eq('id', currentUser.id)
          .order('updated_at', ascending: false) // Get the most recent entry
          .limit(1) // Limit to one row
          .maybeSingle();

      if (response != null) {
        // Use Supabase data if it exists
        _caloriesGoal = response['calories_goal'] ?? _caloriesGoal;
        _proteinGoal = response['protein_goal'] ?? _proteinGoal;
        _carbsGoal = response['carbs_goal'] ?? _carbsGoal;
        _fatGoal = response['fat_goal'] ?? _fatGoal;

        // Save to local storage
        _saveNutritionGoals();
        notifyListeners();
        _updateWidgets();
      } else {
        // No data in Supabase, sync local data up
        await _syncNutritionGoalsToSupabase();
      }
    } catch (e) {
      debugPrint('Error syncing nutrition goals from Supabase: $e');
    }
  }

  Future<void> _saveNutritionGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('calories_goal', _caloriesGoal);
      await prefs.setDouble('protein_goal', _proteinGoal);
      await prefs.setDouble('carbs_goal', _carbsGoal);
      await prefs.setDouble('fat_goal', _fatGoal);
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
    }
  }

  Future<void> _saveEntries() async {
    try {
      final entriesJson = jsonEncode(
        _entries.map((entry) => entry.toJson()).toList(),
      );

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, entriesJson);

      // Sync to Supabase if user is authenticated
      await _syncEntriesToSupabase(entriesJson);

      // Update widgets
      _updateWidgets();
    } catch (e) {
      debugPrint('Error saving food entries: $e');
    }
  }

  Future<void> _syncEntriesToSupabase(String entriesJson) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('No user logged in, skipping sync to Supabase');
        return;
      }

      debugPrint('Starting sync to Supabase...');

      // Validate that entriesJson is proper JSON
      try {
        // First check if entriesJson is empty or null
        if (entriesJson.isEmpty) {
          debugPrint('Entries JSON is empty, nothing to sync');
          return;
        }

        // Print the first 100 characters of the JSON for debugging
        debugPrint(
            'Raw JSON (truncated): ${entriesJson.length > 100 ? entriesJson.substring(0, 100) + '...' : entriesJson}');

        // Verify that it's valid JSON by parsing and re-encoding it
        List<dynamic> decodedJson;
        try {
          decodedJson = jsonDecode(entriesJson) as List<dynamic>;
        } catch (e) {
          // If decode fails, try to clean the JSON string
          String cleanJson = entriesJson
              .replaceAll("'", '"') // Replace single quotes with double quotes
              .replaceAll(RegExp(r'([{,]\s*)(\w+)(\s*:)'),
                  r'$1"$2"$3'); // Add quotes to keys

          decodedJson = jsonDecode(cleanJson) as List<dynamic>;
          debugPrint('Cleaned JSON format before syncing');
        }

        // Re-encode to ensure proper JSON format
        final validatedJson = jsonEncode(decodedJson);

        // Check if entry exists
        debugPrint('Checking if user has existing entries in Supabase');
        final existingEntry = await Supabase.instance.client
            .from('user_food_entries')
            .select('user_id')
            .eq('user_id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (existingEntry != null) {
          // Update existing entry
          debugPrint('Found existing entries, updating...');
          await Supabase.instance.client.from('user_food_entries').update({
            'entries_json': validatedJson,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', currentUser.id);
          debugPrint('Successfully updated food entries in Supabase');
        } else {
          // Insert new entry
          debugPrint('No existing entries, creating new record...');
          await Supabase.instance.client.from('user_food_entries').insert({
            'user_id': currentUser.id,
            'entries_json': validatedJson,
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Successfully created food entries in Supabase');
        }

        debugPrint(
            'Food entries synced to Supabase (${decodedJson.length} entries)');
      } catch (jsonError) {
        debugPrint('Error with JSON format during sync: $jsonError');
        // Instead of rethrowing, handle it more gracefully
        debugPrint('Attempted to sync with invalid JSON format');
      }
    } catch (e) {
      debugPrint('Error syncing entries to Supabase: $e');
    }
  }

  Future<void> _syncNutritionGoalsToSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await Supabase.instance.client.from('user_macros').upsert({
        'id': currentUser.id,
        'calories_goal': _caloriesGoal,
        'protein_goal': _proteinGoal,
        'carbs_goal': _carbsGoal,
        'fat_goal': _fatGoal,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Nutrition goals synced to Supabase');
    } catch (e) {
      debugPrint('Error syncing nutrition goals to Supabase: $e');
    }
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    return _entries
        .where((entry) =>
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  List<FoodEntry> getEntriesForMeal(String meal, DateTime date) {
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
    notifyListeners();
    await _saveEntries();
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    await _saveEntries();
  }

  Future<void> clearEntries() async {
    _entries.clear();
    notifyListeners();

    // Only clear from local storage, not from Supabase
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    // Remove the code that deletes from Supabase
    debugPrint('Entries cleared from local storage only');
  }

  double getTotalCaloriesForDate(DateTime date) {
    final entriesForDate = getEntriesForDate(date);
    return entriesForDate.fold(0, (sum, entry) {
      double multiplier = entry.quantity;
      // Convert to grams if needed
      switch (entry.unit) {
        case "oz":
          multiplier *= 28.35;
          break;
        case "kg":
          multiplier *= 1000;
          break;
        case "lbs":
          multiplier *= 453.59;
          break;
      }
      multiplier /= 100; // Since calories are per 100g
      return sum + (entry.food.calories * multiplier);
    });
  }

  List<FoodEntry> getAllEntriesForDate(DateTime date) {
    return _entries
        .where((entry) =>
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  /// Update iOS homescreen widgets with latest data
  Future<void> _updateWidgets() async {
    try {
      // Get today's entries
      final today = DateTime.now();
      final todayEntries = getEntriesForDate(today);

      if (todayEntries.isEmpty) return;

      // Calculate total macros for today
      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var entry in todayEntries) {
        // Convert from per 100g to actual amount based on quantity
        totalCalories += entry.food.calories * entry.quantity / 100;
        totalProtein +=
            (entry.food.nutrients['Protein'] ?? 0.0) * entry.quantity / 100;
        totalCarbs +=
            (entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0) *
                entry.quantity /
                100;
        totalFat += (entry.food.nutrients['Total lipid (fat)'] ?? 0.0) *
            entry.quantity /
            100;
      }

      // Update macro widget with current progress
      await WidgetService.updateMacroWidget(
        totalCalories,
        totalProtein,
        totalCarbs,
        totalFat,
        _caloriesGoal,
        _proteinGoal,
        _carbsGoal,
        _fatGoal,
      );

      // Update recent meals widget
      await WidgetService.updateRecentMeals(todayEntries);
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }

  // Force sync all data with Supabase
  Future<void> syncAllDataWithSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot sync - no user is logged in');
        return;
      }

      debugPrint('Starting full data sync with Supabase...');
      debugPrint('User ID: ${currentUser.id}');
      debugPrint('Total entries count: ${_entries.length}');

      // First sync nutrition goals
      debugPrint('Syncing nutrition goals...');
      await _syncNutritionGoalsToSupabase();

      // Then sync food entries
      debugPrint('Preparing food entries JSON...');
      if (_entries.isEmpty) {
        debugPrint('No food entries to sync');
      } else {
        final List<Map<String, dynamic>> jsonList =
            _entries.map((entry) => entry.toJson()).toList();

        // For debugging, print a sample of the first entry (if available)
        if (jsonList.isNotEmpty) {
          debugPrint(
              'Sample entry structure: ${jsonEncode(jsonList[0]).substring(0, min(100, jsonEncode(jsonList[0]).length))}...');
        }

        final entriesJson = jsonEncode(jsonList);
        debugPrint('Syncing ${jsonList.length} food entries to Supabase...');

        await _syncEntriesToSupabase(entriesJson);
      }

      // Verify data after sync
      try {
        debugPrint('Verifying sync by checking Supabase data...');
        final response = await Supabase.instance.client
            .from('user_food_entries')
            .select('entries_json')
            .eq('user_id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (response != null && response['entries_json'] != null) {
          final dynamic supabaseData = response['entries_json'];
          if (supabaseData is String) {
            final decodedData = jsonDecode(supabaseData);
            if (decodedData is List) {
              debugPrint(
                  'Verification successful: ${decodedData.length} entries found in Supabase');
            } else {
              debugPrint(
                  'Warning: Supabase data is not in expected list format');
            }
          } else {
            debugPrint('Warning: Supabase data is not in string format');
          }
        } else {
          debugPrint('Warning: No data found in Supabase after sync');
        }
      } catch (verifyError) {
        debugPrint('Error verifying sync: $verifyError');
      }

      debugPrint('All data sync process completed');
    } catch (e) {
      debugPrint('Error during full data sync with Supabase: $e');
      if (e is PostgrestException) {
        debugPrint('Supabase error code: ${e.code}');
        debugPrint('Supabase error message: ${e.message}');
      }
    }
  }

  /// Check if the connection to Supabase is working and food entries table is accessible
  Future<Map<String, dynamic>> checkSupabaseConnection() async {
    try {
      final result = <String, dynamic>{
        'connected': false,
        'userAuthenticated': false,
        'foodEntriesTableExists': false,
        'entriesCount': 0,
        'userHasEntries': false,
        'errorMessage': null,
      };

      // Check if Supabase client is initialized
      final client = Supabase.instance.client;

      // Check if user is authenticated
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        result['errorMessage'] = 'No user is authenticated';
        return result;
      }

      result['connected'] = true;
      result['userAuthenticated'] = true;
      result['userId'] = currentUser.id;

      // Check if user_food_entries table exists and is accessible
      try {
        // Count total entries in the table
        final response =
            await client.from('user_food_entries').select('id').count();

        // Get the count from the response
        if (response.count != null) {
          result['foodEntriesTableExists'] = true;
          result['entriesCount'] = response.count;
        }

        // Check if this specific user has entries
        final userEntries = await client
            .from('user_food_entries')
            .select('entries_json')
            .eq('user_id', currentUser.id)
            .maybeSingle();

        if (userEntries != null) {
          result['userHasEntries'] = true;

          // Try to parse the entries for validation
          if (userEntries['entries_json'] != null) {
            try {
              final dynamic entriesJson = userEntries['entries_json'];
              if (entriesJson is String) {
                final decoded = jsonDecode(entriesJson);
                result['entriesInDatabase'] =
                    decoded is List ? decoded.length : 0;
              } else if (entriesJson is List) {
                result['entriesInDatabase'] = entriesJson.length;
              }
            } catch (e) {
              result['entriesParseError'] = e.toString();
            }
          }
        }
      } catch (e) {
        result['foodEntriesTableExists'] = false;
        result['errorMessage'] =
            'Error accessing user_food_entries table: ${e.toString()}';
      }

      return result;
    } catch (e) {
      return {
        'connected': false,
        'errorMessage': 'Connection error: ${e.toString()}'
      };
    }
  }

  /// Public method to force sync and return diagnostic information
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
      // First check Supabase connection
      final connectionStatus = await checkSupabaseConnection();
      diagnosticInfo['connectionStatus'] = connectionStatus;

      if (connectionStatus['connected'] != true ||
          connectionStatus['userAuthenticated'] != true) {
        diagnosticInfo['errors'].add('Supabase connection check failed');
        return diagnosticInfo;
      }

      // Try to sync
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        diagnosticInfo['errors'].add('No authenticated user found for sync');
        return diagnosticInfo;
      }

      // Generate entries JSON
      if (_entries.isEmpty) {
        diagnosticInfo['warnings'].add('No local entries to sync');
      } else {
        try {
          // Prepare the JSON
          final List<Map<String, dynamic>> jsonList =
              _entries.map((entry) => entry.toJson()).toList();
          final entriesJson = jsonEncode(jsonList);
          diagnosticInfo['entriesJsonLength'] = entriesJson.length;

          // Try to sync to Supabase
          try {
            // Check if entry exists
            final existingEntry = await Supabase.instance.client
                .from('user_food_entries')
                .select('user_id')
                .eq('user_id', currentUser.id)
                .limit(1)
                .maybeSingle();

            if (existingEntry != null) {
              // Update existing entry
              await Supabase.instance.client.from('user_food_entries').update({
                'entries_json': entriesJson,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('user_id', currentUser.id);
              diagnosticInfo['action'] = 'updated';
            } else {
              // Insert new entry
              await Supabase.instance.client.from('user_food_entries').insert({
                'user_id': currentUser.id,
                'entries_json': entriesJson,
                'updated_at': DateTime.now().toIso8601String(),
              });
              diagnosticInfo['action'] = 'inserted';
            }

            // Verify the sync was successful
            final verification = await Supabase.instance.client
                .from('user_food_entries')
                .select('entries_json')
                .eq('user_id', currentUser.id)
                .limit(1)
                .maybeSingle();

            if (verification != null && verification['entries_json'] != null) {
              final syncedJson = verification['entries_json'];
              if (syncedJson is String) {
                final decodedSynced = jsonDecode(syncedJson) as List;
                diagnosticInfo['syncedEntriesCount'] = decodedSynced.length;
                diagnosticInfo['syncVerified'] =
                    decodedSynced.length == _entries.length;

                if (decodedSynced.length != _entries.length) {
                  diagnosticInfo['warnings'].add(
                      'Synced count (${decodedSynced.length}) does not match local count (${_entries.length})');
                }
              } else {
                diagnosticInfo['warnings']
                    .add('Synced data is not in expected string format');
              }
            } else {
              diagnosticInfo['warnings']
                  .add('Could not verify sync - no data found');
            }

            diagnosticInfo['success'] = true;
          } catch (syncError) {
            diagnosticInfo['errors']
                .add('Sync operation error: ${syncError.toString()}');
            if (syncError is PostgrestException) {
              diagnosticInfo['postgrestError'] = {
                'code': syncError.code,
                'message': syncError.message,
              };
            }
          }
        } catch (jsonError) {
          diagnosticInfo['errors']
              .add('JSON encoding error: ${jsonError.toString()}');
        }
      }
    } catch (e) {
      diagnosticInfo['errors'].add('General error: ${e.toString()}');
    }

    return diagnosticInfo;
  }

  Future<void> loadEntriesFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      debugPrint('Explicitly loading food entries from Supabase...');

      final response = await Supabase.instance.client
          .from('user_food_entries')
          .select('entries_json')
          .eq('user_id', currentUser.id)
          .limit(1)
          .maybeSingle();

      if (response != null && response['entries_json'] != null) {
        final entriesJson = response['entries_json'];
        if (entriesJson is String && entriesJson.isNotEmpty) {
          final List<dynamic> entriesData = jsonDecode(entriesJson);

          _entries = entriesData
              .map((entryData) => FoodEntry.fromJson(entryData))
              .toList();

          // Save to local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_storageKey, entriesJson);

          notifyListeners();
          _updateWidgets();

          debugPrint(
              'Successfully loaded ${_entries.length} entries from Supabase');
        }
      }
    } catch (e) {
      debugPrint('Error loading entries from Supabase: $e');
    }
  }
}
