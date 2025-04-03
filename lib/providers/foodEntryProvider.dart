// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:math'; // Added for min function
import '../services/widget_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel

// Define the channel name consistently
const String _statsChannelName = 'app.macrobalance.com/stats';
const MethodChannel _statsChannel = MethodChannel(_statsChannelName);

class FoodEntryProvider with ChangeNotifier {
  List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';

  // Daily nutrition goals
  double _caloriesGoal = 2000.0;
  double _proteinGoal = 150.0;
  double _carbsGoal = 225.0;
  double _fatGoal = 65.0;

  // Additional goals and parameters
  int _stepsGoal = 10000;
  double _bmr = 1500.0;
  double _tdee = 2000.0;
  double _goalWeightKg = 0.0;
  double _currentWeightKg = 0.0;
  String _goalType =
      "maintain"; // Changed from int to String, default "maintain"
  int _deficitSurplus = 500;

  // Cache for date entries
  final Map<String, List<FoodEntry>> _dateEntriesCache = {};
  final Map<String, DateTime> _dateCacheTimestamp = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Flag to prevent multiple initial loads
  bool _initialLoadComplete = false;

  FoodEntryProvider() {
    // Load data asynchronously without blocking constructor
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialLoadComplete) return;
    await _loadEntries();
    await loadNutritionGoals(); // Use the public method
    _initialLoadComplete = true;
    debugPrint("FoodEntryProvider initialized.");
  }

  /// Ensures the provider is initialized, loading data if needed.
  Future<void> ensureInitialized() async {
    if (!_initialLoadComplete) {
      await _initialize();
    }
  }

  List<FoodEntry> get entries => _entries;

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

  // Helper to convert goal type between int and string
  int get goalTypeAsInt {
    switch (_goalType) {
      case "maintain":
        return 1;
      case "lose":
        return 2;
      case "gain":
        return 3;
      default:
        return 1;
    }
  }

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

  set bmr(double value) {
    _bmr = value;
    _saveNutritionGoals();
    notifyListeners();
  }

  set tdee(double value) {
    _tdee = value;
    _saveNutritionGoals();
    notifyListeners();
  }

  set goalWeightKg(double value) {
    _goalWeightKg = value;
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  set currentWeightKg(double value) {
    _currentWeightKg = value;
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  set goalType(String value) {
    _goalType = value;
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  // Also provide a setter for int-based goal type for backward compatibility
  set goalTypeAsInt(int value) {
    switch (value) {
      case 1:
        _goalType = "maintain";
        break;
      case 2:
        _goalType = "lose";
        break;
      case 3:
        _goalType = "gain";
        break;
      default:
        _goalType = "maintain";
    }
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  set deficitSurplus(int value) {
    _deficitSurplus = value;
    _saveNutritionGoals();
    notifyListeners();
    _syncNutritionGoalsToSupabase();
  }

  // New method to update all goals at once
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
    _tdee = tdee;

    _saveNutritionGoals(); // Save locally
    notifyListeners(); // Notify UI
    _updateWidgets(); // Update widgets (if applicable)
    _syncNutritionGoalsToSupabase(); // Sync to Supabase
  }

  Future<void> _loadEntries() async {
    try {
      // First try to load from StorageService (Hive)
      final String? entriesJson = StorageService().get(_storageKey);

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

              // Save the Supabase data locally (now synchronous)
              StorageService().put(_storageKey, processedJson);
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

  /// Loads nutrition goals from local storage (Hive) and syncs with Supabase if necessary.
  /// Prioritizes 'nutrition_goals' key, then falls back to individual keys and 'macro_results'.
  Future<void> loadNutritionGoals() async {
    debugPrint("Loading nutrition goals..."); // Add debug print
    try {
      // First load the basic goals from StorageService (Hive)
      _caloriesGoal =
          StorageService().get('calories_goal', defaultValue: 2000.0);
      _proteinGoal = StorageService().get('protein_goal', defaultValue: 150.0);
      _carbsGoal = StorageService().get('carbs_goal', defaultValue: 225.0);
      _fatGoal =
          StorageService().get('fat_goal', defaultValue: 65.0); // Fallback

      // --- Prioritize loading from 'nutrition_goals' ---
      final String? nutritionGoalsJson =
          StorageService().get('nutrition_goals');
      bool loadedFromNutritionGoals = false;
      if (nutritionGoalsJson != null && nutritionGoalsJson.isNotEmpty) {
        try {
          final Map<String, dynamic> goals = jsonDecode(nutritionGoalsJson);

          // Load macro targets first
          if (goals['macro_targets'] != null && goals['macro_targets'] is Map) {
            final targets = goals['macro_targets'] as Map<String, dynamic>;
            _caloriesGoal = (targets['calories'] ?? _caloriesGoal).toDouble();
            _proteinGoal = (targets['protein'] ?? _proteinGoal).toDouble();
            _carbsGoal = (targets['carbs'] ?? _carbsGoal).toDouble();
            _fatGoal = (targets['fat'] ?? _fatGoal).toDouble();
          } else {
            // Fallback to top-level goals if macro_targets is missing
            _caloriesGoal =
                (goals['calories_goal'] ?? _caloriesGoal).toDouble();
            _proteinGoal = (goals['protein_goal'] ?? _proteinGoal).toDouble();
            _carbsGoal = (goals['carbs_goal'] ?? _carbsGoal).toDouble();
            _fatGoal = (goals['fat_goal'] ?? _fatGoal).toDouble();
          }

          // Load other goals
          _goalWeightKg = (goals['goal_weight_kg'] ?? _goalWeightKg).toDouble();
          _currentWeightKg =
              (goals['current_weight_kg'] ?? _currentWeightKg).toDouble();
          _goalType = goals['goal_type'] ?? _goalType;
          _deficitSurplus = goals['deficit_surplus'] ?? _deficitSurplus;
          _stepsGoal = goals['steps_goal'] ?? _stepsGoal;
          _bmr = (goals['bmr'] ?? _bmr).toDouble();
          _tdee = (goals['tdee'] ?? _tdee).toDouble();

          loadedFromNutritionGoals = true;
          debugPrint('Successfully loaded goals from "nutrition_goals"');
        } catch (e) {
          debugPrint('Error parsing nutrition_goals JSON: $e');
        }
      }

      // --- Fallback to individual keys and 'macro_results' if 'nutrition_goals' failed or was missing ---
      if (!loadedFromNutritionGoals) {
        debugPrint(
            'Falling back to loading goals from individual keys / macro_results');
        // Load individual keys (already done above for basic goals)
        _goalWeightKg =
            StorageService().get('goal_weight_kg', defaultValue: _goalWeightKg);
        _currentWeightKg = StorageService()
            .get('current_weight', defaultValue: _currentWeightKg);

        // Check macro_results for more comprehensive goal data
        final String? macroResultsJson = StorageService().get('macro_results');
        if (macroResultsJson != null && macroResultsJson.isNotEmpty) {
          try {
            final Map<String, dynamic> macroResults =
                jsonDecode(macroResultsJson);

            // Only update if not already set by nutrition_goals (which failed)
            // Use the keys found in the saved JSON: target_calories, protein_g, carb_g, fat_g
            _caloriesGoal = (macroResults['target_calories'] ??
                    macroResults['calories'] ??
                    macroResults['calorie_target'] ??
                    _caloriesGoal)
                .toDouble();
            _proteinGoal = (macroResults['protein_g'] ??
                    macroResults['protein'] ??
                    _proteinGoal)
                .toDouble();
            _carbsGoal =
                (macroResults['carb_g'] ?? macroResults['carbs'] ?? _carbsGoal)
                    .toDouble();
            _fatGoal =
                (macroResults['fat_g'] ?? macroResults['fat'] ?? _fatGoal)
                    .toDouble();
            _stepsGoal = (macroResults['recommended_steps'] ??
                macroResults['steps_goal'] ??
                _stepsGoal); // Check both keys
            _bmr = (macroResults['bmr'] ?? _bmr).toDouble();
            _tdee = (macroResults['tdee'] ?? _tdee).toDouble();

            // Load goal type and deficit/surplus if available
            if (macroResults['goal_type'] != null) {
              final goalTypeValue = macroResults['goal_type'];
              if (goalTypeValue is int) {
                switch (goalTypeValue) {
                  case 1:
                    _goalType = "maintain";
                    break;
                  case 2:
                    _goalType = "lose";
                    break;
                  case 3:
                    _goalType = "gain";
                    break;
                  default:
                    _goalType = "maintain";
                }
              } else if (goalTypeValue is String) {
                _goalType = goalTypeValue;
              }
            }

            if (macroResults['deficit_surplus'] != null) {
              _deficitSurplus = macroResults['deficit_surplus'] is int
                  ? macroResults['deficit_surplus']
                  : int.tryParse(macroResults['deficit_surplus'].toString()) ??
                      _deficitSurplus;
            }
          } catch (e) {
            debugPrint('Error parsing macro_results JSON during fallback: $e');
          }
        } else {
          // If macro_results was empty or parsing failed, set loadedFromNutritionGoals to false
          // This ensures we still attempt Supabase sync if primary load failed.
          loadedFromNutritionGoals = false;
        }
      }

      // --- Sync with Supabase (only if we didn't just load from macro_results fallback) ---
      final currentUser = Supabase.instance.client.auth.currentUser;
      // Check if we successfully loaded from 'nutrition_goals' OR if the fallback from 'macro_results' was NOT used.
      // The flag 'loadedFromNutritionGoals' is slightly misnamed now, it indicates if we loaded from *any* primary local source successfully.
      // Let's rename the flag for clarity.
      bool loadedFromLocalSource =
          loadedFromNutritionGoals; // Rename for clarity

      if (currentUser != null && !loadedFromLocalSource) {
        debugPrint(
            'Attempting to sync nutrition goals from Supabase as local load was incomplete or skipped.');
        await _syncNutritionGoalsFromSupabase();
      } else if (currentUser != null && loadedFromLocalSource) {
        // Only sync to Supabase if we have valid non-default values
        if (_caloriesGoal != 2000.0 ||
            _proteinGoal != 150.0 ||
            _carbsGoal != 225.0 ||
            _fatGoal != 65.0) {
          debugPrint(
              'Fresh local data found. Syncing this data to Supabase...');
          // Since we have fresh local data, sync it to Supabase
          await _syncNutritionGoalsToSupabase();
        } else {
          // The local values are still default values, so try to load from Supabase first
          debugPrint(
              'Local values are default values. Checking Supabase for saved values...');
          await _syncNutritionGoalsFromSupabase();
        }
      }

      // Notify listeners about the updated values
      notifyListeners();
      _updateWidgets();
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  Future<void> _syncNutritionGoalsFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      debugPrint('Starting sync FROM Supabase, current values:');
      debugPrint('Current local calories: $_caloriesGoal');
      debugPrint('Current local protein: $_proteinGoal');
      debugPrint('Current local carbs: $_carbsGoal');
      debugPrint('Current local fat: $_fatGoal');

      // Fetch the user_macros row, specifically selecting the macro_results column
      final response = await Supabase.instance.client
          .from('user_macros')
          .select('macro_results') // Select only the relevant column
          .eq('id', currentUser.id)
          .maybeSingle();

      bool loadedFromSupabase = false;
      if (response != null && response['macro_results'] != null) {
        try {
          final macroResults = response['macro_results'];
          if (macroResults is Map) {
            debugPrint('Loading goals from Supabase macro_results column...');

            // Store original values for comparison
            final originalCalories = _caloriesGoal;
            final originalProtein = _proteinGoal;
            final originalCarbs = _carbsGoal;
            final originalFat = _fatGoal;

            // Extract goals using keys confirmed from user feedback
            _caloriesGoal = (macroResults['target_calories'] ??
                    macroResults['calories'] ??
                    _caloriesGoal)
                .toDouble();
            _proteinGoal = (macroResults['protein_g'] ??
                    macroResults['protein'] ??
                    _proteinGoal)
                .toDouble();
            _carbsGoal =
                (macroResults['carb_g'] ?? macroResults['carbs'] ?? _carbsGoal)
                    .toDouble();
            _fatGoal =
                (macroResults['fat_g'] ?? macroResults['fat'] ?? _fatGoal)
                    .toDouble();
            _stepsGoal = (macroResults['recommended_steps'] ??
                    macroResults['steps_goal'] ??
                    _stepsGoal)
                .toInt();
            _bmr = (macroResults['bmr'] ?? _bmr).toDouble();
            _tdee = (macroResults['tdee'] ?? _tdee).toDouble();

            // Handle weight goals (check nested structure if needed)
            if (macroResults['weight_stats'] != null &&
                macroResults['weight_stats'] is Map) {
              final weightStats =
                  macroResults['weight_stats'] as Map<String, dynamic>;
              _goalWeightKg =
                  (weightStats['goal_weight'] ?? _goalWeightKg).toDouble();
              _currentWeightKg =
                  (weightStats['current_weight'] ?? _currentWeightKg)
                      .toDouble();
            } else {
              // Fallback to top-level keys if weight_stats is missing
              _goalWeightKg = (macroResults['goal_weight_kg'] ??
                      macroResults['goal_weight'] ??
                      _goalWeightKg)
                  .toDouble();
              _currentWeightKg = (macroResults['current_weight_kg'] ??
                      macroResults['current_weight'] ??
                      _currentWeightKg)
                  .toDouble();
            }

            // Handle goal type and deficit (ensure correct types)
            _goalType = macroResults['goal_type']?.toString() ?? _goalType;
            _deficitSurplus =
                (macroResults['deficit_surplus'] ?? _deficitSurplus).toInt();

            loadedFromSupabase = true;
            debugPrint('Successfully loaded goals from Supabase macro_results');
            debugPrint('Values updated from Supabase:');
            debugPrint('Calories: $originalCalories -> $_caloriesGoal');
            debugPrint('Protein: $originalProtein -> $_proteinGoal');
            debugPrint('Carbs: $originalCarbs -> $_carbsGoal');
            debugPrint('Fat: $originalFat -> $_fatGoal');
          } else {
            debugPrint('Supabase macro_results column is not a valid Map.');
          }
        } catch (e) {
          debugPrint('Error parsing Supabase macro_results: $e');
        }
      } else {
        debugPrint(
            'No macro_results found in Supabase for user ${currentUser.id}');
      }

      // If data was loaded from Supabase, save it locally and notify
      if (loadedFromSupabase) {
        _saveNutritionGoals(); // Save the updated goals locally (now synchronous)
        notifyListeners();
        _updateWidgets();

        debugPrint('Successfully synced nutrition goals from Supabase');
        debugPrint('Calories Goal: $_caloriesGoal');
        debugPrint('Protein Goal: $_proteinGoal');
        debugPrint('Carbs Goal: $_carbsGoal');
        debugPrint('Fat Goal: $_fatGoal');
      }
    } catch (e) {
      debugPrint('Error syncing nutrition goals from Supabase: $e');
      if (e is PostgrestException) {
        debugPrint('Supabase error code: ${e.code}');
        debugPrint('Supabase error message: ${e.message}');
      }
    }
  }

  // Now synchronous as StorageService.put is sync
  /// Saves the current nutrition goals state to local storage (Hive) under the 'nutrition_goals' key.
  void _saveNutritionGoals() {
    debugPrint("Saving nutrition goals locally..."); // Add debug print
    try {
      // Consolidate all goals into a single structured map
      final Map<String, dynamic> nutritionGoals = {
        // Use a nested map for macro targets for clarity
        'macro_targets': {
          'calories': _caloriesGoal.isFinite ? _caloriesGoal : 0.0,
          'protein': _proteinGoal.isFinite ? _proteinGoal : 0.0,
          'carbs': _carbsGoal.isFinite ? _carbsGoal : 0.0,
          'fat': _fatGoal.isFinite ? _fatGoal : 0.0,
        },
        'goal_weight_kg': _goalWeightKg.isFinite ? _goalWeightKg : 0.0,
        'current_weight_kg': _currentWeightKg.isFinite ? _currentWeightKg : 0.0,
        'goal_type': _goalType, // Saving as string
        'deficit_surplus': _deficitSurplus,
        'steps_goal': _stepsGoal,
        'bmr': _bmr.isFinite ? _bmr : 0.0,
        'tdee': _tdee.isFinite ? _tdee : 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save the consolidated map to the 'nutrition_goals' key
      StorageService().put('nutrition_goals', jsonEncode(nutritionGoals));
      debugPrint("Successfully saved goals to 'nutrition_goals' key.");

      // Remove saving to individual keys and the separate 'macro_results' key locally
      // StorageService().delete('calories_goal'); // Optional: Clean up old keys
      // StorageService().delete('protein_goal');
      // StorageService().delete('carbs_goal');
      // StorageService().delete('fat_goal');
      // StorageService().delete('goal_weight_kg');
      // StorageService().delete('current_weight');
      // StorageService().delete('macro_results'); // Remove local macro_results saving
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
    }
  }

  Future<void> _syncNutritionGoalsToSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Check if we have default values - don't sync defaults to Supabase
      if (_caloriesGoal == 2000.0 &&
          _proteinGoal == 150.0 &&
          _carbsGoal == 225.0 &&
          _fatGoal == 65.0) {
        debugPrint(
            'Skipping sync TO Supabase - these appear to be default values');
        // Instead, try to get values from Supabase
        await _syncNutritionGoalsFromSupabase();
        return;
      }

      // First check if Supabase has newer data
      final existingData = await Supabase.instance.client
          .from('user_macros')
          .select('updated_at, macro_results')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (existingData != null && existingData['updated_at'] != null) {
        try {
          // Parse the timestamp from Supabase
          final remoteTimestamp = DateTime.parse(existingData['updated_at']);
          // Get our current local time
          final localTimestamp = DateTime.now();
          // If the remote data is newer than 1 minute ago, fetch it instead of overwriting
          if (localTimestamp.difference(remoteTimestamp).inMinutes < 1) {
            debugPrint(
                'Remote data is recent (${remoteTimestamp.toIso8601String()}). Fetching remote data instead of overwriting.');
            await _syncNutritionGoalsFromSupabase();
            return;
          }
        } catch (e) {
          debugPrint('Error parsing timestamp: $e');
        }
      }

      // Construct the comprehensive macro_results JSON object
      final Map<String, dynamic> macroResultsData = {
        // Use 'calorie_target' for consistency with onboarding if needed, or just 'calories'
        'calories': _caloriesGoal.isFinite ? _caloriesGoal : null,
        'calorie_target': _caloriesGoal.isFinite
            ? _caloriesGoal
            : null, // Include both for compatibility?
        'protein': _proteinGoal.isFinite ? _proteinGoal : null,
        'carbs': _carbsGoal.isFinite ? _carbsGoal : null,
        'fat': _fatGoal.isFinite ? _fatGoal : null,
        'goal_weight_kg':
            _goalWeightKg > 0 && _goalWeightKg.isFinite ? _goalWeightKg : null,
        'current_weight_kg': _currentWeightKg > 0 && _currentWeightKg.isFinite
            ? _currentWeightKg
            : null,
        'goal_type': _goalType,
        'deficit_surplus': _deficitSurplus,
        'recommended_steps': _stepsGoal, // Match key from onboarding
        'steps_goal': _stepsGoal, // Include both?
        'bmr': _bmr.isFinite ? _bmr : null,
        'tdee': _tdee.isFinite ? _tdee : null,
        // Add any other relevant fields saved during onboarding if needed
        // 'gender': ...,
        // 'weight': _currentWeightKg, // Redundant?
        // 'height': ...,
        // 'age': ...,
        // 'activity_level': ...,
        // 'protein_ratio': ...,
        // 'fat_ratio': ...,
        // 'body_fat_percentage': ...,
        'updated_at':
            DateTime.now().toIso8601String(), // Add timestamp within JSON
      };

      // Remove null values to keep the JSON clean
      macroResultsData.removeWhere((key, value) => value == null);

      // Prepare the data for upsert, targeting ONLY the 'macro_results' column
      final Map<String, dynamic> upsertData = {
        'id': currentUser.id, // Primary key
        'macro_results': macroResultsData, // The consolidated JSON object
        'updated_at': DateTime.now().toIso8601String(), // Row update timestamp
        // 'email': currentUser.email, // Keep email if it's part of the table structure and needed
      };
      // No need to remove nulls here as we are only sending essential fields.
      // Ensure the 'user_macros' table allows nulls for other columns or has defaults.

      // Upsert the data into the 'user_macros' table
      // This will update the 'macro_results' and 'updated_at' columns for the user's row.
      await Supabase.instance.client.from('user_macros').upsert(upsertData);

      debugPrint(
          'Nutrition goals synced to Supabase (macro_results column) successfully');

      // Optional: Verify the sync by fetching the macro_results column
      final verification = await Supabase.instance.client
          .from('user_macros')
          .select('macro_results')
          .eq('id', currentUser.id)
          .single();

      if (verification != null && verification['macro_results'] != null) {
        debugPrint(
            'Sync verification successful. Synced macro_results: ${jsonEncode(verification['macro_results']).substring(0, min(100, jsonEncode(verification['macro_results']).length))}...'); // Log truncated JSON
      } else {
        debugPrint('Sync verification failed or no macro_results found.');
      }
    } catch (e) {
      debugPrint(
          'Error syncing nutrition goals (macro_results) to Supabase: $e');
      if (e is PostgrestException) {
        debugPrint('Supabase error code: ${e.code}');
        debugPrint('Supabase error message: ${e.message}');

        // Retry once for certain error codes
        if (e.code == '23505' || e.code == '23502') {
          try {
            await Future.delayed(const Duration(seconds: 1));
            await _syncNutritionGoalsToSupabase();
          } catch (retryError) {
            debugPrint('Retry failed: $retryError');
          }
        }
      }
    }
  }

  Future<void> _saveEntries() async {
    try {
      final entriesJson = jsonEncode(
        _entries.map((entry) => entry.toJson()).toList(),
      );

      // Save locally (now synchronous)
      StorageService().put(_storageKey, entriesJson);

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

  // Now synchronous
  void clearEntries() {
    _entries.clear();
    notifyListeners();

    // Only clear from local storage, not from Supabase
    StorageService().delete(_storageKey);

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
    // Convert date to local timezone for consistent comparison
    final localDate = date.toLocal();
    final startOfDay = DateTime(localDate.year, localDate.month, localDate.day);
    final endOfDay = DateTime(
        localDate.year, localDate.month, localDate.day, 23, 59, 59, 999);

    // Create cache key in format 'YYYY-MM-DD'
    final cacheKey =
        '${startOfDay.year}-${startOfDay.month.toString().padLeft(2, '0')}-${startOfDay.day.toString().padLeft(2, '0')}';

    // Check if we have a valid cache entry
    if (_dateEntriesCache.containsKey(cacheKey)) {
      final cacheTimestamp = _dateCacheTimestamp[cacheKey];
      if (cacheTimestamp != null &&
          DateTime.now().difference(cacheTimestamp) < _cacheDuration) {
        // Cache is still valid
        return _dateEntriesCache[cacheKey]!;
      }
    }

    // If cache is invalid or missing, filter entries
    final filteredEntries = _entries.where((entry) {
      final entryDate = entry.date.toLocal();
      return !entryDate.isBefore(startOfDay) && !entryDate.isAfter(endOfDay);
    }).toList();

    // Update cache
    _dateEntriesCache[cacheKey] = filteredEntries;
    _dateCacheTimestamp[cacheKey] = DateTime.now();

    return filteredEntries;
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

  // Method to notify native side about data changes
  Future<void> _notifyNativeStatsChanged() async {
    try {
      // We don't need to send data, just notify that it changed
      await _statsChannel.invokeMethod('macrosDataChanged');
      debugPrint('[FoodEntryProvider] Notified native side: macrosDataChanged');
    } on PlatformException catch (e) {
      debugPrint(
          '[FoodEntryProvider] Failed to notify native side: ${e.message}');
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

          // Save to local storage (now synchronous)
          StorageService().put(_storageKey, entriesJson);

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

  // Clear cache when entries are modified
  Future<void> _clearDateCache() async {
    _dateEntriesCache.clear();
    _dateCacheTimestamp.clear();
  }

  /// Resets internal goal variables to default values and notifies listeners.
  /// Does NOT clear storage - that should be done separately.
  void resetGoalsToDefault() {
    _caloriesGoal = 2000.0;
    _proteinGoal = 150.0;
    _carbsGoal = 225.0;
    _fatGoal = 65.0;
    _stepsGoal = 10000;
    _bmr = 1500.0;
    _tdee = 2000.0;
    _goalWeightKg = 0.0;
    _currentWeightKg = 0.0;
    _goalType = "maintain";
    _deficitSurplus = 500;

    debugPrint('FoodEntryProvider goals reset to default values.');
    _saveNutritionGoals(); // Ensure values are saved locally
    notifyListeners();
    _updateWidgets(); // Update widgets with default goals
    _syncNutritionGoalsToSupabase(); // Sync default values to Supabase
  }
}
